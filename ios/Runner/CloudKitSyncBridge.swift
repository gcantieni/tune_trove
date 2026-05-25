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

@available(iOS 15, macOS 14, *)
class CloudKitSyncBridge: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private let ckContainer = CKContainer(identifier: "iCloud.com.gcantieni.tuneTrove")
    private var privateDB: CKDatabase { ckContainer.privateCloudDatabase }
    private let zoneID = CKRecordZone.ID(
        zoneName: "TuneTroveZone",
        ownerName: CKCurrentUserDefaultName
    )

    func setup(binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: CloudKitSyncChannels.method,
            binaryMessenger: binaryMessenger
        )
        eventChannel = FlutterEventChannel(
            name: CloudKitSyncChannels.event,
            binaryMessenger: binaryMessenger
        )
        methodChannel?.setMethodCallHandler(handleMethod)
        eventChannel?.setStreamHandler(self)
    }

    private func handleMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("[CKSync] handleMethod: \(call.method)")
        Task {
            do {
                switch call.method {
                case "isAvailable":
                    let status = try await ckContainer.accountStatus()
                    await MainActor.run { result(status == .available) }

                case "startSync":
                    try await ensureZoneExists()
                    try await fetchRemoteChanges()
                    await MainActor.run { result(nil) }

                case "pushChanges":
                    guard let records = call.arguments as? [[String: Any]] else {
                        await MainActor.run {
                            result(FlutterError(code: "BAD_ARGS", message: "records array required", details: nil))
                        }
                        return
                    }
                    try await pushChanges(records: records)
                    await MainActor.run { result(nil) }

                case "subscribeToChanges":
                    try await setupDatabaseSubscription()
                    await MainActor.run { result(nil) }

                default:
                    await MainActor.run { result(FlutterMethodNotImplemented) }
                }
            } catch {
                let ckErr = error as? CKError
                let code = ckErr?.code.rawValue ?? -1
                let info = ckErr?.userInfo ?? [:]
                print("[CKSync] ERROR code=\(code) desc=\(error.localizedDescription) info=\(info)")
                await MainActor.run {
                    result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Zone Management

    private func ensureZoneExists() async throws {
        let key = "ck_zone_created_\(zoneID.zoneName)"
        let alreadyKnown = UserDefaults.standard.bool(forKey: key)
        print("[CKSync] ensureZoneExists: alreadyKnown=\(alreadyKnown)")
        guard !alreadyKnown else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
            print("[CKSync] ensureZoneExists: zone created OK")
        } catch let ckErr as CKError
            where ckErr.code == .serverRecordChanged || ckErr.code == .unknownItem {
            print("[CKSync] ensureZoneExists: swallowed \(ckErr.code.rawValue) — zone exists on server")
        } catch {
            print("[CKSync] ensureZoneExists: UNEXPECTED ERROR \(error)")
            throw error
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Push local → CloudKit

    private func pushChanges(records: [[String: Any]]) async throws {
        print("[CKSync] pushChanges: building from \(records.count) maps")
        var toSave: [CKRecord] = []
        var toDelete: [CKRecord.ID] = []

        for map in records {
            guard let recordType = map["recordType"] as? String,
                  let cloudId = map["cloudId"] as? String else { continue }
            let recordID = CKRecord.ID(recordName: cloudId, zoneID: zoneID)
            if let deleted = map["deleted"] as? Bool, deleted {
                toDelete.append(recordID)
            } else {
                // Use a fresh CKRecord (no change tag) — optimistic write.
                // Conflicts are resolved reactively in saveWithConflictRetry.
                let record = CKRecord(recordType: recordType, recordID: recordID)
                populateRecord(record, from: map)
                toSave.append(record)
            }
        }

        print("[CKSync] pushChanges: \(toSave.count) to save, \(toDelete.count) to delete")
        guard !toSave.isEmpty || !toDelete.isEmpty else { return }
        try await saveWithConflictRetry(toSave: toSave, toDelete: toDelete)
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
                // endTime) are audio-position seconds and must stay as numbers.
                if ckKey.hasSuffix("At") {
                    record[ckKey] = Date(timeIntervalSince1970: n.doubleValue / 1000) as CKRecordValue
                } else {
                    record[ckKey] = n as CKRecordValue
                }
            case is NSNull:
                record[ckKey] = nil
            default:
                break
            }
        }
    }

    private func saveWithConflictRetry(toSave: [CKRecord], toDelete: [CKRecord.ID]) async throws {
        print("[CKSync] saveWithConflictRetry: attempting save of \(toSave.count) records")
        do {
            let (saveResults, _) = try await privateDB.modifyRecords(
                saving: toSave,
                deleting: toDelete,
                savePolicy: .allKeys,
                atomically: false
            )
            print("[CKSync] saveWithConflictRetry: modifyRecords returned, processing per-record results")

            // For each per-record serverRecordChanged conflict, apply our local
            // values onto the server record (which carries the current change tag)
            // and retry. If the error omits serverRecord, fetch it explicitly.
            var toRetry: [CKRecord] = []
            for (id, result) in saveResults {
                guard case .failure(let error) = result,
                      let ckErr = error as? CKError,
                      ckErr.code == .serverRecordChanged else { continue }

                print("[CKSync] saveWithConflictRetry: per-record conflict on \(id.recordName)")
                let ourRecord = ckErr.clientRecord
                    ?? toSave.first(where: { $0.recordID == id })

                let serverRecord: CKRecord
                if let server = ckErr.serverRecord {
                    serverRecord = server
                } else if let rec = ourRecord {
                    print("[CKSync] saveWithConflictRetry: serverRecord missing, fetching \(id.recordName)")
                    serverRecord = (try? await privateDB.record(for: id)) ?? rec
                } else {
                    continue
                }

                // Local wins: copy all our field values onto the server record.
                for key in (ourRecord?.allKeys() ?? []) {
                    serverRecord[key] = ourRecord![key]
                }
                toRetry.append(serverRecord)
            }

            if !toRetry.isEmpty {
                print("[CKSync] saveWithConflictRetry: retrying \(toRetry.count) conflicted records")
                _ = try await privateDB.modifyRecords(
                    saving: toRetry,
                    deleting: [],
                    savePolicy: .allKeys,
                    atomically: false
                )
            }
            print("[CKSync] saveWithConflictRetry: done")

        } catch let ckErr as CKError where ckErr.code == .serverRecordChanged {
            // modifyRecords threw globally rather than returning per-record errors.
            // Re-fetch every record to get current change tags, apply our values, retry.
            print("[CKSync] saveWithConflictRetry: global serverRecordChanged — re-fetching all \(toSave.count) records")
            var refreshed: [CKRecord] = []
            for record in toSave {
                if let server = try? await privateDB.record(for: record.recordID) {
                    for key in record.allKeys() { server[key] = record[key] }
                    refreshed.append(server)
                } else {
                    refreshed.append(record)
                }
            }
            print("[CKSync] saveWithConflictRetry: retrying all after global conflict")
            _ = try await privateDB.modifyRecords(
                saving: refreshed,
                deleting: toDelete,
                savePolicy: .allKeys,
                atomically: false
            )
            print("[CKSync] saveWithConflictRetry: done (global conflict path)")
        }
    }

    private func mergeConflict(client: CKRecord, server: CKRecord, ancestor: CKRecord?) -> CKRecord {
        let clientModified = (client["modifiedAt"] as? Date) ?? Date.distantPast
        let serverModified = (server["modifiedAt"] as? Date) ?? Date.distantPast
        for key in client.allKeys() {
            let clientChanged = !ckEqual(client[key], ancestor?[key])
            let serverChanged = !ckEqual(server[key], ancestor?[key])
            if clientChanged && !serverChanged {
                server[key] = client[key]
            } else if clientChanged && serverChanged && clientModified > serverModified {
                server[key] = client[key]
            }
        }
        return server
    }

    // MARK: - Pull CloudKit → Dart

    private var tokenKey: String { "ck_token_\(zoneID.zoneName)" }

    private func fetchRemoteChanges() async throws {
        emitStatus("syncing")
        defer { emitStatus("idle") }
        print("[CKSync] fetchRemoteChanges: starting")
        do {
            try await runZoneChangeFetch(resetToken: false)
            print("[CKSync] fetchRemoteChanges: completed OK")
        } catch let ckErr as CKError
            where ckErr.code == .changeTokenExpired || ckErr.code == .serverRecordChanged {
            print("[CKSync] fetchRemoteChanges: got \(ckErr.code.rawValue), resetting token and retrying")
            UserDefaults.standard.removeObject(forKey: tokenKey)
            try await runZoneChangeFetch(resetToken: true)
            print("[CKSync] fetchRemoteChanges: retry completed OK")
        } catch {
            if isEmptyZoneError(error) {
                // CloudKit returns HTTP 500 / CKInternalErrorDomain 2000 for a
                // custom zone that has never had records written to it. This is
                // a known server quirk, not a real failure — treat as no changes.
                print("[CKSync] fetchRemoteChanges: empty zone (HTTP 500 / 2000) — no records yet, ignoring")
                return
            }
            print("[CKSync] fetchRemoteChanges: FAILED \(error)")
            throw error
        }
    }

    private func isEmptyZoneError(_ error: Error) -> Bool {
        guard let ckErr = error as? CKError else { return false }
        let underlying = ckErr.userInfo[NSUnderlyingErrorKey] as? NSError
        return underlying?.domain == "CKInternalErrorDomain" && underlying?.code == 2000
    }

    private func runZoneChangeFetch(resetToken: Bool) async throws {
        let token: CKServerChangeToken? = resetToken ? nil : UserDefaults.standard
            .data(forKey: tokenKey)
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = token

        let op = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: config]
        )

        op.recordWasChangedBlock = { [weak self] _, result in
            if case .success(let record) = result { self?.emitRecord(record) }
        }
        op.recordWithIDWasDeletedBlock = { [weak self] id, type in
            self?.emitDeletion(cloudId: id.recordName, recordType: type)
        }
        op.recordZoneChangeTokensUpdatedBlock = { [weak self] _, newToken, _ in
            guard let self, let newToken else { return }
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: self.tokenKey)
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    print("[CKSync] runZoneChangeFetch: operation success")
                case .failure(let e):
                    let ckErr = e as? CKError
                    print("[CKSync] runZoneChangeFetch: operation failure \(e)")
                    print("[CKSync]   code=\(ckErr?.code.rawValue ?? -1) userInfo=\(ckErr?.userInfo ?? [:])")
                }
                cont.resume(with: result)
            }
            self.privateDB.add(op)
        }
    }

    // MARK: - Background Subscription

    private func setupDatabaseSubscription() async throws {
        let key = "ck_subscription_registered"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let sub = CKDatabaseSubscription(subscriptionID: "tune-trove-db-changes")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        try await privateDB.save(sub)
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - EventChannel helpers

    private func emitRecord(_ record: CKRecord) {
        var fields: [String: Any] = ["cloudId": record.recordID.recordName]
        for key in record.allKeys() {
            let snakeKey = camelToSnake(key)
            switch record[key] {
            case let s as String:
                fields[snakeKey] = s
            case let n as NSNumber:
                fields[snakeKey] = n
            case let d as Date:
                fields[snakeKey] = Int(d.timeIntervalSince1970 * 1000)
            case nil:
                fields[snakeKey] = NSNull()
            default:
                break
            }
        }
        let payload: [String: Any] = ["type": "upsert", "recordType": record.recordType, "fields": fields]
        DispatchQueue.main.async { [weak self] in self?.eventSink?(payload) }
    }

    private func emitDeletion(cloudId: String, recordType: String) {
        let payload: [String: Any] = ["type": "delete", "recordType": recordType, "cloudId": cloudId]
        DispatchQueue.main.async { [weak self] in self?.eventSink?(payload) }
    }

    private func emitStatus(_ status: String) {
        let payload: [String: Any] = ["type": "status", "status": status]
        DispatchQueue.main.async { [weak self] in self?.eventSink?(payload) }
    }

    // MARK: - String conversion helpers

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

    private func ckEqual(_ a: CKRecordValue?, _ b: CKRecordValue?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case (let s1 as String, let s2 as String): return s1 == s2
        case (let n1 as NSNumber, let n2 as NSNumber): return n1 == n2
        case (let d1 as Date, let d2 as Date): return d1 == d2
        default: return false
        }
    }
}

@available(iOS 15, macOS 14, *)
extension CloudKitSyncBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
