import SwiftUI
import Combine

@MainActor final class GameStore: ObservableObject {
    @Published private(set) var session = GameSession()
    @Published private(set) var records: [GameRecord] = []
    @Published private(set) var submittedIDs: Set<UUID> = []
    @Published var storageError: String?
    @Published var showResult = false
    @Published var feedback: DigitAnswer?
    private let fileURL: URL
    private let now: () -> TimeInterval
    // Corrupt saves stay on disk until the user explicitly clears them.
    // A transient read failure (for example data protection before unlock) is retried instead.
    private var canWrite = true
    private var transientReadFailure = false
    private var editedSinceLoad = false
    private var sceneActive: [UUID: Bool] = [:]

    init(fileURL: URL? = nil, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
        self.fileURL = fileURL ?? URL.applicationSupportDirectory.appending(path: "Pi100/progress.json")
        load()
    }
    func elapsed() -> TimeInterval { session.elapsed(at: now()) }
    func start() {
        retryLoadIfNeeded()
        mutate { session.start(at: now()) }
        save()
    }
    func pause() { mutate { session.pause(at: now()) }; save() }
    func hint() { mutate { session.revealHint() }; save() }
    func enter(_ digit: Int) {
        let before = session
        guard let answer = session.enter(digit, at: now()) else { return }
        if session != before { editedSinceLoad = true }
        feedback = answer
        if session.phase == .finished {
            if !records.contains(where: { $0.id == session.id }) { records.insert(GameRecord(session: session), at: 0) }
            records = Array(records.prefix(200))
            showResult = true
        }
        save()
    }
    func newSession(_ mode: GameMode, positions: [Int]? = nil) {
        session = GameSession(mode: mode, positions: positions)
        feedback = nil
        showResult = false
        editedSinceLoad = true
        save()
    }
    func markSubmitted(_ id: UUID) { submittedIDs.insert(id); save() }
    func deleteAll() {
        session = GameSession()
        records = []
        submittedIDs = []
        feedback = nil
        showResult = false
        editedSinceLoad = false
        transientReadFailure = false
        canWrite = true
        save()
    }
    /// Registers one window. Several scenes share this store; a challenge pauses only when none remain active.
    func registerScene(_ id: UUID, active: Bool) {
        sceneActive[id] = active
        if active { retryLoadIfNeeded() }
    }
    func unregisterScene(_ id: UUID) {
        sceneActive.removeValue(forKey: id)
    }
    func updateScene(_ id: UUID, active: Bool) {
        sceneActive[id] = active
        if active {
            retryLoadIfNeeded()
        } else if !sceneActive.isEmpty && !sceneActive.values.contains(true) {
            pause()
        }
    }
    func retryLoadIfNeeded() {
        guard transientReadFailure, !editedSinceLoad else { return }
        load()
    }
    private func mutate(_ change: () -> Void) {
        let before = session
        change()
        if session != before { editedSinceLoad = true }
    }
    func save() {
        guard canWrite else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let retainedIDs = Set(records.map(\.id))
            submittedIDs.formIntersection(retainedIDs)
            let data = SavedProgress(session: session.savedSnapshot(at: now()), records: records, submittedIDs: submittedIDs)
            try JSONEncoder().encode(data).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            storageError = nil
        } catch { storageError = L.text("无法保存进度，请检查设备储存空间。", "Progress could not be saved. Check device storage.") }
    }
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            transientReadFailure = true
            canWrite = false
            storageError = L.text("暂时无法读取存档，原文件已保留。回到应用后会再试。", "The save could not be read just now and was left untouched. It will be tried again when you return.")
            return
        }
        do {
            let saved = try JSONDecoder().decode(SavedProgress.self, from: data)
            guard saved.isValid else { throw CocoaError(.coderReadCorrupt) }
            session = saved.session
            records = saved.records
            submittedIDs = saved.submittedIDs
            transientReadFailure = false
            canWrite = true
            storageError = nil
        } catch {
            transientReadFailure = false
            canWrite = false
            storageError = L.text("已有存档无法读取，原文件已保留。可在设置中清除后重新开始。", "The saved data could not be read and has been preserved. Clear local data in Settings to start again.")
        }
    }
}

enum L {
    static var chinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }
    static func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    static func mode(_ mode: GameMode) -> String {
        switch mode {
        case .practice: text("练习", "Practice")
        case .challenge: text("挑战", "Challenge")
        case .review: text("错题复习", "Review")
        }
    }
    static func time(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "--:--" }
        let value = Int(min(max(seconds, 0), 100_000_000))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
