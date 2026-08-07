import SwiftUI

struct CommunicationSessionSetupView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var router: RefTraceAppRouter
    @State private var draft = CommunicationSessionSetupDraft()
    @State private var errorMessage: String?
    let gameID: UUID

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } }
    private var expectedParticipants: [CommunicationParticipant] {
        game.map { communicationStore.expectedParticipants(for: $0, profile: gameStore.profile) } ?? []
    }

    var body: some View {
        Form {
            if let game {
                Section("Game") {
                    LabeledContent("Teams", value: game.teamsDisplayName)
                    LabeledContent("Sport", value: game.sport.rawValue)
                    LabeledContent("League", value: game.leagueName)
                    LabeledContent("Site", value: game.gameSiteName)
                }

                Section("Expected Officials") {
                    Text("\(selectedCount) of 6 selected")
                        .foregroundStyle(selectedCount > 6 ? RefTraceTheme.warning : .secondary)
                    ForEach(expectedParticipants) { participant in
                        Toggle(isOn: Binding(get: { participant.isHeadOfficial || draft.selectedParticipantIDs.contains(participant.id) }, set: { enabled in setParticipant(participant, enabled: enabled) })) {
                            VStack(alignment: .leading) {
                                Text(participant.displayName)
                                Text(participant.assignedPosition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(participant.isHeadOfficial)
                    }
                }

                Section("Preference") {
                    Picker("Preferred Communication", selection: $draft.preferredCommunicationMode) {
                        ForEach(PreferredCommunicationMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Permissions") {
                    Toggle("Crew may speak to entire crew", isOn: $draft.teamVoiceEnabled)
                    Toggle("Crew may send private voice", isOn: $draft.privateVoiceEnabled)
                    Toggle("Crew may send team text", isOn: $draft.teamTextEnabled)
                    Toggle("Crew may send private text", isOn: $draft.privateTextEnabled)
                    Toggle("Enable transcription", isOn: $draft.transcriptionEnabled)
                    Toggle("Enable metadata logging", isOn: $draft.loggingEnabled)
                }

                if let errorMessage {
                    Section("Unable to Create") { Text(errorMessage).foregroundStyle(RefTraceTheme.warning) }
                }

                Section {
                    Button("Create Communication Session") { create(game) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Game not found.")
            }
        }
        .navigationTitle("Communication Setup")
        .onAppear {
            draft.selectedParticipantIDs = Set(expectedParticipants.map(\.id))
        }
    }

    private var selectedCount: Int {
        expectedParticipants.filter { $0.isHeadOfficial || draft.selectedParticipantIDs.contains($0.id) }.count
    }

    private func setParticipant(_ participant: CommunicationParticipant, enabled: Bool) {
        if enabled {
            guard selectedCount < 6 else { return }
            draft.selectedParticipantIDs.insert(participant.id)
        } else {
            draft.selectedParticipantIDs.remove(participant.id)
        }
    }

    private func create(_ game: RefTraceGame) {
        do {
            _ = try communicationStore.createSession(game: game, profile: gameStore.profile, draft: draft)
            router.go(.officialsCommunication(game.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
