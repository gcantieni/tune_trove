import CloudKit
import Foundation
#if canImport(UIKit)
import Flutter
#elseif canImport(AppKit)
import FlutterMacOS
#endif

enum CloudKitSyncChannels {
    static let method = "com.gcantieni.tuneTrove/cloudkit_sync"
    static let event  = "com.gcantieni.tuneTrove/cloudkit_sync_state"
}

/// Bridges the Drift database to CloudKit via `CKSyncEngine`.
///
/// The engine owns zone creation, change-token persistence, batching, retry and
/// backoff. Dart drives an explicit, deterministic sync cycle:
///   1. `fetchChanges` — pulls remote records and returns them as the result.
///   2. Dart reconciles them into Drift (dedupe + last-writer-wins).
///   3. `stageRecords` — Dart serializes local rows to upload.
///   4. `sendChanges` — flushes staged changes to CloudKit.
///
/// `automaticallySync` is disabled so every sync is request/response and there
/// is no background interleaving to race against reconciliation.
@available(iOS 17, macOS 14, *)
@MainActor
final class CloudKitSyncBridge: NSObject {
    /// The active bridge, so the app delegate's push handler can reach it
    /// without threading a reference through Flutter's engine plumbing.
    static weak var shared: CloudKitSyncBridge?

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private let ckContainer = CKContainer(identifier: "iCloud.com.gcantieni.tuneTrove")
    private var database: CKDatabase { ckContainer.privateCloudDatabase }
    private let zoneID = CKRecordZone.ID(
        zoneName: "TuneTroveZone",
        ownerName: CKCurrentUserDefaultName
    )
    private let subscriptionID = "tune-trove-db-changes"

    private var syncEngine: CKSyncEngine?

    /// Field maps staged from Dart, keyed by record name (cloudId), awaiting send.
    private var pendingRecordMaps: [String: [String: Any]] = [:]

    /// Server records observed during a fetch, reused when sending so an update
    /// carries the current change tag instead of conflicting.
    private var serverRecordCache: [CKRecord.ID: CKRecord] = [:]

    /// Accumulators populated during an explicit `fetchChanges` call.
    private var fetchedUpserts: [[String: Any]] = []
    private var fetchedDeletions: [[String: Any]] = []

    /// Accumulators populated during an explicit `sendChanges` call. Records
    /// that fail with a recoverable error (conflict, missing zone) are re-staged
    /// rather than counted here — only terminal failures land in `sentFailures`.
    private var sentSavedCount = 0
    private var sentFailures: [String] = []

    /// Counts conflicts during a send that resolved in the *server's* favor — we
    /// abandoned that many local pushes and should warn the user + pull.
    private var serverWonCount = 0

    func setup(binaryMessenger: FlutterBinaryMessenger) {
        let method = FlutterMethodChannel(
            name: CloudKitSyncChannels.method,
            binaryMessenger: binaryMessenger
        )
        let event = FlutterEventChannel(
            name: CloudKitSyncChannels.event,
            binaryMessenger: binaryMessenger
        )
        // Flutter dispatches channel calls on the platform (main) thread, so we
        // can safely assume main-actor isolation when hopping into the bridge.
        method.setMethodCallHandler { [weak self] call, result in
            MainActor.assumeIsolated { self?.handleMethod(call, result: result) }
        }
        event.setStreamHandler(self)
        methodChannel = method
        eventChannel = event
        CloudKitSyncBridge.shared = self
    }

    // MARK: - Push notifications

