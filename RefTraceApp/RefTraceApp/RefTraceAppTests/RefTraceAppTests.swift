import Foundation
import SwiftUI
import Testing
@testable import RefTraceApp

@MainActor
struct RefTraceAppTests {
    @Test func normalLaunchStartsAtHome() async throws {
        let router = RefTraceAppRouter()
        #expect(router.path.isEmpty)
    }

    @Test func deepLinkRoutesToImportPreview() async throws {
        let router = RefTraceAppRouter()
        router.handleIncomingURL(URL(string: "reftrace://game/start?transferID=TX-123")!)
        #expect(router.pendingDeepLinkTransferID == "TX-123")
        #expect(RefTraceAppRouter.transferID(from: URL(string: "https://reftrace.com/game/start?transferID=TX-456")!) == "TX-456")
    }

    @Test func manualGameValidationRequiresFields() async throws {
        let store = makeStore()
        let errors = store.validate(CreateRefTraceGameDraft())
        #expect(!errors.isEmpty)
    }

    @Test func reportTimeIsFortyFiveMinutesBeforeStart() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CreateRefTraceGameDraft.defaultReportTime(for: start) == start.addingTimeInterval(-45 * 60))
    }

    @Test func duplicateGameDetectionRejectsSameActiveGame() async throws {
        let store = makeStore()
        var draft = completeDraft()
        _ = try store.createGame(from: draft, openManagement: true)
        draft.notes = "Duplicate"
        #expect(store.validate(draft).contains(.duplicateGame))
    }

    @Test func activeGameRestrictionRejectsSecondActiveGame() async throws {
        let store = makeStore()
        _ = try store.createGame(from: completeDraft(), openManagement: true)
        var second = completeDraft()
        second.homeTeamName = "East"
        second.awayTeamName = "West"
        #expect(store.validate(second).contains(.anotherGameAlreadyActive))
    }

    @Test func validOfficialEaseImportAssignsSource() async throws {
        let store = makeStore()
        store.loadPendingOfficialEaseSample(count: 1)
        let assignment = try #require(store.pendingAssignments.first)
        let game = try store.importAssignment(assignment, openManagement: false)
        #expect(game.source == .officialEase)
        #expect(game.transferID == assignment.transferID)
        #expect(store.pendingAssignments.isEmpty)
    }

    @Test func expiredTransferIsRejected() async throws {
        let store = makeStore()
        store.simulateExpiredTransfer()
        let assignment = try #require(store.pendingAssignments.first)
        #expect(store.validateTransfer(assignment) == .transferExpired)
    }

    @Test func wrongOfficialTransferIsRejected() async throws {
        let store = makeStore()
        store.simulateWrongOfficialTransfer()
        let assignment = try #require(store.pendingAssignments.first)
        #expect(store.validateTransfer(assignment) == .assignmentBelongsToAnotherOfficial)
    }

    @Test func duplicateTransferIsRejected() async throws {
        let store = makeStore()
        store.loadPendingOfficialEaseSample(count: 1)
        let assignment = try #require(store.pendingAssignments.first)
        _ = try store.importAssignment(assignment, openManagement: false)
        var duplicate = assignment
        duplicate.game.id = UUID()
        #expect(store.validateTransfer(duplicate) == .duplicateGame)
    }

    @Test func recentGamesAreNewestFirst() async throws {
        let store = makeStore()
        store.loadRecentSamples()
        let dates = store.recentGames.map(\.lastSavedAt)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func activeGameRestorationFindsActiveGame() async throws {
        let store = makeStore()
        store.loadActiveSample()
        #expect(store.activeGame?.status == .active)
    }

    @Test func syncStatusDisplayLogicReportsOffline() async throws {
        let store = makeStore()
        store.simulateOffline()
        #expect(store.needsAttentionMessage == "RefTrace is offline.")
    }

    @Test func officialEaseGameMapsToDisplayModel() async throws {
        let store = makeStore()
        store.loadPendingOfficialEaseSample(count: 1)
        let assignment = try #require(store.pendingAssignments.first)
        let model = try #require(RefTraceHomeViewModel.mapOfficialEaseAssignmentToUpcomingGameDisplayModel(assignment, currentOfficialID: store.profile?.officialID, now: Date().addingTimeInterval(-60)))
        #expect(model.source == .officialEase)
        #expect(model.transferID == assignment.transferID)
        #expect(model.teamsDisplay.contains("vs."))
    }

    @Test func manualRefTraceGameMapsCorrectly() async throws {
        let game = upcomingGame(status: .ready, source: .manualRefTrace)
        let model = try #require(RefTraceHomeViewModel.mapRefTraceGameToUpcomingGameDisplayModel(game, currentOfficialID: RefTraceOfficialProfile.demo.officialID, now: Date()))
        #expect(model.source == .manualRefTrace)
        #expect(model.sourceGameID == game.id)
        #expect(model.assignmentStatus == RefTraceGameStatus.ready.rawValue)
    }

    @Test func gamesBelongingToAnotherOfficialAreExcluded() async throws {
        var game = upcomingGame(status: .ready)
        game.assignedOfficialID = "other-official"
        #expect(RefTraceHomeViewModel.mapRefTraceGameToUpcomingGameDisplayModel(game, currentOfficialID: RefTraceOfficialProfile.demo.officialID) == nil)
    }

    @Test func completedAndCancelledGamesAreExcluded() async throws {
        #expect(RefTraceHomeViewModel.mapRefTraceGameToUpcomingGameDisplayModel(upcomingGame(status: .completed), currentOfficialID: RefTraceOfficialProfile.demo.officialID) == nil)
        #expect(RefTraceHomeViewModel.mapRefTraceGameToUpcomingGameDisplayModel(upcomingGame(status: .cancelled), currentOfficialID: RefTraceOfficialProfile.demo.officialID) == nil)
    }

    @Test func expiredTransfersAreExcluded() async throws {
        let store = makeStore()
        store.simulateExpiredTransfer()
        let assignment = try #require(store.pendingAssignments.first)
        #expect(RefTraceHomeViewModel.mapOfficialEaseAssignmentToUpcomingGameDisplayModel(assignment, currentOfficialID: store.profile?.officialID) == nil)
    }

    @Test func earliestReportTimeSortsFirst() async throws {
        var later = displayModel(id: "later", reportOffset: 600)
        later.leagueName = "A"
        let earlier = displayModel(id: "earlier", reportOffset: 0)
        let sorted = RefTraceHomeViewModel.sortUpcomingGames([later, earlier])
        #expect(sorted.first?.id == "earlier")
    }

    @Test func duplicateAssignmentIDsAreCollapsed() async throws {
        var first = displayModel(id: "first")
        var second = displayModel(id: "second")
        first.sourceAssignmentID = "A-1"
        second.sourceAssignmentID = "A-1"
        #expect(RefTraceHomeViewModel.deduplicateGames([first, second]).count == 1)
    }

    @Test func duplicateTransferIDsAreCollapsed() async throws {
        var first = displayModel(id: "first")
        var second = displayModel(id: "second")
        first.transferID = "TX-1"
        second.transferID = "TX-1"
        #expect(RefTraceHomeViewModel.deduplicateGames([first, second]).count == 1)
    }

    @Test func compositeDuplicatesAreCollapsed() async throws {
        let first = displayModel(id: "first")
        let second = displayModel(id: "second")
        #expect(RefTraceHomeViewModel.deduplicateGames([first, second]).count == 1)
    }

    @Test func importedRecordPreferredOverPendingDuplicate() async throws {
        var pending = displayModel(id: "pending")
        pending.sourceGameID = nil
        pending.source = .officialEase
        pending.sourceAssignmentID = "A-1"
        pending.transferID = "TX-1"
        var imported = pending
        imported.id = "imported"
        imported.sourceGameID = UUID()
        imported.gameStatus = .imported
        imported.latestSynchronizationDate = Date().addingTimeInterval(60)
        let deduped = RefTraceHomeViewModel.deduplicateGames([pending, imported])
        #expect(deduped.count == 1)
        #expect(deduped.first?.id == "imported")
    }

    @Test func activeGamesAreExcludedFromUpcomingPolicy() async throws {
        #expect(RefTraceHomeViewModel.mapRefTraceGameToUpcomingGameDisplayModel(upcomingGame(status: .active), currentOfficialID: RefTraceOfficialProfile.demo.officialID) == nil)
    }

    @Test func missingMascotDoesNotBreakDisplay() async throws {
        #expect(UpcomingGameDisplayModel.teamDisplay(name: "Riverbend", mascot: "") == "Riverbend")
    }

    @Test func emptyStateIsTriggeredWhenNoUpcomingGames() async throws {
        let store = makeStore()
        let models = RefTraceHomeViewModel.upcomingGames(from: store)
        #expect(models.isEmpty)
    }

    @Test func cachedGamesRemainAfterRefreshFailure() async throws {
        let store = makeStore()
        store.loadOfflineCachedUpcomingGame()
        let before = RefTraceHomeViewModel.upcomingGames(from: store)
        store.refreshOfficialEaseAssignments()
        let after = RefTraceHomeViewModel.upcomingGames(from: store)
        #expect(!before.isEmpty)
        #expect(after == before)
    }

    @Test func homeRefreshUpdatesUpcomingList() async throws {
        let store = makeStore()
        let viewModel = RefTraceHomeViewModel()
        viewModel.loadHomeData(from: store)
        #expect(viewModel.upcomingGames.isEmpty)
        store.loadPendingOfficialEaseSample(count: 1)
        viewModel.refreshUpcomingGames(from: store)
        #expect(viewModel.upcomingGames.count == 1)
    }

    @Test func communicationSessionCreatesWithOneHeadOfficial() async throws {
        let store = CommunicationStore()
        let game = upcomingGame(status: .active)
        let session = try store.createSession(game: game, profile: .demo, draft: CommunicationSessionSetupDraft())
        #expect(store.participants(for: session.id).filter(\.isHeadOfficial).count == 1)
    }

    @Test func communicationSessionMaximumSixParticipants() async throws {
        let store = CommunicationStore()
        let game = upcomingGame(status: .active)
        let session = try store.createSession(game: game, profile: .demo, draft: CommunicationSessionSetupDraft())
        store.setAllConnected(sessionID: session.id)
        for index in 0..<3 {
            let participant = testParticipant(sessionID: session.id, first: "Extra", last: "\(index)")
            try? store.addParticipant(participant)
        }
        #expect(store.participants(for: session.id).count <= 6)
        #expect(throws: CommunicationError.sessionAtCapacity) {
            try store.addParticipant(testParticipant(sessionID: session.id, first: "Seventh", last: "Device"))
        }
    }

    @Test func headOfficialRoleIdentification() async throws {
        let service = RefTraceCommunicationPermissionService()
        #expect(service.isHeadOfficial(position: "Head Referee"))
        #expect(service.isHeadOfficial(position: "Center Referee"))
        #expect(!service.isHeadOfficial(position: "Line Judge"))
    }

    @Test func invalidParticipantJoinRejected() async throws {
        let store = CommunicationStore()
        var game = upcomingGame(status: .active)
        let session = try store.createSession(game: game, profile: .demo, draft: CommunicationSessionSetupDraft())
        game.assignedOfficialID = "official-harvey"
        let otherProfile = RefTraceOfficialProfile(officialID: "unknown", preferredDisplayName: "Unknown")
        #expect(throws: CommunicationError.notAssignedToGame) {
            try store.join(sessionCode: session.sessionCode, game: game, profile: otherProfile)
        }
    }

    @Test func invalidSessionCodeRejected() async throws {
        let store = CommunicationStore()
        #expect(throws: CommunicationError.invalidSessionCode) {
            try store.join(sessionCode: "BAD", game: upcomingGame(status: .active), profile: .demo)
        }
    }

    @Test func recipientResolutionMatchesNamesAndPosition() async throws {
        let resolver = VoiceRecipientResolver()
        let sessionID = UUID()
        let jamesWatson = testParticipant(sessionID: sessionID, first: "James", last: "Watson", position: "Line Judge")
        let morganLee = testParticipant(sessionID: sessionID, first: "Morgan", last: "Lee", position: "Back Judge")
        #expect(resolver.resolve("Morgan", participants: [jamesWatson, morganLee]) == .participant(morganLee))
        #expect(resolver.resolve("Watson", participants: [jamesWatson, morganLee]) == .participant(jamesWatson))
        #expect(resolver.resolve("Morgan Lee", participants: [jamesWatson, morganLee]) == .participant(morganLee))
        #expect(resolver.resolve("Line Judge", participants: [jamesWatson, morganLee]) == .participant(jamesWatson))
    }

    @Test func ambiguousRecipientIsRejected() async throws {
        let resolver = VoiceRecipientResolver()
        let sessionID = UUID()
        let first = testParticipant(sessionID: sessionID, first: "James", last: "Watson")
        let second = testParticipant(sessionID: sessionID, first: "James", last: "Carter")
        if case .ambiguous(let matches) = resolver.resolve("James", participants: [first, second]) {
            #expect(matches.count == 2)
        } else {
            Issue.record("Expected ambiguous recipient")
        }
    }

    @Test func entireCrewAndPrivateRouting() async throws {
        let store = CommunicationStore()
        let session = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: CommunicationSessionSetupDraft())
        store.selectEntireCrew(sessionID: session.id)
        #expect(store.selectedRecipient?.type == .entireCrew)
        let participant = try #require(store.participants(for: session.id).first(where: { !$0.isHeadOfficial }))
        store.selectParticipant(participant)
        #expect(store.selectedRecipient?.type == .individual)
    }

    @Test func communicationPreferenceModesPersist() async throws {
        var draft = CommunicationSessionSetupDraft()
        draft.preferredCommunicationMode = .text
        let store = CommunicationStore()
        let session = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: draft)
        #expect(session.preferredCommunicationMode == .text)
        draft.preferredCommunicationMode = .voice
        let second = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: draft)
        #expect(second.preferredCommunicationMode == .voice)
    }

    @Test func textDeliveryAcknowledgmentAndDuplicatePrevention() async throws {
        let store = CommunicationStore()
        let session = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: CommunicationSessionSetupDraft())
        let first = try store.sendText(sessionID: session.id, body: "Ready", acknowledgmentRequired: true)
        let duplicate = try store.sendText(sessionID: session.id, body: "Ready", acknowledgmentRequired: true)
        #expect(first.id == duplicate.id)
        #expect(first.deliveryStatus == .delivered)
        store.acknowledge(messageID: first.id, status: .acknowledged)
        #expect(store.messages(for: session.id).first?.acknowledgmentStatus == .acknowledged)
    }

    @Test func sequenceOrderingAndOfflineQueueing() async throws {
        let store = CommunicationStore()
        let session = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: CommunicationSessionSetupDraft())
        _ = try store.sendText(sessionID: session.id, body: "First")
        _ = try store.sendText(sessionID: session.id, body: "Second", offline: true)
        let messages = store.messages(for: session.id)
        #expect(messages.map(\.sequenceNumber) == messages.map(\.sequenceNumber).sorted())
        #expect(messages.last?.deliveryStatus == .queued)
        store.flushQueuedMessages(sessionID: session.id)
        #expect(store.messages(for: session.id).last?.deliveryStatus == .delivered)
    }

    @Test func reconnectionSessionLockHeadTransferAndEnding() async throws {
        let store = CommunicationStore()
        let session = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: CommunicationSessionSetupDraft())
        store.simulateDisconnectedParticipant(sessionID: session.id)
        store.simulateReconnection(sessionID: session.id)
        #expect(store.participants(for: session.id).allSatisfy { $0.connectionStatus != .disconnected })
        store.lockSession(sessionID: session.id)
        #expect(store.activeSession(for: session.gameID)?.status == .locked)
        let participant = try #require(store.participants(for: session.id).first(where: { !$0.isHeadOfficial }))
        store.transferHeadOfficial(to: participant.id, sessionID: session.id)
        #expect(store.activeSession(for: session.gameID)?.headOfficialID == participant.officialID)
        store.endSession(sessionID: session.id)
        #expect(store.sessions.first?.status == .ended)
    }

    @Test func metadataLogCreatedAndNoRawAudioStored() async throws {
        let store = CommunicationStore()
        let session = try store.createSession(game: upcomingGame(status: .active), profile: .demo, draft: CommunicationSessionSetupDraft())
        let transmission = try store.beginVoiceTransmission(sessionID: session.id)
        store.endVoiceTransmission(transmission.id)
        #expect(!store.logs(for: session.id).isEmpty)
        #expect(store.voiceTransmissions.first?.transcriptAvailable == false)
    }

    @Test func expiredSessionRejectsVoiceAndJoin() async throws {
        let store = CommunicationStore()
        let game = upcomingGame(status: .active)
        let session = try store.createSession(game: game, profile: .demo, draft: CommunicationSessionSetupDraft())
        store.endSession(sessionID: session.id)
        #expect(throws: CommunicationError.sessionEnded) {
            _ = try store.beginVoiceTransmission(sessionID: session.id)
        }
        #expect(throws: CommunicationError.sessionEnded) {
            try store.join(sessionCode: session.sessionCode, game: game, profile: .demo)
        }
    }

    @Test func speechPermissionDenialErrorExists() async throws {
        #expect(CommunicationError.speechPermissionDenied.localizedDescription.contains("Speech recognition"))
        #expect(CommunicationError.microphonePermissionDenied.localizedDescription.contains("Microphone"))
    }

    private func makeStore() -> RefTraceGameStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RefTraceTests-\(UUID().uuidString).json")
        return RefTraceGameStore(storeURL: url, loadSamples: false)
    }

    private func makeInGameStore() -> RefTraceInGameStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RefTraceInGameTests-\(UUID().uuidString).json")
        return RefTraceInGameStore(storageURL: url)
    }

    @Test func gameClockStartAndStopUsesTimestampState() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        store.startGameClock(for: game, profile: .demo)
        #expect(store.reconciledState(for: game).gameClock.isRunning)
        store.stopGameClock(for: game, profile: .demo)
        #expect(!store.reconciledState(for: game).gameClock.isRunning)
    }

    @Test func backgroundClockReconciliationReducesRemainingTime() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var clock = GameClockState(duration: 60, remainingTime: 60, isRunning: true, referenceStartTimestamp: start, lastSynchronizedTimestamp: start, currentPeriod: "Q1", stateVersion: 1, showTenthsUnderOneMinute: false)
        clock = clock.reconciled(now: start.addingTimeInterval(10))
        #expect(clock.remainingTime == 50)
    }

    @Test func playClockOperatesIndependentlyFromGameClock() async throws {
        var game = upcomingGame(status: .active)
        game.sport = .football
        let store = makeInGameStore()
        store.startPlayClock(for: game, profile: .demo)
        let state = store.reconciledState(for: game)
        #expect(state.playClock?.isRunning == true)
        #expect(state.gameClock.isRunning == false)
    }

    @Test func footballScoreCalculationLogsEvent() async throws {
        var game = upcomingGame(status: .active)
        game.sport = .football
        let store = makeInGameStore()
        _ = try store.addScore(to: .home, scoreType: .touchdown(points: 6), game: game, profile: .demo)
        #expect(store.reconciledState(for: game).homeScore == 6)
        #expect(store.scoreEvents[game.id, default: []].count == 1)
        #expect(store.gameEvents[game.id, default: []].contains { $0.eventType == .scoreAdded })
    }

    @Test func soccerAndLacrosseScoreCalculation() async throws {
        let store = makeInGameStore()
        var soccer = upcomingGame(status: .active)
        soccer.id = UUID()
        soccer.sport = .soccer
        _ = try store.addScore(to: .away, scoreType: .goal(points: 1), game: soccer, profile: .demo)
        #expect(store.reconciledState(for: soccer).awayScore == 1)
        var lacrosse = upcomingGame(status: .active)
        lacrosse.id = UUID()
        lacrosse.sport = .lacrosse
        _ = try store.addScore(to: .home, scoreType: .goal(points: 1), game: lacrosse, profile: .demo)
        #expect(store.reconciledState(for: lacrosse).homeScore == 1)
    }

    @Test func duplicateScoreEventIsPrevented() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        _ = try store.addScore(to: .home, scoreType: .fieldGoal(points: 3), game: game, profile: .demo)
        #expect(throws: RefTraceInGameError.duplicateEvent) {
            _ = try store.addScore(to: .home, scoreType: .fieldGoal(points: 3), game: game, profile: .demo)
        }
    }

    @Test func scoreReversalCreatesLinkedAppendOnlyRecord() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        let event = try store.addScore(to: .home, scoreType: .fieldGoal(points: 3), game: game, profile: .demo)
        let reversal = try store.reverseScore(event, game: game, profile: .demo, reason: "Wrong team")
        #expect(reversal.relatedScoreEventID == event.id)
        #expect(store.scoreEvents[game.id, default: []].count == 2)
        #expect(store.reconciledState(for: game).homeScore == 0)
    }

    @Test func timeoutDecrementAndLowerBoundProtection() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        _ = try store.recordTimeout(.homeTeam, game: game, profile: .demo)
        #expect(store.reconciledState(for: game).homeTimeouts == 2)
        _ = try store.recordTimeout(.homeTeam, game: game, profile: .demo)
        _ = try store.recordTimeout(.homeTeam, game: game, profile: .demo)
        #expect(throws: RefTraceInGameError.timeoutUnavailable) {
            _ = try store.recordTimeout(.homeTeam, game: game, profile: .demo)
        }
    }

    @Test func possessionOnlyAppliesToFootballAndFlagFootball() async throws {
        var football = upcomingGame(status: .active)
        football.sport = .football
        let store = makeInGameStore()
        try store.changePossession(to: .home, game: football, profile: .demo)
        #expect(store.reconciledState(for: football).possession == .home)
        var soccer = upcomingGame(status: .active)
        soccer.id = UUID()
        soccer.sport = .soccer
        #expect(throws: RefTraceInGameError.possessionNotAvailable) {
            try store.changePossession(to: .home, game: soccer, profile: .demo)
        }
    }

    @Test func footballCrewPositionValidation() async throws {
        var game = upcomingGame(status: .active)
        game.sport = .football
        game.otherOfficials = ["Umpire", "Linesman", "Head Linesman"]
        #expect(SportGameConfiguration.configuration(for: game, crewCount: 4).allowedOfficialPositions.contains(.backJudge) == false)
        #expect(SportGameConfiguration.configuration(for: game, crewCount: 5).allowedOfficialPositions.contains(.backJudge))
    }

    @Test func flagFootballPositionValidation() async throws {
        var game = upcomingGame(status: .active)
        game.sport = .flagFootball
        let positions = SportGameConfiguration.configuration(for: game).allowedOfficialPositions
        #expect(positions == [.headReferee, .backJudge])
    }

    @Test func eventSequenceOrderingIsMonotonic() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        store.startGameClock(for: game, profile: .demo)
        store.stopGameClock(for: game, profile: .demo)
        let sequences = store.gameEvents[game.id, default: []].map(\.sequenceNumber)
        #expect(sequences == sequences.sorted())
    }

    @Test func unsupportedAIResponseDoesNotFabricateAnswer() async throws {
        var game = upcomingGame(status: .active)
        game.ruleDocumentID = nil
        game.ruleVersion = nil
        let store = makeInGameStore()
        let response = store.answerRulesQuestion("Invent a foul", game: game, profile: .demo)
        #expect(response.confidenceStatus == .unsupported)
        #expect(response.explanation == "I could not confirm this enforcement from the approved rule set.")
    }

    @Test func watchPayloadSerializesScoreLogAndRejectsStaleUpdate() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        _ = try store.addScore(to: .home, scoreType: .touchdown(points: 6), game: game, profile: .demo)
        let payload = store.watchPayload(for: game)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(RefTraceWatchGameState.self, from: data)
        #expect(decoded.scoreLog.count == 1)
        let manager = RefTraceWatchConnectivityManager()
        manager.update(gameState: payload)
        var stale = payload
        stale.syncVersion = payload.syncVersion - 1
        #expect(!manager.shouldAccept(stale))
    }

    @Test func completedGameStatePersistsFinalStatus() async throws {
        let game = upcomingGame(status: .active)
        let store = makeInGameStore()
        store.completeGame(game, profile: .demo)
        #expect(store.reconciledState(for: game).status == .completed)
        #expect(store.gameEvents[game.id, default: []].contains { $0.eventType == .gameCompleted })
    }

    @Test func viewerDeepLinkRoutesToAccessPreview() async throws {
        let router = RefTraceAppRouter()
        router.handleIncomingURL(URL(string: "reftrace://view-game?token=VIEW-1234")!)
        #expect(router.pendingViewerToken == "VIEW-1234")
        #expect(RefTraceAppRouter.viewerToken(from: URL(string: "https://reftrace.com/view-game/VIEW-5678")!) == "VIEW-5678")
        #expect(RefTraceAppRouter.transferID(from: URL(string: "reftrace://game/start?transferID=TX-123")!) == "TX-123")
    }

    @Test func spectatorStateMappingExcludesOfficialIdentity() async throws {
        let game = upcomingGame(status: .active)
        let state = RefTraceInGameStore().displayState(for: game)
        let spectatorState = SpectatorGameState.from(game: game, state: state)
        let encoded = String(data: try JSONEncoder().encode(spectatorState), encoding: .utf8) ?? ""
        #expect(!encoded.contains(game.assignedOfficialName))
        #expect(!(game.assignedOfficialID.map { encoded.contains($0) } ?? false))
        #expect(!encoded.contains("assignment"))
    }

    @Test func spectatorClockRendersFromAuthoritativeState() async throws {
        let reference = Date(timeIntervalSince1970: 1_000)
        var state = spectatorState(sport: .football)
        state.gameClockRemaining = 120
        state.gameClockIsRunning = true
        state.clockReferenceTimestamp = reference
        state.lastUpdatedAt = reference
        let clock = SpectatorClockDisplayService(safeStaleInterval: 45)
        #expect(clock.displayText(for: state, now: reference.addingTimeInterval(15)) == "01:45")
        #expect(clock.displayText(for: state, now: reference.addingTimeInterval(50)) == "02:00")
        #expect(clock.dataStatus(for: state, now: reference.addingTimeInterval(50)) == .unavailable)
    }

    @Test func staleSpectatorClockUpdateIsRejected() async throws {
        var current = spectatorState(sport: .football)
        current.stateVersion = 4
        var stale = current
        stale.stateVersion = 3
        let clock = SpectatorClockDisplayService()
        #expect(!clock.shouldAccept(current: current, incoming: stale))
    }

    @Test func spectatorPossessionVisibilityFollowsSport() async throws {
        #expect(spectatorState(sport: .football).possessionVisible)
        #expect(spectatorState(sport: .flagFootball).possessionVisible)
        #expect(!spectatorState(sport: .soccer).possessionVisible)
        #expect(!spectatorState(sport: .lacrosse).possessionVisible)
    }

    @Test func viewerCodeFailuresAreRejected() async throws {
        let store = makeStore()
        store.loadActiveSample()
        let inGameStore = RefTraceInGameStore()
        let service = LocalSpectatorGameStateService(gameStore: store, inGameStore: inGameStore)
        await #expect(throws: SpectatorPortalError.invalidCode) {
            _ = try await service.validate(codeOrToken: "INVALID", role: .observer)
        }
        let reference = SpectatorGameState.publicReference(for: try #require(store.games.first))
        let expired = service.generateViewerCode(publicGameReference: reference, expiresAt: Date().addingTimeInterval(-60))
        await #expect(throws: SpectatorPortalError.expiredCode) {
            _ = try await service.validate(codeOrToken: expired, role: .observer)
        }
        let revoked = service.generateViewerCode(publicGameReference: reference)
        service.revokeViewerCode(revoked)
        await #expect(throws: SpectatorPortalError.revokedCode) {
            _ = try await service.validate(codeOrToken: revoked, role: .observer)
        }
    }

    @Test func spectatorAccessLogIsCreated() async throws {
        let store = makeStore()
        store.loadActiveSample()
        let inGameStore = RefTraceInGameStore()
        let service = LocalSpectatorGameStateService(gameStore: store, inGameStore: inGameStore)
        let reference = SpectatorGameState.publicReference(for: try #require(store.games.first))
        _ = try await service.validateAccess(SpectatorViewerAPI.ValidateAccessRequest(tokenOrCode: reference, role: .coach, accessMethod: .authenticatedRefTrace))
        let logs = await service.logs(publicGameReference: reference)
        #expect(logs.count == 1)
        #expect(logs.first?.viewerRole == .coach)
        #expect(logs.first?.accessResult == .allowed)
    }

    @Test func finalSpectatorGameStopsClockDisplay() async throws {
        var state = spectatorState(sport: .football)
        state.gameClockRemaining = 33
        state.gameClockIsRunning = true
        state.clockReferenceTimestamp = Date(timeIntervalSince1970: 1_000)
        state.lastUpdatedAt = Date(timeIntervalSince1970: 1_000)
        state.gameStatus = .completed
        state.dataStatus = .final
        state.isFinal = true
        let clock = SpectatorClockDisplayService()
        #expect(clock.displayText(for: state, now: Date(timeIntervalSince1970: 1_020)) == "00:33")
        #expect(clock.dataStatus(for: state, now: Date(timeIntervalSince1970: 1_020)) == .final)
    }

    @Test func footballStartGameArmsOpeningWhistleWithoutStartingClock() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-arm.json"))
        let game = upcomingGame(status: .active)
        try store.startFootballGamePreparation(for: game, profile: .demo)
        #expect(store.displayState(for: game).gameClock.isRunning == false)
        #expect(store.footballState(for: game).initialWhistleStartArmed == true)
        #expect(store.footballState(for: game).gameClockState == .armedForOpeningWhistle)
    }

    @Test func headRefOpeningWhistleStartsGameClock() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-opening.json"))
        let game = upcomingGame(status: .active)
        try store.startFootballGamePreparation(for: game, profile: .demo)
        _ = try store.processFootballWhistle(footballWhistle(game: game, officialID: RefTraceOfficialProfile.demo.officialID, position: .headReferee), game: game, profile: .demo)
        #expect(store.displayState(for: game).gameClock.isRunning)
        #expect(store.footballState(for: game).initialWhistleStartArmed == false)
    }

    @Test func otherOfficialPreStartWhistleDoesNotStartClock() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-wrong-opening.json"))
        let game = upcomingGame(status: .active)
        try store.startFootballGamePreparation(for: game, profile: .demo)
        let processed = try store.processFootballWhistle(footballWhistle(game: game, officialID: "line-judge", position: .linesman), game: game, profile: .demo)
        #expect(processed.triggeredAction == .ignoredWrongAuthority)
        #expect(store.displayState(for: game).gameClock.isRunning == false)
    }

    @Test func crewWhistleStartsTwentyFiveSecondPlayClockWithoutStoppingGameClock() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-crew-whistle.json"))
        let game = upcomingGame(status: .active)
        try store.startFootballGamePreparation(for: game, profile: .demo)
        _ = try store.processFootballWhistle(footballWhistle(game: game, officialID: RefTraceOfficialProfile.demo.officialID, position: .headReferee), game: game, profile: .demo)
        _ = try store.processFootballWhistle(footballWhistle(game: game, officialID: "line-judge", position: .linesman, detectedAt: Date().addingTimeInterval(2)), game: game, profile: .demo)
        let state = store.displayState(for: game)
        #expect(state.gameClock.isRunning)
        #expect(state.playClock?.isRunning == true)
        #expect(Int(state.playClock?.duration ?? 0) == 25)
    }

    @Test func duplicateCrewWhistleDoesNotRestartPlayClockRepeatedly() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-duplicate-whistle.json"))
        let game = upcomingGame(status: .active)
        try store.startFootballGamePreparation(for: game, profile: .demo)
        let start = Date()
        _ = try store.processFootballWhistle(footballWhistle(game: game, officialID: RefTraceOfficialProfile.demo.officialID, position: .headReferee, detectedAt: start), game: game, profile: .demo)
        _ = try store.processFootballWhistle(footballWhistle(game: game, officialID: "line-judge", position: .linesman, detectedAt: start.addingTimeInterval(2)), game: game, profile: .demo)
        _ = try store.processFootballWhistle(footballWhistle(game: game, officialID: "umpire", position: .umpire, detectedAt: start.addingTimeInterval(2.2)), game: game, profile: .demo)
        #expect(store.endOfPlayEvents[game.id, default: []].count == 1)
        #expect(store.whistleEvents[game.id, default: []].contains { $0.triggeredAction == .ignoredDuplicate })
    }

    @Test func footballTimeoutRequiresHeadRefereeAuthority() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-timeout-auth.json"))
        var game = upcomingGame(status: .active)
        game.assignedPosition = "Line Judge"
        #expect(throws: RefTraceInGameError.headRefereeRequired) {
            try store.requestFootballTimeoutStop(for: game, profile: .demo, source: .localMock)
        }
    }

    @Test func footballTwoMinutePreAlertOnlySendsOnceInSecondQuarter() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-two-minute.json"))
        let game = upcomingGame(status: .active)
        store.changePeriod(for: game, to: "Q2", profile: .demo)
        try store.adjustGameClockAsHeadRef(for: game, delta: 125 - store.displayState(for: game).gameClock.remainingTime, profile: .demo, reason: "Testing pre-alert")
        let first = store.processTwoMinuteWarningIfNeeded(for: game, previousRemaining: 126, profile: .demo)
        let second = store.processTwoMinuteWarningIfNeeded(for: game, previousRemaining: 126, profile: .demo)
        #expect(first != nil)
        #expect(second == nil)
    }

    @Test func footballWatchPayloadIdentifiesHeadRefereeTimeoutCapability() async throws {
        let store = RefTraceInGameStore(storageURL: tempURL("football-watch.json"))
        let game = upcomingGame(status: .active)
        let payload = store.watchPayload(for: game)
        #expect(payload.isFootball)
        #expect(payload.isHeadReferee)
        #expect(payload.watchTimeoutStatus == "Head Referee clock authority")
    }

    private func spectatorState(sport: RefTraceSport) -> SpectatorGameState {
        var game = upcomingGame(status: .active)
        game.sport = sport
        return SpectatorGameState.from(game: game, state: RefTraceInGameStore().displayState(for: game))
    }

    private func footballWhistle(game: RefTraceGame, officialID: String, position: RefTraceOfficialPosition, confidence: Double = 0.95, detectedAt: Date = Date()) -> WhistleDetectionEvent {
        WhistleDetectionEvent(
            gameID: game.id,
            officialID: officialID,
            officialPosition: position,
            deviceReference: position == .headReferee ? "head-ref-device" : "crew-device",
            source: .localMock,
            detectedAt: detectedAt,
            classification: confidence > 0.8 ? .refereeWhistle : .possibleWhistle,
            confidence: confidence,
            estimatedDurationMilliseconds: 300,
            signalQuality: confidence > 0.8 ? .good : .poor
        )
    }

    private func tempURL(_ filename: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    }

    private func completeDraft() -> CreateRefTraceGameDraft {
        var draft = CreateRefTraceGameDraft()
        draft.leagueName = "Varsity"
        draft.homeTeamName = "North"
        draft.homeTeamMascot = "Tigers"
        draft.awayTeamName = "South"
        draft.awayTeamMascot = "Hawks"
        draft.gameSiteName = "Memorial Stadium"
        draft.gameSiteAddress = "100 Main Street"
        draft.fieldOrCourt = "Field 1"
        draft.assignedPosition = draft.sport.positions[0]
        draft.updateDefaultReportTime()
        return draft
    }

    private func upcomingGame(status: RefTraceGameStatus, source: RefTraceGameSource = .manualRefTrace) -> RefTraceGame {
        let start = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return RefTraceGame(
            source: source,
            sport: .football,
            leagueID: "league-1",
            leagueName: "Varsity",
            homeTeamName: "North",
            homeTeamMascot: "Tigers",
            awayTeamName: "South",
            awayTeamMascot: "Hawks",
            gameSiteName: "Memorial Stadium",
            gameSiteAddress: "100 Main Street",
            fieldOrCourt: "Field 1",
            gameDate: start,
            scheduledStartTime: start,
            reportTime: start.addingTimeInterval(-45 * 60),
            assignedOfficialID: RefTraceOfficialProfile.demo.officialID,
            assignedOfficialName: "Harvey",
            assignedPosition: "Head Referee",
            status: status
        )
    }

    private func testParticipant(sessionID: UUID, first: String, last: String, position: String = "Line Judge") -> CommunicationParticipant {
        let displayName = "\(first) \(last)"
        return CommunicationParticipant(
            sessionID: sessionID,
            officialID: "official-\(first.lowercased())-\(last.lowercased())",
            officialFirstName: first,
            officialLastName: last,
            displayName: displayName,
            normalizedSearchNames: CommunicationParticipant.normalizedTerms(firstName: first, lastName: last, displayName: displayName, position: position),
            assignedPosition: position,
            gameAssignmentID: nil,
            deviceID: "test-device-\(UUID().uuidString)",
            isHeadOfficial: false
        )
    }

    private func displayModel(id: String, reportOffset: TimeInterval = 0) -> UpcomingGameDisplayModel {
        let start = Date(timeIntervalSince1970: 1_800_000_000 + reportOffset)
        return UpcomingGameDisplayModel(
            id: id,
            sourceGameID: UUID(),
            sourceAssignmentID: nil,
            transferID: nil,
            source: .manualRefTrace,
            sport: "Football",
            leagueName: "Varsity",
            homeTeamName: "North",
            homeTeamMascot: "Tigers",
            awayTeamName: "South",
            awayTeamMascot: "Hawks",
            gameDate: start,
            reportTime: start.addingTimeInterval(-45 * 60),
            scheduledStartTime: start,
            gameSiteName: "Memorial Stadium",
            fieldOrCourt: "Field 1",
            assignedPosition: "Head Referee",
            assignmentStatus: "Ready",
            gameStatus: .ready,
            syncStatus: .upToDate,
            latestSynchronizationDate: start
        )
    }
}
