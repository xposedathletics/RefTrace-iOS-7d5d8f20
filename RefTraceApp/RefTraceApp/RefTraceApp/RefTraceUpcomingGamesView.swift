import SwiftUI

struct RefTraceUpcomingGamesSection: View {
    let games: [UpcomingGameDisplayModel]
    let isLoading: Bool
    let errorMessage: String?
    let tapAction: (UpcomingGameDisplayModel) -> Void
    let viewAllAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OfficialEaseHomeLayout.groupSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(sectionTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OfficialEaseHomeColor.primaryTextOnNavy)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if games.count > 1 {
                    Button("View All", action: viewAllAction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OfficialEaseHomeColor.secondaryTextOnNavy)
                }
            }

            if isLoading {
                RefTraceUpcomingLoadingCard()
            }

            if let errorMessage {
                RefTraceUpcomingErrorCard(message: errorMessage)
            }

            if let nextGame = games.first {
                RefTraceUpcomingGameCard(game: nextGame, tapAction: tapAction)
            } else if !isLoading {
                RefTraceUpcomingEmptyCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitle: String {
        games.count == 1 ? "Upcoming Game" : "Upcoming Games"
    }
}

struct RefTraceUpcomingGameCard: View {
    let game: UpcomingGameDisplayModel
    let tapAction: (UpcomingGameDisplayModel) -> Void

    var body: some View {
        Button {
            tapAction(game)
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        assignmentTitle
                        Spacer(minLength: 12)
                        RefTraceUpcomingStatusBadge(status: game.assignmentStatus, syncStatus: game.syncStatus)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        assignmentTitle
                        RefTraceUpcomingStatusBadge(status: game.assignmentStatus, syncStatus: game.syncStatus)
                    }
                }

                VStack(spacing: 14) {
                    RefTraceUpcomingDetailRow(systemImage: "calendar", title: "Date", value: UpcomingGameDisplayModel.dateFormatter.string(from: game.gameDate))
                    RefTraceUpcomingDetailRow(systemImage: "clock.fill", title: "Report Time", value: UpcomingGameDisplayModel.timeFormatter.string(from: game.reportTime))
                    RefTraceUpcomingDetailRow(systemImage: "timer", title: "Start Time", value: UpcomingGameDisplayModel.timeFormatter.string(from: game.scheduledStartTime))
                    RefTraceUpcomingDetailRow(systemImage: "mappin.and.ellipse", title: "Location", value: game.locationDisplay)
                    RefTraceUpcomingDetailRow(systemImage: "whistle.fill", title: "Position", value: game.assignedPosition)
                }
            }
            .officialEaseHomeCardStyle(padding: OfficialEaseHomeLayout.cardPadding, cornerRadius: OfficialEaseHomeLayout.cardCornerRadius)
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: OfficialEaseHomeLayout.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.voiceOverLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var assignmentTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next Assignment")
                .font(.headline)
                .foregroundStyle(OfficialEaseHomeColor.secondaryTextOnCard)
                .fixedSize(horizontal: false, vertical: true)

            Text(game.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(OfficialEaseHomeColor.primaryTextOnCard)
                .fixedSize(horizontal: false, vertical: true)

            Text(game.teamsDisplay)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OfficialEaseHomeColor.primaryTextOnCard)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RefTraceUpcomingDetailRow: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                leadingLabel
                Spacer(minLength: 12)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OfficialEaseHomeColor.primaryTextOnCard)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                leadingLabel
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OfficialEaseHomeColor.primaryTextOnCard)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leadingLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(OfficialEaseHomeColor.royalBlue)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(OfficialEaseHomeColor.secondaryTextOnCard)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RefTraceUpcomingStatusBadge: View {
    let status: String
    let syncStatus: RefTraceSyncState

    var body: some View {
        Label(displayStatus, systemImage: statusSymbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(statusColor.opacity(0.18))
            .clipShape(Capsule())
            .accessibilityLabel("Status \(displayStatus)")
    }

    private var displayStatus: String {
        syncStatus == .pending ? "Sync Pending" : status
    }

    private var statusSymbol: String {
        switch displayStatus.lowercased() {
        case "accepted", "confirmed", "ready", "imported": return "checkmark.circle.fill"
        case "sync pending", "assigned", "scheduled", "sent", "awaiting response": return "clock.fill"
        case "active": return "play.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch displayStatus.lowercased() {
        case "accepted", "confirmed", "ready", "imported": return OfficialEaseHomeColor.goldText
        case "sync pending", "assigned", "scheduled", "sent", "awaiting response": return OfficialEaseHomeColor.goldText
        case "active": return RefTraceTheme.success
        default: return OfficialEaseHomeColor.goldText
        }
    }
}

private struct RefTraceUpcomingEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No upcoming games", systemImage: "sportscourt")
                .font(.headline)
                .foregroundStyle(OfficialEaseHomeColor.primaryTextOnCard)
            Text("Create a new game or pull an assignment from OfficialEase.")
                .font(.subheadline)
                .foregroundStyle(OfficialEaseHomeColor.secondaryTextOnCard)
        }
        .officialEaseHomeCardStyle(minHeight: 118)
        .accessibilityElement(children: .combine)
    }
}

