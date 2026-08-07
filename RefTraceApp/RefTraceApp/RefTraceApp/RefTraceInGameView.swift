import SwiftUI

struct RefTraceInGameView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var watchManager: RefTraceWatchConnectivityManager
    @EnvironmentObject private var router: RefTraceAppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var activeSheet: InGameSheet?
    @State private var errorMessage: String?

    let gameID: UUID

    private var game: RefTraceGame? {
        gameStore.games.first { $0.id == gameID }
    }

    private var state: InGamePersistedState? {
        game.map { inGameStore.displayState(for: $0) }
    }

    var body: some View {
        Group {
            if let game, let state {
                if inGameStore.isAssignedOfficial(game: game, profile: gameStore.profile) {
                    fieldDisplay(game: game, state: state)
                } else {
                    ContentUnavailableView("Assigned Officials Only", systemImage: "lock.shield", description: Text("Only officials assigned to this game can access production game controls."))
                }
            } else {
                ContentUnavailableView("Game Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("In Game")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { synchronizeWatch() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reconcileAndSync() }
        }
        .sheet(item: $activeSheet) { sheet in
            if let game {
                switch sheet {
                case .score:
                    RefTraceScoreEntryView(game: game)
                case .timeout:
                    RefTraceTimeoutEntryView(game: game)
                case .more:
                    RefTraceMoreGameActionsView(game: game)
                case .rules:
                    LeagueRulesPenaltyAssistantView(game: game)
                }
            }
        }
        .alert("Game Action", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func fieldDisplay(game: RefTraceGame, state: InGamePersistedState) -> some View {
        GeometryReader { proxy in
            VStack(spacing: scaledSpacing(for: proxy.size.height)) {
                Text("In-Game Display")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.01))
                    .accessibilityIdentifier("RefTraceInGameReady")
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_IN_GAME") {
                    uiTestShortcutControls
                }
                #endif
                compactHeader(game: game, state: state)
                teamScoreDisplay(game: game, state: state)
                clockDisplay(game: game, state: state)
                timeoutPossessionRow(game: game, state: state)
                officialPositionCard(game: game)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 70)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(RefTraceTheme.navy.ignoresSafeArea())
            .foregroundStyle(.white)
            .accessibilityIdentifier("RefTraceInGameView")
            .overlay(alignment: .bottom) {
                VStack(spacing: 6) {
                    controls(game: game, state: state)
                    rulesButton
                }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .background(RefTraceTheme.navy)
            }
        }
    }

    private func compactHeader(game: RefTraceGame, state: InGamePersistedState) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.leagueName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text("\(game.sport.rawValue) • \(game.fieldOrCourt)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.currentPeriod)
                    .font(.subheadline.weight(.semibold))
                Label(state.status.rawValue.capitalized, systemImage: syncSymbol(for: game.syncStatus))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(syncColor(for: game.syncStatus))
            }
        }
        .padding(10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func teamScoreDisplay(game: RefTraceGame, state: InGamePersistedState) -> some View {
        HStack(alignment: .center, spacing: 8) {
            teamPanel(side: .away, name: game.awayTeamName, mascot: game.awayTeamMascot, score: state.awayScore, possession: state.possession)
            VStack(spacing: 2) {
                Text("Score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(state.awayScore) - \(state.homeScore)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: 116)
            teamPanel(side: .home, name: game.homeTeamName, mascot: game.homeTeamMascot, score: state.homeScore, possession: state.possession)
        }
    }

    private func teamPanel(side: TeamSide, name: String, mascot: String, score: Int, possession: PossessionState) -> some View {
        VStack(spacing: 4) {
            Text(side.displayName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.70))
            MascotBadge(teamName: name, mascot: mascot, hasPossession: possession.rawValue == side.rawValue)
            Text(name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(mascot.isEmpty ? " " : mascot)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white.opacity(0.78))
            Text("\(score)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(possession.rawValue == side.rawValue ? RefTraceTheme.gold.opacity(0.22) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(possession.rawValue == side.rawValue ? RefTraceTheme.gold : .white.opacity(0.15), lineWidth: possession.rawValue == side.rawValue ? 2 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(side.displayName) team, \(name) \(mascot), score \(score)\(possession.rawValue == side.rawValue ? ", possession" : "")")
    }

    private func clockDisplay(game: RefTraceGame, state: InGamePersistedState) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 2) {
                Text(state.gameClock.displayText)
                    .font(.system(size: 60, weight: .black, design: .monospaced))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text("Game Clock")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(state.gameClock.isRunning ? "Running" : state.gameClock.remainingTime == 0 ? "Expired" : "Stopped")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.gameClock.isRunning ? RefTraceTheme.success : RefTraceTheme.gold)
            }
            .frame(maxWidth: .infinity)
            if let playClock = state.playClock {
                VStack(spacing: 4) {
                    Text(playClock.displayText)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .minimumScaleFactor(0.7)
                    Text("Play Clock")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(width: 92)
                .frame(minHeight: 70)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func timeoutPossessionRow(game: RefTraceGame, state: InGamePersistedState) -> some View {
        HStack(spacing: 8) {
            timeoutBadge(title: "Away", value: state.awayTimeouts)
            timeoutBadge(title: "Home", value: state.homeTimeouts)
            if SportGameConfiguration.configuration(for: game).possessionEnabled {
                Button {
                    switchPossession(game: game, state: state)
                } label: {
                    Label(possessionText(state.possession, game: game), systemImage: "football.fill")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(RefTraceTheme.gold)
                .foregroundStyle(RefTraceTheme.navy)
            }
        }
    }

    private func timeoutBadge(title: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
            Text("\(title) TO")
            Text("\(value)")
                .font(.headline.weight(.black))
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func officialPositionCard(game: RefTraceGame) -> some View {
        HStack(spacing: 8) {
            Label("Your Position: \(inGameStore.displayPosition(for: game))", systemImage: "person.crop.circle.badge.checkmark")
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            if communicationStore.activeSession(for: game.id) != nil {
                Label("Comms", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RefTraceTheme.success)
            }
        }
        .padding(10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func controls(game: RefTraceGame, state: InGamePersistedState) -> some View {
        let isFootball = game.sport == .football
        let canControlFootballClock = !isFootball || inGameStore.canControlFootballClock(game: game, profile: gameStore.profile)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                if isFootball {
                    footballClockControlButton(game: game, state: state, canControl: canControlFootballClock)
                } else {
                    Button {
                        state.gameClock.isRunning ? inGameStore.stopGameClock(for: game, profile: gameStore.profile) : inGameStore.startGameClock(for: game, profile: gameStore.profile)
                        synchronizeWatch()
                    } label: {
                        Label(state.gameClock.isRunning ? "Stop Clock" : "Start Clock", systemImage: state.gameClock.isRunning ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(state.gameClock.isRunning ? RefTraceTheme.warning : RefTraceTheme.success)
                }

                if state.playClock != nil {
                    Button {
                        inGameStore.resetPlayClock(for: game, profile: gameStore.profile)
                        synchronizeWatch()
                    } label: {
                        Label("Reset Play", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canControlFootballClock)
                }
            }
            if isFootball {
                footballAutomationStatus(game: game)
            }
            HStack(spacing: 8) {
                Button { activeSheet = .score } label: {
                    Label("Add Score", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(RefTraceTheme.royalBlue)
                .accessibilityIdentifier("AddScoreButton")
                Button { performTimeoutAction(game: game) } label: {
                    Label(isFootball ? "Timeout / Stop" : "Timeout", systemImage: "timer")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .disabled(isFootball && !canControlFootballClock)
                .accessibilityIdentifier("TimeoutButton")
                Button { activeSheet = .more } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("MoreGameActionsButton")
            }
        }
        .font(.subheadline.weight(.bold))
    }

    private func footballClockControlButton(game: RefTraceGame, state: InGamePersistedState, canControl: Bool) -> some View {
        let footballState = inGameStore.displayFootballState(for: game)
        let title: String
        let icon: String
        let tint: Color
        if footballState.initialWhistleStartArmed {
            title = "Armed"
            icon = "waveform"
            tint = RefTraceTheme.gold
        } else if state.gameClock.isRunning {
            title = "Stop Clock"
            icon = "pause.fill"
            tint = RefTraceTheme.warning
        } else if footballState.gameClockState == .notStarted || state.status == .pregame {
            title = "Start Game"
            icon = "flag.checkered"
            tint = RefTraceTheme.success
        } else {
            title = "Resume Clock"
            icon = "play.fill"
            tint = RefTraceTheme.success
        }
        return Button {
            performFootballClockAction(game: game, state: state)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!canControl || footballState.initialWhistleStartArmed)
        .accessibilityIdentifier("FootballClockAuthorityButton")
    }

    private func footballAutomationStatus(game: RefTraceGame) -> some View {
        let footballState = inGameStore.displayFootballState(for: game)
        let text: String
        switch footballState.gameClockState {
        case .armedForOpeningWhistle:
            text = "Waiting for Head Referee whistle"
        case .running:
            text = "Crew whistles start the 25-second play clock. Game clock remains Head Referee controlled."
        case .timeout:
            text = "Timeout clock stop confirmed by Head Referee"
        default:
            text = inGameStore.canControlFootballClock(game: game, profile: gameStore.profile) ? "Head Referee clock controls enabled" : "Football game clock is Head Referee controlled"
        }
        return Label(text, systemImage: footballState.whistleDetectionState == .listening ? "ear" : "lock.shield")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("FootballAutomationStatus")
    }

    private func performFootballClockAction(game: RefTraceGame, state: InGamePersistedState) {
        do {
            let footballState = inGameStore.displayFootballState(for: game)
            if state.gameClock.isRunning {
                try inGameStore.stopGameClockAsHeadRef(for: game, profile: gameStore.profile)
            } else if footballState.gameClockState == .notStarted || state.status == .pregame {
                try inGameStore.startFootballGamePreparation(for: game, profile: gameStore.profile)
            } else {
                try inGameStore.resumeGameClockAsHeadRef(for: game, profile: gameStore.profile)
            }
            synchronizeWatch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performTimeoutAction(game: RefTraceGame) {
        do {
            if game.sport == .football {
                try inGameStore.requestFootballTimeoutStop(for: game, profile: gameStore.profile, source: .iPhone)
                synchronizeWatch()
            }
            activeSheet = .timeout
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var rulesButton: some View {
        Button { activeSheet = .rules } label: {
            Label("League Rules & Penalty Assistant", systemImage: "book.closed.fill")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(RefTraceTheme.gold)
        .foregroundStyle(RefTraceTheme.navy)
        .accessibilityLabel("League Rules and Penalty Assistant")
        .accessibilityIdentifier("LeagueRulesPenaltyAssistantButton")
    }

    #if DEBUG
    private var uiTestShortcutControls: some View {
        HStack(spacing: 8) {
            Button("Add Score") { activeSheet = .score }
                .accessibilityIdentifier("AddScoreButton")
            Button("Timeout") { activeSheet = .timeout }
                .accessibilityIdentifier("TimeoutButton")
            Button("More") { activeSheet = .more }
                .accessibilityIdentifier("MoreGameActionsButton")
            Button("Rules") { activeSheet = .rules }
                .accessibilityIdentifier("LeagueRulesPenaltyAssistantButton")
        }
        .buttonStyle(.borderedProminent)
        .font(.caption.weight(.bold))
    }
    #endif

    private func switchPossession(game: RefTraceGame, state: InGamePersistedState) {
        let next: PossessionState
        switch state.possession {
        case .home: next = .away
        case .away: next = .home
        default: next = .home
        }
        do {
            try inGameStore.changePossession(to: next, game: game, profile: gameStore.profile)
            synchronizeWatch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func possessionText(_ possession: PossessionState, game: RefTraceGame) -> String {
        switch possession {
        case .home: return "Possession: \(game.homeTeamName)"
        case .away: return "Possession: \(game.awayTeamName)"
        case .pendingKickoff: return "Pending Kickoff"
        case .unknown: return "Set Possession"
        case .notApplicable: return "No Possession"
        }
    }

    private func synchronizeWatch() {
        if let game { inGameStore.synchronizeWatch(for: game, manager: watchManager) }
    }

    private func reconcileAndSync() {
        if let game { _ = inGameStore.reconciledState(for: game); synchronizeWatch() }
    }

    private func syncSymbol(for sync: RefTraceSyncState) -> String {
        switch sync {
        case .upToDate: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .pending: return "clock.fill"
        case .offline: return "wifi.slash"
        case .failed: return "exclamationmark.triangle.fill"
        case .authenticationRequired: return "person.crop.circle.badge.exclamationmark"
        }
    }

    private func syncColor(for sync: RefTraceSyncState) -> Color {
        switch sync {
        case .upToDate: return RefTraceTheme.success
        case .syncing, .pending: return RefTraceTheme.gold
        case .offline, .failed, .authenticationRequired: return RefTraceTheme.warning
        }
    }

    private func scaledSpacing(for height: CGFloat) -> CGFloat {
        height < 700 ? 6 : 10
    }
}

private enum InGameSheet: Identifiable {
    case score
    case timeout
    case more
    case rules
    var id: String { String(describing: self) }
}

private struct MascotBadge: View {
    let teamName: String
    let mascot: String
    let hasPossession: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(hasPossession ? RefTraceTheme.gold : .white.opacity(0.16))
            if !mascot.isEmpty {
                Text(String(mascot.prefix(1)).uppercased())
                    .font(.title2.weight(.black))
                    .foregroundStyle(hasPossession ? RefTraceTheme.navy : .white)
            } else if !teamName.isEmpty {
                Text(String(teamName.prefix(2)).uppercased())
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "shield.fill")
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

struct RefTraceInGameView_Previews: PreviewProvider {
    static var previews: some View {
        let store = RefTraceGameStore(loadSamples: false)
        let inGame = RefTraceInGameStore(storageURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("preview-in-game.json"))
        let communication = CommunicationStore()
        let watch = RefTraceWatchConnectivityManager()
        NavigationStack {
            RefTraceInGameView(gameID: RefTraceGameStore.sampleGames()[0].id)
        }
        .environmentObject(store)
        .environmentObject(inGame)
        .environmentObject(communication)
        .environmentObject(watch)
        .environmentObject(RefTraceAppRouter())
    }
}
