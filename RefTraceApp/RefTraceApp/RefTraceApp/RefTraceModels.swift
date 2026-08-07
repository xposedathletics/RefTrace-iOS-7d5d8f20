import Foundation

struct RefTraceGame: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var officialEaseGameID: String?
    var officialEaseAssignmentID: String?
    var transferID: String?
    var source: RefTraceGameSource
    var sport: RefTraceSport
    var leagueID: String?
    var leagueName: String
    var homeTeamName: String
    var homeTeamMascot: String
    var awayTeamName: String
    var awayTeamMascot: String
    var gameSiteName: String
    var gameSiteAddress: String
    var fieldOrCourt: String
    var gameDate: Date
    var scheduledStartTime: Date
    var reportTime: Date
    var actualStartTime: Date?
    var actualEndTime: Date?
    var assignedOfficialID: String?
    var assignedOfficialName: String
    var assignedPosition: String
    var otherOfficials: [String] = []
    var notes: String = ""
    var status: RefTraceGameStatus
    var homeScore: Int = 0
    var awayScore: Int = 0
    var currentPeriod: String = "Pregame"
    var gameClockStatus: String = "Not Started"
    var ruleDocumentID: String?
    var ruleVersion: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastSavedAt: Date = Date()
    var syncStatus: RefTraceSyncState = .upToDate

    var teamsDisplayName: String {
        "\(awayTeamName) \(awayTeamMascot) at \(homeTeamName) \(homeTeamMascot)"
    }

    var isActiveLike: Bool {
        [.ready, .imported, .active, .paused].contains(status)
    }

    var isCompleted: Bool {
        status == .completed
    }

    var defaultReportTime: Date {
        scheduledStartTime.addingTimeInterval(-45 * 60)
    }
}

enum RefTraceSport: String, CaseIterable, Codable, Hashable, Identifiable {
    case football = "Football"
    case flagFootball = "Flag Football"
    case soccer = "Soccer"
    case lacrosse = "Lacrosse"

    var id: String { rawValue }

    var positions: [String] {
        switch self {
        case .football:
            return ["Head Referee", "Umpire", "Head Linesman", "Line Judge", "Back Judge", "Field Judge", "Side Judge"]
        case .flagFootball:
            return ["Head Referee", "Line Judge", "Back Judge", "Field Judge"]
        case .soccer:
            return ["Center Referee", "Assistant Referee 1", "Assistant Referee 2", "Fourth Official"]
        case .lacrosse:
            return ["Head Referee", "Referee", "Field Judge", "Bench Official"]
        }
    }
}

enum RefTraceGameSource: String, Codable, Hashable {
    case manualRefTrace = "Manual"
    case officialEase = "OfficialEase"
    case restored = "Restored"
    case test = "Test"
}

enum RefTraceGameStatus: String, CaseIterable, Codable, Hashable {
    case draft = "Draft"
    case ready = "Ready"
    case imported = "Imported"
    case active = "Active"
    case paused = "Paused"
    case suspended = "Suspended"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case syncPending = "Sync Pending"
    case syncFailed = "Sync Failed"
}

enum RefTraceSyncState: String, Codable, Hashable {
    case upToDate = "Up to Date"
    case syncing = "Syncing"
    case pending = "Pending"
    case offline = "Offline"
    case failed = "Failed"
    case authenticationRequired = "Authentication Required"
}

struct RefTraceOfficialProfile: Codable, Hashable {
    var officialID: String
    var preferredDisplayName: String?

    static let demo = RefTraceOfficialProfile(officialID: "official-harvey", preferredDisplayName: "Harvey")
}

struct OfficialEaseAssignment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var transferID: String
    var assignmentID: String
    var assignedOfficialID: String
    var assignedOfficialName: String
    var status: String
    var expiresAt: Date?
    var game: RefTraceGame
    var validationStatus: String = "Ready to validate"

    var isExpired: Bool {
        if let expiresAt {
            return expiresAt < Date()
        }
        return false
    }
}

struct RefTraceSyncSummary: Codable, Hashable {
    var connectionStatus: RefTraceSyncState
    var lastSuccessfulSync: Date?
    var pendingOutboundRecords: Int
    var pendingInboundAssignments: Int
    var rulesSyncStatus: RefTraceSyncState
    var gameCompletionSyncStatus: RefTraceSyncState
    var lastSyncError: String?