private struct RefTraceUpcomingLoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Refreshing upcoming games")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OfficialEaseHomeColor.primaryTextOnCard)
        }
        .officialEaseHomeCardStyle(minHeight: 72)
    }
}

private struct RefTraceUpcomingErrorCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(OfficialEaseHomeColor.goldText)
            .officialEaseHomeCardStyle(minHeight: 72)
    }
}

struct RefTraceUpcomingGamesView: View {
    @EnvironmentObject private var router: RefTraceAppRouter
    @EnvironmentObject private var store: RefTraceGameStore
    @StateObject private var viewModel = RefTraceHomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OfficialEaseHomeLayout.cardSpacing) {
                if viewModel.upcomingGames.isEmpty {
                    RefTraceUpcomingEmptyCard()
                } else {
                    ForEach(viewModel.upcomingGames) { game in
                        RefTraceUpcomingGameCard(game: game) { selected in
                            viewModel.routeToUpcomingGame(selected, router: router)
                        }
                    }
                }
            }
            .padding(.horizontal, OfficialEaseHomeLayout.screenPadding)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(OfficialEaseHomeColor.mainBackground)
        .navigationTitle("Upcoming Games")
        .onAppear { viewModel.loadHomeData(from: store) }
    }
}

private enum OfficialEaseHomeColor {
    static let mainBackground = Color(red: 0.03, green: 0.10, blue: 0.22)
    static let navyAccent = Color(red: 0.06, green: 0.16, blue: 0.31)
    static let royalBlue = Color(red: 0.10, green: 0.36, blue: 0.92)
    static let gold = Color(red: 0.93, green: 0.68, blue: 0.19)

    static let cardBackground = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.07, green: 0.15, blue: 0.28, alpha: 1.0)
        }
        return UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
    })

    static let primaryTextOnCard = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark { return UIColor.white }
        return UIColor(red: 0.03, green: 0.10, blue: 0.22, alpha: 1.0)
    })

    static let secondaryTextOnCard = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark { return UIColor(white: 0.82, alpha: 1.0) }
        return UIColor(red: 0.30, green: 0.35, blue: 0.45, alpha: 1.0)
    })

    static let primaryTextOnNavy = Color.white
    static let secondaryTextOnNavy = Color(red: 0.82, green: 0.86, blue: 0.92)

    static let goldText = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 1.0, green: 0.79, blue: 0.28, alpha: 1.0)
        }
        return UIColor(red: 0.42, green: 0.29, blue: 0.03, alpha: 1.0)
    })
}

private enum OfficialEaseHomeLayout {
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let groupSpacing: CGFloat = 14
    static let cardSpacing: CGFloat = 14
    static let cardPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 16
}

