import Foundation

struct SportGameConfiguration: Codable, Hashable {
    var sport: RefTraceSport
    var periods: [String]
    var periodLength: TimeInterval
    var halftimeLength: TimeInterval
    var overtimeRules: String
    var playClockEnabled: Bool
    var defaultPlayClock: TimeInterval
    var alternatePlayClock: TimeInterval
    var possessionEnabled: Bool
    var scoreTypes: [ScoreType]
    var startingTimeouts: Int
    var timeoutDuration: TimeInterval
    var allowedOfficialPositions: [RefTraceOfficialPosition]
    var fiveOfficialCrewEnabled: Bool
    var showTenthsUnderOneMinute: Bool
    var rulesDocumentID: String?
    var rulesVersion: String?

    static func configuration(for game: RefTraceGame, crewCount: Int? = nil) -> SportGameConfiguration {
        switch game.sport {
        case .football:
            let fiveOfficial = (crewCount ?? (game.otherOfficials.count + 1)) >= 5
            var positions: [RefTraceOfficialPosition] = [.headReferee, .linesman, .headLinesman, .umpire]
            if fiveOfficial { positions.append(.backJudge) }
            return SportGameConfiguration(
                sport: game.sport,
                periods: ["Q1", "Q2", "Q3", "Q4"],
                periodLength: 12 * 60,
                halftimeLength: 15 * 60,
                overtimeRules: "League configured",
                playClockEnabled: true,
                defaultPlayClock: 25,
                alternatePlayClock: 40,
                possessionEnabled: true,
                scoreTypes: [
                    .touchdown(points: 6), .extraPointKick(points: 1), .twoPointConversion(points: 2),
                    .fieldGoal(points: 3), .safety(points: 2), .defensiveConversionReturn(points: 2), .manualAdjustment
                ],
                startingTimeouts: 3,
                timeoutDuration: 60,
                allowedOfficialPositions: positions,
                fiveOfficialCrewEnabled: fiveOfficial,
                showTenthsUnderOneMinute: false,
                rulesDocumentID: game.ruleDocumentID,
                rulesVersion: game.ruleVersion
            )
        case .flagFootball:
            return SportGameConfiguration(
                sport: game.sport,
                periods: ["H1", "H2"],
                periodLength: 20 * 60,
                halftimeLength: 5 * 60,
                overtimeRules: "League configured",
                playClockEnabled: true,
                defaultPlayClock: 30,
                alternatePlayClock: 10,
                possessionEnabled: true,
                scoreTypes: [.touchdown(points: 6), .onePointConversion(points: 1), .twoPointConversion(points: 2), .safety(points: 2), .defensiveConversionReturn(points: 2), .manualAdjustment],
                startingTimeouts: 3,
                timeoutDuration: 60,
                allowedOfficialPositions: [.headReferee, .backJudge],
                fiveOfficialCrewEnabled: false,
                showTenthsUnderOneMinute: false,
                rulesDocumentID: game.ruleDocumentID,
                rulesVersion: game.ruleVersion
            )
        case .soccer:
            return SportGameConfiguration(
                sport: game.sport,
                periods: ["1st Half", "2nd Half"],
                periodLength: 45 * 60,
                halftimeLength: 15 * 60,
                overtimeRules: "League configured",
                playClockEnabled: false,
                defaultPlayClock: 0,
                alternatePlayClock: 0,
                possessionEnabled: false,
                scoreTypes: [.goal(points: 1), .ownGoal(points: 1), .penaltyGoal(points: 1), .manualAdjustment],
                startingTimeouts: 0,
                timeoutDuration: 0,
                allowedOfficialPositions: [.centerReferee, .assistantReferee1, .assistantReferee2, .fourthOfficial],
                fiveOfficialCrewEnabled: false,
                showTenthsUnderOneMinute: false,
                rulesDocumentID: game.ruleDocumentID,
                rulesVersion: game.ruleVersion
            )
        case .lacrosse:
            return SportGameConfiguration(
                sport: game.sport,
                periods: ["Q1", "Q2", "Q3", "Q4"],
                periodLength: 12 * 60,
                halftimeLength: 10 * 60,
                overtimeRules: "League configured",
                playClockEnabled: false,
                defaultPlayClock: 0,
                alternatePlayClock: 0,
                possessionEnabled: false,
                scoreTypes: [.goal(points: 1), .manualAdjustment],
                startingTimeouts: 2,
                timeoutDuration: 60,
                allowedOfficialPositions: [.headReferee, .referee, .fieldJudge, .benchOfficial],
                fiveOfficialCrewEnabled: false,
                showTenthsUnderOneMinute: false,
                rulesDocumentID: game.ruleDocumentID,
                rulesVersion: game.ruleVersion
            )
        }
    }
}

