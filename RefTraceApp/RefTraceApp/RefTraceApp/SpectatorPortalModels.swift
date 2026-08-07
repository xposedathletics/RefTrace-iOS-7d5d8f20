import Foundation

public enum SpectatorUserRole: String, CaseIterable, Codable, Hashable, Identifiable {
    case coach
    case parent
    case observer
    case authorizedViewer
    case leagueAdministrator
    case gameAdministrator
    case official

    public var id: String { rawValue }
}

enum SpectatorAccessLevel: String, CaseIterable, Codable, Hashable, Identifiable {
    case `private`
    case invitationOnly
    case leagueMembers
    case teamMembers
    case publicReadOnly

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .invitationOnly: return "Invitation Only"
        case .leagueMembers: return "League Members"
        case .teamMembers: return "Team Members"
        case .publicReadOnly: return "Public Read Only"
        }
    }
}

struct SpectatorAccessPolicy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var accessLevel: SpectatorAccessLevel = .invitationOnly
    var authenticationRequired: Bool = true
    var viewerCodeRequired: Bool = true
    var viewerCodeExpiresAt: Date?
    var allowGameSiteDisplay: Bool = false
    var allowTeamMascots: Bool = true
    var allowPublicListing: Bool = false
    var maximumConcurrentViewers: Int? = nil
    var streamDelaySeconds: Int = 0
    var hideUntilGameStart: Bool = false
    var expireAfterGame: Bool = true
    var archiveAvailability: String = "League policy"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

enum SpectatorGameStatus: String, CaseIterable, Codable, Hashable {
    case scheduled
    case warmup
    case delayed
    case active
    case clockStopped
    case halftime
    case suspended
    case overtime
    case completed
    case cancelled
    case unavailable

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .warmup: return "Warmup"
        case .delayed: return "Weather Delay"
        case .active: return "Live"
        case .clockStopped: return "Clock Stopped"
        case .halftime: return "Halftime"
        case .suspended: return "Suspended"
        case .overtime: return "Overtime"
        case .completed: return "Final"
        case .cancelled: return "Cancelled"
        case .unavailable: return "Temporarily Unavailable"
        }
    }
}

enum SpectatorDataStatus: String, CaseIterable, Codable, Hashable {
    case live
    case updating
    case delayed
    case reconnecting
    case lastUpdated
    case final
    case unavailable

    var displayName: String {
        switch self {
        case .live: return "Live"
        case .updating: return "Updating"
        case .delayed: return "Delayed"
        case .reconnecting: return "Reconnecting"
        case .lastUpdated: return "Last updated"
        case .final: return "Final"
        case .unavailable: return "Live updates temporarily unavailable"
        }
    }
}

struct SpectatorGameState: Identifiable, Codable, Hashable {
    var id: UUID
    var publicGameReference: String
    var sport: RefTraceSport
    var leagueName: String
    var homeTeamName: String
    var homeTeamMascotReference: String
    var homeTeamAbbreviation: String
    var awayTeamName: String
    var awayTeamMascotReference: String
    var awayTeamAbbreviation: String
    var homeScore: Int
    var awayScore: Int
    var gameClockRemaining: TimeInterval
    var gameClockIsRunning: Bool
    var clockReferenceTimestamp: Date?
    var currentPeriod: String
    var possession: PossessionState
    var gameStatus: SpectatorGameStatus
    var scheduledStartTime: Date
    var stateVersion: Int
    var lastUpdatedAt: Date
    var dataStatus: SpectatorDataStatus
    var isFinal: Bool

    var possessionVisible: Bool {
        sport == .football || sport == .flagFootball
    }

    static func from(game: RefTraceGame, state: InGamePersistedState, policy: SpectatorAccessPolicy = SpectatorAccessPolicy()) -> SpectatorGameState {
        SpectatorGameState(
            id: game.id,
            publicGameReference: Self.publicReference(for: game),
            sport: game.sport,
            leagueName: game.leagueName,
            homeTeamName: game.homeTeamName,
            homeTeamMascotReference: policy.allowTeamMascots ? game.homeTeamMascot : "",
            homeTeamAbbreviation: RefTraceInGameStore.abbreviation(for: game.homeTeamName),
            awayTeamName: game.awayTeamName,
            awayTeamMascotReference: policy.allowTeamMascots ? game.awayTeamMascot : "",
            awayTeamAbbreviation: RefTraceInGameStore.abbreviation(for: game.awayTeamName),
            homeScore: state.homeScore,
            awayScore: state.awayScore,
            gameClockRemaining: state.gameClock.remainingTime,
            gameClockIsRunning: state.gameClock.isRunning,
            clockReferenceTimestamp: state.gameClock.referenceStartTimestamp,
            currentPeriod: state.currentPeriod,
            possession: state.possession,
            gameStatus: SpectatorGameStatus(status: state.status, game: game),
            scheduledStartTime: game.scheduledStartTime,
            stateVersion: state.gameClock.stateVersion + (state.playClock?.stateVersion ?? 0) + state.homeScore + state.awayScore,
            lastUpdatedAt: state.lastSavedAt,
            dataStatus: state.status == .completed || game.status == .completed ? .final : .live,
            isFinal: state.status == .completed || game.status == .completed
        )
    }

    static func publicReference(for game: RefTraceGame) -> String {
        "game-\(game.id.uuidString.prefix(8))"
    }
}

