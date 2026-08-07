#if DEBUG
import SwiftUI

struct RefTraceInGameTestingView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @EnvironmentObject private var watchManager: RefTraceWatchConnectivityManager
    @EnvironmentObject private var router: RefTraceAppRouter
    let gameID: UUID
    @State private var lastMessage = "Ready"

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } ?? gameStore.activeGame }

    var body: some View {
        List {
            Section("Demo State") {
                Text("Local deterministic demo only. AI, Watch, networking, and backend sync are simulated unless a production service is configured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Football Four-Official Game") { loadSport(.football, crew: 4) }
                Button("Football Five-Official Game") { loadSport(.football, crew: 5) }
                Button("Flag Football Two-Official Game") { loadSport(.flagFootball, crew: 2) }
                Button("Soccer Game") { loadSport(.soccer, crew: 3) }
                Button("Lacrosse Game") { loadSport(.lacrosse, crew: 3) }
                Button("Missing Mascot Fallback") { loadMissingMascots() }
            }
            if let game {
                Section("Clock") {
                    Button("Start Game Clock") { inGameStore.startGameClock(for: game, profile: gameStore.profile); sync(game) }
                    Button("Stop Game Clock") { inGameStore.stopGameClock(for: game, profile: gameStore.profile); sync(game) }
                    Button("Expire Game Clock") { inGameStore.adjustGameClock(for: game, delta: -99999, profile: gameStore.profile); sync(game) }
                    Button("Start Play Clock") { inGameStore.startPlayClock(for: game, profile: gameStore.profile); sync(game) }
                    Button("Reset Play Clock") { inGameStore.resetPlayClock(for: game, profile: gameStore.profile); sync(game) }
                    Button("Expire Play Clock") { inGameStore.resetPlayClock(for: game, to: 1, profile: gameStore.profile); inGameStore.startPlayClock(for: game, profile: gameStore.profile); sync(game) }
                    Button("Simulate Background/Foreground Recovery") { inGameStore.startGameClock(for: game, profile: gameStore.profile); lastMessage = "Clock is timestamp based and will reconcile on foreground." }
                }
                if game.sport == .football {
                    Section("Football Whistle Automation") {
                        Button("Set Current User as Head Referee") { setAssignedPosition("Head Ref", game: game) }
                        Button("Set Current User as Line Judge") { setAssignedPosition("Line Judge", game: game) }
                        Button("Start Game Selected") { startFootballPreparation(game) }
                        Button("Head Ref Valid Whistle") { simulateWhistle(game: game, officialID: gameStore.profile?.officialID ?? "official-harvey", position: .headReferee, confidence: 0.95) }
                        Button("Non-Head-Ref Pre-Start Whistle") { simulateWhistle(game: game, officialID: "line-judge", position: .linesman, confidence: 0.95) }
                        Button("Low-Confidence Whistle") { simulateWhistle(game: game, officialID: gameStore.profile?.officialID ?? "official-harvey", position: .headReferee, confidence: 0.3) }
                        Button("Crew End-of-Play Whistle") { simulateWhistle(game: game, officialID: "line-judge", position: .linesman, confidence: 0.94) }
                        Button("Three Simultaneous Crew Whistles") { simulateSimultaneousWhistles(game) }
                        Button("Head Ref Timeout") { simulateHeadRefTimeout(game) }
                        Button("Non-Head-Ref Timeout Attempt") { simulateUnauthorizedTimeout(game) }
                        Button("Q2 Crosses 2:05") { simulateTwoMinuteWarning(game, quarter: "Q2") }
                        Button("Q4 Crosses 2:05") { simulateTwoMinuteWarning(game, quarter: "Q4") }
                        Button("View Football Clock Log") { router.go(.gameLog(game.id)) }
                    }
                }
                Section("Scoring") {
                    Button("Add Football Touchdown") { addScore(.touchdown(points: 6), game: game) }
                    Button("Add Extra Point") { addScore(.extraPointKick(points: 1), game: game) }
                    Button("Add Field Goal") { addScore(.fieldGoal(points: 3), game: game) }
                    Button("Add Safety") { addScore(.safety(points: 2), game: game) }
                    Button("Add Flag Football Touchdown") { addScore(.touchdown(points: 6), game: game) }
                    Button("Add Soccer Goal") { addScore(.goal(points: 1), game: game) }
                    Button("Add Lacrosse Goal") { addScore(.goal(points: 1), game: game) }
                    Button("Correct Score") { correctScore(game) }
                    Button("Reverse Last Score") { reverseLastScore(game) }
                }
                Section("Timeouts and Possession") {
                    Button("Record Home Timeout") { recordTimeout(.homeTeam, game: game) }
                    Button("Record Away Timeout") { recordTimeout(.awayTeam, game: game) }
                    Button("Record Official Timeout") { recordTimeout(.official, game: game) }
                    Button("Change Possession") { changePossession(game) }
                }
                Section("Rules, Logs, Watch") {
                    Button("Open League Rules") { router.go(.rules) }
                    Button("Ask Mock AI Supported Question") { _ = inGameStore.answerRulesQuestion("What is defensive holding?", game: game, profile: gameStore.profile); lastMessage = "Mock supported/context response logged." }
                    Button("Ask Mock AI Unsupported Question") { _ = inGameStore.answerRulesQuestion("What is an unsupported invented foul?", game: game, profile: gameStore.profile); lastMessage = "Unsupported response logged without fabrication." }
                    Button("Add Penalty Placeholder") { inGameStore.addPenaltyPlaceholder(for: game, profile: gameStore.profile) }
                    Button("View Score Log") { router.go(.scoreLog(game.id)) }
                    Button("View Full Game Log") { router.go(.gameLog(game.id)) }
                    Button("Simulate Watch Connection") { sync(game); lastMessage = watchManager.status.displayText }
                    Button("Simulate Watch Disconnection") { lastMessage = "Disconnected state must be verified with a real paired Watch target." }
                    Button("Complete Game") { inGameStore.completeGame(game, profile: gameStore.profile); lastMessage = "Game completed in local in-game log." }
                }
            }
            Section("Status") {
                Text(lastMessage)
                Button("Open In-Game Display") {
                    if let game { router.go(.inGame(game.id)) }
                }
                Button("Reset Demo Data", role: .destructive) { inGameStore.resetDemoData(); lastMessage = "In-game demo data reset." }
            }
        }
        .navigationTitle("In-Game Testing")
    }

    private func loadSport(_ sport: RefTraceSport, crew: Int) {
        gameStore.resetAllTestData()
        var game = RefTraceGameStore.sampleGames().first { $0.sport == sport } ?? RefTraceGameStore.sampleGames()[0]
        game.id = UUID()
        game.status = .active
        game.assignedPosition = position(for: sport, crew: crew)
        game.otherOfficials = (1..<crew).map { "Official \($0 + 1)" }
        if sport == .football && crew == 5 { game.assignedPosition = "Back Judge" }
        try? gameStore.replaceGamesForTesting([game])
        inGameStore.resetDemoData()
        _ = inGameStore.state(for: game)
        lastMessage = "Loaded \(sport.rawValue) with \(crew) officials."
    }

    private func loadMissingMascots() {
        loadSport(.football, crew: 4)
        guard var game = gameStore.activeGame else { return }
        game.homeTeamMascot = ""
        game.awayTeamMascot = ""
        try? gameStore.replaceGamesForTesting([game])
        lastMessage = "Loaded missing mascot fallback."
    }

    private func position(for sport: RefTraceSport, crew: Int) -> String {
        switch sport {
        case .football: return crew == 5 ? "Back Judge" : "Head Ref"
        case .flagFootball: return "Head Ref"
        case .soccer: return "Center Referee"
        case .lacrosse: return "Head Referee"
        }
    }

    private func setAssignedPosition(_ position: String, game: RefTraceGame) {
        var updated = game
        updated.assignedPosition = position
        updated.assignedOfficialID = gameStore.profile?.officialID
        updated.assignedOfficialName = gameStore.profile?.preferredDisplayName ?? "Demo Official"
        try? gameStore.replaceGamesForTesting([updated])
        lastMessage = "Current user set as \(position)."
    }

    private func startFootballPreparation(_ game: RefTraceGame) {
        do {
            try inGameStore.startFootballGamePreparation(for: game, profile: gameStore.profile)
            sync(game)
            lastMessage = "Waiting for Head Referee whistle."
        } catch { lastMessage = error.localizedDescription }
    }

    private func simulateWhistle(game: RefTraceGame, officialID: String, position: RefTraceOfficialPosition, confidence: Double) {
        let event = WhistleDetectionEvent(
            gameID: game.id,
            officialID: officialID,
            officialPosition: position,
            deviceReference: position == .headReferee ? "head-ref-device" : "crew-device",
            source: .localMock,
            detectedAt: Date(),
            classification: confidence > 0.8 ? .refereeWhistle : .possibleWhistle,
            confidence: confidence,
            estimatedDurationMilliseconds: 350,
            signalQuality: confidence > 0.8 ? .good : .poor
        )
        do {
            let processed = try inGameStore.processFootballWhistle(event, game: game, profile: gameStore.profile)
            sync(game)
            lastMessage = "Mock whistle: \(processed.triggeredAction.rawValue)"
        } catch { lastMessage = error.localizedDescription }
    }

    private func simulateSimultaneousWhistles(_ game: RefTraceGame) {
        simulateWhistle(game: game, officialID: "line-judge", position: .linesman, confidence: 0.94)
        simulateWhistle(game: game, officialID: "umpire", position: .umpire, confidence: 0.93)
        simulateWhistle(game: game, officialID: "back-judge", position: .backJudge, confidence: 0.92)
    }

    private func simulateHeadRefTimeout(_ game: RefTraceGame) {
        do {
            try inGameStore.requestFootballTimeoutStop(for: game, profile: gameStore.profile, source: .localMock)
            sync(game)
            lastMessage = "Head Referee timeout clock stop recorded."
        } catch { lastMessage = error.localizedDescription }
    }

    private func simulateUnauthorizedTimeout(_ game: RefTraceGame) {
        let otherProfile = RefTraceOfficialProfile(officialID: "line-judge", preferredDisplayName: "Line Judge")
        do {
            try inGameStore.requestFootballTimeoutStop(for: game, profile: otherProfile, source: .localMock)
            lastMessage = "Unexpected authorization success."
        } catch { lastMessage = error.localizedDescription }
    }

    private func simulateTwoMinuteWarning(_ game: RefTraceGame, quarter: String) {
        inGameStore.changePeriod(for: game, to: quarter, profile: gameStore.profile)
        do {
            try inGameStore.adjustGameClockAsHeadRef(for: game, delta: 125 - inGameStore.reconciledState(for: game).gameClock.remainingTime, profile: gameStore.profile, reason: "Testing two-minute warning pre-alert")
            _ = inGameStore.processTwoMinuteWarningIfNeeded(for: game, previousRemaining: 126, profile: gameStore.profile)
            sync(game)
            lastMessage = "Simulated \(quarter) 2:05 pre-alert."
        } catch { lastMessage = error.localizedDescription }
    }

    private func addScore(_ scoreType: ScoreType, game: RefTraceGame) {
        do {
            _ = try inGameStore.addScore(to: .home, scoreType: scoreType, game: game, profile: gameStore.profile)
            sync(game)
            lastMessage = "Score added."
        } catch { lastMessage = error.localizedDescription }
    }

    private func correctScore(_ game: RefTraceGame) {
        do {
            _ = try inGameStore.addScore(to: .home, scoreType: .manualAdjustment, points: 1, correctionStatus: .correction, reason: "Testing correction", game: game, profile: gameStore.profile)
            sync(game)
            lastMessage = "Correction linked through event log."
        } catch { lastMessage = error.localizedDescription }
    }

    private func reverseLastScore(_ game: RefTraceGame) {
        guard let event = inGameStore.scoreEvents[game.id, default: []].last else { lastMessage = "No score to reverse."; return }
        do {
            _ = try inGameStore.reverseScore(event, game: game, profile: gameStore.profile, reason: "Testing reversal")
            sync(game)
            lastMessage = "Score reversed with linked record."
        } catch { lastMessage = error.localizedDescription }
    }

    private func recordTimeout(_ timeout: TimeoutType, game: RefTraceGame) {
        do {
            if game.sport == .football {
                _ = try inGameStore.recordFootballTimeout(timeout, game: game, profile: gameStore.profile, source: .localMock)
            } else {
                _ = try inGameStore.recordTimeout(timeout, game: game, profile: gameStore.profile)
            }
            sync(game)
            lastMessage = "Timeout recorded."
        } catch { lastMessage = error.localizedDescription }
    }

    private func changePossession(_ game: RefTraceGame) {
        do {
            let current = inGameStore.reconciledState(for: game).possession
            try inGameStore.changePossession(to: current == .home ? .away : .home, game: game, profile: gameStore.profile)
            sync(game)
            lastMessage = "Possession changed."
        } catch { lastMessage = error.localizedDescription }
    }

    private func sync(_ game: RefTraceGame) {
        inGameStore.synchronizeWatch(for: game, manager: watchManager)
    }
}
#endif
