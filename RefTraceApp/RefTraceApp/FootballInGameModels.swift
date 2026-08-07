import Foundation

enum FootballClockMode: String, CaseIterable, Codable, Hashable {
    case notStarted
    case armedForOpeningWhistle
    case running
    case stopped
    case timeout
    case twoMinuteWarning
    case halftime
    case quarterBreak
    case suspended
    case completed
}

struct FootballGameConfiguration: Codable, Hashable {
    var regulationQuarterCount: Int
    var quarterDuration: TimeInterval
    var halftimeDuration: TimeInterval
    var twoMinuteWarningEnabled: Bool
    var twoMinuteWarningQuarters: Set<String>
    var twoMinuteWarningThreshold: TimeInterval
    var twoMinutePreAlertSeconds: TimeInterval
    var playClockDuration: TimeInterval
    var alternatePlayClockDuration: TimeInterval
    var gameClockRunsAfterOrdinaryWhistle: Bool
    var timeoutStopsGameClock: Bool
    var headRefWhistleStartsInitialClock: Bool
    var crewWhistleStartsPlayClock: Bool
    var whistleDetectionEnabled: Bool
    var whistleConfidenceThreshold: Double
    var whistleDebounceInterval: TimeInterval
    var minimumWhistleDuration: TimeInterval
    var maximumWhistleDuration: TimeInterval
    var simultaneousWhistleMergeWindow: TimeInterval
    var headRefClockAuthorityRequired: Bool
    var configuredRuleVersion: String?

    static func configuration(for game: RefTraceGame, crewCount: Int? = nil) -> FootballGameConfiguration {
        let base = SportGameConfiguration.configuration(for: game, crewCount: crewCount)
        return FootballGameConfiguration(
            regulationQuarterCount: 4,
            quarterDuration: base.periodLength,
            halftimeDuration: base.halftimeLength,
            twoMinuteWarningEnabled: true,
            twoMinuteWarningQuarters: ["Q2", "Q4"],
            twoMinuteWarningThreshold: 2 * 60,
            twoMinutePreAlertSeconds: 5,
            playClockDuration: 25,
            alternatePlayClockDuration: base.alternatePlayClock,
            gameClockRunsAfterOrdinaryWhistle: true,
            timeoutStopsGameClock: true,
            headRefWhistleStartsInitialClock: true,
            crewWhistleStartsPlayClock: true,
            whistleDetectionEnabled: true,
            whistleConfidenceThreshold: 0.82,
            whistleDebounceInterval: 1.0,
            minimumWhistleDuration: 0.08,
            maximumWhistleDuration: 2.0,
            simultaneousWhistleMergeWindow: 0.75,
            headRefClockAuthorityRequired: true,
            configuredRuleVersion: game.ruleVersion
        )
    }
}

enum WhistleDetectionState: String, CaseIterable, Codable, Hashable {
    case inactive
    case listening
    case active
    case lowConfidence
    case disabled
    case microphoneUnavailable
    case bluetoothInputUnavailable
    case reconnecting
}

enum WhistleDetectionSource: String, CaseIterable, Codable, Hashable {
    case iPhone
    case appleWatch
    case bluetoothHeadset
    case localMock
}

enum WhistleClassification: String, CaseIterable, Codable, Hashable {
    case refereeWhistle
    case possibleWhistle
    case nonWhistle
    case unknown
}

enum WhistleSignalQuality: String, CaseIterable, Codable, Hashable {
    case excellent
    case good
    case limited
    case poor
    case unknown
}

enum WhistleTriggeredAction: String, CaseIterable, Codable, Hashable {
    case none
    case openingGameClockStart
    case playEnded
    case playClockStarted
    case ignoredDuplicate
    case ignoredLowConfidence
    case ignoredWrongAuthority
    case ignoredGameState
}

enum WhistleRejectionReason: String, CaseIterable, Codable, Hashable {
    case lowConfidence
    case wrongAuthority
    case duplicate
    case invalidGameState
    case unassignedOfficial
    case automationDisabled
}

enum TimeoutStopInputSource: String, CaseIterable, Codable, Hashable {
    case iPhone
    case watchAction
    case watchOnScreenButton
    case appIntent
    case shortcut
    case siri
    case localMock
}

