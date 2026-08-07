import SwiftUI

struct CommunicationParticipantsView: View {
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var router: RefTraceAppRouter
    let gameID: UUID

    private var session: CommunicationSession? { communicationStore.activeSession(for: gameID) }

    var body: some View {
        List {
            if let session {
                Section("Participants") {
                    Text("\(communicationStore.connectedParticipants(for: session.id).count) of \(session.maximumParticipants) connected")
                    ForEach(communicationStore.participants(for: session.id)) { participant in
                        VStack(alignment: .leading, spacing: 8) {
                            CommunicationParticipantRow(participant: participant)
                            if !participant.isHeadOfficial {
                                HStack {
                                    Button("Approve") { communicationStore.approveJoin(participantID: participant.id, sessionID: session.id) }
                                    Button(participant.speakingPermission == .muted ? "Restore" : "Mute") { communicationStore.muteParticipant(participant.id, sessionID: session.id, muted: participant.speakingPermission != .muted) }
                                    Button("Make Head") { communicationStore.transferHeadOfficial(to: participant.id, sessionID: session.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section("Head Official Actions") {
                    Button("Simulate All Connected") { communicationStore.setAllConnected(sessionID: session.id) }
                    Button("Lock Session") { communicationStore.lockSession(sessionID: session.id) }
                    Button("End Session", role: .destructive) { communicationStore.endSession(sessionID: session.id); router.go(.gameManagement(gameID)) }
                }
            } else {
                Text("No active communication session.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Crew Connection")
    }
}