extension SpectatorGameStatus {
    init(status: InGameStatus, game: RefTraceGame) {
        if game.status == .cancelled {
            self = .cancelled
            return
        }
        switch status {
        case .pregame, .ready: self = .scheduled
        case .active: self = .active
        case .clockStopped: self = .clockStopped
        case .halftime: self = .halftime
        case .suspended: self = .suspended
        case .overtime: self = .overtime
        case .completed: self = .completed
        case .cancelled: self = .cancelled
        }
    }
}

struct SpectatorGameSummary: Identifiable, Codable, Hashable {
    var id: String { publicGameReference }
    var publicGameReference: String
    var sport: RefTraceSport
    var leagueName: String
    var homeTeamName: String
    var homeTeamMascotReference: String
    var awayTeamName: String
    var awayTeamMascotReference: String
    var scheduledStartTime: Date
    var gameStatus: SpectatorGameStatus
    var dataStatus: SpectatorDataStatus
    var accessPolicy: SpectatorAccessPolicy
}

struct GameViewerToken: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var tokenReference: String
    var publicGameReference: String
    var issuedToUserID: String?
    var role: SpectatorUserRole
    var expiresAt: Date
    var revokedAt: Date?

    var isExpired: Bool { expiresAt < Date() }
    var isRevoked: Bool { revokedAt != nil }
}

struct SpectatorAccessLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var publicGameReference: String
    var gameID: UUID?
    var viewerUserID: String?
    var viewerRole: SpectatorUserRole
    var accessMethod: SpectatorAccessMethod
    var accessResult: SpectatorAccessResult
    var sessionStartedAt: Date?
    var sessionEndedAt: Date?
    var lastSeenAt: Date?
    var deviceReference: String
    var tokenReference: String?
    var failureReasonCode: String?
    var correlationID: UUID = UUID()
    var createdAt: Date = Date()
}

enum SpectatorAccessMethod: String, CaseIterable, Codable, Hashable {
    case authenticatedRefTrace
    case authenticatedOfficialEase
    case invitation
    case viewerCode
    case qrCode
    case universalLink
    case deepLink
    case publicListing
}

enum SpectatorAccessResult: String, CaseIterable, Codable, Hashable {
    case allowed
    case denied
    case expired
    case revoked
    case gameUnavailable
    case networkUnavailable
}

enum SpectatorPortalError: LocalizedError, Equatable {
    case invalidCode
    case expiredCode
    case revokedCode
    case gameUnavailable
    case accessDenied
    case networkUnavailable
    case viewerAccessDisabled
    case staleState

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "Invalid game-view code."
        case .expiredCode: return "This game-view code has expired."
        case .revokedCode: return "This game-view code has been revoked."
        case .gameUnavailable: return "This game is unavailable."
        case .accessDenied: return "You do not have permission to view this game."
        case .networkUnavailable: return "Network unavailable. Showing the last received game state when available."
        case .viewerAccessDisabled: return "Live game viewing is not available for this game."
        case .staleState: return "Live updates are temporarily unavailable. Showing the last received game state."
        }
    }
}

struct SpectatorScoreUpdate: Codable, Hashable {
    var publicGameReference: String
    var homeScore: Int
    var awayScore: Int
    var stateVersion: Int
    var occurredAt: Date
}

struct SpectatorClockUpdate: Codable, Hashable {
    var publicGameReference: String
    var remainingTime: TimeInterval
    var isRunning: Bool
    var referenceTimestamp: Date?
    var currentPeriod: String
    var stateVersion: Int
    var occurredAt: Date
}

struct SpectatorPossessionUpdate: Codable, Hashable {
    var publicGameReference: String
    var possession: PossessionState
    var stateVersion: Int
    var occurredAt: Date
}

struct SpectatorGameStatusUpdate: Codable, Hashable {
    var publicGameReference: String
    var gameStatus: SpectatorGameStatus
    var stateVersion: Int
    var occurredAt: Date
}

enum SpectatorViewerAPI {
    struct GamesResponse: Codable { var games: [SpectatorGameSummary] }
    struct GameResponse: Codable { var game: SpectatorGameSummary }
    struct GameStateResponse: Codable { var state: SpectatorGameState }
    struct ValidateAccessRequest: Codable { var tokenOrCode: String; var viewerUserID: String?; var role: SpectatorUserRole; var accessMethod: SpectatorAccessMethod }
    struct ValidateAccessResponse: Codable { var allowed: Bool; var publicGameReference: String?; var tokenReference: String?; var expiresAt: Date?; var errorCode: String? }
    struct ViewerCodeRequest: Codable { var publicGameReference: String; var expiresAt: Date?; var accessLevel: SpectatorAccessLevel }
    struct ViewerCodeResponse: Codable { var codeReference: String; var expiresAt: Date }
    struct QRTokenRequest: Codable { var publicGameReference: String; var expiresAt: Date? }
    struct QRTokenResponse: Codable { var viewerURL: URL; var tokenReference: String; var expiresAt: Date }
    struct RevokeAccessRequest: Codable { var tokenReference: String; var reason: String }
    struct RevokeAccessResponse: Codable { var revoked: Bool; var revokedAt: Date }
    struct LeaveRequest: Codable { var tokenReference: String?; var sessionEndedAt: Date }
    struct SnapshotResponse: Codable { var state: SpectatorGameState; var events: [SpectatorSafeEventEnvelope] }
    struct ViewerSettingsRequest: Codable { var policy: SpectatorAccessPolicy }
    struct ViewerSettingsResponse: Codable { var policy: SpectatorAccessPolicy }
    struct AccessLogResponse: Codable { var logs: [SpectatorAccessLog] }
}

struct SpectatorSafeEventEnvelope: Codable, Hashable {
    var publicGameReference: String
    var eventType: String
    var stateVersion: Int
    var occurredAt: Date
}
