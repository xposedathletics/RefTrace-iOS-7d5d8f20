import Foundation
import Combine

@MainActor
final class CommunicationStore: ObservableObject {
    @Published private(set) var sessions: [CommunicationSession] = []
    @Published private(set) var participants: [CommunicationParticipant] = []
    @Published private(set) var messages: [GameCommunicationMessage] = []
    @Published private(set) var eventLogs: [CommunicationEventLog] = []
    @Published private(set) var voiceTransmissions: [VoiceTransmissionRecord] = []
    @Published var selectedRecipient: CommunicationRecipient?
    @Published var isTransmitting = false
    @Published var lastError: CommunicationError?
    @Published var mockDictationText = ""

    private var nextSequenceNumber = 1
    private let resolver = VoiceRecipientResolver()

    var activeSession: CommunicationSession? {
        sessions.first { [.waitingForParticipants, .active, .temporarilyDisconnected, .locked].contains($0.status) }
    }

    func activeSession(for gameID: UUID) -> CommunicationSession? {
        sessions.first { $0.gameID == gameID && [.waitingForParticipants, .active, .temporarilyDisconnected, .locked].contains($0.status) }
    }

    func participants(for sessionID: UUID) -> [CommunicationParticipant] {
        participants.filter { $0.sessionID == sessionID && $0.connectionStatus != .removed }
    }

    func connectedParticipants(for sessionID: UUID) -> [CommunicationParticipant] {
        participants(for: sessionID).filter { $0.connectionStatus == .connected }
    }

