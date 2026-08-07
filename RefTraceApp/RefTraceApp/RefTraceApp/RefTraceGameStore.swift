import Foundation
import Combine

@MainActor
final class RefTraceGameStore: ObservableObject {
    @Published private(set) var games: [RefTraceGame] = []
    @Published private(set) var pendingAssignments: [OfficialEaseAssignment] = []
    @Published var syncSummary: RefTraceSyncSummary = .initial
    @Published var profile: RefTraceOfficialProfile? = .demo
    @Published var lastError: RefTraceUserFacingError?

    private let storeURL: URL

    init(storeURL: URL? = nil, loadSamples: Bool = true) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storeURL = storeURL ?? documents.appendingPathComponent("RefTraceGames.json")
        load()
        if loadSamples, pendingAssignments.isEmpty {
            loadPendingOfficialEaseSample(count: 1)
        }
    }

    var activeGame: RefTraceGame? {
        games.filter(\.isActiveLike).sorted { $0.lastSavedAt > $1.lastSavedAt }.first
    }

    var recentGames: [RefTraceGame] {
        games.sorted { $0.lastSavedAt > $1.lastSavedAt }
    }

    var completedGames: [RefTraceGame] {
        games.filter(\.isCompleted).sorted { $0.gameDate > $1.gameDate }
    }

    var needsAttentionMessage: String? {
        if syncSummary.connectionStatus == .offline { return "RefTrace is offline." }
        if pendingAssignments.count == 1 { return "1 OfficialEase game is ready to import." }
        if pendingAssignments.count > 1 { return "\(pendingAssignments.count) OfficialEase games are ready to import." }
        if syncSummary.pendingOutboundRecords > 0 { return "Game results are waiting to sync." }
        if activeGame != nil { return "An active game can be resumed." }
        if syncSummary.rulesSyncStatus == .pending { return "Rule update available." }
        return nil
    }

    func validate(_ draft: CreateRefTraceGameDraft) -> [RefTraceUserFacingError] {
        var missing: [String] = []
        if draft.leagueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("League") }
        if draft.homeTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Home team") }
        if draft.awayTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Away team") }
        if draft.gameSiteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Game site") }
        if draft.assignedPosition.isEmpty { missing.append("Assigned position") }

        var errors = missing.isEmpty ? [] : [RefTraceUserFacingError.missingRequiredFields(missing.joined(separator: ", "))]
        if !draft.homeTeamName.isEmpty && draft.homeTeamName.caseInsensitiveCompare(draft.awayTeamName) == .orderedSame {
            errors.append(.duplicateGame)
        }
        let game = draft.makeGame()
        if isDuplicate(game) { errors.append(.duplicateGame) }
        if activeGame != nil { errors.append(.anotherGameAlreadyActive) }
        return errors
    }

    func saveDraft(_ draft: CreateRefTraceGameDraft) throws {
        try save(game: draft.makeGame(status: .draft))
    }

    func createGame(from draft: CreateRefTraceGameDraft, openManagement: Bool) throws -> RefTraceGame {
        let errors = validate(draft)
        guard errors.isEmpty else {
            lastError = errors.first
            throw errors.first ?? RefTraceUserFacingError.dataStoreFailure
        }
        var game = draft.makeGame(status: openManagement ? .active : .ready)
        game.source = .manualRefTrace
        try save(game: game)
        return game
    }

    func validateTransfer(_ assignment: OfficialEaseAssignment) -> RefTraceUserFacingError? {
        guard assignment.assignedOfficialID == profile?.officialID else { return .assignmentBelongsToAnotherOfficial }
        guard !assignment.isExpired else { return .transferExpired }
        guard !games.contains(where: { $0.transferID == assignment.transferID }) else { return .duplicateGame }
        guard !isDuplicate(assignment.game) else { return .duplicateGame }
        guard activeGame == nil else { return .anotherGameAlreadyActive }
        return nil
    }

    func importAssignment(_ assignment: OfficialEaseAssignment, openManagement: Bool) throws -> RefTraceGame {
        if let error = validateTransfer(assignment) {
            lastError = error
            throw error
        }
        var game = assignment.game
        game.source = .officialEase
        game.transferID = assignment.transferID
        game.officialEaseAssignmentID = assignment.assignmentID
        game.assignedOfficialID = assignment.assignedOfficialID
        game.assignedOfficialName = assignment.assignedOfficialName
        game.status = openManagement ? .active : .imported
        game.syncStatus = .pending
        game.lastSavedAt = Date()
        try save(game: game)
        pendingAssignments.removeAll { $0.transferID == assignment.transferID }
        syncSummary.pendingInboundAssignments = pendingAssignments.count
        syncSummary.pendingOutboundRecords += 1
        return game
    }

    func assignment(for transferID: String) -> OfficialEaseAssignment? {
        pendingAssignments.first { $0.transferID == transferID }
    }

    func validateTransferCode(_ code: String) -> Result<OfficialEaseAssignment, RefTraceUserFacingError> {
        guard syncSummary.connectionStatus != .offline else { return .failure(.officialEaseUnavailable) }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .failure(.transferInvalid) }
        guard let assignment = pendingAssignments.first(where: { $0.transferID == cleaned || $0.assignmentID == cleaned }) else {
            return .failure(.transferInvalid)
        }
        if let error = validateTransfer(assignment) { return .failure(error) }
        return .success(assignment)
    }

    func refreshOfficialEaseAssignments() {
        guard syncSummary.connectionStatus != .offline else {
            lastError = .officialEaseUnavailable
            return
        }
        syncSummary.connectionStatus = .syncing
        if pendingAssignments.isEmpty { loadPendingOfficialEaseSample(count: 1) }
        syncSummary.connectionStatus = .upToDate
        syncSummary.lastSuccessfulSync = Date()
    }

    func retrySync() {
        guard syncSummary.connectionStatus != .offline else {
            lastError = .syncFailure
            return
        }
        syncSummary.connectionStatus = .syncing
        syncSummary.pendingOutboundRecords = 0
        syncSummary.gameCompletionSyncStatus = .upToDate
        syncSummary.lastSyncError = nil
        syncSummary.lastSuccessfulSync = Date()
        syncSummary.connectionStatus = .upToDate
    }

    func resume(_ game: RefTraceGame) throws -> RefTraceGame {
        var updated = game
        updated.status = .active
        updated.lastSavedAt = Date()
        try save(game: updated)
        return updated
    }

    func complete(_ game: RefTraceGame) throws {
        var updated = game
        updated.status = .completed
        updated.actualEndTime = Date()
        updated.lastSavedAt = Date()
        updated.syncStatus = .pending
        try save(game: updated)
    }

    func resetAllTestData() {
        games.removeAll()
        pendingAssignments.removeAll()
        syncSummary = .initial
        saveQuietly()
    }

    func loadPendingOfficialEaseSample(count: Int) {
        let samples = Self.sampleAssignments().prefix(count)
        pendingAssignments = Array(samples)
        syncSummary.pendingInboundAssignments = pendingAssignments.count
    }

    func loadRecentSamples() {
        games = Self.sampleGames().prefix(5).map { $0 }
        saveQuietly()
    }

    func loadActiveSample() {
        var game = Self.sampleGames()[0]
        game.status = .active
        games = [game]
        saveQuietly()
    }

    func simulateOffline() {
        syncSummary.connectionStatus = .offline
    }

    func simulateSyncFailure() {
        syncSummary.connectionStatus = .failed
        syncSummary.lastSyncError = "OfficialEase could not be reached."
    }

    func simulateExpiredTransfer() {
        loadPendingOfficialEaseSample(count: 1)
        guard var assignment = pendingAssignments.first else { return }
        assignment.expiresAt = Date().addingTimeInterval(-3600)
        pendingAssignments = [assignment]
        syncSummary.pendingInboundAssignments = pendingAssignments.count
    }

    func simulateWrongOfficialTransfer() {
        loadPendingOfficialEaseSample(count: 1)
        guard var assignment = pendingAssignments.first else { return }
        assignment.assignedOfficialID = "another-official"
        assignment.assignedOfficialName = "Another Official"
        pendingAssignments = [assignment]
        syncSummary.pendingInboundAssignments = pendingAssignments.count
    }

    #if DEBUG
    func replaceGamesForTesting(_ replacementGames: [RefTraceGame]) throws {
        games = replacementGames
        saveQuietly()
    }

    func loadNoUpcomingGames() {
        games.removeAll()
        pendingAssignments.removeAll()
        syncSummary.pendingInboundAssignments = 0
        saveQuietly()
    }

    func loadThreeUpcomingGames() {
        games.removeAll()
        pendingAssignments = Array(Self.sampleAssignments().prefix(3))
        syncSummary.pendingInboundAssignments = pendingAssignments.count
        saveQuietly()
    }

    func loadManualUpcomingGame() {
        var game = Self.sampleGames()[1]
        game.id = UUID()
        game.source = .manualRefTrace
        game.status = .ready
        game.scheduledStartTime = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        game.gameDate = game.scheduledStartTime
        game.reportTime = game.scheduledStartTime.addingTimeInterval(-45 * 60)
        games = [game]
        pendingAssignments.removeAll()
        syncSummary.pendingInboundAssignments = 0
        saveQuietly()
    }

    func loadDuplicateUpcomingRecords() {
        guard var assignment = Self.sampleAssignments().first else { return }
        assignment.assignmentID = "OE-DUPLICATE"
        assignment.transferID = "TX-DUPLICATE"
        var imported = assignment.game
        imported.id = UUID()
        imported.source = .officialEase
        imported.status = .imported
        imported.officialEaseAssignmentID = assignment.assignmentID
        imported.transferID = assignment.transferID
        imported.syncStatus = .upToDate
        imported.lastSavedAt = Date().addingTimeInterval(60)
        games = [imported]
        pendingAssignments = [assignment]
        syncSummary.pendingInboundAssignments = 1
        saveQuietly()
    }

    func loadAwaitingResponseUpcoming() {
        loadPendingOfficialEaseSample(count: 1)
        guard var assignment = pendingAssignments.first else { return }
        assignment.status = "Awaiting Response"
        pendingAssignments = [assignment]
        syncSummary.pendingInboundAssignments = 1
    }

    func loadAcceptedUpcoming() {
        loadPendingOfficialEaseSample(count: 1)
        guard var assignment = pendingAssignments.first else { return }
        assignment.status = "Accepted"
        pendingAssignments = [assignment]
        syncSummary.pendingInboundAssignments = 1
    }

    func loadImportedUpcomingGame() {
        guard let assignment = Self.sampleAssignments().first else { return }
        var game = assignment.game
        game.id = UUID()
        game.source = .officialEase
        game.status = .imported
        game.officialEaseAssignmentID = assignment.assignmentID
        game.transferID = assignment.transferID
        games = [game]
        pendingAssignments.removeAll()
        syncSummary.pendingInboundAssignments = 0
        saveQuietly()
    }

    func loadCompletedGameRemovedFromUpcoming() {
        var game = Self.sampleGames()[0]
        game.status = .completed
        games = [game]
        pendingAssignments.removeAll()
        syncSummary.pendingInboundAssignments = 0
        saveQuietly()
    }

    func loadOfflineCachedUpcomingGame() {
        loadManualUpcomingGame()
        syncSummary.connectionStatus = .offline
    }

    func loadMissingMascotUpcoming() {
        var game = Self.sampleGames()[3]
        game.id = UUID()
        game.homeTeamMascot = ""
        game.awayTeamMascot = ""
        game.status = .ready
        game.scheduledStartTime = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        game.gameDate = game.scheduledStartTime
        game.reportTime = game.scheduledStartTime.addingTimeInterval(-45 * 60)
        games = [game]
        pendingAssignments.removeAll()
        syncSummary.pendingInboundAssignments = 0
        saveQuietly()
    }

    func loadLongNameUpcoming() {
        var game = Self.sampleGames()[2]
        game.id = UUID()
        game.leagueName = "Very Long Regional Competitive Travel League"
        game.homeTeamName = "Wesley Chapel Championship Academy"
        game.homeTeamMascot = "Wildcats"
        game.awayTeamName = "Pasco County International"
        game.awayTeamMascot = "Pirates"
        game.status = .ready
        game.scheduledStartTime = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        game.gameDate = game.scheduledStartTime
        game.reportTime = game.scheduledStartTime.addingTimeInterval(-45 * 60)
        games = [game]
        pendingAssignments.removeAll()
        syncSummary.pendingInboundAssignments = 0
        saveQuietly()
    }
    #endif

    private func save(game: RefTraceGame) throws {
        var updated = game
        updated.updatedAt = Date()
        updated.lastSavedAt = Date()
        if let index = games.firstIndex(where: { $0.id == updated.id }) {
            games[index] = updated
        } else {
            games.append(updated)
        }
        do {
            let data = try JSONEncoder.refTrace.encode(games)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            #if DEBUG
            print("RefTrace save failed: \(error)")
            #endif
            lastError = .localSaveFailure
            throw RefTraceUserFacingError.localSaveFailure
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            games = try JSONDecoder.refTrace.decode([RefTraceGame].self, from: data)
        } catch {
            #if DEBUG
            print("RefTrace load failed: \(error)")
            #endif
            lastError = .dataStoreFailure
        }
    }

    private func saveQuietly() {
        do {
            let data = try JSONEncoder.refTrace.encode(games)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            #if DEBUG
            print("RefTrace quiet save failed: \(error)")
            #endif
        }
    }

    private func isDuplicate(_ game: RefTraceGame) -> Bool {
        games.contains { existing in
            existing.isActiveLike &&
            existing.homeTeamName.caseInsensitiveCompare(game.homeTeamName) == .orderedSame &&
            existing.awayTeamName.caseInsensitiveCompare(game.awayTeamName) == .orderedSame &&
            existing.gameSiteName.caseInsensitiveCompare(game.gameSiteName) == .orderedSame &&
            abs(existing.scheduledStartTime.timeIntervalSince(game.scheduledStartTime)) < 60
        }
    }

    static func sampleGames() -> [RefTraceGame] {
        let now = Date()
        return RefTraceSport.allCases.enumerated().map { index, sport in
            RefTraceGame(
                source: index.isMultiple(of: 2) ? .manualRefTrace : .officialEase,
                sport: sport,
                leagueID: "league-\(index)",
                leagueName: ["Varsity", "JV", "Club", "Youth"][index],
                homeTeamName: ["North", "East", "Central", "Metro"][index],
                homeTeamMascot: ["Tigers", "Rockets", "Knights", "Lions"][index],
                awayTeamName: ["South", "West", "River", "County"][index],
                awayTeamMascot: ["Hawks", "Storm", "Bears", "Eagles"][index],
                gameSiteName: ["Memorial Stadium", "City Sports Park", "Civic Field", "Lakeside Complex"][index],
                gameSiteAddress: "100 Main Street",
                fieldOrCourt: ["Field 1", "Field 4", "Pitch A", "Turf 2"][index],
                gameDate: now.addingTimeInterval(Double(index) * -86400),
                scheduledStartTime: now.addingTimeInterval(Double(index + 2) * 3600),
                reportTime: now.addingTimeInterval(Double(index + 2) * 3600 - 2700),
                assignedOfficialID: RefTraceOfficialProfile.demo.officialID,
                assignedOfficialName: "Harvey",
                assignedPosition: sport.positions.first ?? "Official",
                status: index == 0 ? .active : .completed,
                homeScore: index * 7,
                awayScore: index * 5,
                currentPeriod: index == 0 ? "1st Quarter" : "Final",
                gameClockStatus: index == 0 ? "Running" : "Final",
                ruleDocumentID: "rules-\(sport.rawValue)",
                ruleVersion: "2026.1"
            )
        }
    }

    static func sampleAssignments() -> [OfficialEaseAssignment] {
        sampleGames().enumerated().map { index, game in
            var importedGame = game
            importedGame.id = UUID()
            importedGame.source = .officialEase
            importedGame.status = .imported
            importedGame.transferID = "TX-2026-00\(index + 1)"
            return OfficialEaseAssignment(
                transferID: "TX-2026-00\(index + 1)",
                assignmentID: "OE-A-00\(index + 1)",
                assignedOfficialID: RefTraceOfficialProfile.demo.officialID,
                assignedOfficialName: "Harvey",
                status: "Assigned",
                expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                game: importedGame
            )
        }
    }
}

private extension JSONEncoder {
    static var refTrace: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var refTrace: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