enum RefTraceOfficialPosition: String, CaseIterable, Codable, Hashable, Identifiable {
    case headReferee
    case linesman
    case headLinesman
    case umpire
    case backJudge
    case centerReferee
    case assistantReferee1
    case assistantReferee2
    case fourthOfficial
    case referee
    case fieldJudge
    case benchOfficial
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .headReferee: return "Head Ref"
        case .linesman: return "Linesman"
        case .headLinesman: return "Head Linesman"
        case .umpire: return "Umpire"
        case .backJudge: return "Back Judge"
        case .centerReferee: return "Center Referee"
        case .assistantReferee1: return "Assistant Referee 1"
        case .assistantReferee2: return "Assistant Referee 2"
        case .fourthOfficial: return "Fourth Official"
        case .referee: return "Referee"
        case .fieldJudge: return "Field Judge"
        case .benchOfficial: return "Bench Official"
        case .unknown: return "Official"
        }
    }

    static func normalize(_ text: String) -> RefTraceOfficialPosition {
        let cleaned = text.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        switch cleaned {
        case "headref", "headreferee", "crewchief", "leadofficial": return .headReferee
        case "linesman", "linejudge": return .linesman
        case "headlinesman": return .headLinesman
        case "umpire": return .umpire
        case "backjudge": return .backJudge
        case "centerreferee": return .centerReferee
        case "assistantreferee1", "ar1": return .assistantReferee1
        case "assistantreferee2", "ar2": return .assistantReferee2
        case "fourthofficial": return .fourthOfficial
        case "referee": return .referee
        case "fieldjudge": return .fieldJudge
        case "benchofficial": return .benchOfficial
        default: return .unknown
        }
    }
}

enum TeamSide: String, CaseIterable, Codable, Hashable, Identifiable {
    case home
    case away
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum PossessionState: String, CaseIterable, Codable, Hashable {
    case home
    case away
    case unknown
    case pendingKickoff
    case notApplicable
}

enum InGameStatus: String, CaseIterable, Codable, Hashable {
    case pregame
    case ready
    case active
    case clockStopped
    case halftime
    case suspended
    case overtime
    case completed
    case cancelled
}

enum ClockEventSubtype: String, Codable, Hashable {
    case gameStarted
    case gameStopped
    case gameAdjusted
    case playStarted
    case playStopped
    case playReset
    case playExpired
    case periodChanged
}

struct GameClockState: Codable, Hashable {
    var duration: TimeInterval
    var remainingTime: TimeInterval
    var isRunning: Bool
    var referenceStartTimestamp: Date?
    var lastSynchronizedTimestamp: Date
    var currentPeriod: String
    var stateVersion: Int
    var showTenthsUnderOneMinute: Bool

