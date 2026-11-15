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
    private var draining = false
    private var needsAnotherPass = false

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
    /// The system login sheet was dismissed without a later handler callback.
    func noteAuthInterfaceDismissed() {
        authController = nil
        authenticating = false
    }
    func submitPending(from store: GameStore) async {
        authenticated = GKLocalPlayer.local.isAuthenticated
        guard authenticated else { return }
        let resume = await submitScores(from: store) { milliseconds in
            try await GKLeaderboard.submitScore(milliseconds, context: 0, player: GKLocalPlayer.local,
                                                leaderboardIDs: [Self.leaderboardID])
        }
        if resume {
            Task { @MainActor [weak self] in
                await self?.submitPending(from: store)
            }
        }
    }
    /// Submits every qualifying record. One rejection does not stop the rest of the queue.
    /// A score that arrives while a request is in flight is included before this call returns.
    /// Returns true when cancellation stopped the drain with work still queued.
    @discardableResult
    func submitScores(from store: GameStore, using send: @escaping @MainActor (Int) async throws -> Void) async -> Bool {
        if draining {
            needsAnotherPass = true
            return false
        }
        draining = true
        defer { draining = false }
        var failed = false
        var succeeded = false
        var attempted = Set<UUID>()
        while !Task.isCancelled {
            needsAnotherPass = false
            let pending = store.records.filter { record in
                record.leaderboardMilliseconds != nil && !store.submittedIDs.contains(record.id) && !attempted.contains(record.id)
            }
            if pending.isEmpty { break }
            for record in pending {
                guard let milliseconds = record.leaderboardMilliseconds else { continue }
                attempted.insert(record.id)
                do {
                    try await send(milliseconds)
                    store.markSubmitted(record.id)
                    succeeded = true
                } catch {
                    if error is CancellationError {
                        needsAnotherPass = true
                        break
                    }
                    failed = true
                }
                if Task.isCancelled {
                    needsAnotherPass = true
                    break
                }
            }
            if !needsAnotherPass { break }
        }
        if failed {
            status = L.text("暂未提交，联网后可重试。", "Not submitted yet. Retry when online.")
        } else if succeeded {
            status = L.text("全球榜成绩已提交", "Global score submitted")
        }
        return Task.isCancelled && needsAnotherPass
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
