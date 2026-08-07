import SwiftUI

struct RefTraceHomeView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = RefTraceHomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                upcomingGamesSection
                if let message = store.needsAttentionMessage {
                    statusBanner(message)
                }
                primaryActions
                activeGameSection
                recentGamesSection
                quickAccessSection
                syncStatusSection
            }
            .padding()
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.go(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .refreshable {
            viewModel.refreshUpcomingGames(from: store)
        }
        .onAppear {
            viewModel.loadHomeData(from: store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.loadHomeData(from: store)
            }
        }
        .onChange(of: store.games) { _, _ in
            viewModel.loadHomeData(from: store)
        }
        .onChange(of: store.pendingAssignments) { _, _ in
            viewModel.processOfficialEaseUpdate(from: store)
        }
        .onChange(of: store.syncSummary) { _, _ in
            viewModel.loadHomeData(from: store)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? RefTraceTheme.navy : Color(.systemGroupedBackground)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "whistle.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(RefTraceTheme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("RefTrace")
                    .font(.largeTitle.bold())
                Text(welcomeText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var welcomeText: String {
        if let name = store.profile?.preferredDisplayName, !name.isEmpty {
            return "Welcome, \(name)"
        }
        return "Welcome to RefTrace"
    }

    private var upcomingGamesSection: some View {
        RefTraceUpcomingGamesSection(
            games: viewModel.upcomingGames,
            isLoading: viewModel.isLoadingUpcomingGames,
            errorMessage: viewModel.upcomingGamesError,
            tapAction: { game in
                viewModel.routeToUpcomingGame(game, router: router)
            },
            viewAllAction: {
                router.go(.upcomingGames)
            }
        )
    }

    private var primaryActions: some View {
        VStack(spacing: 12) {
            RefTracePrimaryActionButton(
                title: "Create New Game",
                subtitle: "Enter game details manually",
                systemImage: "plus.circle.fill"
            ) {
                router.go(.createGame)
            }
            RefTracePrimaryActionButton(
                title: "Pull from OfficialEase",
                subtitle: "Retrieve an assigned game",
                systemImage: "arrow.down.circle.fill"
            ) {
                router.go(.importOfficialEaseGame)
            }
        }
    }

    private var activeGameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Active Game")
            if let game = store.activeGame {
                RefTraceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(game.teamsDisplayName)
                            .font(.headline)
                        Text("\(game.sport.rawValue) • \(game.leagueName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Label("\(game.awayScore)-\(game.homeScore)", systemImage: "sportscourt")
                            Spacer()
                            Text(game.currentPeriod)
                            Text(game.gameClockStatus)
                        }
                        .font(.subheadline)
                        Text("\(game.gameSiteName) • \(game.status.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Last saved \(game.lastSavedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            router.go(.inGame(game.id))
                        } label: {
                            Label("Resume Game", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                RefTraceCard {
                    Text("No active game")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Recent Games")
                Spacer()
                Button("View All Games") { router.go(.gameHistory) }
            }
            if store.recentGames.isEmpty {
                RefTraceCard {
                    Text("No games have been created or imported.")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(store.recentGames.prefix(5)) { game in
                        Button {
                            router.go(.gameManagement(game.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.teamsDisplayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(game.sport.rawValue) • \(game.leagueName) • \(game.status.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(game.gameDate.formatted(date: .abbreviated, time: .omitted)) • \(game.source.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if game.isCompleted {
                                    Text("\(game.awayScore)-\(game.homeScore)")
                                        .font(.headline)
                                }
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: RefTraceTheme.cardRadius))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Quick Access")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                quickButton("Rules", systemImage: "book.closed") { router.go(.rules) }
                quickButton("Game Viewer", systemImage: "eye.fill") { router.go(.gameViewerDiscovery) }
                quickButton("Completed Games", systemImage: "checkmark.circle") { router.go(.completedGames) }
                quickButton("Sync Status", systemImage: "arrow.triangle.2.circlepath") { router.go(.syncStatus) }
                quickButton("Settings", systemImage: "gearshape") { router.go(.settings) }
                #if DEBUG
                quickButton("Home Testing", systemImage: "slider.horizontal.3") { router.go(.homeTesting) }
                #endif
            }
        }
    }

    private var syncStatusSection: some View {
        RefTraceCard {
            HStack {
                Label(store.syncSummary.connectionStatus.rawValue, systemImage: syncSymbol)
                    .foregroundStyle(syncColor)
                Spacer()
                Text("Last sync \(lastSyncText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture { router.go(.syncStatus) }
    }

    private var syncSymbol: String {
        switch store.syncSummary.connectionStatus {
        case .upToDate: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .pending: return "clock.fill"
        case .offline: return "wifi.slash"
        case .failed: return "exclamationmark.triangle.fill"
        case .authenticationRequired: return "person.crop.circle.badge.exclamationmark"
        }
    }

    private var syncColor: Color {
        switch store.syncSummary.connectionStatus {
        case .upToDate: return RefTraceTheme.success
        case .syncing, .pending: return RefTraceTheme.gold
        case .offline, .failed, .authenticationRequired: return RefTraceTheme.warning
        }
    }

    private var lastSyncText: String {
        store.syncSummary.lastSuccessfulSync?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
    }

    private func statusBanner(_ message: String) -> some View {
        Button {
            if store.syncSummary.connectionStatus == .offline || store.syncSummary.pendingOutboundRecords > 0 {
                router.go(.syncStatus)
            } else if !store.pendingAssignments.isEmpty {
                router.go(.importOfficialEaseGame)
            } else if let activeGame = store.activeGame {
                router.go(.gameManagement(activeGame.id))
            }
        } label: {
            Label(message, systemImage: "bell.badge.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RefTraceTheme.gold.opacity(0.24), in: RoundedRectangle(cornerRadius: RefTraceTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private func quickButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
    }
}
