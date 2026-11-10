import Foundation

enum GameMode: String, Codable, CaseIterable { case practice, challenge, review }
enum GamePhase: String, Codable { case ready, running, paused, finished }

struct DigitAnswer: Codable, Equatable {
    let position: Int
    let entered: Int
    let assisted: Bool
    var expected: Int { PiDigits.values[position] }
    var isCorrect: Bool { entered == expected && !assisted }
}

enum PiDigits {
    static let text = "1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679"
    static let values = text.compactMap(\.wholeNumberValue)
}

struct GameSession: Codable, Equatable {
    let id: UUID
    let mode: GameMode
    let positions: [Int]
    private(set) var answers: [DigitAnswer] = []
    private(set) var phase: GamePhase = .ready
    private(set) var accumulated: TimeInterval = 0
    private(set) var runningSince: TimeInterval?
    private(set) var hintShown = false
    private(set) var interrupted = false

    init(mode: GameMode = .practice, positions: [Int]? = nil) {
        id = UUID()
        self.mode = mode
        let valid = Array(Set((positions ?? Array(0..<100)).filter { (0..<100).contains($0) })).sorted()
        self.positions = mode == .review && !valid.isEmpty ? valid : Array(0..<100)
    }
    var currentPosition: Int? { answers.count < positions.count ? positions[answers.count] : nil }
    var correctCount: Int { answers.filter(\.isCorrect).count }
    var mistakes: [Int] { answers.filter { !$0.isCorrect }.map(\.position) }
    var eligibleForLeaderboard: Bool {
        mode == .challenge && phase == .finished && correctCount == 100 && !interrupted
    }
    func elapsed(at now: TimeInterval) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now - $0) } ?? 0)
    }
    mutating func start(at now: TimeInterval) {
        guard phase == .ready || phase == .paused else { return }
        phase = .running
        runningSince = now
    }
    mutating func pause(at now: TimeInterval) {
        guard phase == .running else { return }
        accumulated = elapsed(at: now)
        runningSince = nil
        phase = .paused
        interrupted = true
    }
    mutating func revealHint() {
        guard mode != .challenge, phase == .running else { return }
        hintShown = true
    }
    @discardableResult mutating func enter(_ digit: Int, at now: TimeInterval) -> DigitAnswer? {
        guard phase == .running, (0...9).contains(digit), let position = currentPosition else { return nil }
        let answer = DigitAnswer(position: position, entered: digit, assisted: hintShown)
        answers.append(answer)
        hintShown = false
        if answers.count == positions.count {
            accumulated = elapsed(at: now)
            runningSince = nil
            phase = .finished
        }
        return answer
    }
    func savedSnapshot(at now: TimeInterval) -> GameSession {
        var copy = self
        copy.pause(at: now)
        return copy
    }
    var isValid: Bool {
        guard !positions.isEmpty, positions == Array(Set(positions)).sorted(),
              positions.allSatisfy({ (0..<100).contains($0) }),
              answers.count <= positions.count, accumulated.isFinite, accumulated >= 0,
              runningSince == nil, phase != .running else { return false }
        if mode != .review && positions != Array(0..<100) { return false }
        for (offset, answer) in answers.enumerated() {
            if answer.position != positions[offset] || !(0...9).contains(answer.entered) { return false }
            if mode == .challenge && answer.assisted { return false }
        }
        return (phase == .finished) == (answers.count == positions.count)
    }
}

struct GameRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let session: GameSession
    init(session: GameSession, date: Date = Date()) {
        id = session.id
        self.date = date
        self.session = session
    }
    var leaderboardMilliseconds: Int? {
        guard session.eligibleForLeaderboard, session.accumulated.isFinite,
              session.accumulated >= 0, session.accumulated < 86_400 else { return nil }
        return max(1, Int((session.accumulated * 1_000).rounded()))
    }
    static func ranked(_ records: [GameRecord]) -> [GameRecord] {
        records.filter { $0.session.mode == .challenge }.sorted {
            if $0.session.correctCount != $1.session.correctCount { return $0.session.correctCount > $1.session.correctCount }
            return $0.session.accumulated < $1.session.accumulated
        }
    }
}

struct SavedProgress: Codable {
    var version = 1
    var session: GameSession
    var records: [GameRecord]
    var submittedIDs: Set<UUID> = []
    var isValid: Bool {
        version == 1 && session.isValid && records.count <= 200 && Set(records.map(\.id)).count == records.count &&
        records.allSatisfy { $0.id == $0.session.id && $0.session.phase == .finished && $0.session.isValid }
    }
}
