import SwiftUI
import UIKit
import OSLog

/// Requests a quarter turn when an iPhone scene is wider than it is tall.
/// Duo's inner display need not map a tall window to `.portrait`.
/// Layout remains vertical even when the system cannot honor the request.
struct TallWindowPreference: UIViewRepresentable {
    let scenePhase: ScenePhase
    let availableSize: CGSize

    func makeUIView(context: Context) -> PreferenceView { PreferenceView() }

    func updateUIView(_ view: PreferenceView, context: Context) {
        view.active = scenePhase == .active
        view.setNeedsLayout()
    }

    final class PreferenceView: UIView {
        var active = false {
            didSet { if active != oldValue { resetPreference() } }
        }
        private weak var requestedScene: UIWindowScene?
        private var screenID: ObjectIdentifier?
        private var handledDisplay = false
        private var generation = 0
        private static let log = Logger(subsystem: "me.zhuhong.pi100", category: "Orientation")

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resetPreference()
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard active, let window, let scene = window.windowScene else { return }
            // This is an iPhone orientation preference, not a device-based layout branch.
            guard traitCollection.userInterfaceIdiom == .phone else { return }
            let currentScreenID = ObjectIdentifier(scene.screen)
            if requestedScene !== scene || screenID != currentScreenID {
                requestedScene = scene
                screenID = currentScreenID
                resetPreference()
            }
            guard !handledDisplay, window.bounds.width > 0, window.bounds.height > 0 else { return }
            guard scene.effectiveGeometry.interfaceOrientation != .unknown else { return }
            handledDisplay = true
            // Give each display/activation a default, then respect subsequent user rotation.
            guard window.bounds.width > window.bounds.height else { return }
            let requestGeneration = generation
            // Avoid reentrant geometry changes during the current layout pass.
            Task { @MainActor [weak self, weak scene] in
                guard let self, let scene, self.active, self.generation == requestGeneration,
                      let window = self.window, window.windowScene === scene,
                      ObjectIdentifier(scene.screen) == currentScreenID,
                      window.bounds.width > window.bounds.height else { return }
                let orientation = scene.effectiveGeometry.interfaceOrientation
                guard orientation != .unknown else { return }
                let target: UIInterfaceOrientationMask = orientation.isPortrait ? .landscapeRight : .portrait
                Self.log.debug("Requesting tall window from \(window.bounds.width)x\(window.bounds.height), orientation \(orientation.rawValue)")
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { error in
                    // Split View and system orientation policies may deny a request.
                    // Don't retry every frame; the one-column layout still fits.
                    Self.log.info("Tall-window preference was not applied: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        private func resetPreference() {
            generation += 1
            handledDisplay = false
        }
    }
}