    func reconciled(now: Date = Date()) -> GameClockState {
        guard isRunning, let referenceStartTimestamp else { return self }
        var copy = self
        let elapsed = max(0, now.timeIntervalSince(referenceStartTimestamp))
        copy.remainingTime = max(0, remainingTime - elapsed)
        copy.referenceStartTimestamp = now
        if copy.remainingTime == 0 {
            copy.isRunning = false
            copy.referenceStartTimestamp = nil
        }
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    var displayText: String {
        let remaining = max(0, remainingTime)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        if showTenthsUnderOneMinute && remaining < 60 && remaining > 0 {
            let tenths = Int((remaining - floor(remaining)) * 10)
            return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

typealias PlayClockState = GameClockState

enum ScoreType: Codable, Hashable, Identifiable {
    case touchdown(points: Int)
    case extraPointKick(points: Int)
    case onePointConversion(points: Int)
    case twoPointConversion(points: Int)
    case fieldGoal(points: Int)
    case safety(points: Int)
    case defensiveConversionReturn(points: Int)
    case goal(points: Int)
    case ownGoal(points: Int)
    case penaltyGoal(points: Int)
    case manualAdjustment

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .touchdown: return "Touchdown"
        case .extraPointKick: return "Extra Point Kick"
        case .onePointConversion: return "One-Point Conversion"
        case .twoPointConversion: return "Two-Point Conversion"
        case .fieldGoal: return "Field Goal"
        case .safety: return "Safety"
        case .defensiveConversionReturn: return "Defensive Conversion Return"
        case .goal: return "Goal"
        case .ownGoal: return "Own Goal"
        case .penaltyGoal: return "Penalty Goal"
        case .manualAdjustment: return "Manual Score Adjustment"
        }
    }

    var defaultPoints: Int {
        switch self {
        case .touchdown(let points), .extraPointKick(let points), .onePointConversion(let points), .twoPointConversion(let points), .fieldGoal(let points), .safety(let points), .defensiveConversionReturn(let points), .goal(let points), .ownGoal(let points), .penaltyGoal(let points): return points
        case .manualAdjustment: return 0
        }
    }

    var requiresReason: Bool {
        if case .manualAdjustment = self { return true }
        return false
    }
}

enum ScoreCorrectionStatus: String, CaseIterable, Codable, Hashable {
    case standard
    case correction
    case administrativeAdjustment
    case reversal
}

enum TimeoutType: String, CaseIterable, Codable, Hashable, Identifiable {
    case homeTeam
    case awayTeam
    case official
    case injury
    case media
    case administrative
    case other

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .homeTeam: return "Home Team"
        case .awayTeam: return "Away Team"
        case .official: return "Official"
        case .injury: return "Injury"
        case .media: return "Media"
        case .administrative: return "Administrative"
        case .other: return "Other"
        }
    }
}

enum GameEventType: String, CaseIterable, Codable, Hashable {
    case gameCreated
    case gameStarted
    case startGameSelected
    case openingWhistleArmed
    case openingWhistleDetected
    case openingWhistleRejected
    case gameClockStarted
    case gameClockStopped
    case gameClockResumed
    case gameClockAdjusted
    case crewWhistleDetected
    case crewWhistleMerged
    case crewWhistleRejected
    case endOfPlayDetected
    case playClockStarted
    case playClockStopped
    case playClockReset
    case playClockExpired
    case timeoutRequested
    case timeoutClockStopped
    case timeoutRecorded
    case twoMinutePreAlertSent
    case twoMinuteWarningReached
    case watchClockCommand
    case watchCommandPending
    case watchCommandConfirmed
    case watchCommandFailed
    case deviceDisconnected
    case deviceReconnected
    case periodStarted
    case periodEnded
    case halftimeStarted
    case halftimeEnded
    case overtimeStarted
    case scoreAdded
    case scoreCorrected
    case scoreReversed
    case timeoutTaken
    case timeoutCorrected
    case possessionChanged
    case possessionCorrected
    case penaltyPlaceholder
    case gameSuspended
    case gameResumed
    case gameEnded
    case gameCompleted
    case syncCompleted
    case syncFailed
}

struct ScoreEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var scoringTeamID: String
    var scoringTeamName: String
    var scoreType: ScoreType
    var pointValue: Int
    var period: String
    var gameClockTime: String
    var playClockTime: String?
    var wallClockTimestamp: Date = Date()
    var homeScoreBefore: Int
    var awayScoreBefore: Int
    var homeScoreAfter: Int
    var awayScoreAfter: Int
    var enteredByOfficialID: String
    var enteredByOfficialName: String
    var enteredByPosition: String
    var sourceDevice: String
    var correctionStatus: ScoreCorrectionStatus
    var correctionReason: String?
    var relatedScoreEventID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncStatus: RefTraceSyncState = .pending
}

