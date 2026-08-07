import Foundation

protocol CommunicationSessionRepository {
    func createSession(_ session: CommunicationSession, participants: [CommunicationParticipant]) async throws -> CommunicationSession
    func activeSession(for gameID: UUID) async throws -> CommunicationSession?
    func join(sessionID: UUID, participant: CommunicationParticipant) async throws
    func approve(sessionID: UUID, participantID: UUID) async throws
    func leave(sessionID: UUID, participantID: UUID) async throws
    func lock(sessionID: UUID) async throws
    func end(sessionID: UUID) async throws
}

protocol CommunicationParticipantRepository {
    func participants(for sessionID: UUID) async throws -> [CommunicationParticipant]
    func update(_ participant: CommunicationParticipant) async throws
}

protocol VoiceCommunicationService {
    func joinChannel(session: CommunicationSession) async throws
    func beginTransmission(session: CommunicationSession, recipient: CommunicationRecipient) async throws -> VoiceTransmissionRecord
    func endTransmission(_ transmission: VoiceTransmissionRecord) async throws -> VoiceTransmissionRecord
    func leaveChannel(session: CommunicationSession) async throws
}

protocol TextCommunicationService {
    func send(_ message: GameCommunicationMessage) async throws -> GameCommunicationMessage
    func queuedMessages(sessionID: UUID) async throws -> [GameCommunicationMessage]
}

protocol CommunicationSignalingService {
    func registerDevice(sessionID: UUID, deviceReference: String) async throws
    func registerPushToTalk(sessionID: UUID, channelUUID: UUID) async throws
}

protocol CommunicationLogRepository {
    func append(_ event: CommunicationEventLog) async throws
    func events(sessionID: UUID) async throws -> [CommunicationEventLog]
}

protocol CommunicationTranscriptionService {
    func requestAuthorization() async -> SpeechTranscriptionAuthorizationStatus
    func transcribeMock(_ text: String) async -> SpeechTranscriptionResult
}

protocol CommunicationIdentityService {
    func currentOfficialID() -> String?
    func currentDeviceReference() -> String
}

protocol CommunicationPermissionService {
    func isOfficial(_ officialID: String, assignedTo game: RefTraceGame) -> Bool
    func isHeadOfficial(position: String) -> Bool
}

protocol CommunicationQualityService {
    func currentNetworkQuality() -> NetworkQuality
}

struct BackendCommunicationSessionRepository: CommunicationSessionRepository {
    func createSession(_ session: CommunicationSession, participants: [CommunicationParticipant]) async throws -> CommunicationSession { throw CommunicationError.productionBackendRequired }
    func activeSession(for gameID: UUID) async throws -> CommunicationSession? { throw CommunicationError.productionBackendRequired }
    func join(sessionID: UUID, participant: CommunicationParticipant) async throws { throw CommunicationError.productionBackendRequired }
    func approve(sessionID: UUID, participantID: UUID) async throws { throw CommunicationError.productionBackendRequired }
    func leave(sessionID: UUID, participantID: UUID) async throws { throw CommunicationError.productionBackendRequired }
    func lock(sessionID: UUID) async throws { throw CommunicationError.productionBackendRequired }
    func end(sessionID: UUID) async throws { throw CommunicationError.productionBackendRequired }
}

struct BackendTextCommunicationService: TextCommunicationService {
    func send(_ message: GameCommunicationMessage) async throws -> GameCommunicationMessage { throw CommunicationError.productionBackendRequired }
    func queuedMessages(sessionID: UUID) async throws -> [GameCommunicationMessage] { throw CommunicationError.productionBackendRequired }
}

struct PushToTalkVoiceCommunicationService: VoiceCommunicationService {
    func joinChannel(session: CommunicationSession) async throws {
        #if canImport(PushToTalk)
        throw CommunicationError.productionBackendRequired
        #else
        throw CommunicationError.pushToTalkEntitlementRequired
        #endif
    }

    func beginTransmission(session: CommunicationSession, recipient: CommunicationRecipient) async throws -> VoiceTransmissionRecord {
        #if canImport(PushToTalk)
        throw CommunicationError.productionBackendRequired
        #else
        throw CommunicationError.pushToTalkEntitlementRequired
        #endif
    }

    func endTransmission(_ transmission: VoiceTransmissionRecord) async throws -> VoiceTransmissionRecord {
        var ended = transmission
        ended.endedAt = Date()
        ended.durationMilliseconds = Int((ended.endedAt ?? Date()).timeIntervalSince(ended.startedAt) * 1000)
        ended.deliveryStatus = .failed
        return ended
    }

    func leaveChannel(session: CommunicationSession) async throws { }
}

final class LocalCommunicationLogRepository: CommunicationLogRepository {
    private var storedEvents: [CommunicationEventLog] = []

    func append(_ event: CommunicationEventLog) async throws {
        storedEvents.append(event)
    }

    func events(sessionID: UUID) async throws -> [CommunicationEventLog] {
        storedEvents.filter { $0.sessionID == sessionID }.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }
}

struct MockVoiceCommunicationService: VoiceCommunicationService {
    func joinChannel(session: CommunicationSession) async throws { }

    func beginTransmission(session: CommunicationSession, recipient: CommunicationRecipient) async throws -> VoiceTransmissionRecord {
        VoiceTransmissionRecord(
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
    }

    func endTransmission(_ transmission: VoiceTransmissionRecord) async throws -> VoiceTransmissionRecord {
        var ended = transmission
        ended.endedAt = Date()
        ended.durationMilliseconds = Int((ended.endedAt ?? Date()).timeIntervalSince(ended.startedAt) * 1000)
        ended.deliveryStatus = .delivered
        ended.participantsDelivered = transmission.recipientParticipantIDs
        return ended
    }

    func leaveChannel(session: CommunicationSession) async throws { }
}

struct MockTextCommunicationService: TextCommunicationService {
    func send(_ message: GameCommunicationMessage) async throws -> GameCommunicationMessage {
        var sent = message
        sent.deliveryStatus = .delivered
        sent.sentAt = Date()
        sent.deliveredAt = sent.sentAt
        sent.syncStatus = .upToDate
        return sent
    }

    func queuedMessages(sessionID: UUID) async throws -> [GameCommunicationMessage] { [] }
}

struct LocalCommunicationIdentityService: CommunicationIdentityService {
    let profile: RefTraceOfficialProfile?

    func currentOfficialID() -> String? { profile?.officialID }

    func currentDeviceReference() -> String {
        let key = "RefTraceLocalDeviceReference"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let generated = "local-device-\(UUID().uuidString)"
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

struct RefTraceCommunicationPermissionService: CommunicationPermissionService {
    func isOfficial(_ officialID: String, assignedTo game: RefTraceGame) -> Bool {
        if game.assignedOfficialID == officialID { return true }
        return game.otherOfficials.contains { VoiceRecipientResolver.normalize($0) == VoiceRecipientResolver.normalize(officialID) }
    }

    func isHeadOfficial(position: String) -> Bool {
        Self.isLeadershipPosition(position)
    }

    static func isLeadershipPosition(_ position: String) -> Bool {
        let normalized = VoiceRecipientResolver.normalize(position)
        return ["head referee", "center referee", "crew chief", "lead official"].contains(normalized)
    }
}

struct MockCommunicationQualityService: CommunicationQualityService {
    var quality: NetworkQuality = .good
    func currentNetworkQuality() -> NetworkQuality { quality }
}

#if DEBUG
struct LocalPeerCommunicationService {
    static let label = "Local Development Demo - not production field communication"
}
#endif