private extension View {
    func officialEaseHomeCardStyle(
        padding: CGFloat = OfficialEaseHomeLayout.cardPadding,
        minHeight: CGFloat? = nil,
        cornerRadius: CGFloat = OfficialEaseHomeLayout.cardCornerRadius
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(OfficialEaseHomeColor.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("One upcoming Football game") {
    RefTraceUpcomingGamesSection(games: [PreviewUpcomingGames.football], isLoading: false, errorMessage: nil, tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Multiple Flag Football games") {
    RefTraceUpcomingGamesSection(games: [PreviewUpcomingGames.flagFootball, PreviewUpcomingGames.accepted, PreviewUpcomingGames.syncPending], isLoading: false, errorMessage: nil, tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Soccer long names") {
    RefTraceUpcomingGameCard(game: PreviewUpcomingGames.longSoccer, tapAction: { _ in })
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Lacrosse missing mascots") {
    RefTraceUpcomingGameCard(game: PreviewUpcomingGames.lacrosseMissingMascots, tapAction: { _ in })
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Awaiting Response status") {
    RefTraceUpcomingGameCard(game: PreviewUpcomingGames.awaitingResponse, tapAction: { _ in })
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Accepted status") {
    RefTraceUpcomingGameCard(game: PreviewUpcomingGames.accepted, tapAction: { _ in })
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Imported status") {
    RefTraceUpcomingGameCard(game: PreviewUpcomingGames.imported, tapAction: { _ in })
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Sync Pending status") {
    RefTraceUpcomingGameCard(game: PreviewUpcomingGames.syncPending, tapAction: { _ in })
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("No upcoming games") {
    RefTraceUpcomingGamesSection(games: [], isLoading: false, errorMessage: nil, tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Loading state") {
    RefTraceUpcomingGamesSection(games: [], isLoading: true, errorMessage: nil, tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Error with cached games") {
    RefTraceUpcomingGamesSection(games: [PreviewUpcomingGames.football], isLoading: false, errorMessage: "Upcoming games could not be refreshed. Showing saved games.", tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
}

#Preview("Dark mode") {
    RefTraceUpcomingGamesSection(games: [PreviewUpcomingGames.football], isLoading: false, errorMessage: nil, tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
        .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    RefTraceUpcomingGamesSection(games: [PreviewUpcomingGames.longSoccer], isLoading: false, errorMessage: nil, tapAction: { _ in }, viewAllAction: {})
        .padding()
        .background(OfficialEaseHomeColor.mainBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
}

private enum PreviewUpcomingGames {
    static let football = model(sport: "Football", league: "Varsity", home: "Wesley Chapel", homeMascot: "Wildcats", away: "Pasco", awayMascot: "Pirates", status: "Assigned")
    static let flagFootball = model(sport: "Flag Football", league: "Comeback Season League", home: "Eagles", homeMascot: "", away: "Tigers", awayMascot: "", status: "Confirmed")
    static let accepted = model(sport: "Flag Football", league: "Comeback Season League", home: "Eagles", homeMascot: "", away: "Tigers", awayMascot: "", status: "Accepted")
    static let imported = model(sport: "Football", league: "Youth Recreational League", home: "Hawks", homeMascot: "", away: "Panthers", awayMascot: "", status: "Imported")
    static let syncPending = model(sport: "Soccer", league: "Competitive Travel League", home: "United", homeMascot: "", away: "Rovers", awayMascot: "", status: "Ready", sync: .pending)
    static let awaitingResponse = model(sport: "Football", league: "Regional League", home: "North", homeMascot: "Tigers", away: "South", awayMascot: "Hawks", status: "Awaiting Response")
    static let longSoccer = model(sport: "Soccer", league: "Very Long Regional Competitive Travel League", home: "Wesley Chapel Championship Academy", homeMascot: "Wildcats", away: "Pasco County International", awayMascot: "Pirates", status: "Accepted")
    static let lacrosseMissingMascots = model(sport: "Lacrosse", league: "Youth", home: "Riverbend", homeMascot: "", away: "Lakeside", awayMascot: "", status: "Assigned")

    static func model(sport: String, league: String, home: String, homeMascot: String, away: String, awayMascot: String, status: String, sync: RefTraceSyncState = .upToDate) -> UpcomingGameDisplayModel {
        let start = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return UpcomingGameDisplayModel(
            id: UUID().uuidString,
            sourceGameID: UUID(),
            sourceAssignmentID: nil,
            transferID: nil,
            source: .manualRefTrace,
            sport: sport,
            leagueName: league,
            homeTeamName: home,
            homeTeamMascot: homeMascot,
            awayTeamName: away,
            awayTeamMascot: awayMascot,
            gameDate: start,
            reportTime: start.addingTimeInterval(-45 * 60),
            scheduledStartTime: start,
            gameSiteName: "Comeback Season Field 1",
            fieldOrCourt: "Field 1",
            assignedPosition: "Head Referee",
            assignmentStatus: status,
            gameStatus: .ready,
            syncStatus: sync,
            latestSynchronizationDate: Date()
        )
    }
}
