import XCTest
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
        for digit in PiDigits.values { game.enter(digit, at: 200) }
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
}
