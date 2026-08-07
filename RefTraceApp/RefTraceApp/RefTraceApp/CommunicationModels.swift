import Foundation

struct CommunicationSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var officialEaseGameID: String?
    var officialEaseAssignmentIDs: [String]
    var organizationID: String?
    var leagueID: String?
    var sport: RefTraceSport
    var sessionName: String
    var sessionCode: String
    var headOfficialID: String
    var headOfficialName: String
    var headOfficialDeviceID: String
    var maximumParticipants: Int = 6
    var participantCount: Int = 0
    var status: CommunicationSessionStatus = .draft
    var preferredCommunicationMode: PreferredCommunicationMode = .voice
    var teamVoiceEnabled = true
    var privateVoiceEnabled = true
    var teamTextEnabled = true
    var privateTextEnabled = true
    var speechRecipientSelectionEnabled = true
    var transcriptionEnabled = false
    var loggingEnabled = true
    var encryptionStatus: CommunicationEncryptionStatus = .enabled
    var createdAt: Date = Date()
    var activatedAt: Date?
    var endedAt: Date?
    var lastActivityAt: Date = Date()
    var backendChannelID: String?
    var pushToTalkChannelUUID: UUID?
    var syncStatus: RefTraceSyncState = .pending
}

enum CommunicationSessionStatus: String, Codable, CaseIterable, Hashable {
    case draft = "Draft"
    case waitingForParticipants = "Waiting for Participants"
    case active = "Active"
    case temporarilyDisconnected = "Temporarily Disconnected"
    case locked = "Locked"
    case ending = "Ending"
    case ended = "Ended"
    case failed = "Failed"
}

enum PreferredCommunicationMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case voice = "Voice"
    case text = "Text"
    case askEachTime = "Ask Each Time"

    var id: String { rawValue }
}

enum CommunicationEncryptionStatus: String, Codable, Hashable {
    case enabled = "Encrypted"
    case pending = "Pending"
    case unavailable = "Unavailable"
}

struct CommunicationParticipant: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var sessionID: UUID
    var officialID: String
    var officialFirstName: String
    var officialLastName: String
    var displayName: String
    var normalizedSearchNames: [String]
    var assignedPosition: String
    var gameAssignmentID: String?
    var deviceID: String
    var isHeadOfficial: Bool
    var connectionStatus: ParticipantConnectionStatus = .invited
    var audioStatus: ParticipantAudioStatus = .available
    var microphoneStatus: MicrophoneStatus = .unknown
    var textStatus: ParticipantTextStatus = .available
    var acknowledgmentStatus: MessageAcknowledgmentStatus = .none
    var speakingPermission: SpeakingPermission = .allowed
    var joinedAt: Date?
    var lastSeenAt: Date?
    var disconnectedAt: Date?
    var networkQuality: NetworkQuality = .unknown
    var bluetoothAudioConnected = false
    var pushToTalkRegistered = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    static func normalizedTerms(firstName: String, lastName: String, displayName: String, position: String) -> [String] {
        [firstName, lastName, displayName, position]
            .map(normalizeSearchTerm)
            .filter { !$0.isEmpty }
    }

    private static func normalizeSearchTerm(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

enum ParticipantConnectionStatus: String, Codable, CaseIterable, Hashable {
    case invited = "Invited"
    case requestingAccess = "Requesting Access"
    case connected = "Connected"
    case reconnecting = "Reconnecting"
    case disconnected = "Disconnected"
    case removed = "Removed"
    case declined = "Declined"
    case unavailable = "Unavailable"
}

enum ParticipantAudioStatus: String, Codable, Hashable {
    case available = "Voice Available"
    case receiving = "Receiving"
    case transmitting = "Transmitting"
    case muted = "Muted"
    case unavailable = "Voice Unavailable"
}

enum MicrophoneStatus: String, Codable, Hashable {
    case unknown = "Unknown"
    case available = "Available"
    case permissionDenied = "Permission Denied"
    case unavailable = "Unavailable"
}

enum ParticipantTextStatus: String, Codable, Hashable {
    case available = "Text Available"
    case queued = "Queued"
    case unavailable = "Text Unavailable"
}

enum MessageAcknowledgmentStatus: String, Codable, Hashable {
    case none = "None"
    case required = "Required"
    case acknowledged = "Acknowledged"
    case needClarification = "Need Clarification"
    case unable = "Unable"
}

enum SpeakingPermission: String, Codable, Hashable {
    case allowed = "Allowed"
    case headOfficialOnly = "Head Official Only"
    case requestRequired = "Request Required"
    case muted = "Muted"
}

enum NetworkQuality: String, Codable, CaseIterable, Hashable {
    case excellent = "Excellent"
    case good = "Good"
    case limited = "Limited"
    case poor = "Poor"
    case unavailable = "Unavailable"
    case unknown = "Unknown"
}

enum CommunicationRecipientType: String, Codable, CaseIterable, Hashable {
    case entireCrew = "Entire Crew"
    case individual = "Individual"
    case headOfficial = "Head Official"
}

struct CommunicationRecipient: Identifiable, Hashable {
    var id: String
    var type: CommunicationRecipientType
    var displayName: String
    var participantIDs: [UUID]

    static func entireCrew(_ participantIDs: [UUID]) -> CommunicationRecipient {
        CommunicationRecipient(id: "entireCrew", type: .entireCrew, displayName: "Entire Crew", participantIDs: participantIDs)
    }
}

struct GameCommunicationMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var sessionID: UUID
    var gameID: UUID
    var senderOfficialID: String
    var senderDisplayName: String
    var senderPosition: String
    var recipientType: CommunicationRecipientType
    var recipientParticipantIDs: [UUID]
    var recipientDisplayNames: [String]
    var communicationType: CommunicationType
    var textBody: String
    var transcriptBody: String?
    var deliveryStatus: MessageDeliveryStatus = .draft
    var acknowledgmentStatus: MessageAcknowledgmentStatus = .none
    var priority: CommunicationPriority = .routine
    var createdAt: Date = Date()
    var sentAt: Date?
    var deliveredAt: Date?
    var readAt: Date?
    var acknowledgedAt: Date?
    var failedAt: Date?
    var failureReasonCode: String?
    var correlationID: UUID = UUID()
    var sequenceNumber: Int
    var encryptionStatus: CommunicationEncryptionStatus = .enabled
    var syncStatus: RefTraceSyncState = .pending
}

