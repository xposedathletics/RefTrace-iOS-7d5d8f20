import SwiftUI

#if DEBUG
struct OfficialsCommunicationTestingView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var router: RefTraceAppRouter
    let gameID: UUID

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } ?? gameStore.activeGame }
    private var session: CommunicationSession? { game.flatMap { communicationStore.activeSession(for: $0.id) } }

    var body: some View {
        List {
            Section("Local Development Demo") {
                Text("Simulated voice and networking only. No audio is transmitted to another physical device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(LocalPeerCommunicationService.label)
                    .font(.caption)
                    .foregroundStyle(RefTraceTheme.warning)
            }

            Section("Setup") {
                Button("Load sample active game") { gameStore.loadActiveSample() }
                Button("Set current user as Head Official") { gameStore.loadActiveSample() }
                Button("Create a communication session") { createSession() }
                Button("Add five sample crew officials") { addFiveCrew() }
                Button("Attempt seventh device") { attemptSeventhDevice() }
                Button("Simulate all six devices connected") { if let session { communicationStore.setAllConnected(sessionID: session.id) } }
                Button("Simulate one disconnected device") { if let session { communicationStore.simulateDisconnectedParticipant(sessionID: session.id) } }
            }

            Section("Recipients") {
                Button("Select Entire Crew") { if let session { communicationStore.selectEntireCrew(sessionID: session.id) } }
                Button("Select official by first name") { resolve("Morgan") }
                Button("Select official by last name") { resolve("Lee") }
                Button("Select official by full name") { resolve("Morgan Lee") }
                Button("Select official by position") { resolve("Line Judge") }
                Button("Simulate ambiguous name") { resolve("James") }
                Text("Selected: \(communicationStore.selectedRecipient?.displayName ?? "None")")
            }

            Section("Voice and Text") {
                Button("Begin team voice transmission") { beginVoice(entireCrew: true) }
                Button("End latest voice transmission") { endLatestVoice() }
                Button("Begin private voice transmission") { beginVoice(entireCrew: false) }
                Button("Send team text") { sendText("Ready", entireCrew: true) }
                Button("Send private text") { sendText("Call me", entireCrew: false) }
                Button("Dictate mock text") { communicationStore.mockDictationText = "Meet at midfield" }
                Button("Generate mock transcript") { generateTranscript() }
                Button("Correct transcript") { correctTranscript() }
                Button("Request acknowledgment") { requestAcknowledgment() }
                Button("Acknowledge latest message") { acknowledgeLatest() }
            }

            Section("Connection") {
                Button("Simulate poor network quality") { if let session { communicationStore.simulatePoorNetwork(sessionID: session.id) } }
                Button("Simulate Bluetooth connection") { if let session { communicationStore.simulateBluetooth(sessionID: session.id, connected: true) } }
                Button("Simulate Bluetooth disconnection") { if let session { communicationStore.simulateBluetooth(sessionID: session.id, connected: false) } }
                Button("Simulate offline text queue") { if let session { try? communicationStore.queueOfflineText(sessionID: session.id) } }
                Button("Simulate reconnection") { if let session { communicationStore.simulateReconnection(sessionID: session.id); communicationStore.flushQueuedMessages(sessionID: session.id) } }
            }

            Section("Session") {
                Button("Transfer Head Official role") { transferHead() }
                Button("Lock session") { if let session { communicationStore.lockSession(sessionID: session.id) } }
                Button("End session") { if let session { communicationStore.endSession(sessionID: session.id) } }
                Button("View communication logs") { if let game { router.go(.communicationHistory(game.id)) } }
                Button("Reset all demo data", role: .destructive) { communicationStore.resetDemoData() }
            }
        }
        .navigationTitle("Communication Testing")
    }

    private func createSession() {
        guard let game else { return }
        var draft = CommunicationSessionSetupDraft()
        draft.selectedParticipantIDs = Set(communicationStore.expectedParticipants(for: game, profile: gameStore.profile).map(\.id))
        _ = try? communicationStore.createSession(game: game, profile: gameStore.profile, draft: draft)
    }

    private func addFiveCrew() {
        guard let game, let session else { createSession(); return }
        let expected = communicationStore.expectedParticipants(for: game, profile: gameStore.profile).filter { !$0.isHeadOfficial }.prefix(5)
        for participant in expected { try? communicationStore.addParticipant(participant) }
    }

    private func attemptSeventhDevice() {
        guard let session else { return }
        let participant = CommunicationParticipant(
            sessionID: session.id,
            officialID: "official-seventh",
            officialFirstName: "Seventh",
            officialLastName: "Device",
            displayName: "Seventh Device",
            normalizedSearchNames: ["seventh", "device", "seventh device"],
            assignedPosition: "Observer",
            gameAssignmentID: nil,
            deviceID: "local-seventh",
            isHeadOfficial: false
        )
        do { try communicationStore.addParticipant(participant) } catch { communicationStore.lastError = .sessionAtCapacity }
    }

    private func resolve(_ text: String) {
        if let session { _ = communicationStore.selectRecipient(spokenText: text, sessionID: session.id) }
    }

    private func beginVoice(entireCrew: Bool) {
        guard let session else { return }
        if entireCrew { communicationStore.selectEntireCrew(sessionID: session.id) }
        else if let participant = communicationStore.participants(for: session.id).first(where: { !$0.isHeadOfficial }) { communicationStore.selectParticipant(participant) }
        _ = try? communicationStore.beginVoiceTransmission(sessionID: session.id)
    }

    private func endLatestVoice() {
        if let id = communicationStore.voiceTransmissions.last?.id { communicationStore.endVoiceTransmission(id) }
    }

    private func sendText(_ text: String, entireCrew: Bool) {
        guard let session else { return }
        if entireCrew { communicationStore.selectEntireCrew(sessionID: session.id) }
        else if let participant = communicationStore.participants(for: session.id).first(where: { !$0.isHeadOfficial }) { communicationStore.selectParticipant(participant) }
        _ = try? communicationStore.sendText(sessionID: session.id, body: text)
    }

    private func generateTranscript() {
        if let id = communicationStore.voiceTransmissions.last?.id { communicationStore.generateMockTranscript(for: id, text: "Penalty discussion at midfield") }
    }

    private func correctTranscript() {
        if let id = communicationStore.voiceTransmissions.last?.id { communicationStore.correctTranscript(transmissionID: id, correctedText: "Penalty discussion at midfield") }
    }

    private func requestAcknowledgment() {
        if let session { _ = try? communicationStore.sendText(sessionID: session.id, body: "Confirm position", priority: .important, acknowledgmentRequired: true) }
    }

    private func acknowledgeLatest() {
        if let id = communicationStore.messages.last?.id { communicationStore.acknowledge(messageID: id, status: .acknowledged) }
    }

    private func transferHead() {
        guard let session, let participant = communicationStore.participants(for: session.id).first(where: { !$0.isHeadOfficial }) else { return }
        communicationStore.transferHeadOfficial(to: participant.id, sessionID: session.id)
    }
}
#endif
