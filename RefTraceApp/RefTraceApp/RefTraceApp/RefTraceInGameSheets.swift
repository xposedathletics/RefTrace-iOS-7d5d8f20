import SwiftUI

struct RefTraceScoreEntryView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @EnvironmentObject private var watchManager: RefTraceWatchConnectivityManager
    @Environment(\.dismiss) private var dismiss
    let game: RefTraceGame
    @State private var selectedTeam: TeamSide = .home
    @State private var selectedScoreType: ScoreType
    @State private var manualPoints = 0
    @State private var note = ""
    @State private var errorMessage: String?

    init(game: RefTraceGame) {
        self.game = game
        let first = SportGameConfiguration.configuration(for: game).scoreTypes.first ?? .manualAdjustment
        _selectedScoreType = State(initialValue: first)
        _manualPoints = State(initialValue: first.defaultPoints)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Team") {
                    Picker("Team", selection: $selectedTeam) {
                        Text("Away: \(game.awayTeamName)").tag(TeamSide.away)
                        Text("Home: \(game.homeTeamName)").tag(TeamSide.home)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Score Type") {
                    Picker("Score Type", selection: $selectedScoreType) {
                        ForEach(SportGameConfiguration.configuration(for: game).scoreTypes) { scoreType in
                            Text("\(scoreType.displayName) (+\(scoreType.defaultPoints))").tag(scoreType)
                        }
                    }
                    Stepper("Point Value: \(manualPoints)", value: $manualPoints, in: 0...20)
                }
                Section("Game Clock") {
                    let state = inGameStore.reconciledState(for: game)
                    LabeledContent("Period", value: state.currentPeriod)
                    LabeledContent("Clock", value: state.gameClock.displayText)
                }
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(RefTraceTheme.warning) }
                }
            }
            .navigationTitle("Add Score")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirm") { confirmScore() } }
            }
            .onChange(of: selectedScoreType) { _, newValue in
                manualPoints = newValue.defaultPoints
            }
        }
    }

    private func confirmScore() {
        do {
            _ = try inGameStore.addScore(to: selectedTeam, scoreType: selectedScoreType, points: manualPoints, game: game, profile: gameStore.profile)
            inGameStore.synchronizeWatch(for: game, manager: watchManager)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RefTraceTimeoutEntryView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @EnvironmentObject private var watchManager: RefTraceWatchConnectivityManager
    @Environment(\.dismiss) private var dismiss
    let game: RefTraceGame
    @State private var timeoutType: TimeoutType = .homeTeam
    @State private var reason = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Timeout Type") {
                    Picker("Timeout", selection: $timeoutType) {
                        ForEach(TimeoutType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                Section("Current Timeouts") {
                    let state = inGameStore.reconciledState(for: game)
                    LabeledContent("Away", value: "\(state.awayTimeouts)")
                    LabeledContent("Home", value: "\(state.homeTimeouts)")
                    LabeledContent("Clock", value: state.gameClock.displayText)
                }
                Section("Reason") {
                    TextField("Optional note", text: $reason, axis: .vertical)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(RefTraceTheme.warning) }
                }
            }
            .navigationTitle("Record Timeout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Record") { recordTimeout() } }
            }
        }
    }

    private func recordTimeout() {
        do {
            if game.sport == .football {
                _ = try inGameStore.recordFootballTimeout(timeoutType, game: game, profile: gameStore.profile, source: .iPhone, reason: reason.isEmpty ? nil : reason)
            } else {
                _ = try inGameStore.recordTimeout(timeoutType, game: game, profile: gameStore.profile, reason: reason.isEmpty ? nil : reason)
            }
            inGameStore.synchronizeWatch(for: game, manager: watchManager)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RefTraceMoreGameActionsView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @EnvironmentObject private var watchManager: RefTraceWatchConnectivityManager
    @EnvironmentObject private var router: RefTraceAppRouter
    @Environment(\.dismiss) private var dismiss
    let game: RefTraceGame
    @State private var selectedPeriod: String
    @State private var errorMessage: String?

    init(game: RefTraceGame) {
        self.game = game
        let first = SportGameConfiguration.configuration(for: game).periods.first ?? "Q1"
        _selectedPeriod = State(initialValue: first)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Clock") {
                    if game.sport == .football && !inGameStore.canControlFootballClock(game: game, profile: gameStore.profile) {
                        Text("Football game-clock and play-clock corrections are Head Referee-only.")
                            .foregroundStyle(RefTraceTheme.warning)
                    }
                    Button("Add 10 Seconds") { adjustGameClock(delta: 10, reason: "Added 10 seconds from More Actions") }
                        .disabled(game.sport == .football && !inGameStore.canControlFootballClock(game: game, profile: gameStore.profile))
                    Button("Remove 10 Seconds") { adjustGameClock(delta: -10, reason: "Removed 10 seconds from More Actions") }
                        .disabled(game.sport == .football && !inGameStore.canControlFootballClock(game: game, profile: gameStore.profile))
                    if let playClock = inGameStore.reconciledState(for: game).playClock {
                        Button("Start Play Clock") { startPlayClock() }
                            .disabled(game.sport == .football && !inGameStore.canControlFootballClock(game: game, profile: gameStore.profile))
                        Button("Stop Play Clock") { stopPlayClock() }
                            .disabled(game.sport == .football && !inGameStore.canControlFootballClock(game: game, profile: gameStore.profile))
                        Button("Reset Alternate Play Clock") { resetAlternatePlayClock() }
                            .disabled(game.sport == .football && !inGameStore.canControlFootballClock(game: game, profile: gameStore.profile))
                        Text("Current play clock: \(playClock.displayText)").foregroundStyle(.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(RefTraceTheme.warning)
                    }
                }
                Section("Period") {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(SportGameConfiguration.configuration(for: game).periods, id: \.self) { Text($0).tag($0) }
                    }
                    Button("Set Period") { inGameStore.changePeriod(for: game, to: selectedPeriod, profile: gameStore.profile); sync() }
                }
                Section("Logs") {
                    Button("View Score Log") { dismiss(); router.go(.scoreLog(game.id)) }
                    Button("View Full Game Log") { dismiss(); router.go(.gameLog(game.id)) }
                }
                Section("Officials") {
                    Button("Officials Communication") { dismiss(); router.go(.officialsCommunication(game.id)) }
                    Button("Sync Status") { dismiss(); router.go(.syncStatus) }
                    #if DEBUG
                    Button("In-Game Testing") { dismiss(); router.go(.inGameTesting(game.id)) }
                    #endif
                }
                Section("Game Status") {
                    Button("Add Penalty Placeholder") { inGameStore.addPenaltyPlaceholder(for: game, profile: gameStore.profile); sync() }
                    Button("Complete Game", role: .destructive) {
                        inGameStore.completeGame(game, profile: gameStore.profile)
                        try? gameStore.complete(game)
                        sync()
                        dismiss()
                        router.go(.gameSummary(game.id))
                    }
                }
            }
            .navigationTitle("More Actions")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func adjustGameClock(delta: TimeInterval, reason: String) {
        do {
            if game.sport == .football {
                try inGameStore.adjustGameClockAsHeadRef(for: game, delta: delta, profile: gameStore.profile, reason: reason)
            } else {
                inGameStore.adjustGameClock(for: game, delta: delta, profile: gameStore.profile)
            }
            sync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPlayClock() {
        inGameStore.startPlayClock(for: game, profile: gameStore.profile)
        errorMessage = inGameStore.currentError
        sync()
    }

    private func stopPlayClock() {
        inGameStore.stopPlayClock(for: game, profile: gameStore.profile)
        errorMessage = inGameStore.currentError
        sync()
    }

    private func resetAlternatePlayClock() {
        inGameStore.resetPlayClock(for: game, to: SportGameConfiguration.configuration(for: game).alternatePlayClock, profile: gameStore.profile)
        errorMessage = inGameStore.currentError
        sync()
    }

    private func sync() {
        inGameStore.synchronizeWatch(for: game, manager: watchManager)
    }
}

struct RefTraceScoreLogView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    let gameID: UUID

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } }
    private var events: [ScoreEvent] { inGameStore.scoreEvents[gameID, default: []].sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        List {
            if events.isEmpty {
                ContentUnavailableView("No Scores Recorded", systemImage: "list.bullet.rectangle")
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(event.period) — \(event.gameClockTime)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(event.correctionStatus.rawValue.capitalized).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text("\(event.scoringTeamName) \(event.scoreType.displayName) \(event.pointValue >= 0 ? "+" : "")\(event.pointValue)")
                            .font(.headline)
                        Text("Home \(event.homeScoreAfter), Away \(event.awayScoreAfter)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Entered by \(event.enteredByOfficialName) • \(event.enteredByPosition)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Score Log")
    }
}

struct RefTraceGameLogView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    let gameID: UUID
    @State private var filter: GameLogFilter = .all

    private var events: [GameEventRecord] {
        inGameStore.gameEvents[gameID, default: []]
            .filter { filter.matches($0) }
            .sorted { $0.sequenceNumber > $1.sequenceNumber }
    }

    var body: some View {
        VStack {
            Picker("Filter", selection: $filter) {
                ForEach(GameLogFilter.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            List {
                if events.isEmpty {
                    ContentUnavailableView("No Events", systemImage: "tray")
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(event.eventType.rawValue).font(.headline)
                                Spacer()
                                Text("#\(event.sequenceNumber)").font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(event.period) • \(event.gameClockTime)").font(.subheadline).foregroundStyle(.secondary)
                            Text(event.details).font(.body)
                            if let officialName = event.officialName {
                                Text("Entered by \(officialName)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Game Log")
    }
}

enum GameLogFilter: String, CaseIterable, Identifiable {
    case all
    case scores
    case timeouts
    case possession
    case clock
    case penalties
    case corrections

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    func matches(_ event: GameEventRecord) -> Bool {
        switch self {
        case .all: return true
        case .scores: return [.scoreAdded, .scoreCorrected, .scoreReversed].contains(event.eventType)
        case .timeouts: return [.timeoutTaken, .timeoutCorrected, .timeoutRequested, .timeoutClockStopped, .timeoutRecorded].contains(event.eventType)
        case .possession: return [.possessionChanged, .possessionCorrected].contains(event.eventType)
        case .clock: return [.startGameSelected, .openingWhistleArmed, .openingWhistleDetected, .openingWhistleRejected, .gameClockStarted, .gameClockStopped, .gameClockResumed, .gameClockAdjusted, .crewWhistleDetected, .crewWhistleMerged, .crewWhistleRejected, .endOfPlayDetected, .playClockStarted, .playClockStopped, .playClockReset, .playClockExpired, .twoMinutePreAlertSent, .twoMinuteWarningReached, .watchClockCommand, .watchCommandPending, .watchCommandConfirmed, .watchCommandFailed, .deviceDisconnected, .deviceReconnected].contains(event.eventType)
        case .penalties: return event.eventType == .penaltyPlaceholder
        case .corrections: return [.scoreCorrected, .scoreReversed, .timeoutCorrected, .possessionCorrected, .gameClockAdjusted].contains(event.eventType)
        }
    }
}

struct LeagueRulesPenaltyAssistantView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    let game: RefTraceGame
    @State private var question = ""
    @State private var response: PenaltyRulesAssistantResponse?
    @State private var showingRelatedRules = false

    private let quickQuestions = ["Fouls", "Penalty Distance", "Enforcement Spot", "Loss of Down", "Automatic First Down", "Clock Administration", "Possession Changes", "Scoring Plays", "Offsetting Fouls", "Dead-Ball Fouls", "Unsportsmanlike Conduct", "Overtime"]

    var body: some View {
        NavigationStack {
            List {
                Section("Rule Source") {
                    LabeledContent("League", value: game.leagueName)
                    LabeledContent("Sport", value: game.sport.rawValue)
                    LabeledContent("Rule Version", value: game.ruleVersion ?? "No approved synchronized rules")
                    if game.ruleDocumentID == nil && game.ruleVersion == nil {
                        Text("No approved synchronized rules are available. RefTrace will not fabricate a penalty answer.")
                            .foregroundStyle(RefTraceTheme.warning)
                    }
                }
                Section("Quick Questions") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                        ForEach(quickQuestions, id: \.self) { item in
                            Button(item) { question = item }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                Section("Ask") {
                    TextField("Ask a penalty or enforcement question", text: $question, axis: .vertical)
                    Button("Ask Assistant") { ask() }
                        .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let response {
                    Section("AI Rules Assistance") {
                        RulesAssistantResponseView(response: response)
                        Button("View Related Rules") { showingRelatedRules = true }
                        Text("AI rules assistance does not replace the Head Official’s final on-field ruling.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Recent Questions") {
                    ForEach(inGameStore.rulesQueryLogs[game.id, default: []].sorted { $0.createdAt > $1.createdAt }) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.questionText).font(.subheadline.weight(.semibold))
                            Text(log.responseSummary).font(.caption).foregroundStyle(.secondary)
                            Text(log.confidenceStatus.rawValue.capitalized).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Rules Assistant")
            .sheet(isPresented: $showingRelatedRules) {
                NavigationStack { RefTraceRulesView().navigationTitle("Related Rules") }
            }
        }
    }

    private func ask() {
        response = inGameStore.answerRulesQuestion(question, game: game, profile: gameStore.profile)
    }
}

private struct RulesAssistantResponseView: View {
    let response: PenaltyRulesAssistantResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Foul", response.foulName)
            row("Sport", response.sport.rawValue)
            row("League", response.league)
            row("Rule Version", response.ruleVersion ?? "Unknown")
            row("Penalty", response.penalty)
            row("Enforcement", response.enforcement)
            row("Additional Result", response.additionalResult)
            row("Classification", response.classification)
            row("Exceptions", response.exceptions)
            row("Source", response.source)
            row("Explanation", response.explanation)
            if !response.followUpQuestions.isEmpty {
                Text("Follow-up Questions").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                ForEach(response.followUpQuestions, id: \.self) { Text($0) }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

struct RefTraceGameSummaryView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    let gameID: UUID

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } }

    var body: some View {
        List {
            if let game {
                let state = inGameStore.reconciledState(for: game)
                Section("Final") {
                    Text(game.teamsDisplayName).font(.headline)
                    LabeledContent("Final Score", value: "Away \(state.awayScore), Home \(state.homeScore)")
                    LabeledContent("League", value: game.leagueName)
                    LabeledContent("Sport", value: game.sport.rawValue)
                    LabeledContent("Date", value: game.gameDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Game Site", value: game.gameSiteName)
                }
                Section("Game Records") {
                    LabeledContent("Scores", value: "\(inGameStore.scoreEvents[game.id, default: []].count)")
                    LabeledContent("Timeouts", value: "\(inGameStore.timeoutEvents[game.id, default: []].count)")
                    LabeledContent("Possession Changes", value: "\(inGameStore.possessionEvents[game.id, default: []].count)")
                    LabeledContent("Penalty Placeholders", value: "\(inGameStore.penaltyEvents[game.id, default: []].count)")
                    LabeledContent("Rules Questions", value: "\(inGameStore.rulesQueryLogs[game.id, default: []].count)")
                    LabeledContent("Communication Sessions", value: communicationStore.activeSession(for: game.id) == nil ? "None active" : "Available")
                    LabeledContent("Sync", value: state.syncStatus.rawValue)
                }
                Section("Officials") {
                    LabeledContent("Assigned", value: game.assignedOfficialName)
                    LabeledContent("Position", value: inGameStore.displayPosition(for: game))
                    ForEach(game.otherOfficials, id: \.self) { Text($0) }
                }
            } else {
                ContentUnavailableView("Game Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Game Summary")
    }
}
