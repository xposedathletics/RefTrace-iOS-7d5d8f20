import SwiftUI

struct OfficialsCommunicationView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var router: RefTraceAppRouter
    @StateObject private var audioRouteManager = AudioRouteManager()
    @State private var textBody = ""
    @State private var quickMessage = "Ready"
    @State private var currentTransmissionID: UUID?
    @State private var accessibleToggleMode = false
    @State private var acknowledgmentRequired = false
    @State private var priority: CommunicationPriority = .routine
    @State private var spokenRecipient = ""
    @State private var showingEndConfirmation = false
    let gameID: UUID

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } }
    private var session: CommunicationSession? { communicationStore.activeSession(for: gameID) }
    private var participants: [CommunicationParticipant] { session.map { communicationStore.participants(for: $0.id) } ?? [] }
    private var connectedCountText: String { session.map { "\(communicationStore.connectedParticipants(for: $0.id).count) of \($0.maximumParticipants) connected" } ?? "No session" }

    var body: some View {
        Group {
            if let game {
                if let session {
                    activeCommunication(game: game, session: session)
                } else if communicationStore.isHeadOfficial(game: game, profile: gameStore.profile) {
                    setupPrompt(game: game)
                } else {
                    waitingPrompt(game: game)
                }
            } else {
                ContentUnavailableView("Game Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Officials Communication")
        .confirmationDialog("End communication session?", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button("End Session", role: .destructive) {
                if let session { communicationStore.endSession(sessionID: session.id) }
                router.go(.gameManagement(gameID))
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Live communication will stop. Pending text and metadata logs will remain available.")
        }
    }

    private func activeCommunication(game: RefTraceGame, session: CommunicationSession) -> some View {
        List {
            Section {
                compactGameHeader(game: game, session: session)
            }

            Section("Recipient") {
                CommunicationRecipientPicker(sessionID: session.id)
                HStack {
                    TextField("Speak recipient command", text: $spokenRecipient)
                    Button("Resolve") {
                        _ = communicationStore.selectRecipient(spokenText: spokenRecipient, sessionID: session.id)
                    }
                }
                if let error = communicationStore.lastError {
                    Text(error.localizedDescription)
                        .foregroundStyle(RefTraceTheme.warning)
                }
            }

            Section("Voice") {
                Toggle("Accessible tap-to-talk mode", isOn: $accessibleToggleMode)
                Button {
                    handlePushToTalk(session: session)
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: communicationStore.isTransmitting ? "waveform.circle.fill" : "waveform.and.person.filled")
                            .font(.system(size: 54, weight: .semibold))
                        Text(communicationStore.isTransmitting ? "Transmitting" : "Push to Talk")
                            .font(.title3.weight(.bold))
                        Text("Recipient: \(communicationStore.selectedRecipient?.displayName ?? "Entire Crew")")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                }
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
                    guard !accessibleToggleMode, currentTransmissionID == nil else { return }
                    beginTransmission(session: session)
                }.onEnded { _ in
                    guard !accessibleToggleMode, let currentTransmissionID else { return }
                    communicationStore.endVoiceTransmission(currentTransmissionID)
                    self.currentTransmissionID = nil
                })
                Text("Mock voice mode: production voice requires Apple Push to Talk, APNs, backend signaling, and secure media transport.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text") {
                Picker("Priority", selection: $priority) {
                    ForEach(CommunicationPriority.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Acknowledgment Required", isOn: $acknowledgmentRequired)
                TextField("Message", text: $textBody, axis: .vertical)
                    .lineLimit(2...5)
                Picker("Quick Message", selection: $quickMessage) {
                    ForEach(Self.quickMessages, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Button("Send") { sendText(session: session, body: textBody, type: .text) }
                    Button("Send Quick") { sendText(session: session, body: quickMessage, type: .quickMessage) }
                    Button("Dictate Mock") {
                        textBody = communicationStore.mockDictationText.isEmpty ? "Clock issue" : communicationStore.mockDictationText
                    }
                }
            }

            Section("Audio Device") {
                LabeledContent("Current Device", value: audioRouteManager.currentAudioDevice)
                LabeledContent("Microphone", value: audioRouteManager.microphoneAvailable ? "Available" : "Unavailable")
                LabeledContent("Bluetooth", value: audioRouteManager.bluetoothConnected ? "Connected" : "Not Connected")
                if let warning = audioRouteManager.audioRouteWarning {
                    Text(warning).foregroundStyle(RefTraceTheme.warning)
                }
                Button("Configure Voice Audio") { try? audioRouteManager.configureForVoiceCommunication() }
            }

            Section("Connected Officials") {
                ForEach(participants) { participant in
                    CommunicationParticipantRow(participant: participant)
                }
                Button("Participants and Controls") { router.go(.communicationParticipants(gameID)) }
            }

            Section("Recent Activity") {
                let logs = communicationStore.logs(for: session.id).suffix(5)
                if logs.isEmpty {
                    Text("No communication activity yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(logs)) { log in
                        VStack(alignment: .leading) {
                            Text(log.eventType.rawValue).font(.subheadline.weight(.semibold))
                            Text(log.detailsSummary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Communication History") { router.go(.communicationHistory(gameID)) }
            }

            Section("Session Controls") {
                Picker("Preferred Communication", selection: Binding(get: { session.preferredCommunicationMode }, set: { _ in })) {
                    ForEach(PreferredCommunicationMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Button("Lock Session") { communicationStore.lockSession(sessionID: session.id) }
                Button("End Session", role: .destructive) { showingEndConfirmation = true }
                #if DEBUG
                Button("Communication Testing") { router.go(.communicationTesting(gameID)) }
                #endif
            }
        }
    }

    private func setupPrompt(game: RefTraceGame) -> some View {
        ContentUnavailableView {
            Label("No Communication Session", systemImage: "waveform.and.person.filled")
        } description: {
            Text("Create a secure game communication session for this officiating crew.")
        } actions: {
            Button("Create Communication Session") { router.go(.communicationSetup(game.id)) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func waitingPrompt(game: RefTraceGame) -> some View {
        ContentUnavailableView {
            Label("Waiting for Head Official", systemImage: "hourglass")
        } description: {
            Text("The Head Official must create the game communication session before crew officials can join.")
        } actions: {
            Button("Join Communication Session") { router.go(.communicationJoin(game.id)) }
                .buttonStyle(.bordered)
        }
    }

    private func compactGameHeader(game: RefTraceGame, session: CommunicationSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.teamsDisplayName)
                .font(.headline)
            Text("\(game.sport.rawValue) • \(game.leagueName) • \(game.gameSiteName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Label(game.currentPeriod, systemImage: "sportscourt")
                Spacer()
                Text("Head: \(session.headOfficialName)")
            }
            .font(.caption)
            LabeledContent("Connected", value: connectedCountText)
        }
    }

    private func handlePushToTalk(session: CommunicationSession) {
        if accessibleToggleMode, communicationStore.isTransmitting, let currentTransmissionID {
            communicationStore.endVoiceTransmission(currentTransmissionID)
            self.currentTransmissionID = nil
        } else {
            beginTransmission(session: session)
        }
    }

    private func beginTransmission(session: CommunicationSession) {
        currentTransmissionID = try? communicationStore.beginVoiceTransmission(sessionID: session.id).id
    }

    private func sendText(session: CommunicationSession, body: String, type: CommunicationType) {
        _ = try? communicationStore.sendText(sessionID: session.id, body: body, type: type, priority: priority, acknowledgmentRequired: acknowledgmentRequired)
        textBody = ""
    }

    static let quickMessages = ["Ready", "Confirm position", "Timeout", "Clock issue", "Penalty discussion", "Meet at midfield", "Injury timeout", "Need replacement", "Check equipment", "End of period", "Call me", "Repeat last message"]
}

struct CommunicationRecipientPicker: View {
    @EnvironmentObject private var communicationStore: CommunicationStore
    let sessionID: UUID

    var body: some View {
        Picker("Recipient", selection: Binding(get: { communicationStore.selectedRecipient?.id ?? "entireCrew" }, set: { id in select(id) })) {
            Text("Entire Crew").tag("entireCrew")
            ForEach(communicationStore.participants(for: sessionID)) { participant in
                Text("\(participant.displayName) - \(participant.assignedPosition)").tag(participant.id.uuidString)
            }
        }
    }

    private func select(_ id: String) {
        if id == "entireCrew" { communicationStore.selectEntireCrew(sessionID: sessionID); return }
        if let participant = communicationStore.participants(for: sessionID).first(where: { $0.id.uuidString == id }) {
            communicationStore.selectParticipant(participant)
        }
    }
}

struct CommunicationParticipantRow: View {
    let participant: CommunicationParticipant

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(participant.displayName).font(.subheadline.weight(.semibold))
                    if participant.isHeadOfficial {
                        Text("Head Official").font(.caption2.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 4).background(RefTraceTheme.gold.opacity(0.2), in: Capsule())
                    }
                }
                Text("\(participant.assignedPosition) • \(participant.connectionStatus.rawValue) • \(participant.networkQuality.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: participant.bluetoothAudioConnected ? "headphones.circle.fill" : "mic.circle")
                .foregroundStyle(participant.audioStatus == .unavailable ? RefTraceTheme.warning : RefTraceTheme.royalBlue)
        }
        .accessibilityElement(children: .combine)
    }
}