    func messages(for sessionID: UUID) -> [GameCommunicationMessage] {
        messages.filter { $0.sessionID == sessionID }.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    func logs(for sessionID: UUID) -> [CommunicationEventLog] {
        eventLogs.filter { $0.sessionID == sessionID }.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    func expectedParticipants(for game: RefTraceGame, profile: RefTraceOfficialProfile?) -> [CommunicationParticipant] {
        let sessionID = activeSession(for: game.id)?.id ?? UUID()
        let headOfficialID = game.assignedOfficialID ?? profile?.officialID ?? "head-official"
        let headDisplay = game.assignedOfficialName.isEmpty ? (profile?.preferredDisplayName ?? "Head Official") : game.assignedOfficialName
        var result = [makeParticipant(sessionID: sessionID, officialID: headOfficialID, displayName: headDisplay, position: game.assignedPosition, isHead: true, assignmentID: game.officialEaseAssignmentID)]

        for (index, name) in game.otherOfficials.prefix(5).enumerated() {
            result.append(makeParticipant(sessionID: sessionID, officialID: "crew-\(index + 1)-\(VoiceRecipientResolver.normalize(name))", displayName: name, position: samplePosition(for: game.sport, index: index + 1), isHead: false, assignmentID: nil))
        }

        if result.count == 1 {
            let samples = sampleCrew(for: game.sport, sessionID: sessionID)
            result.append(contentsOf: samples.prefix(3))
        }
        return Array(result.prefix(6))
    }

    func isHeadOfficial(game: RefTraceGame, profile: RefTraceOfficialProfile?) -> Bool {
        if RefTraceCommunicationPermissionService.isLeadershipPosition(game.assignedPosition), game.assignedOfficialID == profile?.officialID {
            return true
        }
        return game.assignedOfficialID == profile?.officialID && RefTraceCommunicationPermissionService.isLeadershipPosition(game.assignedPosition)
    }

    @discardableResult
    func createSession(game: RefTraceGame, profile: RefTraceOfficialProfile?, draft: CommunicationSessionSetupDraft) throws -> CommunicationSession {
        guard let officialID = profile?.officialID else { throw CommunicationError.currentOfficialUnavailable }
        guard isHeadOfficial(game: game, profile: profile) else { throw CommunicationError.notHeadOfficial }
        let expected = expectedParticipants(for: game, profile: profile)
        let invited = expected.filter { $0.isHeadOfficial || draft.selectedParticipantIDs.isEmpty || draft.selectedParticipantIDs.contains($0.id) }
        guard invited.count <= 6 else { throw CommunicationError.sessionAtCapacity }

        var session = CommunicationSession(
            gameID: game.id,
            officialEaseGameID: game.officialEaseGameID,
            officialEaseAssignmentIDs: [game.officialEaseAssignmentID].compactMap { $0 },
            organizationID: nil,
            leagueID: game.leagueID,
            sport: game.sport,
            sessionName: "\(game.sport.rawValue) Crew Communication",
            sessionCode: Self.generateSessionCode(),
            headOfficialID: officialID,
            headOfficialName: profile?.preferredDisplayName ?? game.assignedOfficialName,
            headOfficialDeviceID: LocalCommunicationIdentityService(profile: profile).currentDeviceReference(),
            participantCount: invited.count,
            status: .waitingForParticipants,
            preferredCommunicationMode: draft.preferredCommunicationMode,
            teamVoiceEnabled: draft.teamVoiceEnabled,
            privateVoiceEnabled: draft.privateVoiceEnabled,
            teamTextEnabled: draft.teamTextEnabled,
            privateTextEnabled: draft.privateTextEnabled,
            transcriptionEnabled: draft.transcriptionEnabled,
            loggingEnabled: draft.loggingEnabled
        )
        session.activatedAt = Date()
        session.lastActivityAt = Date()
        sessions.removeAll { $0.gameID == game.id && $0.status != .ended }
        sessions.append(session)

        participants.removeAll { $0.sessionID == session.id }
        participants.append(contentsOf: invited.map { participant in
            var updated = participant
            updated.sessionID = session.id
            updated.connectionStatus = updated.isHeadOfficial ? .connected : .invited
            updated.joinedAt = updated.isHeadOfficial ? Date() : nil
            updated.lastSeenAt = updated.isHeadOfficial ? Date() : nil
            updated.pushToTalkRegistered = updated.isHeadOfficial
            return updated
        })
        selectedRecipient = CommunicationRecipient.entireCrew(participants(for: session.id).map(\.id))
        appendLog(session: session, type: .sessionCreated, actorOfficialID: officialID, actorDisplayName: session.headOfficialName, details: "Communication session created.")
        return session
    }

    func join(sessionCode: String, game: RefTraceGame, profile: RefTraceOfficialProfile?) throws {
        guard let sessionIndex = sessions.firstIndex(where: { $0.sessionCode == sessionCode && $0.gameID == game.id }) else { throw CommunicationError.invalidSessionCode }
        guard sessions[sessionIndex].status != .ended else { throw CommunicationError.sessionEnded }
        guard sessions[sessionIndex].status != .locked else { throw CommunicationError.sessionLocked }
        guard participants(for: sessions[sessionIndex].id).count < sessions[sessionIndex].maximumParticipants else { throw CommunicationError.sessionAtCapacity }
        guard let officialID = profile?.officialID else { throw CommunicationError.currentOfficialUnavailable }
        guard game.assignedOfficialID == officialID || participants.contains(where: { $0.sessionID == sessions[sessionIndex].id && $0.officialID == officialID }) else {
            throw CommunicationError.notAssignedToGame
        }

        if let participantIndex = participants.firstIndex(where: { $0.sessionID == sessions[sessionIndex].id && $0.officialID == officialID }) {
            participants[participantIndex].connectionStatus = .connected
            participants[participantIndex].joinedAt = participants[participantIndex].joinedAt ?? Date()
            participants[participantIndex].lastSeenAt = Date()
        } else {
            let participant = makeParticipant(sessionID: sessions[sessionIndex].id, officialID: officialID, displayName: profile?.preferredDisplayName ?? "Official", position: "Official", isHead: false, assignmentID: nil)
            participants.append(participant)
        }
        sessions[sessionIndex].participantCount = participants(for: sessions[sessionIndex].id).count
        sessions[sessionIndex].status = .active
        appendLog(session: sessions[sessionIndex], type: .officialConnected, actorOfficialID: officialID, actorDisplayName: profile?.preferredDisplayName ?? "Official", details: "Official connected.")
    }

    func approveJoin(participantID: UUID, sessionID: UUID) {
        guard let index = participants.firstIndex(where: { $0.id == participantID && $0.sessionID == sessionID }) else { return }
        participants[index].connectionStatus = .connected
        participants[index].joinedAt = participants[index].joinedAt ?? Date()
        participants[index].lastSeenAt = Date()
        if let session = sessions.first(where: { $0.id == sessionID }) {
            appendLog(session: session, type: .joinApproved, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, targetParticipantIDs: [participantID], details: "Join request approved.")
        }
    }

    func addParticipant(_ participant: CommunicationParticipant) throws {
        guard participants(for: participant.sessionID).count < 6 else { throw CommunicationError.sessionAtCapacity }
        participants.append(participant)
    }

    func setAllConnected(sessionID: UUID) {
        for index in participants.indices where participants[index].sessionID == sessionID {
            participants[index].connectionStatus = .connected
            participants[index].joinedAt = participants[index].joinedAt ?? Date()
            participants[index].lastSeenAt = Date()
        }
        updateParticipantCount(sessionID: sessionID)
    }

    func simulateDisconnectedParticipant(sessionID: UUID) {
        guard let index = participants.firstIndex(where: { $0.sessionID == sessionID && !$0.isHeadOfficial }) else { return }
        participants[index].connectionStatus = .disconnected
        participants[index].disconnectedAt = Date()
        if let session = sessions.first(where: { $0.id == sessionID }) {
            appendLog(session: session, type: .officialDisconnected, actorOfficialID: participants[index].officialID, actorDisplayName: participants[index].displayName, details: "Official disconnected.")
        }
    }

    func simulateReconnection(sessionID: UUID) {
        for index in participants.indices where participants[index].sessionID == sessionID && participants[index].connectionStatus == .disconnected {
            participants[index].connectionStatus = .connected
            participants[index].lastSeenAt = Date()
            participants[index].disconnectedAt = nil
        }
        if let session = sessions.first(where: { $0.id == sessionID }) {
            appendLog(session: session, type: .reconnection, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, details: "Disconnected participants reconnected.")
        }
    }

    func lockSession(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].status = .locked
        appendLog(session: sessions[index], type: .sessionLocked, actorOfficialID: sessions[index].headOfficialID, actorDisplayName: sessions[index].headOfficialName, details: "Session locked.")
    }

    func endSession(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].status = .ended
        sessions[index].endedAt = Date()
        sessions[index].lastActivityAt = Date()
        for participantIndex in participants.indices where participants[participantIndex].sessionID == sessionID {
            participants[participantIndex].connectionStatus = .disconnected
            participants[participantIndex].disconnectedAt = Date()
        }
        appendLog(session: sessions[index], type: .sessionEnded, actorOfficialID: sessions[index].headOfficialID, actorDisplayName: sessions[index].headOfficialName, details: "Session ended. Raw voice audio was not stored.")
        isTransmitting = false
    }

