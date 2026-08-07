import SwiftUI

struct RefTraceGameManagementView: View {
    @EnvironmentObject private var store: RefTraceGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var router: RefTraceAppRouter
    let gameID: UUID

    private var game: RefTraceGame? {
        store.games.first { $0.id == gameID }
    }

    var body: some View {
        Group {
            if let game {
                List {
                    Section("Game") {
                        LabeledContent("Teams", value: game.teamsDisplayName)
                        LabeledContent("Sport", value: game.sport.rawValue)
                        LabeledContent("League", value: game.leagueName)
                        LabeledContent("Status", value: game.status.rawValue)
                        LabeledContent("Source", value: game.source.rawValue)
                    }
                    Section("In-Game Display") {
                        Button {
                            router.go(.inGame(game.id))
                        } label: {
                            Label("Open In-Game Display", systemImage: "sportscourt.fill")
                        }
                    }
                    Section("Score") {
                        LabeledContent("Home", value: "\(game.homeScore)")
                        LabeledContent("Away", value: "\(game.awayScore)")
                        LabeledContent("Period", value: game.currentPeriod)
                        LabeledContent("Clock", value: game.gameClockStatus)
                    }
                    Section("Site") {
                        LabeledContent("Location", value: game.gameSiteName)
                        LabeledContent("Field or Court", value: game.fieldOrCourt)
                    }
                    Section("Crew Communication") {
                        if let session = communicationStore.activeSession(for: game.id) {
                            LabeledContent("Status", value: session.status.rawValue)
                            LabeledContent("Connected", value: "\(communicationStore.connectedParticipants(for: session.id).count) of \(session.maximumParticipants)")
                        } else {
                            Text(communicationStore.isHeadOfficial(game: game, profile: store.profile) ? "Create a secure crew communication session for this game." : "Waiting for Head Official to create a communication session.")
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            router.go(.officialsCommunication(game.id))
                        } label: {
                            Label("Officials Communication", systemImage: "waveform.and.person.filled")
                        }
                    }
                    if !game.isCompleted {
                        Button("Complete Game") {
                            try? store.complete(game)
                        }
                    }
                }
                .navigationTitle("Game Management")
            } else {
                ContentUnavailableView("Game Not Found", systemImage: "exclamationmark.triangle")
                    .navigationTitle("Game Management")
            }
        }
    }
}

struct RefTraceRulesView: View {
    @EnvironmentObject private var store: RefTraceGameStore

    var body: some View {
        List {
            if store.games.contains(where: { $0.ruleDocumentID != nil }) {
                ForEach(store.games.filter { $0.ruleDocumentID != nil }) { game in
                    VStack(alignment: .leading) {
                        Text("\(game.sport.rawValue) Rules")
                            .font(.headline)
                        Text("Version \(game.ruleVersion ?? "Unknown")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No synchronized rules are available for this device.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rules")
    }
}

struct RefTraceSettingsView: View {
    @EnvironmentObject private var store: RefTraceGameStore

    var body: some View {
        Form {
            Section("Official") {
                LabeledContent("Name", value: store.profile?.preferredDisplayName ?? "Not signed in")
                LabeledContent("Official ID", value: store.profile?.officialID ?? "Unavailable")
            }
            Section("OfficialEase") {
                LabeledContent("Connection", value: store.syncSummary.connectionStatus.rawValue)
            }
        }
        .navigationTitle("Settings")
    }
}