    static let initial = RefTraceSyncSummary(
        connectionStatus: .upToDate,
        lastSuccessfulSync: Date(),
        pendingOutboundRecords: 0,
        pendingInboundAssignments: 0,
        rulesSyncStatus: .upToDate,
        gameCompletionSyncStatus: .upToDate,
        lastSyncError: nil
    )
}

enum RefTraceUserFacingError: LocalizedError, Equatable {
    case officialEaseUnavailable
    case authenticationRequired
    case transferExpired
    case transferInvalid
    case assignmentBelongsToAnotherOfficial
    case duplicateGame
    case anotherGameAlreadyActive
    case missingRules
    case localSaveFailure
    case syncFailure
    case dataStoreFailure
    case missingRequiredFields(String)

    var errorDescription: String? {
        switch self {
        case .officialEaseUnavailable:
            return "OfficialEase is unavailable. Try again later."
        case .authenticationRequired:
            return "OfficialEase authentication is required."
        case .transferExpired:
            return "This transfer has expired."
        case .transferInvalid:
            return "This transfer code is invalid."
        case .assignmentBelongsToAnotherOfficial:
            return "This assignment belongs to another official."
        case .duplicateGame:
            return "This game already exists in RefTrace."
        case .anotherGameAlreadyActive:
            return "Another game is already active. Complete or suspend it before starting a new game."
        case .missingRules:
            return "No synchronized rules are available for this league and sport."
        case .localSaveFailure:
            return "RefTrace could not save this game locally."
        case .syncFailure:
            return "Synchronization failed. Saved games remain available."
        case .dataStoreFailure:
            return "RefTrace could not read the local data store."
        case .missingRequiredFields(let fields):
            return "Missing required fields: \(fields)."
        }
    }
}

struct CreateRefTraceGameDraft: Equatable {
    var sport: RefTraceSport = .football
    var leagueName = ""
    var homeTeamName = ""
    var homeTeamMascot = ""
    var awayTeamName = ""
    var awayTeamMascot = ""
    var gameSiteName = ""
    var gameSiteAddress = ""
    var fieldOrCourt = ""
    var gameDate = Date()
    var scheduledStartTime = Date()
    var reportTime = Date().addingTimeInterval(-45 * 60)
    var assignedPosition = RefTraceSport.football.positions.first ?? ""
    var otherOfficials = ""
    var notes = ""

    mutating func updateDefaultReportTime() {
        reportTime = Self.defaultReportTime(for: scheduledStartTime)
    }

    static func defaultReportTime(for scheduledStartTime: Date) -> Date {
        scheduledStartTime.addingTimeInterval(-45 * 60)
    }

    var reportTimeDiffersFromDefault: Bool {
        abs(reportTime.timeIntervalSince(Self.defaultReportTime(for: scheduledStartTime))) > 60
    }

    func makeGame(status: RefTraceGameStatus = .ready) -> RefTraceGame {
        RefTraceGame(
            source: .manualRefTrace,
            sport: sport,
            leagueID: nil,
            leagueName: leagueName.trimmingCharacters(in: .whitespacesAndNewlines),
            homeTeamName: homeTeamName.trimmingCharacters(in: .whitespacesAndNewlines),
            homeTeamMascot: homeTeamMascot.trimmingCharacters(in: .whitespacesAndNewlines),
            awayTeamName: awayTeamName.trimmingCharacters(in: .whitespacesAndNewlines),
            awayTeamMascot: awayTeamMascot.trimmingCharacters(in: .whitespacesAndNewlines),
            gameSiteName: gameSiteName.trimmingCharacters(in: .whitespacesAndNewlines),
            gameSiteAddress: gameSiteAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            fieldOrCourt: fieldOrCourt.trimmingCharacters(in: .whitespacesAndNewlines),
            gameDate: gameDate,
            scheduledStartTime: scheduledStartTime,
            reportTime: reportTime,
            assignedOfficialID: RefTraceOfficialProfile.demo.officialID,
            assignedOfficialName: RefTraceOfficialProfile.demo.preferredDisplayName ?? "",
            assignedPosition: assignedPosition,
            otherOfficials: otherOfficials.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            notes: notes,
            status: status
        )
    }
}