    func transferHeadOfficial(to participantID: UUID, sessionID: UUID) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }), let newHeadIndex = participants.firstIndex(where: { $0.id == participantID && $0.sessionID == sessionID }) else { return }
        for index in participants.indices where participants[index].sessionID == sessionID {
            participants[index].isHeadOfficial = index == newHeadIndex
        }
        sessions[sessionIndex].headOfficialID = participants[newHeadIndex].officialID
        sessions[sessionIndex].headOfficialName = participants[newHeadIndex].displayName
        appendLog(session: sessions[sessionIndex], type: .headOfficialTransferred, actorOfficialID: participants[newHeadIndex].officialID, actorDisplayName: participants[newHeadIndex].displayName, targetParticipantIDs: [participantID], details: "Head Official role transferred.")
    }

    func removeParticipant(_ participantID: UUID, sessionID: UUID) {
        guard let index = participants.firstIndex(where: { $0.id == participantID && $0.sessionID == sessionID }) else { return }
        participants[index].connectionStatus = .removed
        if let session = sessions.first(where: { $0.id == sessionID }) {
            appendLog(session: session, type: .participantRemoved, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, targetParticipantIDs: [participantID], details: "Participant removed.")
        }
        updateParticipantCount(sessionID: sessionID)
    }

    func muteParticipant(_ participantID: UUID, sessionID: UUID, muted: Bool) {
        guard let index = participants.firstIndex(where: { $0.id == participantID && $0.sessionID == sessionID }) else { return }
        participants[index].speakingPermission = muted ? .muted : .allowed
    }

    func selectEntireCrew(sessionID: UUID) {
        selectedRecipient = CommunicationRecipient.entireCrew(participants(for: sessionID).map(\.id))
    }

    func selectParticipant(_ participant: CommunicationParticipant) {
        selectedRecipient = CommunicationRecipient(id: participant.id.uuidString, type: participant.isHeadOfficial ? .headOfficial : .individual, displayName: participant.displayName, participantIDs: [participant.id])
    }

    func selectRecipient(spokenText: String, sessionID: UUID) -> VoiceRecipientResolver.Resolution {
        let resolution = resolver.resolve(spokenText, participants: participants(for: sessionID))
        switch resolution {
        case .entireCrew:
            selectEntireCrew(sessionID: sessionID)
        case .participant(let participant):
            selectParticipant(participant)
        case .ambiguous(let matches):
            lastError = .ambiguousRecipient(matches.map(\.displayName))
        case .notFound:
            lastError = .recipientNotFound
        }
        return resolution
    }

    @discardableResult
    func beginVoiceTransmission(sessionID: UUID) throws -> VoiceTransmissionRecord {
        guard let session = sessions.first(where: { $0.id == sessionID }), session.status != .ended else { throw CommunicationError.sessionEnded }
        guard let recipient = selectedRecipient else { throw CommunicationError.recipientNotFound }
        let record = VoiceTransmissionRecord(
            sessionID: session.id,
            gameID: session.gameID,
            senderOfficialID: session.headOfficialID,
            senderDisplayName: session.headOfficialName,
            senderPosition: "Head Official",
            recipientType: recipient.type,
            recipientParticipantIDs: recipient.participantIDs,
            startedAt: Date(),
            networkQuality: .good
        )
        voiceTransmissions.append(record)
        isTransmitting = true
        appendLog(session: session, type: .voiceTransmissionStarted, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, targetParticipantIDs: recipient.participantIDs, voiceTransmissionID: record.id, details: "Voice transmission started to \(recipient.displayName). Metadata only; no raw audio stored.")
        return record
    }

    func endVoiceTransmission(_ transmissionID: UUID) {
        guard let index = voiceTransmissions.firstIndex(where: { $0.id == transmissionID }), let session = sessions.first(where: { $0.id == voiceTransmissions[index].sessionID }) else { return }
        voiceTransmissions[index].endedAt = Date()
        voiceTransmissions[index].durationMilliseconds = Int((voiceTransmissions[index].endedAt ?? Date()).timeIntervalSince(voiceTransmissions[index].startedAt) * 1000)
        voiceTransmissions[index].deliveryStatus = .delivered
        voiceTransmissions[index].participantsDelivered = voiceTransmissions[index].recipientParticipantIDs
        isTransmitting = false
        appendLog(session: session, type: .voiceTransmissionEnded, actorOfficialID: voiceTransmissions[index].senderOfficialID, actorDisplayName: voiceTransmissions[index].senderDisplayName, targetParticipantIDs: voiceTransmissions[index].recipientParticipantIDs, voiceTransmissionID: voiceTransmissions[index].id, durationMilliseconds: voiceTransmissions[index].durationMilliseconds, details: "Voice transmission ended. Metadata only; no raw audio stored.")
    }

    @discardableResult
    func sendText(sessionID: UUID, body: String, type: CommunicationType = .text, priority: CommunicationPriority = .routine, acknowledgmentRequired: Bool = false, offline: Bool = false) throws -> GameCommunicationMessage {
        guard let session = sessions.first(where: { $0.id == sessionID }), session.status != .ended else { throw CommunicationError.sessionEnded }
        guard let recipient = selectedRecipient else { throw CommunicationError.recipientNotFound }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CommunicationError.recipientNotFound }
        if messages.contains(where: { $0.sessionID == sessionID && $0.textBody == trimmed && $0.recipientParticipantIDs == recipient.participantIDs }) {
            return messages.first { $0.sessionID == sessionID && $0.textBody == trimmed && $0.recipientParticipantIDs == recipient.participantIDs }!
        }

        var message = GameCommunicationMessage(
            sessionID: session.id,
            gameID: session.gameID,
            senderOfficialID: session.headOfficialID,
            senderDisplayName: session.headOfficialName,
            senderPosition: "Head Official",
            recipientType: recipient.type,
            recipientParticipantIDs: recipient.participantIDs,
            recipientDisplayNames: [recipient.displayName],
            communicationType: type,
            textBody: trimmed,
            deliveryStatus: offline ? .queued : .delivered,
            acknowledgmentStatus: acknowledgmentRequired ? .required : .none,
            priority: priority,
            sentAt: offline ? nil : Date(),
            deliveredAt: offline ? nil : Date(),
            sequenceNumber: nextSequence()
        )
        if offline { message.syncStatus = .pending } else { message.syncStatus = .upToDate }
        messages.append(message)
        appendLog(session: session, type: .textSent, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, targetParticipantIDs: recipient.participantIDs, communicationMessageID: message.id, details: "Text sent to \(recipient.displayName).")
        return message
    }

    func acknowledge(messageID: UUID, status: MessageAcknowledgmentStatus) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].acknowledgmentStatus = status
        messages[index].acknowledgedAt = Date()
        if let session = sessions.first(where: { $0.id == messages[index].sessionID }) {
            appendLog(session: session, type: .messageAcknowledged, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, communicationMessageID: messageID, details: "Message acknowledgment updated to \(status.rawValue).")
        }
    }

    func acknowledgmentCount(for message: GameCommunicationMessage) -> (acknowledged: Int, total: Int) {
        guard message.acknowledgmentStatus == .required else { return (0, message.recipientParticipantIDs.count) }
        let acknowledged = message.acknowledgedAt == nil ? 0 : message.recipientParticipantIDs.count
        return (acknowledged, message.recipientParticipantIDs.count)
    }

    func queueOfflineText(sessionID: UUID) throws {
        _ = try sendText(sessionID: sessionID, body: "Queued while offline", offline: true)
    }

    func flushQueuedMessages(sessionID: UUID) {
        for index in messages.indices where messages[index].sessionID == sessionID && messages[index].deliveryStatus == .queued {
            messages[index].deliveryStatus = .delivered
            messages[index].sentAt = Date()
            messages[index].deliveredAt = Date()
            messages[index].syncStatus = .upToDate
        }
    }

    func generateMockTranscript(for transmissionID: UUID, text: String) {
        guard let index = voiceTransmissions.firstIndex(where: { $0.id == transmissionID }), let session = sessions.first(where: { $0.id == voiceTransmissions[index].sessionID }) else { return }
        voiceTransmissions[index].transcriptAvailable = true
        voiceTransmissions[index].transcriptID = UUID()
        appendLog(session: session, type: .transcriptGenerated, actorOfficialID: voiceTransmissions[index].senderOfficialID, actorDisplayName: voiceTransmissions[index].senderDisplayName, voiceTransmissionID: transmissionID, details: "Automated transcript - may contain errors: \(text)")
    }

    func correctTranscript(transmissionID: UUID, correctedText: String) {
        guard let transmission = voiceTransmissions.first(where: { $0.id == transmissionID }), let session = sessions.first(where: { $0.id == transmission.sessionID }) else { return }
        appendLog(session: session, type: .transcriptCorrected, actorOfficialID: transmission.senderOfficialID, actorDisplayName: transmission.senderDisplayName, voiceTransmissionID: transmissionID, details: "Transcript corrected: \(correctedText)")
    }

    func simulatePoorNetwork(sessionID: UUID) {
        for index in participants.indices where participants[index].sessionID == sessionID {
            participants[index].networkQuality = .poor
        }
    }

    func simulateBluetooth(sessionID: UUID, connected: Bool) {
        for index in participants.indices where participants[index].sessionID == sessionID && participants[index].isHeadOfficial {
            participants[index].bluetoothAudioConnected = connected
        }
        if let session = sessions.first(where: { $0.id == sessionID }) {
            appendLog(session: session, type: .audioRouteChanged, actorOfficialID: session.headOfficialID, actorDisplayName: session.headOfficialName, details: connected ? "Bluetooth audio connected." : "Bluetooth audio disconnected.")
        }
    }

    func loadDemoSession(game: RefTraceGame, profile: RefTraceOfficialProfile?) {
        let expected = expectedParticipants(for: game, profile: profile)
        var draft = CommunicationSessionSetupDraft()
        draft.selectedParticipantIDs = Set(expected.map(\.id))
        _ = try? createSession(game: game, profile: profile, draft: draft)
    }

    func resetDemoData() {
        sessions.removeAll()
        participants.removeAll()
        messages.removeAll()
        eventLogs.removeAll()
        voiceTransmissions.removeAll()
        selectedRecipient = nil
        isTransmitting = false
        lastError = nil
        nextSequenceNumber = 1
    }

    private func makeParticipant(sessionID: UUID, officialID: String, displayName: String, position: String, isHead: Bool, assignmentID: String?) -> CommunicationParticipant {
        let parts = displayName.split(separator: " ").map(String.init)
        let first = parts.first ?? displayName
        let last = parts.dropFirst().joined(separator: " ")
        return CommunicationParticipant(
            sessionID: sessionID,
            officialID: officialID,
            officialFirstName: first,
            officialLastName: last,
            displayName: displayName,
            normalizedSearchNames: CommunicationParticipant.normalizedTerms(firstName: first, lastName: last, displayName: displayName, position: position),
            assignedPosition: position,
            gameAssignmentID: assignmentID,
            deviceID: "app-device-ref-\(UUID().uuidString)",
            isHeadOfficial: isHead
        )
    }

    private func sampleCrew(for sport: RefTraceSport, sessionID: UUID) -> [CommunicationParticipant] {
        let positions = sport.positions
        return [
            makeParticipant(sessionID: sessionID, officialID: "official-james-watson", displayName: "James Watson", position: positions.dropFirst().first ?? "Line Judge", isHead: false, assignmentID: nil),
            makeParticipant(sessionID: sessionID, officialID: "official-james-carter", displayName: "James Carter", position: positions.dropFirst(2).first ?? "Back Judge", isHead: false, assignmentID: nil),
            makeParticipant(sessionID: sessionID, officialID: "official-morgan-lee", displayName: "Morgan Lee", position: positions.dropFirst(3).first ?? "Field Judge", isHead: false, assignmentID: nil)
        ]
    }

    private func samplePosition(for sport: RefTraceSport, index: Int) -> String {
        let positions = sport.positions
        guard index < positions.count else { return "Official" }
        return positions[index]
    }

    private func updateParticipantCount(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].participantCount = participants(for: sessionID).count
    }

    private func appendLog(session: CommunicationSession, type: CommunicationEventType, actorOfficialID: String, actorDisplayName: String, targetParticipantIDs: [UUID] = [], communicationMessageID: UUID? = nil, voiceTransmissionID: UUID? = nil, durationMilliseconds: Int? = nil, details: String) {
        guard session.loggingEnabled else { return }
        eventLogs.append(
            CommunicationEventLog(
                sessionID: session.id,
                gameID: session.gameID,
                eventType: type,
                actorOfficialID: actorOfficialID,
                actorDisplayName: actorDisplayName,
                targetParticipantIDs: targetParticipantIDs,
                communicationMessageID: communicationMessageID,
                voiceTransmissionID: voiceTransmissionID,
                durationMilliseconds: durationMilliseconds,
                deliveryResult: nil,
                networkQuality: .good,
                deviceReference: nil,
                sequenceNumber: nextSequence(),
                detailsSummary: details
            )
        )
    }

    private func nextSequence() -> Int {
        defer { nextSequenceNumber += 1 }
        return nextSequenceNumber
    }

    private static func generateSessionCode() -> String {
        String(UUID().uuidString.prefix(6)).uppercased()
    }
}
