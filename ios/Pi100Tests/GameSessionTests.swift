import XCTest
import SwiftUI
@testable import Pi100

final class GameSessionTests: XCTestCase {
    func testPiFixtureHasExactly100CorrectDigits() {
        XCTAssertEqual(PiDigits.values.count, 100)
        XCTAssertEqual(String(PiDigits.text.suffix(10)), "3421170679")
    }
    func testInputOnlyAcceptedWhileRunning() {
        var game = GameSession()
        XCTAssertNil(game.enter(1, at: 0))
        game.start(at: 10)
        XCTAssertNil(game.enter(11, at: 11))
        XCTAssertNotNil(game.enter(1, at: 12))
        game.pause(at: 15)
        XCTAssertNil(game.enter(4, at: 16))
        XCTAssertEqual(game.answers.count, 1)
    }
    func testHintDoesNotEarnCreditAndIsAddedToReview() {
        var game = GameSession()
        game.start(at: 0)
        game.revealHint()
        game.enter(1, at: 1)
        game.enter(4, at: 2)
        XCTAssertEqual(game.correctCount, 1)
        XCTAssertEqual(game.mistakes, [0])
        XCTAssertFalse(game.hintShown)
    }
    func testWrongDigitAdvancesAndKeepsExpectedDigit() {
        var game = GameSession()
        game.start(at: 0)
        let answer = game.enter(9, at: 1)
        XCTAssertEqual(answer?.expected, 1)
        XCTAssertEqual(answer?.entered, 9)
        XCTAssertEqual(game.currentPosition, 1)
        XCTAssertEqual(game.correctCount, 0)
    }
    func testPerfectChallengeQualifiesAndStopsAt100() {
        var game = GameSession(mode: .challenge)
        game.start(at: 100)
        game.revealHint()
        XCTAssertFalse(game.hintShown)
        let first = game.enter(PiDigits.values[0], at: 200)
        XCTAssertEqual(first?.assisted, false)
        XCTAssertTrue(first?.isCorrect == true)
        for digit in PiDigits.values.dropFirst() { game.enter(digit, at: 200) }
        XCTAssertEqual(game.phase, .finished)
        XCTAssertEqual(game.correctCount, 100)
        XCTAssertTrue(game.eligibleForLeaderboard)
        XCTAssertEqual(GameRecord(session: game).leaderboardMilliseconds, 100_000)
        XCTAssertNil(game.enter(0, at: 201))
        XCTAssertEqual(game.elapsed(at: 999), 100)
    }
    func testPauseExcludesBackgroundTimeAndInvalidatesGlobalScore() {
        var game = GameSession(mode: .challenge)
        game.start(at: 10)
        game.pause(at: 20)
        XCTAssertEqual(game.elapsed(at: 500), 10)
        game.start(at: 500)
        for digit in PiDigits.values { game.enter(digit, at: 510) }
        XCTAssertEqual(game.accumulated, 20)
        XCTAssertFalse(game.eligibleForLeaderboard)
        XCTAssertNil(GameRecord(session: game).leaderboardMilliseconds)
    }
    func testSnapshotDoesNotPauseLiveGameAndRestoresPaused() throws {
        var game = GameSession(mode: .challenge)
        game.start(at: 5)
        game.enter(1, at: 6)
        let saved = game.savedSnapshot(at: 8)
        XCTAssertEqual(game.phase, .running)
        XCTAssertFalse(game.interrupted)
        XCTAssertEqual(saved.phase, .paused)
        XCTAssertTrue(saved.interrupted)
        XCTAssertTrue(saved.isValid)
        let decoded = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded.answers, game.answers)
        XCTAssertEqual(decoded.accumulated, 3)
    }
    func testReviewPositionsAreSanitized() {
        let game = GameSession(mode: .review, positions: [10, -1, 100, 2, 2])
        XCTAssertEqual(game.positions, [2, 10])
        XCTAssertEqual(game.currentPosition, 2)
    }
    func testPracticeNeverQualifiesGlobally() {
        var game = GameSession()
        game.start(at: 0)
        for digit in PiDigits.values { game.enter(digit, at: 100) }
        XCTAssertNil(GameRecord(session: game).leaderboardMilliseconds)
    }
    func testAccuracyRanksAheadOfSpeed() {
        func record(wrong: Bool, time: Double) -> GameRecord {
            var game = GameSession(mode: .challenge)
            game.start(at: 0)
            for digit in PiDigits.values { game.enter(wrong ? 0 : digit, at: time) }
            return GameRecord(session: game)
        }
        let fastWrong = record(wrong: true, time: 1)
        let slowPerfect = record(wrong: false, time: 100)
        XCTAssertEqual(GameRecord.ranked([fastWrong, slowPerfect]).first?.id, slowPerfect.id)
    }
    @MainActor func testStorageRestoresAndDeletesProgress() {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 10 })
        store.start(); store.enter(1)
        let restored = GameStore(fileURL: url)
        XCTAssertEqual(restored.session.answers.count, 1)
        XCTAssertEqual(restored.session.phase, .paused)
        restored.deleteAll()
        XCTAssertEqual(GameStore(fileURL: url).session.phase, .ready)
    }
    @MainActor func testCorruptSaveIsPreservedUntilExplicitReset() throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: url)
        let store = GameStore(fileURL: url)
        XCTAssertNotNil(store.storageError)
        store.start(); store.enter(1)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        store.deleteAll()
        XCTAssertNil(store.storageError)
        XCTAssertTrue(try JSONDecoder().decode(SavedProgress.self, from: Data(contentsOf: url)).isValid)
    }
    func testReviewAllowsHintsAndDoesNotQualify() {
        var game = GameSession(mode: .review, positions: [0, 1])
        game.start(at: 0)
        game.revealHint()
        XCTAssertTrue(game.hintShown)
        let hinted = game.enter(1, at: 1)
        XCTAssertEqual(hinted?.assisted, true)
        XCTAssertFalse(hinted?.isCorrect == true)
        XCTAssertEqual(game.mistakes, [0])
        XCTAssertEqual(game.correctCount, 0)
        let clean = game.enter(4, at: 2)
        XCTAssertEqual(clean?.isCorrect, true)
        XCTAssertEqual(game.correctCount, 1)
        XCTAssertEqual(game.phase, .finished)
        XCTAssertFalse(game.eligibleForLeaderboard)
        XCTAssertNil(GameRecord(session: game).leaderboardMilliseconds)
    }
    func testPauseKeepsPartialProgressAndBlocksTheGlobalBoard() {
        var game = GameSession(mode: .challenge)
        game.start(at: 1)
        game.enter(1, at: 2)
        game.pause(at: 4)
        XCTAssertEqual(game.answers.map(\.entered), [1])
        XCTAssertEqual(game.phase, .paused)
        XCTAssertTrue(game.interrupted)
        XCTAssertEqual(game.elapsed(at: 50), 3)
        game.start(at: 50)
        for (index, digit) in PiDigits.values.enumerated() where index > 0 { game.enter(digit, at: 60) }
        XCTAssertEqual(game.phase, .finished)
        XCTAssertEqual(game.correctCount, 100)
        XCTAssertFalse(game.eligibleForLeaderboard)
        XCTAssertNil(GameRecord(session: game).leaderboardMilliseconds)
        XCTAssertEqual(game.accumulated, 13)
    }
    func testBackwardsClockDoesNotReduceAccumulatedTime() {
        var game = GameSession()
        game.start(at: 50)
        XCTAssertEqual(game.elapsed(at: 40), 0)
        XCTAssertEqual(game.elapsed(at: 55), 5)
        game.pause(at: 60)
        XCTAssertEqual(game.elapsed(at: 1), 10)
    }
    func testLeaderboardMillisecondsStayInsideGameCenterRange() throws {
        var borderline = GameSession(mode: .challenge)
        borderline.start(at: 0)
        for digit in PiDigits.values { borderline.enter(digit, at: 86_399.9996) }
        if let milliseconds = GameRecord(session: borderline).leaderboardMilliseconds {
            XCTAssertGreaterThanOrEqual(milliseconds, 1)
            XCTAssertLessThanOrEqual(milliseconds, 86_399_999)
        }
        var instant = GameSession(mode: .challenge)
        instant.start(at: 5)
        for digit in PiDigits.values { instant.enter(digit, at: 5) }
        XCTAssertEqual(GameRecord(session: instant).leaderboardMilliseconds, 1)
        var tooLong = GameSession(mode: .challenge)
        tooLong.start(at: 0)
        for digit in PiDigits.values { tooLong.enter(digit, at: 86_400) }
        XCTAssertNil(GameRecord(session: tooLong).leaderboardMilliseconds)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameRecord(session: instant))) as! [String: Any]
        var session = object["session"] as! [String: Any]
        session["accumulated"] = 1e20
        object["session"] = session
        let decoded = try JSONDecoder().decode(GameRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.leaderboardMilliseconds)
        XCTAssertEqual(L.time(0), "00:00")
        XCTAssertEqual(L.time(65), "01:05")
        XCTAssertEqual(L.time(.nan), "--:--")
        XCTAssertFalse(L.time(decoded.session.accumulated).isEmpty)
        XCTAssertFalse(L.time(.greatestFiniteMagnitude).isEmpty)
    }
    @MainActor func testRecoveredChallengeKeepsProgressButCannotQualify() {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let clock = MutableClock()
        let store = GameStore(fileURL: url, now: { clock.value })
        store.newSession(.challenge)
        store.start()
        clock.value = 5
        store.enter(1)
        XCTAssertEqual(store.session.phase, .running)
        XCTAssertFalse(store.session.interrupted)
        let restored = GameStore(fileURL: url, now: { clock.value })
        XCTAssertEqual(restored.session.phase, .paused)
        XCTAssertTrue(restored.session.interrupted)
        XCTAssertEqual(restored.session.answers.map(\.entered), [1])
        restored.start()
        clock.value = 15
        for (index, digit) in PiDigits.values.enumerated() where index > 0 { restored.enter(digit) }
        XCTAssertEqual(restored.session.phase, .finished)
        XCTAssertEqual(restored.session.correctCount, 100)
        XCTAssertFalse(restored.session.eligibleForLeaderboard)
        XCTAssertNil(restored.records.first?.leaderboardMilliseconds)
        XCTAssertEqual(restored.records.count, 1)
    }
    @MainActor func testFinishedPerfectChallengeStillQualifiesAfterReload() {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let clock = MutableClock()
        let store = GameStore(fileURL: url, now: { clock.value })
        store.newSession(.challenge)
        store.start()
        clock.value = 12.5
        for digit in PiDigits.values { store.enter(digit) }
        XCTAssertEqual(store.session.phase, .finished)
        XCTAssertFalse(store.session.interrupted)
        XCTAssertEqual(store.records.first?.leaderboardMilliseconds, 12_500)
        let restored = GameStore(fileURL: url, now: { clock.value })
        XCTAssertTrue(restored.session.eligibleForLeaderboard)
        XCTAssertEqual(restored.records.first?.leaderboardMilliseconds, 12_500)
        XCTAssertEqual(restored.records.count, 1)
    }
    @MainActor func testRecentRecordsStopAtTwoHundred() {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 30 })
        var oldest: UUID?
        var newest: UUID?
        for round in 0..<201 {
            store.newSession(.challenge)
            store.start()
            for digit in PiDigits.values { store.enter(digit) }
            let id = store.records[0].id
            if round == 0 {
                oldest = id
                store.markSubmitted(id)
            }
            newest = id
        }
        guard let oldest, let newest else {
            XCTFail("expected the oldest and newest record ids")
            return
        }
        XCTAssertEqual(store.records.count, 200)
        XCTAssertEqual(store.records.first?.id, newest)
        XCTAssertFalse(store.records.contains { $0.id == oldest })
        XCTAssertFalse(store.submittedIDs.contains(oldest))
        let restored = GameStore(fileURL: url, now: { 30 })
        XCTAssertEqual(restored.records.count, 200)
        XCTAssertEqual(restored.records.first?.id, newest)
        XCTAssertFalse(restored.submittedIDs.contains(oldest))
        XCTAssertTrue(restored.session.isValid)
    }
    @MainActor func testInvalidSaveContentsAreNotReplaced() throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 3 })
        store.start()
        store.enter(1)
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        object["version"] = 2
        let invalid = try JSONSerialization.data(withJSONObject: object)
        try invalid.write(to: url)
        let blocked = GameStore(fileURL: url, now: { 3 })
        XCTAssertNotNil(blocked.storageError)
        blocked.start()
        blocked.enter(9)
        XCTAssertEqual(try Data(contentsOf: url), invalid)
    }
    @MainActor func testUnreadableSaveIsLeftUntouchedAndCanBeRetried() throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        let store = GameStore(fileURL: url, now: { 8 })
        store.start()
        store.enter(1)
        let preserved = try Data(contentsOf: url)
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        } catch {
            throw XCTSkip("Could not change save permissions: \(error)")
        }
        var readable = false
        do {
            _ = try Data(contentsOf: url)
            readable = true
        } catch {
            readable = false
        }
        guard !readable else {
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            throw XCTSkip("This environment can read files with mode 000")
        }
        let blocked = GameStore(fileURL: url, now: { 8 })
        let edited = GameStore(fileURL: url, now: { 8 })
        XCTAssertNotNil(blocked.storageError)
        XCTAssertNotNil(edited.storageError)
        edited.start()
        edited.enter(4)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        XCTAssertEqual(try Data(contentsOf: url), preserved)
        blocked.retryLoadIfNeeded()
        XCTAssertNil(blocked.storageError)
        XCTAssertEqual(blocked.session.answers.map(\.entered), [1])
        XCTAssertEqual(blocked.session.phase, .paused)
        edited.retryLoadIfNeeded()
        XCTAssertEqual(edited.session.answers.map(\.entered), [4])
        XCTAssertEqual(try Data(contentsOf: url), preserved)
    }
    @MainActor func testBackgroundDisqualifiesOnlyWhenNoSceneStaysActive() {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 10 })
        let phone = UUID()
        let pad = UUID()
        store.registerScene(phone, active: true)
        store.registerScene(pad, active: true)
        store.start()
        store.enter(1)
        store.updateScene(pad, active: false)
        XCTAssertEqual(store.session.phase, .running)
        XCTAssertFalse(store.session.interrupted)
        store.updateScene(phone, active: false)
        XCTAssertEqual(store.session.phase, .paused)
        XCTAssertTrue(store.session.interrupted)
        XCTAssertEqual(store.session.answers.map(\.entered), [1])
        store.updateScene(phone, active: true)
        XCTAssertEqual(store.session.phase, .paused)
        let other = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: other) }
        let replaced = GameStore(fileURL: other, now: { 10 })
        let window = UUID()
        replaced.registerScene(window, active: true)
        replaced.start()
        replaced.enter(1)
        replaced.unregisterScene(window)
        XCTAssertEqual(replaced.session.phase, .running)
        XCTAssertFalse(replaced.session.interrupted)
    }
    @MainActor func testPracticeAndInterruptedChallengesAreNotSubmitted() async {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 4 })
        store.newSession(.practice)
        store.start()
        for digit in PiDigits.values { store.enter(digit) }
        store.newSession(.challenge)
        store.start()
        store.enter(9)
        for digit in PiDigits.values.dropFirst() { store.enter(digit) }
        store.newSession(.challenge)
        store.start()
        store.pause()
        store.start()
        for digit in PiDigits.values { store.enter(digit) }
        let service = GameCenterService()
        let probe = ScoreProbe()
        await service.submitScores(from: store) { _ in probe.calls += 1 }
        XCTAssertEqual(probe.calls, 0)
        XCTAssertTrue(store.submittedIDs.isEmpty)
    }
    @MainActor func testOneRejectedScoreDoesNotBlockOtherPendingScores() async {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 20 })
        func finish() -> UUID {
            store.newSession(.challenge)
            store.start()
            for digit in PiDigits.values { store.enter(digit) }
            return store.records[0].id
        }
        let older = finish()
        let newer = finish()
        let service = GameCenterService()
        let probe = ScoreProbe()
        await service.submitScores(from: store) { _ in
            probe.calls += 1
            if probe.calls == 1 { throw NSError(domain: "Pi100Tests", code: 1) }
        }
        XCTAssertEqual(probe.calls, 2)
        XCTAssertFalse(store.submittedIDs.contains(newer))
        XCTAssertTrue(store.submittedIDs.contains(older))
        XCTAssertEqual(service.status, L.text("暂未提交，联网后可重试。", "Not submitted yet. Retry when online."))
        await service.submitScores(from: store) { _ in }
        XCTAssertTrue(store.submittedIDs.contains(newer))
        XCTAssertEqual(service.status, L.text("全球榜成绩已提交", "Global score submitted"))
    }
    @MainActor func testInFlightSubmissionAlsoSendsAScoreAddedDuringTheRequest() async {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = GameStore(fileURL: url, now: { 20 })
        func finish() -> UUID {
            store.newSession(.challenge)
            store.start()
            for digit in PiDigits.values { store.enter(digit) }
            return store.records[0].id
        }
        let first = finish()
        let service = GameCenterService()
        let probe = ScoreProbe()
        let resume = await service.submitScores(from: store) { _ in
            if probe.second == nil {
                probe.second = finish()
                await service.submitScores(from: store) { _ in probe.sawNestedSend = true }
            }
        }
        XCTAssertFalse(probe.sawNestedSend)
        XCTAssertFalse(resume)
        XCTAssertTrue(store.submittedIDs.contains(first))
        XCTAssertNotNil(probe.second)
        XCTAssertTrue(store.submittedIDs.contains(probe.second!))
    }
    @MainActor func testTallWindowPreferenceIsLinkedIntoTheApp() {
        let preference = TallWindowPreference(scenePhase: .active, availableSize: CGSize(width: 390, height: 844))
        XCTAssertEqual(preference.availableSize, CGSize(width: 390, height: 844))
        XCTAssertEqual(preference.scenePhase, .active)
    }
}

private final class MutableClock: @unchecked Sendable {
    var value: TimeInterval = 0
}

@MainActor private final class ScoreProbe {
    var calls = 0
    var second: UUID?
    var sawNestedSend = false
}
