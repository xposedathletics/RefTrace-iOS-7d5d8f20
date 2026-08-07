import Foundation
import Combine

struct UpcomingGameDisplayModel: Identifiable, Hashable {
    var id: String
    var sourceGameID: UUID?
    var sourceAssignmentID: String?
    var transferID: String?
    var source: RefTraceGameSource
    var sport: String
    var leagueName: String
    var homeTeamName: String
    var homeTeamMascot: String
    var awayTeamName: String
    var awayTeamMascot: String
    var gameDate: Date
    var reportTime: Date
    var scheduledStartTime: Date
    var gameSiteName: String
    var fieldOrCourt: String
    var assignedPosition: String
    var assignmentStatus: String
    var gameStatus: RefTraceGameStatus
    var syncStatus: RefTraceSyncState
    var latestSynchronizationDate: Date

    var title: String { sport }

    var teamsDisplay: String {
        let home = Self.teamDisplay(name: homeTeamName, mascot: homeTeamMascot)
        let away = Self.teamDisplay(name: awayTeamName, mascot: awayTeamMascot)
        return "\(home) vs. \(away)"
    }

    var locationDisplay: String {
        fieldOrCourt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? gameSiteName : "\(gameSiteName), \(fieldOrCourt)"
    }

    var isPendingOfficialEaseImport: Bool {
        source == .officialEase && sourceGameID == nil && transferID != nil
    }

    var voiceOverLabel: String {
        "Upcoming \(sport) game. \(teamsDisplay). Report at \(Self.timeFormatter.string(from: reportTime)). Game starts at \(Self.timeFormatter.string(from: scheduledStartTime)) at \(locationDisplay). Assigned as \(assignedPosition). Status \(assignmentStatus)."
    }

