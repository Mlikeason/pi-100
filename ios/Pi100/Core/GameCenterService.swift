import GameKit
import SwiftUI
import Combine

@MainActor final class GameCenterService: ObservableObject {
    // Create this exact leaderboard in App Store Connect, ascending, best score,
    // elapsed time (milliseconds). Only perfect uninterrupted challenges qualify.
    static let leaderboardID = "me.zhuhong.pi100.perfect100"
    @Published var authController: UIViewController?
    @Published var authenticated = false
    @Published var status = ""
    private var authenticating = false
    private var submitting = false

    func authenticate() {
        guard !authenticating else { return }
        authenticating = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                guard let self else { return }
                self.authController = controller
                self.authenticated = GKLocalPlayer.local.isAuthenticated
                if controller == nil { self.authenticating = false }
                if let error { self.status = error.localizedDescription }
                else if self.authenticated { self.status = L.text("已连接 Game Center", "Connected to Game Center") }
                else { self.status = L.text("登录 Game Center 后可提交全球成绩。", "Sign in to Game Center to submit global scores.") }
            }
        }
    }
    func submitPending(from store: GameStore) async {
        guard authenticated, !submitting else { return }
        submitting = true
        defer { submitting = false }
        for record in store.records where !store.submittedIDs.contains(record.id) {
            guard let milliseconds = record.leaderboardMilliseconds else { continue }
            do {
                try await GKLeaderboard.submitScore(milliseconds, context: 0, player: GKLocalPlayer.local,
                                                    leaderboardIDs: [Self.leaderboardID])
                store.markSubmitted(record.id)
                status = L.text("全球榜成绩已提交", "Global score submitted")
            } catch {
                status = L.text("暂未提交，联网后可重试。", "Not submitted yet. Retry when online.")
                break
            }
        }
    }
}

struct AuthenticationView: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
struct LeaderboardView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator { dismiss() } }
    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(leaderboardID: GameCenterService.leaderboardID, playerScope: .global, timeScope: .allTime)
        controller.gameCenterDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}
    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) { close() }
    }
}
