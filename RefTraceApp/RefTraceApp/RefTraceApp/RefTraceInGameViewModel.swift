import Foundation
import Combine

@MainActor
final class RefTraceInGameViewModel: ObservableObject {
    @Published private(set) var game: RefTraceGame?
    @Published private(set) var homeScore = 0
    @Published private(set) var awayScore = 0
    @Published private(set) var homeTimeouts = 0
    @Published private(set) var awayTimeouts = 0
    @Published private(set) var possession: PossessionState = .unknown
    @Published private(set) var gameClockState: GameClockState?
    @Published private(set) var playClockState: PlayClockState?
    @Published private(set) var currentPeriod = "Pregame"
    @Published private(set) var assignedOfficialPosition = "Official"
    @Published private(set) var scoreEvents: [ScoreEvent] = []
    @Published private(set) var timeoutEvents: [TimeoutEvent] = []
    @Published private(set) var recentGameEvents: [GameEventRecord] = []
    @Published private(set) var activeRuleDocument: String?
    @Published private(set) var watchSyncStatus: RefTraceWatchSyncStatus = .noActiveGame
    @Published private(set) var persistenceStatus: RefTraceSyncState = .upToDate
    @Published var currentError: String?

    func loadGame(_ game: RefTraceGame, store: RefTraceInGameStore) {
        self.game = game
        let state = store.reconciledState(for: game)
        homeScore = state.homeScore
        awayScore = state.awayScore
        homeTimeouts = state.homeTimeouts
        awayTimeouts = state.awayTimeouts
        possession = state.possession
        gameClockState = state.gameClock
        playClockState = state.playClock
        currentPeriod = state.currentPeriod
        assignedOfficialPosition = store.displayPosition(for: game)
        scoreEvents = store.scoreEvents[game.id, default: []]
        timeoutEvents = store.timeoutEvents[game.id, default: []]
        recentGameEvents = Array(store.gameEvents[game.id, default: []].suffix(10))
        activeRuleDocument = game.ruleDocumentID
        watchSyncStatus = store.watchSyncStatus
        persistenceStatus = state.syncStatus
        currentError = store.currentError
    }

    func startGameClock(store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) {
        guard let game else { return }
        store.startGameClock(for: game, profile: profile)
        loadGame(game, store: store)
    }

    func stopGameClock(store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) {
        guard let game else { return }
        store.stopGameClock(for: game, profile: profile)
        loadGame(game, store: store)
    }

    func adjustGameClock(delta: TimeInterval, store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) {
        guard let game else { return }
        store.adjustGameClock(for: game, delta: delta, profile: profile)
        loadGame(game, store: store)
    }

    func resetPlayClock(store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) {
        guard let game else { return }
        store.resetPlayClock(for: game, profile: profile)
        loadGame(game, store: store)
    }

    func addScore(team: TeamSide, scoreType: ScoreType, points: Int? = nil, store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) throws {
        guard let game else { return }
        _ = try store.addScore(to: team, scoreType: scoreType, points: points, game: game, profile: profile)
        loadGame(game, store: store)
    }

    func recordTimeout(_ timeoutType: TimeoutType, store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) throws {
        guard let game else { return }
        _ = try store.recordTimeout(timeoutType, game: game, profile: profile)
        loadGame(game, store: store)
    }

    func changePossession(_ newPossession: PossessionState, store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) throws {
        guard let game else { return }
        try store.changePossession(to: newPossession, game: game, profile: profile)
        loadGame(game, store: store)
    }

    func changePeriod(_ period: String, store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) {
        guard let game else { return }
        store.changePeriod(for: game, to: period, profile: profile)
        loadGame(game, store: store)
    }

    func openRulesAssistant() {}
    func saveGameState() {}
    func appendGameEvent() {}

    func synchronizeWatch(store: RefTraceInGameStore, manager: RefTraceWatchConnectivityManager) {
        guard let game else { return }
        store.synchronizeWatch(for: game, manager: manager)
        loadGame(game, store: store)
    }

    func completeGame(store: RefTraceInGameStore, profile: RefTraceOfficialProfile?) {
        guard let game else { return }
        store.completeGame(game, profile: profile)
        loadGame(game, store: store)
    }
}