    static func teamDisplay(name: String, mascot: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMascot = mascot.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMascot.isEmpty { return trimmedName }
        if trimmedName.isEmpty { return trimmedMascot }
        return "\(trimmedName) \(trimmedMascot)"
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

@MainActor
final class RefTraceHomeViewModel: ObservableObject {
    @Published private(set) var upcomingGames: [UpcomingGameDisplayModel] = []
    @Published private(set) var isLoadingUpcomingGames = false
    @Published private(set) var upcomingGamesError: String?
    @Published private(set) var activeGame: RefTraceGame?
    @Published private(set) var recentGames: [RefTraceGame] = []
    @Published private(set) var syncStatus: RefTraceSyncSummary = .initial

    func loadHomeData(from store: RefTraceGameStore) {
        activeGame = store.activeGame
        recentGames = store.recentGames
        syncStatus = store.syncSummary
        upcomingGames = Self.upcomingGames(from: store)
        upcomingGamesError = store.lastError.map { _ in "Upcoming games could not be refreshed. Showing saved games." }
    }

    func refreshUpcomingGames(from store: RefTraceGameStore) {
        isLoadingUpcomingGames = true
        store.refreshOfficialEaseAssignments()
        loadHomeData(from: store)
        isLoadingUpcomingGames = false
    }

    func processOfficialEaseUpdate(from store: RefTraceGameStore) {
        loadHomeData(from: store)
    }

    func routeToUpcomingGame(_ game: UpcomingGameDisplayModel, router: RefTraceAppRouter) {
        if game.isPendingOfficialEaseImport, let transferID = game.transferID {
            router.go(.importPreview(transferID))
            return
        }

        if let sourceGameID = game.sourceGameID {
            router.go(.gameManagement(sourceGameID))
        }
    }

    static func upcomingGames(from store: RefTraceGameStore, now: Date = Date()) -> [UpcomingGameDisplayModel] {
        let profileID = store.profile?.officialID
        let imported = store.games.compactMap { mapRefTraceGameToUpcomingGameDisplayModel($0, currentOfficialID: profileID, now: now) }
        let pending = store.pendingAssignments.compactMap { mapOfficialEaseAssignmentToUpcomingGameDisplayModel($0, currentOfficialID: profileID, now: now) }
        return sortUpcomingGames(deduplicateGames(imported + pending))
    }

    static func mapOfficialEaseAssignmentToUpcomingGameDisplayModel(_ assignment: OfficialEaseAssignment, currentOfficialID: String?, now: Date = Date()) -> UpcomingGameDisplayModel? {
        guard assignment.assignedOfficialID == currentOfficialID else { return nil }
        guard !assignment.isExpired else { return nil }
        let normalizedStatus = assignment.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !["declined", "expired", "cancelled", "completed"].contains(normalizedStatus) else { return nil }
        guard assignment.game.scheduledStartTime >= now.addingTimeInterval(-4 * 60 * 60) else { return nil }

        return UpcomingGameDisplayModel(
            id: "assignment:\(assignment.assignmentID)",
            sourceGameID: nil,
            sourceAssignmentID: assignment.assignmentID,
            transferID: assignment.transferID,
            source: .officialEase,
            sport: assignment.game.sport.rawValue,
            leagueName: assignment.game.leagueName,
            homeTeamName: assignment.game.homeTeamName,
            homeTeamMascot: assignment.game.homeTeamMascot,
            awayTeamName: assignment.game.awayTeamName,
            awayTeamMascot: assignment.game.awayTeamMascot,
            gameDate: assignment.game.gameDate,
            reportTime: assignment.game.reportTime,
            scheduledStartTime: assignment.game.scheduledStartTime,
            gameSiteName: assignment.game.gameSiteName,
            fieldOrCourt: assignment.game.fieldOrCourt,
            assignedPosition: assignment.game.assignedPosition,
            assignmentStatus: assignment.status,
            gameStatus: assignment.game.status,
            syncStatus: assignment.game.syncStatus,
            latestSynchronizationDate: assignment.game.lastSavedAt
        )
    }

    static func mapRefTraceGameToUpcomingGameDisplayModel(_ game: RefTraceGame, currentOfficialID: String?, now: Date = Date()) -> UpcomingGameDisplayModel? {
        guard game.status != .completed, game.status != .cancelled, game.status != .active else { return nil }
        guard game.scheduledStartTime >= now.addingTimeInterval(-4 * 60 * 60) else { return nil }
        if let officialID = game.assignedOfficialID, let currentOfficialID, officialID != currentOfficialID { return nil }

        return UpcomingGameDisplayModel(
            id: "game:\(game.id.uuidString)",
            sourceGameID: game.id,
            sourceAssignmentID: game.officialEaseAssignmentID,
            transferID: game.transferID,
            source: game.source,
            sport: game.sport.rawValue,
            leagueName: game.leagueName,
            homeTeamName: game.homeTeamName,
            homeTeamMascot: game.homeTeamMascot,
            awayTeamName: game.awayTeamName,
            awayTeamMascot: game.awayTeamMascot,
            gameDate: game.gameDate,
            reportTime: game.reportTime,
            scheduledStartTime: game.scheduledStartTime,
            gameSiteName: game.gameSiteName,
            fieldOrCourt: game.fieldOrCourt,
            assignedPosition: game.assignedPosition,
            assignmentStatus: game.status.rawValue,
            gameStatus: game.status,
            syncStatus: game.syncStatus,
            latestSynchronizationDate: game.lastSavedAt
        )
    }

    static func deduplicateGames(_ games: [UpcomingGameDisplayModel]) -> [UpcomingGameDisplayModel] {
        var bestByKey: [String: UpcomingGameDisplayModel] = [:]
        for game in games {
            let keys = dedupeKeys(for: game)
            let existingKey = keys.first { bestByKey[$0] != nil }
            let selectedKey = existingKey ?? keys[0]
            if let existing = bestByKey[selectedKey] {
                let preferred = preferredGame(existing, game)
                for key in Set(dedupeKeys(for: existing) + dedupeKeys(for: game)) {
                    bestByKey[key] = preferred
                }
            } else {
                for key in keys { bestByKey[key] = game }
            }
        }
        return Array(Set(bestByKey.values))
    }

    static func sortUpcomingGames(_ games: [UpcomingGameDisplayModel]) -> [UpcomingGameDisplayModel] {
        games.sorted {
            if $0.reportTime != $1.reportTime { return $0.reportTime < $1.reportTime }
            if $0.scheduledStartTime != $1.scheduledStartTime { return $0.scheduledStartTime < $1.scheduledStartTime }
            if $0.leagueName != $1.leagueName { return $0.leagueName < $1.leagueName }
            return $0.teamsDisplay < $1.teamsDisplay
        }
    }

    private static func dedupeKeys(for game: UpcomingGameDisplayModel) -> [String] {
        var keys: [String] = []
        if let sourceAssignmentID = game.sourceAssignmentID, !sourceAssignmentID.isEmpty { keys.append("assignment:\(sourceAssignmentID)") }
        if let transferID = game.transferID, !transferID.isEmpty { keys.append("transfer:\(transferID)") }
        if let sourceGameID = game.sourceGameID { keys.append("game:\(sourceGameID.uuidString)") }
        keys.append("composite:\(game.leagueName.lowercased())|\(game.homeTeamName.lowercased())|\(game.awayTeamName.lowercased())|\(game.gameSiteName.lowercased())|\(Int(game.scheduledStartTime.timeIntervalSince1970 / 60))")
        return keys
    }

    private static func preferredGame(_ lhs: UpcomingGameDisplayModel, _ rhs: UpcomingGameDisplayModel) -> UpcomingGameDisplayModel {
        let lhsScore = preferenceScore(lhs)
        let rhsScore = preferenceScore(rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore ? lhs : rhs }
        return lhs.latestSynchronizationDate >= rhs.latestSynchronizationDate ? lhs : rhs
    }

    private static func preferenceScore(_ game: UpcomingGameDisplayModel) -> Int {
        var score = 0
        if game.sourceGameID != nil { score += 20 }
        if game.gameStatus == .imported { score += 15 }
        if game.source == .officialEase { score += 8 }
        if game.syncStatus == .upToDate { score += 4 }
        score += [game.leagueName, game.homeTeamName, game.awayTeamName, game.gameSiteName, game.fieldOrCourt, game.assignedPosition].filter { !$0.isEmpty }.count
        return score
    }
}