struct TimeoutEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var timeoutType: TimeoutType
    var chargedTeamID: String?
    var chargedTeamName: String?
    var period: String
    var gameClockTime: String
    var durationSeconds: Int
    var homeTimeoutsBefore: Int
    var awayTimeoutsBefore: Int
    var homeTimeoutsAfter: Int
    var awayTimeoutsAfter: Int
    var enteredByOfficialID: String
    var enteredByOfficialName: String
    var correctionStatus: ScoreCorrectionStatus
    var correctionReason: String?
    var requestedAt: Date = Date()
    var authoritativeClockStoppedAt: Date?
    var stoppedByOfficialID: String?
    var stoppedByDeviceReference: String?
    var stopInputSource: TimeoutStopInputSource?
    var gameClockBefore: String?
    var gameClockAfter: String?
    var playClockBefore: String?
    var playClockAfter: String?
    var timeoutNumberForTeam: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncStatus: RefTraceSyncState = .pending
}

struct PossessionEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var previousPossession: PossessionState
    var newPossession: PossessionState
    var period: String
    var gameClockTime: String
    var enteredByOfficialID: String
    var enteredByOfficialName: String
    var reason: String?
    var createdAt: Date = Date()
    var syncStatus: RefTraceSyncState = .pending
}

struct GameEventRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var officialEaseGameID: String?
    var officialEaseAssignmentID: String?
    var seasonID: String?
    var leagueID: String?
    var sport: RefTraceSport
    var eventType: GameEventType
    var eventSubtype: String?
    var teamID: String?
    var teamName: String?
    var officialID: String?
    var officialName: String?
    var officialPosition: String?
    var period: String
    var gameClockTime: String
    var playClockTime: String?
    var wallClockTimestamp: Date = Date()
    var homeScoreBefore: Int
    var awayScoreBefore: Int
    var homeScoreAfter: Int
    var awayScoreAfter: Int
    var homeTimeoutsBefore: Int
    var awayTimeoutsBefore: Int
    var homeTimeoutsAfter: Int
    var awayTimeoutsAfter: Int
    var possessionBefore: PossessionState
    var possessionAfter: PossessionState
    var points: Int?
    var details: String
    var correctionReason: String?
    var relatedEventID: UUID?
    var sourceDevice: String
    var sourceApp: String
    var sequenceNumber: Int
    var correlationID: UUID
    var syncStatus: RefTraceSyncState = .pending
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

enum PenaltyEventStatus: String, CaseIterable, Codable, Hashable {
    case placeholder
    case draft
    case recorded
    case enforced
    case declined
    case offsetting
    case corrected
    case removed
}

struct PenaltyEventRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var eventLogID: UUID?
    var committingTeamID: String?
    var offendedTeamID: String?
    var callingOfficialID: String?
    var foulName: String?
    var ruleCode: String?
    var penaltyDistance: String?
    var enforcementSpot: String?
    var downConsequence: String?
    var clockConsequence: String?
    var acceptedStatus: String?
    var gameClockTime: String
    var period: String
    var notes: String
    var status: PenaltyEventStatus
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct RulesAssistantQueryLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gameID: UUID
    var officialID: String
    var ruleDocumentID: String?
    var ruleVersion: String?
    var questionText: String
    var normalizedQuestion: String
    var responseSummary: String
    var citedRuleItemIDs: [String]
    var confidenceStatus: RulesAssistantConfidenceStatus
    var createdAt: Date = Date()
    var responseReceivedAt: Date?
    var backendRequestID: String?
    var syncStatus: RefTraceSyncState = .pending
}

