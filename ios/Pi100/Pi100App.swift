import SwiftUI

@main struct Pi100App: App {
    @StateObject private var store: GameStore
    @StateObject private var gameCenter = GameCenterService()
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let url = URL.temporaryDirectory.appending(path: "pi100-ui-tests.json")
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