struct FootballInGameState: Identifiable, Codable, Hashable {
    var id: UUID { gameID }
    var gameID: UUID
    var quarter: String
    var gameClockState: FootballClockMode
    var playClockState: FootballClockMode
    var gameStatus: InGameStatus
    var headRefereeID: String?
    var authoritativeDeviceID: String
    var initialWhistleStartArmed: Bool
    var whistleDetectionState: WhistleDetectionState
    var lastAcceptedWhistleEventID: UUID?
    var lastEndOfPlayEventID: UUID?
    var activeTimeoutID: UUID?
    var twoMinuteWarningState: TwoMinuteWarningCoordinatorState
    var gameClockVersion: Int
    var playClockVersion: Int
    var lastAuthoritativeClockCommand: UUID?
    var lastSynchronizedAt: Date
}

struct WhistleDetectionEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var officialID: String
    var officialPosition: RefTraceOfficialPosition
    var deviceReference: String
    var source: WhistleDetectionSource
    var detectedAt: Date
    var classification: WhistleClassification
    var confidence: Double
    var estimatedDurationMilliseconds: Int
    var signalQuality: WhistleSignalQuality
    var accepted: Bool = false
    var rejectionReason: WhistleRejectionReason?
    var mergedIntoEventID: UUID?
    var triggeredAction: WhistleTriggeredAction = .none
    var createdAt: Date = Date()
}

struct EndOfPlayWhistleEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var quarter: String
    var gameClockTime: String
    var sourceWhistleEventIDs: [UUID]
    var detectedOfficialIDs: [String]
    var acceptedAt: Date
    var playClockStartedAt: Date
    var playClockDuration: TimeInterval
    var gameClockWasRunning: Bool
    var createdAt: Date = Date()
}

enum TwoMinuteWarningCoordinatorState: String, CaseIterable, Codable, Hashable {
    case notApplicable
    case pending
    case preAlertSent
    case thresholdReached
    case acknowledged
    case completed
}

enum TwoMinuteWarningType: String, CaseIterable, Codable, Hashable {
    case fiveSecondPreAlert
    case twoMinuteThreshold
}

struct TwoMinuteWarningEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var quarter: String
    var warningType: TwoMinuteWarningType
    var gameClockTime: String
    var authoritativeClockVersion: Int
    var targetOfficialIDs: [String]
    var deliveredOfficialIDs: [String]
    var deliveredWatchIDs: [String]
    var failedRecipientIDs: [String]
    var triggeredAt: Date
    var createdAt: Date = Date()
}

struct GameClockCorrectionEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var quarter: String
    var previousClockTime: String
    var correctedClockTime: String
    var differenceMilliseconds: Int
    var reason: String
    var correctedByOfficialID: String
    var correctedByDevice: String
    var createdAt: Date = Date()
    var stateVersionBefore: Int
    var stateVersionAfter: Int
}

struct AuthoritativeClockSnapshot: Identifiable, Codable, Hashable {
    var id: UUID { gameID }
    var gameID: UUID
    var quarter: String
    var remainingGameTime: TimeInterval
    var gameClockIsRunning: Bool
    var gameClockReferenceTimestamp: Date?
    var remainingPlayClockTime: TimeInterval?
    var playClockIsRunning: Bool
    var playClockReferenceTimestamp: Date?
    var gameClockVersion: Int
    var playClockVersion: Int
    var authoritativeOfficialID: String?
    var authoritativeDeviceReference: String
    var lastCommandID: UUID?
    var lastUpdatedAt: Date
}

struct CrewWhistleSignal: Identifiable, Codable, Hashable {
    var id: UUID { eventID }
    var eventID: UUID
    var gameID: UUID
    var officialID: String
    var officialPosition: RefTraceOfficialPosition
    var detectedAt: Date
    var confidence: Double
    var deviceReference: String
    var sequenceNumber: Int
}

struct FootballPlaySequence: Identifiable, Codable, Hashable {
    enum Status: String, CaseIterable, Codable, Hashable {
        case waitingForSnap
        case live
        case ended
        case timeout
        case cancelled
        case corrected
    }

    var id: UUID = UUID()
    var gameID: UUID
    var quarter: String
    var sequenceNumber: Int
    var startedAtGameClock: String
    var startedAtWallClock: Date
    var endedAtGameClock: String?
    var endedAtWallClock: Date?
    var endingWhistleEventID: UUID?
    var playClockStartedAt: Date?
    var status: Status
}