enum RulesAssistantConfidenceStatus: String, CaseIterable, Codable, Hashable {
    case supported
    case needsContext
    case unsupported
    case backendRequired
}

struct PenaltyRulesAssistantResponse: Codable, Hashable {
    var foulName: String
    var sport: RefTraceSport
    var league: String
    var ruleVersion: String?
    var penalty: String
    var enforcement: String
    var additionalResult: String
    var classification: String
    var exceptions: String
    var source: String
    var explanation: String
    var confidenceStatus: RulesAssistantConfidenceStatus
    var followUpQuestions: [String]
}

protocol GameEventRepository {
    func loadEvents(for gameID: UUID) async throws -> [GameEventRecord]
    func append(_ event: GameEventRecord) async throws
}

protocol ScoreEventRepository {
    func loadScoreEvents(for gameID: UUID) async throws -> [ScoreEvent]
    func append(_ event: ScoreEvent) async throws
}

protocol TimeoutEventRepository {
    func loadTimeoutEvents(for gameID: UUID) async throws -> [TimeoutEvent]
    func append(_ event: TimeoutEvent) async throws
}

protocol PossessionEventRepository {
    func loadPossessionEvents(for gameID: UUID) async throws -> [PossessionEvent]
    func append(_ event: PossessionEvent) async throws
}

protocol PenaltyEventRepository {
    func loadPenaltyEvents(for gameID: UUID) async throws -> [PenaltyEventRecord]
    func append(_ event: PenaltyEventRecord) async throws
}

protocol ActiveGameStateRepository {
    func loadState(for gameID: UUID) async throws -> InGamePersistedState?
    func saveState(_ state: InGamePersistedState) async throws
}

protocol PenaltyRulesAssistantService {
    func answer(question: String, game: RefTraceGame, ruleDocumentID: String?, ruleVersion: String?) async throws -> PenaltyRulesAssistantResponse
}

struct InGamePersistedState: Identifiable, Codable, Hashable {
    var id: UUID { gameID }
    var gameID: UUID
    var homeScore: Int
    var awayScore: Int
    var homeTimeouts: Int
    var awayTimeouts: Int
    var possession: PossessionState
    var gameClock: GameClockState
    var playClock: PlayClockState?
    var status: InGameStatus
    var currentPeriod: String
    var lastSavedAt: Date
    var syncStatus: RefTraceSyncState
}

enum RefTraceInGameAPI {
    struct GameStateResponse: Codable { var state: InGamePersistedState }
    struct UpdateGameStateRequest: Codable { var state: InGamePersistedState; var idempotencyKey: UUID }
    struct CreateGameEventRequest: Codable { var event: GameEventRecord; var idempotencyKey: UUID }
    struct GameEventsResponse: Codable { var events: [GameEventRecord] }
    struct CreateScoreRequest: Codable { var scoreEvent: ScoreEvent; var idempotencyKey: UUID }
    struct UpdateScoreRequest: Codable { var scoreEvent: ScoreEvent; var correctionReason: String }
    struct CreateTimeoutRequest: Codable { var timeoutEvent: TimeoutEvent; var idempotencyKey: UUID }
    struct UpdateTimeoutRequest: Codable { var timeoutEvent: TimeoutEvent; var correctionReason: String }
    struct CreatePossessionEventRequest: Codable { var event: PossessionEvent; var idempotencyKey: UUID }
    struct CreatePenaltyRequest: Codable { var penalty: PenaltyEventRecord; var idempotencyKey: UUID }
    struct PenaltiesResponse: Codable { var penalties: [PenaltyEventRecord] }
    struct RulesQuestionRequest: Codable { var question: String; var ruleDocumentID: String?; var ruleVersion: String? }
    struct RulesQuestionResponse: Codable { var response: PenaltyRulesAssistantResponse; var log: RulesAssistantQueryLog }
    struct CompleteGameRequest: Codable { var finalState: InGamePersistedState; var eventCount: Int; var idempotencyKey: UUID }
}