enum CommunicationType: String, Codable, CaseIterable, Hashable {
    case text = "Text"
    case dictatedText = "Dictated Text"
    case quickMessage = "Quick Message"
    case systemMessage = "System Message"
    case voiceMetadata = "Voice Metadata"
    case acknowledgment = "Acknowledgment"
}

enum MessageDeliveryStatus: String, Codable, CaseIterable, Hashable {
    case draft = "Draft"
    case queued = "Queued"
    case sending = "Sending"
    case sent = "Sent"
    case delivered = "Delivered"
    case partiallyDelivered = "Partially Delivered"
    case failed = "Failed"
    case expired = "Expired"
}

enum CommunicationPriority: String, Codable, CaseIterable, Identifiable, Hashable {
    case routine = "Routine"
    case important = "Important"
    case urgent = "Urgent"

    var id: String { rawValue }
}

struct CommunicationEventLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var sessionID: UUID
    var gameID: UUID
    var eventType: CommunicationEventType
    var actorOfficialID: String
    var actorDisplayName: String
    var targetParticipantIDs: [UUID]
    var communicationMessageID: UUID?
    var voiceTransmissionID: UUID?
    var timestamp: Date = Date()
    var durationMilliseconds: Int?
    var deliveryResult: String?
    var networkQuality: NetworkQuality
    var deviceReference: String?
    var correlationID: UUID = UUID()
    var sequenceNumber: Int
    var detailsSummary: String
    var syncStatus: RefTraceSyncState = .pending
}

enum CommunicationEventType: String, Codable, CaseIterable, Hashable {
    case sessionCreated = "Session Created"
    case sessionActivated = "Session Activated"
    case officialInvited = "Official Invited"
    case joinRequested = "Join Requested"
    case joinApproved = "Join Approved"
    case officialConnected = "Official Connected"
    case officialDisconnected = "Official Disconnected"
    case reconnection = "Reconnection"
    case sessionLocked = "Session Locked"
    case sessionUnlocked = "Session Unlocked"
    case voiceTransmissionStarted = "Voice Transmission Started"
    case voiceTransmissionEnded = "Voice Transmission Ended"
    case voiceDeliveryFailed = "Voice Delivery Failed"
    case textSent = "Text Sent"
    case textDelivered = "Text Delivered"
    case textRead = "Text Read"
    case messageAcknowledged = "Message Acknowledged"
    case transcriptGenerated = "Transcript Generated"
    case transcriptCorrected = "Transcript Corrected"
    case communicationPreferenceChanged = "Communication Preference Changed"
    case audioRouteChanged = "Audio Route Changed"
    case headOfficialTransferred = "Head Official Transferred"
    case participantRemoved = "Participant Removed"
    case sessionEnded = "Session Ended"
    case synchronizationCompleted = "Synchronization Completed"
    case synchronizationFailed = "Synchronization Failed"
}