protocol FootballGameStateRepository {
    func loadFootballState(for gameID: UUID) async throws -> FootballInGameState?
    func saveFootballState(_ state: FootballInGameState) async throws
}

protocol WhistleEventRepository {
    func loadWhistleEvents(for gameID: UUID) async throws -> [WhistleDetectionEvent]
    func append(_ event: WhistleDetectionEvent) async throws
}

protocol ClockCorrectionRepository {
    func loadClockCorrections(for gameID: UUID) async throws -> [GameClockCorrectionEvent]
    func append(_ event: GameClockCorrectionEvent) async throws
}

protocol FootballPlaySequenceRepository {
    func loadPlaySequences(for gameID: UUID) async throws -> [FootballPlaySequence]
    func append(_ sequence: FootballPlaySequence) async throws
}

protocol GameClockService {
    func start(_ clock: GameClockState, now: Date) -> GameClockState
    func stop(_ clock: GameClockState, now: Date) -> GameClockState
    func adjust(_ clock: GameClockState, delta: TimeInterval, now: Date) -> GameClockState
}

protocol PlayClockService {
    func start25(_ clock: PlayClockState, now: Date) -> PlayClockState
    func stop(_ clock: PlayClockState, now: Date) -> PlayClockState
    func reset25(_ clock: PlayClockState, now: Date) -> PlayClockState
    func manuallyAdjust(_ clock: PlayClockState, remaining: TimeInterval, now: Date) -> PlayClockState
}

protocol WhistleDetectionService {
    var state: WhistleDetectionState { get }
    func requestMicrophoneAccess() async -> Bool
    func startListening(for gameID: UUID, officialID: String) async throws
    func stopListening() async
}

protocol CrewWhistleAggregationService {
    func isDuplicate(_ event: WhistleDetectionEvent, acceptedEvents: [WhistleDetectionEvent], configuration: FootballGameConfiguration) -> Bool
    func merge(events: [WhistleDetectionEvent], configuration: FootballGameConfiguration) -> [WhistleDetectionEvent]
}

protocol AuthoritativeFootballClockService {
    func snapshot(for state: InGamePersistedState, footballState: FootballInGameState) -> AuthoritativeClockSnapshot
}

protocol TwoMinuteWarningService {
    func shouldSendPreAlert(quarter: String, previousRemaining: TimeInterval, currentRemaining: TimeInterval, configuration: FootballGameConfiguration, alreadySent: Bool) -> Bool
}

protocol HeadRefereeAuthorizationService {
    func canControlFootballClock(game: RefTraceGame, profile: RefTraceOfficialProfile?) -> Bool
}

protocol WatchGameControlService {
    func requestHeadRefereeTimeout(gameID: UUID, source: TimeoutStopInputSource) async throws -> UUID
}

protocol CrewGameSynchronizationService {
    func publish(snapshot: AuthoritativeClockSnapshot) async throws
    func queue(event: GameEventRecord) async
}

enum FootballInGameAPI {
    struct FootballStateResponse: Codable { var state: FootballInGameState; var snapshot: AuthoritativeClockSnapshot }
    struct StartPreparationRequest: Codable { var officialID: String; var deviceReference: String; var idempotencyKey: UUID }
    struct WhistleRequest: Codable { var signal: CrewWhistleSignal; var idempotencyKey: UUID }
    struct EndOfPlayRequest: Codable { var whistleEventIDs: [UUID]; var idempotencyKey: UUID }
    struct ClockCommandRequest: Codable { var officialID: String; var deviceReference: String; var commandID: UUID; var stateVersion: Int; var reason: String? }
    struct ClockAdjustRequest: Codable { var officialID: String; var deviceReference: String; var commandID: UUID; var correctedRemainingTime: TimeInterval; var reason: String }
    struct PlayClockCommandRequest: Codable { var officialID: String; var deviceReference: String; var commandID: UUID; var duration: TimeInterval? }
    struct TimeoutRequest: Codable { var timeoutType: TimeoutType; var officialID: String; var deviceReference: String; var source: TimeoutStopInputSource; var idempotencyKey: UUID }
    struct TwoMinuteWarningRequest: Codable { var quarter: String; var warningType: TwoMinuteWarningType; var authoritativeClockVersion: Int; var idempotencyKey: UUID }
    struct ClockEventsResponse: Codable { var events: [GameEventRecord] }
    struct WhistleEventsResponse: Codable { var events: [WhistleDetectionEvent] }
}
