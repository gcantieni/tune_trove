import MusicKit
import Foundation
#if canImport(UIKit)
import Flutter
#elseif canImport(AppKit)
import FlutterMacOS
#endif

enum MusicKitChannels {
    static let method = "com.gcantieni.tuneTrove/musickit"
    static let event  = "com.gcantieni.tuneTrove/musickit_state"
}

@available(iOS 15, macOS 14, *)
class MusicKitBridge: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var positionTimer: Timer?
    private var loopRemaining = 0
    private var currentSong: Song?
    private var currentStartTime: Double?
    private var currentEndTime: Double?
    private var lastEmittedStatus = "unknown"

    func setup(binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: MusicKitChannels.method,
            binaryMessenger: binaryMessenger
        )
        eventChannel = FlutterEventChannel(
            name: MusicKitChannels.event,
            binaryMessenger: binaryMessenger
        )
        methodChannel?.setMethodCallHandler(handleMethod)
        eventChannel?.setStreamHandler(self)
    }

    private func handleMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Task {
            do {
                switch call.method {
                case "authorize":
                    let status = await MusicAuthorization.request()
                    result(status.rawValue)

                case "authorizationStatus":
                    result(MusicAuthorization.currentStatus.rawValue)

                case "search":
                    guard let args = call.arguments as? [String: Any],
                          let query = args["query"] as? String else {
                        result(FlutterError(code: "BAD_ARGS", message: "query required", details: nil))
                        return
                    }
                    let types = args["types"] as? [String] ?? ["songs", "albums", "artists"]
                    let results = try await searchCatalog(query: query, types: types)
                    result(results)

                case "play":
                    guard let args = call.arguments as? [String: Any],
                          let catalogId = args["catalogId"] as? String else {
                        result(FlutterError(code: "BAD_ARGS", message: "catalogId required", details: nil))
                        return
                    }
                    let startTime    = args["startTime"]    as? Double
                    let endTime      = args["endTime"]      as? Double
                    let playbackRate = args["playbackRate"] as? Double ?? 1.0
                    let loopCount    = args["loopCount"]    as? Int    ?? 0
                    try await playItem(
                        catalogId:    catalogId,
                        startTime:    startTime,
                        endTime:      endTime,
                        playbackRate: playbackRate,
                        loopCount:    loopCount
                    )
                    result(nil)

                case "pause":
                    ApplicationMusicPlayer.shared.pause()
                    result(nil)

                case "resume":
                    try await ApplicationMusicPlayer.shared.play()
                    result(nil)

                case "stop":
                    ApplicationMusicPlayer.shared.stop()
                    stopPlaybackObservation()
                    result(nil)

                case "seek":
                    guard let args = call.arguments as? [String: Any],
                          let position = args["position"] as? Double else {
                        result(FlutterError(code: "BAD_ARGS", message: "position required", details: nil))
                        return
                    }
                    ApplicationMusicPlayer.shared.playbackTime = position
                    result(nil)

                case "setPlaybackRate":
                    guard let args = call.arguments as? [String: Any],
                          let rate = args["rate"] as? Double else {
                        result(FlutterError(code: "BAD_ARGS", message: "rate required", details: nil))
                        return
                    }
                    ApplicationMusicPlayer.shared.state.playbackRate = Float(rate)
                    result(nil)

                case "setRepeatMode":
                    guard let args = call.arguments as? [String: Any],
                          let mode = args["mode"] as? String else {
                        result(FlutterError(code: "BAD_ARGS", message: "mode required", details: nil))
                        return
                    }
                    switch mode {
                    case "one": ApplicationMusicPlayer.shared.state.repeatMode = .one
                    case "all": ApplicationMusicPlayer.shared.state.repeatMode = .all
                    default:    ApplicationMusicPlayer.shared.state.repeatMode = MusicPlayer.RepeatMode.none
                    }
                    result(nil)

                default:
                    result(FlutterMethodNotImplemented)
                }
            } catch {
                result(FlutterError(code: "MUSICKIT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    // MARK: - Search

    private func searchCatalog(query: String, types: [String]) async throws -> [[String: Any]] {
        var request = MusicCatalogSearchRequest(
            term: query,
            types: musicEntityTypes(for: types)
        )
        request.limit = 25
        let response = try await request.response()

        var results: [[String: Any]] = []

        if types.contains("songs") {
            for song in response.songs {
                results.append([
                    "kind":       "song",
                    "id":         song.id.rawValue,
                    "title":      song.title,
                    "artistName": song.artistName,
                    "albumTitle": song.albumTitle ?? "",
                    "durationMs": Int((song.duration ?? 0) * 1000),
                    "artworkUrl": song.artwork.map { artworkUrl($0, size: 300) } ?? "",
                ])
            }
        }
        if types.contains("albums") {
            for album in response.albums {
                results.append([
                    "kind":       "album",
                    "id":         album.id.rawValue,
                    "title":      album.title,
                    "artistName": album.artistName,
                    "albumTitle": album.title,
                    "durationMs": 0,
                    "artworkUrl": album.artwork.map { artworkUrl($0, size: 300) } ?? "",
                ])
            }
        }
        if types.contains("artists") {
            for artist in response.artists {
                results.append([
                    "kind":       "artist",
                    "id":         artist.id.rawValue,
                    "title":      artist.name,
                    "artistName": artist.name,
                    "albumTitle": "",
                    "durationMs": 0,
                    "artworkUrl": artist.artwork.map { artworkUrl($0, size: 300) } ?? "",
                ])
            }
        }
        return results
    }

    private func musicEntityTypes(for strings: [String]) -> [any MusicCatalogSearchable.Type] {
        var types: [any MusicCatalogSearchable.Type] = []
        if strings.contains("songs")   { types.append(Song.self)   }
        if strings.contains("albums")  { types.append(Album.self)  }
        if strings.contains("artists") { types.append(Artist.self) }
        return types
    }

    private func artworkUrl(_ artwork: Artwork, size: Int) -> String {
        artwork.url(width: size, height: size)?.absoluteString ?? ""
    }

    // MARK: - Playback

    private func playItem(
        catalogId:    String,
        startTime:    Double?,
        endTime:      Double?,
        playbackRate: Double,
        loopCount:    Int
    ) async throws {
        let player = ApplicationMusicPlayer.shared
        let songId = MusicItemID(catalogId)
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songId)
        request.properties = []
        let response = try await request.response()
        guard let song = response.items.first else { return }

        // ApplicationMusicPlayer.Options (startTime/endTime/playbackRate) is iOS-only.
#if canImport(UIKit)
        if #available(iOS 16, *) {
            var options = ApplicationMusicPlayer.Options()
            if let start = startTime { options.startTime  = start }
            if let end   = endTime   { options.endTime    = end   }
            options.playbackRate = Float(playbackRate)
            player.options = options
        }
#endif

        // Set state and start the timer *before* play() so the observation
        // loop is running even if play() throws (macOS daemon timeout).
        currentSong      = song
        currentStartTime = startTime
        currentEndTime   = endTime
        player.queue     = [song]
        startPlaybackObservation(loopCount: loopCount)

#if canImport(AppKit)
        // On macOS, ApplicationMusicPlayer.shared may log a Music daemon
        // connection timeout ("applicationQueuePlayer ... ping did not pong")
        // and throw, but playback still starts via the system Music process.
        // The observation timer already running will detect the status change.
        try? await player.play()
#else
        try await player.play()
#endif
    }

    // MARK: - Observation
    //
    // MusicPlayer.State does not expose $playbackStatus as an AsyncSequence on
    // any platform, so a 100 ms timer handles both position updates and
    // status-change detection (by diffing against lastEmittedStatus).

    private func startPlaybackObservation(loopCount: Int) {
        // Dispatch entirely to the main queue: this method is called from a
        // Swift concurrency Task that resumes on the cooperative thread pool,
        // where Timer.scheduledTimer would target a run loop that never runs.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.positionTimer?.invalidate()
            self.loopRemaining = loopCount
            self.lastEmittedStatus = "unknown"
            self.positionTimer = Timer.scheduledTimer(
                withTimeInterval: 0.1,
                repeats: true
            ) { [weak self] _ in
                self?.tick()
            }
        }
    }

    private func stopPlaybackObservation() {
        // May be called from a Task (cooperative thread) or from the main thread.
        // Always dispatch to main to match where the timer was scheduled.
        DispatchQueue.main.async { [weak self] in
            self?.positionTimer?.invalidate()
            self?.positionTimer = nil
        }
    }

    private func tick() {
        let player = ApplicationMusicPlayer.shared
        let position = player.playbackTime
        let status: String
        switch player.state.playbackStatus {
        case .playing:     status = "playing"
        case .paused:      status = "paused"
        case .stopped:     status = "stopped"
        case .interrupted: status = "interrupted"
        default:           status = "unknown"
        }

        let durationMs = Int((currentSong?.duration ?? 0) * 1000)

        if status != lastEmittedStatus {
            lastEmittedStatus = status
            let statusPayload: [String: Any] = [
                "event":      "statusChanged",
                "status":     status,
                "position":   position,
                "catalogId":  currentSong?.id.rawValue ?? "",
                "title":      currentSong?.title       ?? "",
                "artistName": currentSong?.artistName  ?? "",
                "durationMs": durationMs,
            ]
            DispatchQueue.main.async { [weak self] in self?.eventSink?(statusPayload) }
        }

        if let endTime = currentEndTime, position >= endTime {
            if loopRemaining == 0 {
                player.stop()
                stopPlaybackObservation()
            } else {
                if loopRemaining > 0 { loopRemaining -= 1 }
                player.playbackTime = currentStartTime ?? 0
            }
            return
        }

        let posPayload: [String: Any] = [
            "event":      "positionUpdate",
            "position":   position,
            "status":     status,
            "catalogId":  currentSong?.id.rawValue ?? "",
            "durationMs": durationMs,
        ]
        DispatchQueue.main.async { [weak self] in self?.eventSink?(posPayload) }
    }
}

// MARK: - FlutterStreamHandler

@available(iOS 15, macOS 14, *)
extension MusicKitBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        stopPlaybackObservation()
        return nil
    }
}