struct VoiceTransmissionRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var sessionID: UUID
    var gameID: UUID
    var senderOfficialID: String
    var senderDisplayName: String
    var senderPosition: String
    var recipientType: CommunicationRecipientType
    var recipientParticipantIDs: [UUID]
    var startedAt: Date
    var endedAt: Date?
    var durationMilliseconds: Int?
    var deliveryStatus: MessageDeliveryStatus = .sending
    var participantsDelivered: [UUID] = []
    var participantsFailed: [UUID] = []
    var transcriptID: UUID?
    var transcriptAvailable = false
    var networkQuality: NetworkQuality = .unknown
    var interruptionReason: String?
    var correlationID: UUID = UUID()
    var syncStatus: RefTraceSyncState = .pending
}

struct CommunicationSessionSetupDraft: Equatable {
    var selectedParticipantIDs: Set<UUID> = []
    var preferredCommunicationMode: PreferredCommunicationMode = .voice
    var teamVoiceEnabled = true
    var privateVoiceEnabled = true
    var teamTextEnabled = true
    var privateTextEnabled = true
    var transcriptionEnabled = false
    var loggingEnabled = true
}

struct CommunicationAPI {
    struct CreateSessionRequest: Codable { var gameID: UUID; var invitedOfficialIDs: [String]; var preferredMode: PreferredCommunicationMode }
    struct ActiveSessionResponse: Codable { var session: CommunicationSession? }
    struct JoinSessionRequest: Codable { var sessionCode: String; var gameID: UUID; var officialID: String; var deviceReference: String }
    struct ApproveJoinRequest: Codable { var participantID: UUID; var approved: Bool }
    struct LeaveSessionRequest: Codable { var participantID: UUID }
    struct LockSessionRequest: Codable { var locked: Bool }
    struct EndSessionRequest: Codable { var reason: String }
    struct ParticipantPermissionsRequest: Codable { var speakingPermission: SpeakingPermission }
    struct VoiceTransmissionStartRequest: Codable { var recipientType: CommunicationRecipientType; var recipientParticipantIDs: [UUID] }
    struct VoiceTransmissionEndRequest: Codable { var transmissionID: UUID; var endedAt: Date }
    struct SendMessageRequest: Codable { var message: GameCommunicationMessage }
    struct AcknowledgeMessageRequest: Codable { var acknowledgmentStatus: MessageAcknowledgmentStatus }
    struct LogEventsRequest: Codable { var events: [CommunicationEventLog] }
    struct DeviceRegistrationRequest: Codable { var appDeviceReference: String; var officialID: String }
    struct PushToTalkRegistrationRequest: Codable { var channelUUID: UUID; var devicePushTokenReference: String }
}

enum CommunicationError: LocalizedError, Equatable {
    case gameNotFound
    case currentOfficialUnavailable
    case notAssignedToGame
    case notHeadOfficial
    case sessionAtCapacity
    case invalidSessionCode
    case sessionEnded
    case sessionLocked
    case ambiguousRecipient([String])
    case recipientNotFound
    case recipientUnavailable
    case permissionDenied
    case productionBackendRequired
    case pushToTalkEntitlementRequired
    case microphonePermissionDenied
    case speechPermissionDenied

    var errorDescription: String? {
        switch self {
        case .gameNotFound: return "Game not found."
        case .currentOfficialUnavailable: return "Current official identity is unavailable."
        case .notAssignedToGame: return "Only officials assigned to this game may join the communication session."
        case .notHeadOfficial: return "Only the Head Official can perform this action."
        case .sessionAtCapacity: return "This communication session already has six participants."
        case .invalidSessionCode: return "The session code is invalid."
        case .sessionEnded: return "This communication session has ended."
        case .sessionLocked: return "This communication session is locked."
        case .ambiguousRecipient(let names): return "Multiple officials match. Select \(names.joined(separator: " or "))."
        case .recipientNotFound: return "No official matches that recipient."
        case .recipientUnavailable: return "The selected official is unavailable."
        case .permissionDenied: return "Communication permission is denied."
        case .productionBackendRequired: return "Production communication requires the secure RefTrace backend."
        case .pushToTalkEntitlementRequired: return "Apple Push to Talk entitlement and configuration are required for production voice."
        case .microphonePermissionDenied: return "Microphone permission is required for push-to-talk."
        case .speechPermissionDenied: return "Speech recognition permission is required for dictation and spoken recipient selection."
        }
    }
}