    /// Called by the app delegate when a remote notification arrives. Returns
    /// true if it was a CloudKit push for our subscription (and a sync was
    /// nudged), so the delegate can report `.newData`.
    @discardableResult
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == subscriptionID
        else { return false }
        print("[CKSync] remote push received — nudging Dart to sync")
        eventSink?(["type": "remoteChange"])
        return true
    }

    /// Registers a silent database subscription so CloudKit pushes when another
    /// device changes data. Idempotent; guarded by a persisted flag.
    private func ensureSubscription() {
        let key = "ck_subscription_\(subscriptionID)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        Task {
            do {
                let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
                let info = CKSubscription.NotificationInfo()
                info.shouldSendContentAvailable = true
                subscription.notificationInfo = info
                _ = try await database.modifySubscriptions(
                    saving: [subscription],
                    deleting: []
                )
                UserDefaults.standard.set(true, forKey: key)
                print("[CKSync] database subscription registered")
            } catch {
                print("[CKSync] subscription registration failed: \(describeError(error))")
            }
        }
    }

    // MARK: - Method channel

    private func handleMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Runs on the main actor (the enclosing class is @MainActor), so the
        // FlutterResult callbacks below are invoked on the platform thread.
        Task {
            do {
                switch call.method {
                case "isAvailable":
                    let status = try await ckContainer.accountStatus()
                    result(status == .available)

                case "initialize":
                    initializeEngine()
                    result(nil)

                case "fetchChanges":
                    let changes = try await performFetch()
                    result(changes)

                case "stageRecords":
                    guard let records = call.arguments as? [[String: Any]] else {
                        result(badArgs())
                        return
                    }
                    stageRecords(records)
                    result(nil)

                case "stageDeletions":
                    guard let dels = call.arguments as? [[String: Any]] else {
                        result(badArgs())
                        return
                    }
                    stageDeletions(dels)
                    result(nil)

                case "sendChanges":
                    let summary = try await performSend()
                    result(summary)

                default:
                    result(FlutterMethodNotImplemented)
                }
            } catch {
                let detail = describeError(error)
                print("[CKSync] ERROR method=\(call.method) \(detail)")
                if let ckErr = error as? CKError {
                    print("[CKSync]   userInfo=\(ckErr.userInfo)")
                }
                result(FlutterError(code: "CLOUDKIT_ERROR", message: "\(call.method): \(detail)", details: detail))
            }
        }
    }

    private func badArgs() -> FlutterError {
        FlutterError(code: "BAD_ARGS", message: "expected array argument", details: nil)
    }

    /// Flattens a CKError (and its underlying/partial errors) into one line so
    /// the real reason for a rejection is visible without digging in Xcode.
    private func describeError(_ error: Error) -> String {
        guard let ck = error as? CKError else {
            let ns = error as NSError
            return "\(ns.domain) code=\(ns.code) \(ns.localizedDescription)"
        }
        var parts: [String] = ["CKError code=\(ck.code.rawValue) (\(ck.code))"]
        if let underlying = ck.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying=\(underlying.domain):\(underlying.code)")
        }
        if let retry = ck.retryAfterSeconds {
            parts.append("retryAfter=\(retry)s")
        }
        if let partial = ck.partialErrorsByItemID, !partial.isEmpty {
            parts.append("partialCount=\(partial.count)")
            for (id, itemError) in partial {
                let pe = itemError as NSError
                let name = (id as? CKRecord.ID)?.recordName ?? "\(id)"
                var detail = "code=\(pe.code) \(pe.localizedDescription)"
                // CloudKit puts the precise schema/type rejection reason here.
                if let server = pe.userInfo["ServerErrorDescription"] as? String {
                    detail += " — \(server)"
                }
                parts.append("[\(name): \(detail)]")
            }
        }
        return parts.joined(separator: " ")
    }

    /// Last-writer-wins: true when the server's copy is newer than our pending
    /// local change. Compares `modified_at` and falls back to `created_at`
    /// (matching the inbound reconciliation rule). Returns false (local wins)
    /// when either side lacks a timestamp — e.g. join records
    /// (TuneRecording/SetTune), which have neither.
    private func serverWins(localFor recordName: String, server: CKRecord) -> Bool {
        guard let localMs = localTimestampMs(recordName),
              let serverMs = serverTimestampMs(server)
        else { return false }
        return serverMs > localMs
    }

    private func localTimestampMs(_ recordName: String) -> Int64? {
        guard let map = pendingRecordMaps[recordName] else { return nil }
        if let m = (map["modified_at"] as? NSNumber)?.int64Value { return m }
        if let c = (map["created_at"] as? NSNumber)?.int64Value { return c }
        return nil
    }

    private func serverTimestampMs(_ record: CKRecord) -> Int64? {
        if let d = record["modifiedAt"] as? Date { return Int64(d.timeIntervalSince1970 * 1000) }
        if let d = record["createdAt"] as? Date { return Int64(d.timeIntervalSince1970 * 1000) }
        return nil
    }

    /// True when a failed send was *only* concurrent-edit conflicts
    /// (`serverRecordChanged`), which `handleSentChanges` has already rebased and
    /// re-staged — so the send is safe to retry.
    private func isRecoverableConflict(_ error: CKError) -> Bool {
        guard error.code == .partialFailure,
              let partials = error.partialErrorsByItemID, !partials.isEmpty
        else { return false }
        return partials.values.allSatisfy {
            switch ($0 as? CKError)?.code {
            case .serverRecordChanged, .batchRequestFailed: return true
            default: return false
            }
        }
    }

    // MARK: - Engine lifecycle

    private func initializeEngine() {
        guard syncEngine == nil else { return }
        loadPendingMaps()
        var config = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: loadState(),
            delegate: self
        )
        config.automaticallySync = false
        let engine = CKSyncEngine(config)
        // Ensure the custom zone exists before the first record send. Saving an
        // existing zone is a no-op, so this is safe to issue on every launch.
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        syncEngine = engine
        ensureSubscription()
        print("[CKSync] engine initialized")
    }

    private func engineOrThrow() throws -> CKSyncEngine {
        if syncEngine == nil { initializeEngine() }
        guard let engine = syncEngine else {
            throw NSError(
                domain: "CKSync", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "sync engine unavailable"]
            )
        }
        return engine
    }

    // MARK: - Fetch / send

    private func performFetch() async throws -> [String: Any] {
        let engine = try engineOrThrow()
        fetchedUpserts = []
        fetchedDeletions = []
        emitStatus("syncing")
        defer { emitStatus("idle") }
        try await engine.fetchChanges()
        return ["upserts": fetchedUpserts, "deletions": fetchedDeletions]
    }

    private func performSend() async throws -> [String: Any] {
        let engine = try engineOrThrow()
        sentSavedCount = 0
        sentFailures = []
        serverWonCount = 0
        emitStatus("syncing")
        defer { emitStatus("idle") }

        // `sendChanges` throws a `.partialFailure` of `.serverRecordChanged` when
        // another device changed a record concurrently. By the time it throws,
        // `handleSentChanges` has already rebased those records onto the current
        // server records and re-staged them — so retry the send (bounded) to
        // flush the rebased versions instead of deferring to the next sync.
        var attempt = 0
        while true {
            do {
                try await engine.sendChanges()
                break
            } catch let error as CKError where attempt < 3 && isRecoverableConflict(error) {
                attempt += 1
                print("[CKSync] send conflict — resolved (LWW), retrying (attempt \(attempt))")
            }
        }

        // Conflicts the server won mean we dropped local pushes; warn the user
        // and nudge a pull so this device adopts the winning values.
        if serverWonCount > 0 {
            eventSink?(["type": "localOverwritten", "count": serverWonCount])
            eventSink?(["type": "remoteChange"])
        }

        return [
            "saved": sentSavedCount,
            "failedCount": sentFailures.count,
            "failures": Array(sentFailures.prefix(5)),
        ]
    }

    private func stageRecords(_ records: [[String: Any]]) {
        guard let engine = try? engineOrThrow() else { return }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for map in records {
            guard let cloudId = map["cloudId"] as? String, map["recordType"] is String else { continue }
            pendingRecordMaps[cloudId] = map
            changes.append(.saveRecord(CKRecord.ID(recordName: cloudId, zoneID: zoneID)))
        }
        savePendingMaps()
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    private func stageDeletions(_ dels: [[String: Any]]) {
        guard let engine = try? engineOrThrow() else { return }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for del in dels {
            guard let cloudId = del["cloudId"] as? String else { continue }
            pendingRecordMaps.removeValue(forKey: cloudId)
            changes.append(.deleteRecord(CKRecord.ID(recordName: cloudId, zoneID: zoneID)))
        }
        savePendingMaps()
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    // MARK: - Engine state persistence

    private var stateFileURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ck_sync_engine_state.dat")
    }

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateFileURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ serialization: CKSyncEngine.State.Serialization) {
        guard let data = try? JSONEncoder().encode(serialization) else { return }
        try? data.write(to: stateFileURL, options: .atomic)
    }

    // The engine persists *which* records are pending; we separately persist the
    // field data needed to rebuild them, so an incrementally-staged change still
    // sends after an app restart.
    private var mapsFileURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ck_pending_maps.json")
    }

    private func loadPendingMaps() {
        guard let data = try? Data(contentsOf: mapsFileURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        else { return }
        pendingRecordMaps = obj
    }

    private func savePendingMaps() {
        if pendingRecordMaps.isEmpty {
            try? FileManager.default.removeItem(at: mapsFileURL)
            return
        }
        guard JSONSerialization.isValidJSONObject(pendingRecordMaps),
              let data = try? JSONSerialization.data(withJSONObject: pendingRecordMaps)
        else { return }
        try? data.write(to: mapsFileURL, options: .atomic)
    }

    // MARK: - Account changes

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn:
            emitStatus("idle")
        case .signOut, .switchAccounts:
            // Drop in-memory caches; the persisted engine state is reset by the
            // engine itself for the new account. Local user data is preserved.
            pendingRecordMaps.removeAll()
            serverRecordCache.removeAll()
            emitStatus("idle")
        @unknown default:
            break
        }
    }

    // MARK: - Sent-change results (conflicts, missing zone)

    private func handleSentChanges(_ event: CKSyncEngine.Event.SentRecordZoneChanges, engine: CKSyncEngine) {
        for saved in event.savedRecords {
            serverRecordCache[saved.recordID] = saved
            pendingRecordMaps.removeValue(forKey: saved.recordID.recordName)
            sentSavedCount += 1
        }
        if !event.savedRecords.isEmpty { savePendingMaps() }
        for failed in event.failedRecordSaves {
            let record = failed.record
            let error = failed.error
            switch error.code {
            case .serverRecordChanged:
                // Concurrent edit. Resolve last-writer-wins by `modified_at`.
                guard let server = error.serverRecord else {
                    // No server copy to compare — rebase optimistically (local).
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
                    break
                }
                serverRecordCache[record.recordID] = server
                if serverWins(localFor: record.recordID.recordName, server: server) {
                    // Server's copy is newer: abandon our push and pull it so this
                    // device adopts the winning value.
                    pendingRecordMaps.removeValue(forKey: record.recordID.recordName)
                    engine.state.remove(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
                    serverWonCount += 1
                    savePendingMaps()
                } else {
                    // Local is newer (or no comparable timestamp): rebase onto the
                    // server's change tag and retry, overwriting the server copy.
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
                }
            case .zoneNotFound, .userDeletedZone:
                // Recoverable: recreate the zone and retry.
                serverRecordCache.removeValue(forKey: record.recordID)
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            case .batchRequestFailed:
                // Failed only because a sibling in the same batch conflicted;
                // re-stage and retry once the sibling is rebased.
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            case .unknownItem:
                // The record no longer exists server-side (delete race); benign.
                pendingRecordMaps.removeValue(forKey: record.recordID.recordName)
            default:
                // Terminal failure — surface it to the user.
                let reason = describeError(error)
                sentFailures.append("\(record.recordType) \(record.recordID.recordName): \(reason)")
                print("[CKSync] save failed for \(record.recordID.recordName): \(reason)")
            }
        }
    }

    // MARK: - Record <-> map conversion

    /// Builds the inbound field map (snake_case keys) that
    /// `SyncReconciliationService` expects.
    private func fieldsFromRecord(_ record: CKRecord) -> [String: Any] {
        var fields: [String: Any] = ["cloud_id": record.recordID.recordName]
        for key in record.allKeys() {
            let snakeKey = camelToSnake(key)
            switch record[key] {
            case let s as String:
                fields[snakeKey] = s
            case let n as NSNumber:
                fields[snakeKey] = n
            case let d as Date:
                fields[snakeKey] = Int(d.timeIntervalSince1970 * 1000)
            default:
                break
            }
        }
        return fields
    }

    private func populateRecord(_ record: CKRecord, from map: [String: Any]) {
        let skip: Set<String> = ["recordType", "cloudId", "deleted"]
        for (key, value) in map where !skip.contains(key) {
            let ckKey = snakeToCamel(key)
            switch value {
            case let s as String:
                record[ckKey] = s as CKRecordValue
            case let n as NSNumber:
                // Only keys ending in "At" (createdAt, modifiedAt) carry
                // ms-since-epoch timestamps. Keys ending in "Time" (startTime,
                // endTime) are audio-position seconds and must stay numeric.
                if ckKey.hasSuffix("At") {
                    record[ckKey] = Date(timeIntervalSince1970: n.doubleValue / 1000) as CKRecordValue
                } else {
                    record[ckKey] = n as CKRecordValue
                }
            default:
                break
            }
        }
    }

    // MARK: - EventChannel helpers

    private func emitStatus(_ status: String) {
        eventSink?(["type": "status", "status": status])
    }

    // MARK: - String conversion

    private func snakeToCamel(_ s: String) -> String {
        let parts = s.split(separator: "_")
        guard let first = parts.first else { return s }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private func camelToSnake(_ s: String) -> String {
        var result = ""
        for char in s {
            if char.isUppercase && !result.isEmpty {
                result += "_" + char.lowercased()
            } else {
                result += char.lowercased()
            }
        }
        return result
    }
}

// MARK: - CKSyncEngineDelegate

@available(iOS 17, macOS 14, *)
extension CloudKitSyncBridge: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let e):
            saveState(e.stateSerialization)

        case .accountChange(let e):
            handleAccountChange(e)

        case .fetchedRecordZoneChanges(let e):
            for modification in e.modifications {
                let record = modification.record
                serverRecordCache[record.recordID] = record
                fetchedUpserts.append([
                    "recordType": record.recordType,
                    "fields": fieldsFromRecord(record),
                ])
            }
            for deletion in e.deletions {
                serverRecordCache.removeValue(forKey: deletion.recordID)
                fetchedDeletions.append([
                    "recordType": deletion.recordType,
                    "cloudId": deletion.recordID.recordName,
                ])
            }

        case .sentRecordZoneChanges(let e):
            handleSentChanges(e, engine: syncEngine)

        case .fetchedDatabaseChanges, .sentDatabaseChanges,
             .willFetchChanges, .willFetchRecordZoneChanges,
             .didFetchRecordZoneChanges, .didFetchChanges,
             .willSendChanges, .didSendChanges:
            break

        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        // Build records up front on the main actor; the provider closure runs
        // off-actor, so it may only read this prepared local map.
        var prepared: [CKRecord.ID: CKRecord] = [:]
        var orphaned: [CKSyncEngine.PendingRecordZoneChange] = []
        for change in pending {
            guard case .saveRecord(let recordID) = change else { continue }
            guard let map = pendingRecordMaps[recordID.recordName],
                  let recordType = map["recordType"] as? String else {
                // We no longer have data for this id (e.g. deleted locally).
                orphaned.append(.saveRecord(recordID))
                continue
            }
            // Reuse the cached server record (with its change tag) when we have
            // one, so updates apply cleanly; otherwise create a fresh record.
            let record = serverRecordCache[recordID] ?? CKRecord(recordType: recordType, recordID: recordID)
            populateRecord(record, from: map)
            prepared[recordID] = record
        }
        if !orphaned.isEmpty {
            syncEngine.state.remove(pendingRecordZoneChanges: orphaned)
        }

        // Capture an immutable snapshot: the record provider may run on another
        // executor, and capturing a `var` is an error in the Swift 6 language mode.
        let records = prepared
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            records[recordID]
        }
    }
}

// MARK: - FlutterStreamHandler

@available(iOS 17, macOS 14, *)
extension CloudKitSyncBridge: FlutterStreamHandler {
    // Flutter invokes these on the platform (main) thread.
    nonisolated func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        MainActor.assumeIsolated { self.eventSink = events }
        return nil
    }

    nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
        MainActor.assumeIsolated { self.eventSink = nil }
        return nil
    }
}
