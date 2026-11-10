import SwiftUI

@main struct Pi100App: App {
    @StateObject private var store: GameStore
    @StateObject private var gameCenter = GameCenterService()
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            // Application Support survives termination. The temporary directory may be purged and would drop --restore.
            let directory = URL.applicationSupportDirectory.appending(path: "Pi100UITests", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "progress.json")
            if !ProcessInfo.processInfo.arguments.contains("--restore") { try? FileManager.default.removeItem(at: url) }
            _store = StateObject(wrappedValue: GameStore(fileURL: url))
            return
        }
        #endif
        _store = StateObject(wrappedValue: GameStore())
    }
    var body: some Scene {
        WindowGroup { GameView().environmentObject(store).environmentObject(gameCenter) }
    }
}
