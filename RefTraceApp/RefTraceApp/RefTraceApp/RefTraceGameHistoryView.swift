import SwiftUI

struct RefTraceGameHistoryView: View {
    @EnvironmentObject private var store: RefTraceGameStore
    @EnvironmentObject private var router: RefTraceAppRouter
    var completedOnly = false

    private var games: [RefTraceGame] {
        completedOnly ? store.completedGames : store.recentGames
    }

    var body: some View {
        List {
            if games.isEmpty {
                Text(completedOnly ? "No completed games are available." : "No games have been created or imported.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(games) { game in
                    Button {
                        router.go(.gameManagement(game.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.teamsDisplayName)
                                .font(.headline)
                            Text("\(game.sport.rawValue) • \(game.leagueName) • \(game.status.rawValue) • \(game.source.rawValue)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if game.isCompleted {
                                Text("Final: \(game.awayScore)-\(game.homeScore)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(completedOnly ? "Completed Games" : "All Games")
    }
}
