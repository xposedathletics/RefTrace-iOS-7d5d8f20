import SwiftUI

struct GameViewerDiscoveryView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @State private var games: [SpectatorGameSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    router.go(.gameViewerCode)
                } label: {
                    Label("Enter Viewer Code", systemImage: "number.square")
                }

                Button {
                    errorMessage = "QR scanning requires a production viewer-token service and camera configuration."
                } label: {
                    Label("Scan Game QR Code", systemImage: "qrcode.viewfinder")
                }
            }

            Section("My Available Games") {
                if isLoading {
                    ProgressView("Refreshing games")
                } else if games.isEmpty {
                    ContentUnavailableView("No games are currently available to view.", systemImage: "eye.slash")
                } else {
                    ForEach(games) { game in
                        Button {
                            router.go(.gameViewerAccessPreview(game.publicGameReference))
                        } label: {
                            SpectatorDiscoveryGameRow(game: game)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("SpectatorGameRow")
                    }
                }
            }
        }
        .navigationTitle("Game Viewer")
        .refreshable { await loadGames() }
        .task { await loadGames() }
        .alert("Game Viewer", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadGames() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
            games = try await service.availableGames(role: .authorizedViewer)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Live games could not be refreshed."
        }
    }
}

struct EnterGameViewerCodeView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @StateObject private var viewModel = CoachParentObserverGameViewModel()
    @State private var code = ""

    var body: some View {
        Form {
            Section("Viewer Code") {
                TextField("Enter viewer code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("GameViewerCodeField")
                Button {
                    Task { await validateCode() }
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let error = viewModel.accessError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(RefTraceTheme.warning)
                }
            }

            Section {
                Text("Viewer codes grant read-only access to approved score, clock, team, mascot, and possession information only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Enter Viewer Code")
    }

    private func validateCode() async {
        let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
        if let reference = await viewModel.validateAccess(codeOrToken: code.trimmingCharacters(in: .whitespacesAndNewlines), role: .authorizedViewer, service: service) {
            router.go(.gameViewerAccessPreview(reference))
        }
    }
}

struct GameViewerAccessPreviewView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @State private var state: SpectatorGameState?
    @State private var errorMessage: String?

    let publicGameReference: String

    var body: some View {
        Group {
            if let state {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Game Viewer")
                        .font(.title.bold())
                    SpectatorPreviewCard(state: state)
                    Button {
                        router.go(.gameViewer(publicGameReference))
                    } label: {
                        Label("Continue", systemImage: "eye.fill")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("SpectatorContinueButton")
                    Spacer()
                }
                .padding()
            } else if let errorMessage {
                ContentUnavailableView("Game Viewer", systemImage: "lock.shield", description: Text(errorMessage))
            } else {
                ProgressView("Validating access")
            }
        }
        .navigationTitle("Access Preview")
        .task { await loadPreview() }
    }

    private func loadPreview() async {
        do {
            let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
            let validation = try await service.validateAccess(
                SpectatorViewerAPI.ValidateAccessRequest(tokenOrCode: publicGameReference, role: .authorizedViewer, accessMethod: .authenticatedRefTrace)
            )
            guard let reference = validation.publicGameReference else { throw SpectatorPortalError.accessDenied }
            state = try await service.currentState(publicGameReference: reference)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "You do not have permission to view this game."
        }
    }
}

struct CoachParentObserverGameView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @StateObject private var viewModel = CoachParentObserverGameViewModel()

    let publicGameReference: String

    var body: some View {
        GeometryReader { proxy in
            Group {
                if viewModel.isLoading && viewModel.gameState == nil {
                    ProgressView("Loading live game")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let state = viewModel.gameState {
                    liveDisplay(state: state, height: proxy.size.height)
                } else {
                    ContentUnavailableView("Game Viewer", systemImage: "eye.slash", description: Text(viewModel.accessError ?? "Live game viewing is not available for this game."))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationTitle("Game Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
            await viewModel.loadGame(publicGameReference: publicGameReference, service: service)
        }
        .onDisappear {
            let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
            Task { await viewModel.stopViewing(publicGameReference: publicGameReference, service: service) }
        }
    }

    private func liveDisplay(state: SpectatorGameState, height: CGFloat) -> some View {
        VStack(spacing: height < 700 ? 10 : 16) {
            spectatorHeader(state)
            spectatorTeams(state)
            spectatorClock(state)
            if state.possessionVisible {
                spectatorPossession(state)
            }
            spectatorConnectionStatus
            Spacer(minLength: 0)
            Text("Read-only viewer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .background(RefTraceTheme.navy.ignoresSafeArea())
        .foregroundStyle(.white)
        .accessibilityIdentifier("CoachParentObserverGameView")
    }

    private func spectatorHeader(_ state: SpectatorGameState) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.leagueName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(state.sport.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.currentPeriod)
                    .font(.subheadline.weight(.semibold))
                Label(state.gameStatus.displayName, systemImage: statusSymbol(for: state.gameStatus))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor(for: state.gameStatus))
            }
        }
        .padding(10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func spectatorTeams(_ state: SpectatorGameState) -> some View {
        HStack(alignment: .center, spacing: 8) {
            SpectatorTeamPanel(side: .away, name: state.awayTeamName, mascot: state.awayTeamMascotReference, score: state.awayScore, possession: state.possession)
            VStack(spacing: 2) {
                Text("Score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(state.awayScore) - \(state.homeScore)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .accessibilityIdentifier("SpectatorScoreDisplay")
            }
            .frame(maxWidth: 116)
            SpectatorTeamPanel(side: .home, name: state.homeTeamName, mascot: state.homeTeamMascotReference, score: state.homeScore, possession: state.possession)
        }
    }

    private func spectatorClock(_ state: SpectatorGameState) -> some View {
        VStack(spacing: 2) {
            Text(viewModel.gameClockDisplay)
                .font(.system(size: 66, weight: .black, design: .monospaced))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .accessibilityIdentifier("SpectatorGameClock")
            Text("Game Clock")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
            Text(clockStatusText(for: state))
                .font(.caption.weight(.bold))
                .foregroundStyle(state.gameClockIsRunning ? RefTraceTheme.success : RefTraceTheme.gold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Game clock \(viewModel.gameClockDisplay), \(clockStatusText(for: state))")
    }

    private func spectatorPossession(_ state: SpectatorGameState) -> some View {
        Label(possessionText(state), systemImage: "football.fill")
            .font(.headline.weight(.bold))
            .foregroundStyle(RefTraceTheme.navy)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RefTraceTheme.gold, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("SpectatorPossession")
    }

    private var spectatorConnectionStatus: some View {
        VStack(spacing: 4) {
            Label(viewModel.dataStatus.displayName, systemImage: dataStatusSymbol(viewModel.dataStatus))
                .font(.caption.weight(.bold))
                .foregroundStyle(dataStatusColor(viewModel.dataStatus))
            if let lastUpdatedAt = viewModel.lastUpdatedAt {
                Text("Last update \(lastUpdatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.66))
            }
            if let connectionError = viewModel.connectionError {
                Text(connectionError)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RefTraceTheme.gold)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func possessionText(_ state: SpectatorGameState) -> String {
        switch state.possession {
        case .home: return "Possession: \(state.homeTeamName)"
        case .away: return "Possession: \(state.awayTeamName)"
        case .pendingKickoff: return "Possession: Pending kickoff"
        case .unknown: return "Possession: Unknown"
        case .notApplicable: return ""
        }
    }

    private func clockStatusText(for state: SpectatorGameState) -> String {
        if state.isFinal { return "Final" }
        if state.gameClockRemaining <= 0 { return "Expired" }
        return state.gameClockIsRunning ? "Running" : "Stopped"
    }

    private func statusSymbol(for status: SpectatorGameStatus) -> String {
        switch status {
        case .active: return "dot.radiowaves.left.and.right"
        case .completed: return "checkmark.seal.fill"
        case .cancelled, .unavailable: return "exclamationmark.triangle.fill"
        case .clockStopped, .halftime, .overtime, .delayed, .suspended: return "pause.circle.fill"
        case .scheduled, .warmup: return "calendar"
        }
    }

    private func statusColor(for status: SpectatorGameStatus) -> Color {
        switch status {
        case .active: return RefTraceTheme.success
        case .completed: return RefTraceTheme.gold
        case .cancelled, .unavailable: return RefTraceTheme.warning
        default: return .white.opacity(0.82)
        }
    }

    private func dataStatusSymbol(_ status: SpectatorDataStatus) -> String {
        switch status {
        case .live: return "checkmark.circle.fill"
        case .updating, .delayed, .lastUpdated: return "clock.fill"
        case .reconnecting: return "wifi.exclamationmark"
        case .final: return "flag.checkered"
        case .unavailable: return "wifi.slash"
        }
    }

    private func dataStatusColor(_ status: SpectatorDataStatus) -> Color {
        switch status {
        case .live, .final: return RefTraceTheme.success
        case .updating, .delayed, .lastUpdated, .reconnecting: return RefTraceTheme.gold
        case .unavailable: return RefTraceTheme.warning
        }
    }
}

struct GameViewerAccessManagementView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @State private var policy = SpectatorAccessPolicy()
    @State private var generatedCode: String?

    let publicGameReference: String

    var body: some View {
        Form {
            Section("Viewer Access") {
                Picker("Access Level", selection: $policy.accessLevel) {
                    ForEach(SpectatorAccessLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                Toggle("Require Authentication", isOn: $policy.authenticationRequired)
                Toggle("Require Viewer Code", isOn: $policy.viewerCodeRequired)
                Toggle("Allow Game Site Display", isOn: $policy.allowGameSiteDisplay)
                Toggle("Allow Team Mascots", isOn: $policy.allowTeamMascots)
                Toggle("Public Listing", isOn: $policy.allowPublicListing)
                Stepper("Display delay: \(policy.streamDelaySeconds)s", value: $policy.streamDelaySeconds, in: 0...300, step: 15)
            }

            Section("Viewer Code") {
                Button("Generate Viewer Code") {
                    let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
                    generatedCode = service.generateViewerCode(publicGameReference: publicGameReference)
                }
                if let generatedCode {
                    Text(generatedCode)
                        .font(.title3.monospaced().weight(.bold))
                }
                Button("Revoke Displayed Code", role: .destructive) {
                    guard let generatedCode else { return }
                    let service = LocalSpectatorGameStateService(gameStore: gameStore, inGameStore: inGameStore)
                    service.revokeViewerCode(generatedCode)
                }
                .disabled(generatedCode == nil)
            }

            Section {
                Text("Production viewer access must be enforced by the backend. This screen stores only local demo policy for RefTrace testing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Viewer Access")
    }
}

#if DEBUG
struct CoachParentObserverPortalTestingView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    @State private var message = "Local spectator demo only."

    var body: some View {
        List {
            Section("Demo Games") {
                Button("No available games") {
                    gameStore.resetAllTestData()
                    message = "No games are currently available to view."
                }
                Button("One live Football game") { loadGame(.football, status: .active) }
                Button("One live Flag Football game") { loadGame(.flagFootball, status: .active) }
                Button("One live Soccer game") { loadGame(.soccer, status: .active) }
                Button("One live Lacrosse game") { loadGame(.lacrosse, status: .active) }
                Button("Game completed") { loadGame(.football, status: .completed) }
                Button("Game cancelled") { loadGame(.football, status: .cancelled) }
            }

            Section("State Simulation") {
                Button("Score update") { addScore() }
                Button("Clock running") { withActiveGame { inGameStore.startGameClock(for: $0, profile: gameStore.profile) } }
                Button("Clock stopped") { withActiveGame { inGameStore.stopGameClock(for: $0, profile: gameStore.profile) } }
                Button("Home possession") { withActiveGame { _ = try? inGameStore.changePossession(to: .home, game: $0, profile: gameStore.profile) } }
                Button("Away possession") { withActiveGame { _ = try? inGameStore.changePossession(to: .away, game: $0, profile: gameStore.profile) } }
                Button("Open Viewer") {
                    if let game = gameStore.games.first {
                        router.go(.gameViewer(SpectatorGameState.publicReference(for: game)))
                    }
                }
            }

            Section("Access") {
                Text(message)
                Button("Viewer code accepted") { message = "Viewer code accepted." }
                Button("Viewer code rejected") { message = "This game-view code is invalid." }
                Button("Expired code") { message = "This game-view code has expired." }
                Button("Revoked code") { message = "This game-view code has been revoked." }
                Button("Connection lost") { message = "Live updates are temporarily unavailable. Showing the last received game state." }
                Button("Reset all demo data") {
                    gameStore.resetAllTestData()
                    inGameStore.resetDemoData()
                    message = "Local spectator demo only."
                }
            }
        }
        .navigationTitle("Viewer Testing")
    }

    private func loadGame(_ sport: RefTraceSport, status: RefTraceGameStatus) {
        gameStore.resetAllTestData()
        inGameStore.resetDemoData()
        var draft = CreateRefTraceGameDraft()
        draft.sport = sport
        draft.leagueName = sport == .flagFootball ? "Metro Flag League" : "County League"
        draft.homeTeamName = "Tigers"
        draft.homeTeamMascot = sport == .soccer ? "" : "Tiger"
        draft.awayTeamName = sport == .lacrosse ? "North Valley Long Name" : "Eagles"
        draft.awayTeamMascot = "Eagle"
        draft.gameSiteName = "Central Stadium"
        draft.gameSiteAddress = "100 Main Street"
        draft.fieldOrCourt = sport == .soccer ? "Pitch 2" : "Field 1"
        draft.scheduledStartTime = Date().addingTimeInterval(600)
        draft.reportTime = draft.scheduledStartTime.addingTimeInterval(-2700)
        draft.assignedPosition = sport == .flagFootball ? "Head Referee" : "Head Referee"
        do {
            let game = try gameStore.createGame(from: draft, openManagement: false)
            if status == .active {
                inGameStore.startGameClock(for: game, profile: gameStore.profile)
                _ = try? inGameStore.changePossession(to: .home, game: game, profile: gameStore.profile)
            }
            message = "Loaded \(sport.rawValue) viewer demo."
        } catch {
            message = "Could not load demo game."
        }
    }

    private func addScore() {
        withActiveGame { game in
            let type = SportGameConfiguration.configuration(for: game).scoreTypes.first ?? .manualAdjustment
            _ = try? inGameStore.addScore(to: .home, scoreType: type, game: game, profile: gameStore.profile)
        }
    }

    private func withActiveGame(_ action: (RefTraceGame) -> Void) {
        if let game = gameStore.activeGame ?? gameStore.games.first {
            action(game)
        }
    }
}
#endif

private struct SpectatorDiscoveryGameRow: View {
    let game: SpectatorGameSummary

    var body: some View {
        HStack(spacing: 12) {
            SpectatorSmallMascotBadge(teamName: game.awayTeamName, mascot: game.awayTeamMascotReference)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(teamDisplay(game.awayTeamName, game.awayTeamMascotReference)) vs. \(teamDisplay(game.homeTeamName, game.homeTeamMascotReference))")
                    .font(.headline)
                    .lineLimit(2)
                Text("\(game.sport.rawValue) • \(game.leagueName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(game.scheduledStartTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(game.gameStatus.displayName)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.18), in: Capsule())
                .foregroundStyle(statusColor)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        game.gameStatus == .active ? RefTraceTheme.success : game.gameStatus == .completed ? RefTraceTheme.gold : .secondary
    }

    private func teamDisplay(_ name: String, _ mascot: String) -> String {
        mascot.isEmpty ? name : "\(name) \(mascot)"
    }
}

private struct SpectatorPreviewCard: View {
    let state: SpectatorGameState

    var body: some View {
        RefTraceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(state.awayTeamName) vs. \(state.homeTeamName)")
                    .font(.title3.bold())
                Text("\(state.sport.rawValue) • \(state.leagueName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(state.scheduledStartTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                Label(state.gameStatus.displayName, systemImage: "dot.radiowaves.left.and.right")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SpectatorTeamPanel: View {
    let side: TeamSide
    let name: String
    let mascot: String
    let score: Int
    let possession: PossessionState

    private var hasPossession: Bool { possession.rawValue == side.rawValue }

    var body: some View {
        VStack(spacing: 4) {
            Text(side.displayName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.70))
            SpectatorMascotBadge(teamName: name, mascot: mascot, hasPossession: hasPossession)
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
        .background(hasPossession ? RefTraceTheme.gold.opacity(0.22) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(hasPossession ? RefTraceTheme.gold : .white.opacity(0.15), lineWidth: hasPossession ? 2 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(side.displayName) team, \(name) \(mascot), score \(score)\(hasPossession ? ", possession" : "")")
    }
}

private struct SpectatorMascotBadge: View {
    let teamName: String
    let mascot: String
    let hasPossession: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(hasPossession ? RefTraceTheme.gold.opacity(0.95) : .white.opacity(0.16))
            if mascot.isEmpty {
                Text(initials)
                    .font(.title3.weight(.black))
                    .foregroundStyle(hasPossession ? RefTraceTheme.navy : .white)
            } else {
                Image(systemName: mascotSymbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(hasPossession ? RefTraceTheme.navy : RefTraceTheme.gold)
            }
        }
        .frame(width: 58, height: 58)
        .accessibilityLabel(mascot.isEmpty ? "\(teamName) mascot unavailable" : "\(mascot) mascot")
    }

    private var initials: String {
        let parts = teamName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "T" : letters.uppercased()
    }

    private var mascotSymbol: String {
        let normalized = mascot.lowercased()
        if normalized.contains("tiger") || normalized.contains("lion") || normalized.contains("cat") { return "pawprint.fill" }
        if normalized.contains("eagle") || normalized.contains("hawk") || normalized.contains("bird") { return "bird.fill" }
        if normalized.contains("wolf") || normalized.contains("bear") { return "pawprint.fill" }
        return "shield.lefthalf.filled"
    }
}

private struct SpectatorSmallMascotBadge: View {
    let teamName: String
    let mascot: String

    var body: some View {
        ZStack {
            Circle().fill(RefTraceTheme.navy.opacity(0.12))
            Text(initials)
                .font(.caption.weight(.black))
                .foregroundStyle(RefTraceTheme.navy)
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private var initials: String {
        let source = mascot.isEmpty ? teamName : mascot
        let letters = source.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "G" : letters.uppercased()
    }
}

#Preview("Football Viewer") {
    CoachParentObserverGameView(publicGameReference: "game-preview")
        .environmentObject(RefTraceGameStore())
        .environmentObject(RefTraceInGameStore())
}
