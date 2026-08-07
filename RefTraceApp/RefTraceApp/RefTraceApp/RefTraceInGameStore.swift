import Foundation
import Combine

@MainActor
final class RefTraceInGameStore: ObservableObject {
    @Published private(set) var states: [UUID: InGamePersistedState] = [:]
    @Published private(set) var scoreEvents: [UUID: [ScoreEvent]] = [:]
    @Published private(set) var timeoutEvents: [UUID: [TimeoutEvent]] = [:]
    @Published private(set) var possessionEvents: [UUID: [PossessionEvent]] = [:]
    @Published private(set) var penaltyEvents: [UUID: [PenaltyEventRecord]] = [:]
    @Published private(set) var gameEvents: [UUID: [GameEventRecord]] = [:]
    @Published private(set) var rulesQueryLogs: [UUID: [RulesAssistantQueryLog]] = [:]
    @Published var currentError: String?
    @Published var watchSyncStatus: RefTraceWatchSyncStatus = .noActiveGame
    @Published private(set) var footballStates: [UUID: FootballInGameState] = [:]
    @Published private(set) var whistleEvents: [UUID: [WhistleDetectionEvent]] = [:]
    @Published private(set) var endOfPlayEvents: [UUID: [EndOfPlayWhistleEvent]] = [:]
    @Published private(set) var twoMinuteWarningEvents: [UUID: [TwoMinuteWarningEvent]] = [:]
    @Published private(set) var clockCorrectionEvents: [UUID: [GameClockCorrectionEvent]] = [:]
    @Published private(set) var footballPlaySequences: [UUID: [FootballPlaySequence]] = [:]

    private let storageURL: URL
    private let headRefAuthorization = RefTraceHeadRefereeAuthorizationService()
    private let gameClockService = StandardGameClockService()
    private let playClockService = FootballPlayClockService()
    private let whistleDeduplicator = CrewWhistleDeduplicator()
    private let twoMinuteCoordinator = TwoMinuteWarningCoordinator()

    init(storageURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = storageURL ?? documents.appendingPathComponent("RefTraceInGameState.json")
        load()
    }

    func state(for game: RefTraceGame) -> InGamePersistedState {
        if let state = states[game.id] { return state.reconciled() }
        let initial = initialState(for: game)
        states[game.id] = initial
        appendGameEvent(for: game, stateBefore: initial, stateAfter: initial, type: .gameCreated, subtype: nil, team: nil, points: nil, details: "Game state initialized", profile: nil)
        saveQuietly()
        return initial
    }

    private func initialState(for game: RefTraceGame) -> InGamePersistedState {
        let configuration = SportGameConfiguration.configuration(for: game)
        let period = configuration.periods.first ?? game.currentPeriod
        let gameClock = GameClockState(
            duration: configuration.periodLength,
            remainingTime: configuration.periodLength,
            isRunning: false,
            referenceStartTimestamp: nil,
            lastSynchronizedTimestamp: Date(),
            currentPeriod: period,
            stateVersion: 0,
            showTenthsUnderOneMinute: configuration.showTenthsUnderOneMinute
        )
        let playClock = configuration.playClockEnabled ? PlayClockState(
            duration: configuration.defaultPlayClock,
            remainingTime: configuration.defaultPlayClock,
            isRunning: false,
            referenceStartTimestamp: nil,
            lastSynchronizedTimestamp: Date(),
            currentPeriod: period,
            stateVersion: 0,
            showTenthsUnderOneMinute: false
        ) : nil
        let initial = InGamePersistedState(
            gameID: game.id,
            homeScore: game.homeScore,
            awayScore: game.awayScore,
            homeTimeouts: configuration.startingTimeouts,
            awayTimeouts: configuration.startingTimeouts,
            possession: configuration.possessionEnabled ? .unknown : .notApplicable,
            gameClock: gameClock,
            playClock: playClock,
            status: game.status == .active ? .active : .pregame,
            currentPeriod: period,
            lastSavedAt: Date(),
            syncStatus: .pending
        )
        return initial
    }

    func displayState(for game: RefTraceGame) -> InGamePersistedState {
        if let state = states[game.id] {
            return state.reconciled()
        }
        return initialState(for: game)
    }

    func reconciledState(for game: RefTraceGame) -> InGamePersistedState {
        let current = state(for: game).reconciled()
        states[game.id] = current
        saveQuietly()
        return current
    }

    func startGameClock(for game: RefTraceGame, profile: RefTraceOfficialProfile?) {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            currentError = RefTraceInGameError.headRefereeRequired.localizedDescription
            return
        }
        let before = state(for: game).reconciled()
        guard !before.gameClock.isRunning, before.gameClock.remainingTime > 0 else { return }
        var after = before
        after.gameClock.isRunning = true
        after.gameClock.referenceStartTimestamp = Date()
        after.gameClock.stateVersion += 1
        after.status = .active
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .gameClockStarted, subtype: ClockEventSubtype.gameStarted.rawValue, team: nil, points: nil, details: "Game clock started", profile: profile)
    }

    func stopGameClock(for game: RefTraceGame, profile: RefTraceOfficialProfile?) {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            currentError = RefTraceInGameError.headRefereeRequired.localizedDescription
            return
        }
        let before = state(for: game).reconciled()
        guard before.gameClock.isRunning else { return }
        var after = before
        after.gameClock.isRunning = false
        after.gameClock.referenceStartTimestamp = nil
        after.gameClock.stateVersion += 1
        after.status = .clockStopped
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .gameClockStopped, subtype: ClockEventSubtype.gameStopped.rawValue, team: nil, points: nil, details: "Game clock stopped", profile: profile)
    }

    func adjustGameClock(for game: RefTraceGame, delta: TimeInterval, profile: RefTraceOfficialProfile?) {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            currentError = RefTraceInGameError.headRefereeRequired.localizedDescription
            return
        }
        let before = state(for: game).reconciled()
        var after = before
        after.gameClock.remainingTime = min(after.gameClock.duration, max(0, after.gameClock.remainingTime + delta))
        after.gameClock.referenceStartTimestamp = after.gameClock.isRunning ? Date() : nil
        after.gameClock.stateVersion += 1
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .gameClockAdjusted, subtype: ClockEventSubtype.gameAdjusted.rawValue, team: nil, points: nil, details: delta >= 0 ? "Game clock adjusted up" : "Game clock adjusted down", profile: profile)
    }

    func startPlayClock(for game: RefTraceGame, profile: RefTraceOfficialProfile?) {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            currentError = RefTraceInGameError.headRefereeRequired.localizedDescription
            return
        }
        let before = state(for: game).reconciled()
        guard var playClock = before.playClock, !playClock.isRunning, playClock.remainingTime > 0 else { return }
        var after = before
        playClock.isRunning = true
        playClock.referenceStartTimestamp = Date()
        playClock.stateVersion += 1
        after.playClock = playClock
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .playClockStarted, subtype: ClockEventSubtype.playStarted.rawValue, team: nil, points: nil, details: "Play clock started", profile: profile)
    }

    func stopPlayClock(for game: RefTraceGame, profile: RefTraceOfficialProfile?) {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            currentError = RefTraceInGameError.headRefereeRequired.localizedDescription
            return
        }
        let before = state(for: game).reconciled()
        guard var playClock = before.playClock?.reconciled(), playClock.isRunning else { return }
        var after = before
        playClock.isRunning = false
        playClock.referenceStartTimestamp = nil
        playClock.stateVersion += 1
        after.playClock = playClock
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .playClockStopped, subtype: ClockEventSubtype.playStopped.rawValue, team: nil, points: nil, details: "Play clock stopped", profile: profile)
    }

    func resetPlayClock(for game: RefTraceGame, to seconds: TimeInterval? = nil, profile: RefTraceOfficialProfile?) {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            currentError = RefTraceInGameError.headRefereeRequired.localizedDescription
            return
        }
        let before = state(for: game).reconciled()
        guard var playClock = before.playClock else { return }
        var after = before
        let value = seconds ?? playClock.duration
        playClock.duration = value
        playClock.remainingTime = value
        playClock.isRunning = false
        playClock.referenceStartTimestamp = nil
        playClock.stateVersion += 1
        after.playClock = playClock
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .playClockReset, subtype: ClockEventSubtype.playReset.rawValue, team: nil, points: nil, details: "Play clock reset", profile: profile)
    }

    func addScore(to side: TeamSide, scoreType: ScoreType, points overridePoints: Int? = nil, correctionStatus: ScoreCorrectionStatus = .standard, reason: String? = nil, game: RefTraceGame, profile: RefTraceOfficialProfile?) throws -> ScoreEvent {
        let points = overridePoints ?? scoreType.defaultPoints
        guard points >= 0 else { throw RefTraceInGameError.negativeScore }
        guard !scoreType.requiresReason || !(reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RefTraceInGameError.correctionReasonRequired }
        let before = state(for: game).reconciled()
        if isDuplicateScore(gameID: game.id, side: side, scoreType: scoreType, points: points, clock: before.gameClock.displayText) {
            throw RefTraceInGameError.duplicateEvent
        }
        var after = before
        if side == .home {
            after.homeScore += points
        } else {
            after.awayScore += points
        }
        after.lastSavedAt = Date()
        update(after, for: game)
        let event = ScoreEvent(
            gameID: game.id,
            scoringTeamID: side.rawValue,
            scoringTeamName: teamName(side, game: game),
            scoreType: scoreType,
            pointValue: points,
            period: after.currentPeriod,
            gameClockTime: before.gameClock.displayText,
            playClockTime: before.playClock?.displayText,
            homeScoreBefore: before.homeScore,
            awayScoreBefore: before.awayScore,
            homeScoreAfter: after.homeScore,
            awayScoreAfter: after.awayScore,
            enteredByOfficialID: profile?.officialID ?? game.assignedOfficialID ?? "unknown-official",
            enteredByOfficialName: profile?.preferredDisplayName ?? game.assignedOfficialName,
            enteredByPosition: displayPosition(for: game),
            sourceDevice: deviceReference,
            correctionStatus: correctionStatus,
            correctionReason: reason,
            syncStatus: .pending
        )
        scoreEvents[game.id, default: []].append(event)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: correctionStatus == .standard ? .scoreAdded : .scoreCorrected, subtype: scoreType.displayName, team: (side.rawValue, teamName(side, game: game)), points: points, details: "\(teamName(side, game: game)) \(scoreType.displayName) +\(points)", profile: profile)
        saveQuietly()
        return event
    }

    func reverseScore(_ scoreEvent: ScoreEvent, game: RefTraceGame, profile: RefTraceOfficialProfile?, reason: String) throws -> ScoreEvent {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RefTraceInGameError.correctionReasonRequired }
        let before = state(for: game).reconciled()
        var after = before
        if scoreEvent.scoringTeamID == TeamSide.home.rawValue {
            after.homeScore = max(0, after.homeScore - scoreEvent.pointValue)
        } else {
            after.awayScore = max(0, after.awayScore - scoreEvent.pointValue)
        }
        after.lastSavedAt = Date()
        update(after, for: game)
        var reversal = scoreEvent
        reversal.id = UUID()
        reversal.pointValue = -scoreEvent.pointValue
        reversal.homeScoreBefore = before.homeScore
        reversal.awayScoreBefore = before.awayScore
        reversal.homeScoreAfter = after.homeScore
        reversal.awayScoreAfter = after.awayScore
        reversal.correctionStatus = .reversal
        reversal.correctionReason = reason
        reversal.relatedScoreEventID = scoreEvent.id
        reversal.createdAt = Date()
        reversal.updatedAt = Date()
        scoreEvents[game.id, default: []].append(reversal)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .scoreReversed, subtype: scoreEvent.scoreType.displayName, team: (scoreEvent.scoringTeamID, scoreEvent.scoringTeamName), points: -scoreEvent.pointValue, details: "Score reversed: \(reason)", profile: profile)
        saveQuietly()
        return reversal
    }

    func recordTimeout(_ timeoutType: TimeoutType, game: RefTraceGame, profile: RefTraceOfficialProfile?, reason: String? = nil) throws -> TimeoutEvent {
        if game.sport == .football && !canControlFootballClock(game: game, profile: profile) {
            throw RefTraceInGameError.headRefereeRequired
        }
        let configuration = SportGameConfiguration.configuration(for: game)
        let before = state(for: game).reconciled()
        var after = before
        var chargedTeamID: String?
        var chargedTeamName: String?
        switch timeoutType {
        case .homeTeam:
            guard after.homeTimeouts > 0 else { throw RefTraceInGameError.timeoutUnavailable }
            chargedTeamID = TeamSide.home.rawValue
            chargedTeamName = teamName(.home, game: game)
            after.homeTimeouts -= 1
        case .awayTeam:
            guard after.awayTimeouts > 0 else { throw RefTraceInGameError.timeoutUnavailable }
            chargedTeamID = TeamSide.away.rawValue
            chargedTeamName = teamName(.away, game: game)
            after.awayTimeouts -= 1
        default:
            break
        }
        after.lastSavedAt = Date()
        update(after, for: game)
        let event = TimeoutEvent(
            gameID: game.id,
            timeoutType: timeoutType,
            chargedTeamID: chargedTeamID,
            chargedTeamName: chargedTeamName,
            period: after.currentPeriod,
            gameClockTime: before.gameClock.displayText,
            durationSeconds: Int(configuration.timeoutDuration),
            homeTimeoutsBefore: before.homeTimeouts,
            awayTimeoutsBefore: before.awayTimeouts,
            homeTimeoutsAfter: after.homeTimeouts,
            awayTimeoutsAfter: after.awayTimeouts,
            enteredByOfficialID: profile?.officialID ?? game.assignedOfficialID ?? "unknown-official",
            enteredByOfficialName: profile?.preferredDisplayName ?? game.assignedOfficialName,
            correctionStatus: .standard,
            correctionReason: reason,
            syncStatus: .pending
        )
        timeoutEvents[game.id, default: []].append(event)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .timeoutTaken, subtype: timeoutType.displayName, team: chargedTeamID.map { ($0, chargedTeamName ?? "") }, points: nil, details: "\(timeoutType.displayName) timeout recorded", profile: profile)
        saveQuietly()
        return event
    }

    func changePossession(to possession: PossessionState, game: RefTraceGame, profile: RefTraceOfficialProfile?, reason: String? = nil) throws {
        let configuration = SportGameConfiguration.configuration(for: game)
        guard configuration.possessionEnabled else { throw RefTraceInGameError.possessionNotAvailable }
        let before = state(for: game).reconciled()
        guard before.possession != possession else { return }
        var after = before
        after.possession = possession
        after.lastSavedAt = Date()
        update(after, for: game)
        let event = PossessionEvent(
            gameID: game.id,
            previousPossession: before.possession,
            newPossession: possession,
            period: after.currentPeriod,
            gameClockTime: before.gameClock.displayText,
            enteredByOfficialID: profile?.officialID ?? game.assignedOfficialID ?? "unknown-official",
            enteredByOfficialName: profile?.preferredDisplayName ?? game.assignedOfficialName,
            reason: reason,
            syncStatus: .pending
        )
        possessionEvents[game.id, default: []].append(event)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .possessionChanged, subtype: possession.rawValue, team: nil, points: nil, details: "Possession changed to \(possession.rawValue)", profile: profile)
        saveQuietly()
    }

    func changePeriod(for game: RefTraceGame, to period: String, profile: RefTraceOfficialProfile?) {
        let before = state(for: game).reconciled()
        var after = before
        after.currentPeriod = period
        after.gameClock.currentPeriod = period
        after.playClock?.currentPeriod = period
        after.gameClock.stateVersion += 1
        after.playClock?.stateVersion += 1
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .periodStarted, subtype: period, team: nil, points: nil, details: "Period changed to \(period)", profile: profile)
    }

    func addPenaltyPlaceholder(for game: RefTraceGame, profile: RefTraceOfficialProfile?, foulName: String = "Penalty placeholder") {
        let current = state(for: game).reconciled()
        let penalty = PenaltyEventRecord(
            gameID: game.id,
            eventLogID: nil,
            callingOfficialID: profile?.officialID,
            foulName: foulName,
            ruleCode: nil,
            penaltyDistance: nil,
            enforcementSpot: nil,
            downConsequence: nil,
            clockConsequence: nil,
            acceptedStatus: nil,
            gameClockTime: current.gameClock.displayText,
            period: current.currentPeriod,
            notes: "Future penalty module placeholder",
            status: .placeholder
        )
        penaltyEvents[game.id, default: []].append(penalty)
        appendGameEvent(for: game, stateBefore: current, stateAfter: current, type: .penaltyPlaceholder, subtype: penalty.foulName, team: nil, points: nil, details: "Penalty placeholder added", profile: profile)
        saveQuietly()
    }

    func completeGame(_ game: RefTraceGame, profile: RefTraceOfficialProfile?) {
        let before = state(for: game).reconciled()
        var after = before
        after.gameClock.isRunning = false
        after.gameClock.referenceStartTimestamp = nil
        after.playClock?.isRunning = false
        after.playClock?.referenceStartTimestamp = nil
        after.status = .completed
        after.syncStatus = .pending
        after.lastSavedAt = Date()
        update(after, for: game)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .gameCompleted, subtype: nil, team: nil, points: nil, details: "Game completed", profile: profile)
        watchSyncStatus = .lastUpdated(Date())
        saveQuietly()
    }

    func footballState(for game: RefTraceGame) -> FootballInGameState {
        if let state = footballStates[game.id] { return state }
        let footballState = initialFootballState(for: game)
        footballStates[game.id] = footballState
        saveQuietly()
        return footballState
    }

    func displayFootballState(for game: RefTraceGame) -> FootballInGameState {
        footballStates[game.id] ?? initialFootballState(for: game)
    }

    private func initialFootballState(for game: RefTraceGame) -> FootballInGameState {
        let inGameState = displayState(for: game)
        return FootballInGameState(
            gameID: game.id,
            quarter: inGameState.currentPeriod,
            gameClockState: .notStarted,
            playClockState: .stopped,
            gameStatus: inGameState.status,
            headRefereeID: normalizedPosition(for: game) == .headReferee ? game.assignedOfficialID : nil,
            authoritativeDeviceID: deviceReference,
            initialWhistleStartArmed: false,
            whistleDetectionState: .inactive,
            lastAcceptedWhistleEventID: nil,
            lastEndOfPlayEventID: nil,
            activeTimeoutID: nil,
            twoMinuteWarningState: .pending,
            gameClockVersion: inGameState.gameClock.stateVersion,
            playClockVersion: inGameState.playClock?.stateVersion ?? 0,
            lastAuthoritativeClockCommand: nil,
            lastSynchronizedAt: Date()
        )
    }

    func isHeadReferee(game: RefTraceGame, profile: RefTraceOfficialProfile?) -> Bool {
        headRefAuthorization.canControlFootballClock(game: game, profile: profile)
    }

    func canControlFootballClock(game: RefTraceGame, profile: RefTraceOfficialProfile?) -> Bool {
        game.sport == .football && isHeadReferee(game: game, profile: profile)
    }

    func startFootballGamePreparation(for game: RefTraceGame, profile: RefTraceOfficialProfile?) throws {
        guard game.sport == .football else { return }
        guard canControlFootballClock(game: game, profile: profile) else { throw RefTraceInGameError.headRefereeRequired }
        let before = state(for: game).reconciled()
        var after = before
        after.gameClock.isRunning = false
        after.gameClock.referenceStartTimestamp = nil
        after.status = .ready
        after.lastSavedAt = Date()
        update(after, for: game)
        var footballState = footballState(for: game)
        footballState.gameClockState = .armedForOpeningWhistle
        footballState.playClockState = after.playClock?.isRunning == true ? .running : .stopped
        footballState.initialWhistleStartArmed = true
        footballState.whistleDetectionState = .listening
        footballState.headRefereeID = profile?.officialID ?? game.assignedOfficialID
        footballState.authoritativeDeviceID = deviceReference
        footballState.lastAuthoritativeClockCommand = UUID()
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .startGameSelected, subtype: nil, team: nil, points: nil, details: "Start Game selected; opening whistle armed", profile: profile)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .openingWhistleArmed, subtype: nil, team: nil, points: nil, details: "Waiting for Head Referee whistle", profile: profile)
        saveQuietly()
    }

    @discardableResult
    func processFootballWhistle(_ event: WhistleDetectionEvent, game: RefTraceGame, profile: RefTraceOfficialProfile?) throws -> WhistleDetectionEvent {
        guard game.sport == .football else { return event }
        let configuration = FootballGameConfiguration.configuration(for: game)
        var footballState = footballState(for: game)
        var processed = event
        processed.createdAt = Date()

        guard configuration.whistleDetectionEnabled else {
            processed.accepted = false
            processed.rejectionReason = .automationDisabled
            processed.triggeredAction = .ignoredGameState
            appendWhistle(processed, game: game, profile: profile, logType: .crewWhistleRejected, details: "Whistle automation is disabled")
            return processed
        }
        guard processed.confidence >= configuration.whistleConfidenceThreshold else {
            processed.accepted = false
            processed.rejectionReason = .lowConfidence
            processed.triggeredAction = .ignoredLowConfidence
            appendWhistle(processed, game: game, profile: profile, logType: .crewWhistleRejected, details: "Low-confidence whistle ignored")
            return processed
        }

        let accepted = whistleEvents[game.id, default: []].filter { $0.accepted }
        guard !whistleDeduplicator.isDuplicate(processed, acceptedEvents: accepted, configuration: configuration) else {
            processed.accepted = false
            processed.rejectionReason = .duplicate
            processed.triggeredAction = .ignoredDuplicate
            appendWhistle(processed, game: game, profile: profile, logType: .crewWhistleMerged, details: "Duplicate whistle merged into the current play event")
            return processed
        }

        if footballState.initialWhistleStartArmed {
            guard processed.officialPosition == .headReferee && processed.officialID == (footballState.headRefereeID ?? profile?.officialID ?? game.assignedOfficialID) else {
                processed.accepted = false
                processed.rejectionReason = .wrongAuthority
                processed.triggeredAction = .ignoredWrongAuthority
                appendWhistle(processed, game: game, profile: profile, logType: .openingWhistleRejected, details: "Pre-start whistle ignored because it did not come from the Head Referee device")
                return processed
            }
            try startGameClockFromOpeningWhistle(processed, game: game, profile: profile)
            processed.accepted = true
            processed.triggeredAction = .openingGameClockStart
            appendWhistle(processed, game: game, profile: profile, logType: .openingWhistleDetected, details: "Opening Head Referee whistle detected; game clock started")
            return processed
        }

        guard footballState.gameClockState == .running || state(for: game).status == .active else {
            processed.accepted = false
            processed.rejectionReason = .invalidGameState
            processed.triggeredAction = .ignoredGameState
            appendWhistle(processed, game: game, profile: profile, logType: .crewWhistleRejected, details: "Crew whistle ignored because Football game state is not active")
            return processed
        }

        processed.accepted = true
        processed.triggeredAction = .playEnded
        appendWhistle(processed, game: game, profile: profile, logType: .crewWhistleDetected, details: "Crew whistle accepted as end-of-play signal")
        try startPlayClockFromEndOfPlay(sourceWhistleIDs: [processed.id], officialIDs: [processed.officialID], game: game, profile: profile)
        footballState = self.footballState(for: game)
        footballState.lastAcceptedWhistleEventID = processed.id
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
        return processed
    }

    func startGameClockFromOpeningWhistle(_ event: WhistleDetectionEvent, game: RefTraceGame, profile: RefTraceOfficialProfile?) throws {
        var footballState = footballState(for: game)
        guard footballState.initialWhistleStartArmed else { throw RefTraceInGameError.invalidFootballClockState }
        let before = state(for: game).reconciled()
        var after = before
        after.gameClock = gameClockService.start(before.gameClock, now: event.detectedAt)
        after.status = .active
        after.lastSavedAt = Date()
        update(after, for: game)
        footballState.gameClockState = .running
        footballState.initialWhistleStartArmed = false
        footballState.lastAcceptedWhistleEventID = event.id
        footballState.gameClockVersion = after.gameClock.stateVersion
        footballState.lastAuthoritativeClockCommand = UUID()
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .gameClockStarted, subtype: "openingWhistle", team: nil, points: nil, details: "Game clock started by validated Head Referee opening whistle", profile: profile)
        saveQuietly()
    }

    func startPlayClockFromEndOfPlay(sourceWhistleIDs: [UUID], officialIDs: [String], game: RefTraceGame, profile: RefTraceOfficialProfile?) throws {
        let configuration = FootballGameConfiguration.configuration(for: game)
        let before = state(for: game).reconciled()
        guard var playClock = before.playClock else { throw RefTraceInGameError.invalidFootballClockState }
        var after = before
        let now = Date()
        playClock = playClockService.processEndOfPlayWhistle(playClock, configuration: configuration, now: now)
        after.playClock = playClock
        after.lastSavedAt = now
        update(after, for: game)
        var footballState = footballState(for: game)
        footballState.playClockState = .running
        footballState.playClockVersion = playClock.stateVersion
        footballState.lastAuthoritativeClockCommand = UUID()
        footballState.lastSynchronizedAt = now
        updateFootballState(footballState)
        let endEvent = EndOfPlayWhistleEvent(
            gameID: game.id,
            quarter: after.currentPeriod,
            gameClockTime: before.gameClock.displayText,
            sourceWhistleEventIDs: sourceWhistleIDs,
            detectedOfficialIDs: officialIDs,
            acceptedAt: now,
            playClockStartedAt: now,
            playClockDuration: configuration.playClockDuration,
            gameClockWasRunning: before.gameClock.isRunning
        )
        endOfPlayEvents[game.id, default: []].append(endEvent)
        footballState.lastEndOfPlayEventID = endEvent.id
        updateFootballState(footballState)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .endOfPlayDetected, subtype: "crewWhistle", team: nil, points: nil, details: "End-of-play whistle detected; game clock unchanged", profile: profile)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .playClockStarted, subtype: "25", team: nil, points: nil, details: "25-second play clock started from crew whistle", profile: profile)
        saveQuietly()
    }

    func requestFootballTimeoutStop(for game: RefTraceGame, profile: RefTraceOfficialProfile?, source: TimeoutStopInputSource = .iPhone) throws {
        guard canControlFootballClock(game: game, profile: profile) else { throw RefTraceInGameError.headRefereeRequired }
        let before = state(for: game).reconciled()
        var after = before
        let now = Date()
        after.gameClock = gameClockService.stop(before.gameClock, now: now)
        if let playClock = before.playClock {
            after.playClock = playClockService.stop(playClock, now: now)
        }
        after.status = .clockStopped
        after.lastSavedAt = now
        update(after, for: game)
        var footballState = footballState(for: game)
        footballState.gameClockState = .timeout
        footballState.playClockState = after.playClock?.isRunning == true ? .running : .stopped
        footballState.activeTimeoutID = UUID()
        footballState.gameClockVersion = after.gameClock.stateVersion
        footballState.playClockVersion = after.playClock?.stateVersion ?? footballState.playClockVersion
        footballState.lastAuthoritativeClockCommand = footballState.activeTimeoutID
        footballState.lastSynchronizedAt = now
        updateFootballState(footballState)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .timeoutRequested, subtype: source.rawValue, team: nil, points: nil, details: "Head Referee timeout stop requested from \(source.rawValue)", profile: profile)
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .timeoutClockStopped, subtype: source.rawValue, team: nil, points: nil, details: "Authoritative game clock stopped for timeout", profile: profile)
        saveQuietly()
    }

    @discardableResult
    func recordFootballTimeout(_ timeoutType: TimeoutType, game: RefTraceGame, profile: RefTraceOfficialProfile?, source: TimeoutStopInputSource = .iPhone, reason: String? = nil) throws -> TimeoutEvent {
        guard canControlFootballClock(game: game, profile: profile) else { throw RefTraceInGameError.headRefereeRequired }
        let before = state(for: game).reconciled()
        let event = try recordTimeout(timeoutType, game: game, profile: profile, reason: reason)
        var enriched = event
        enriched.authoritativeClockStoppedAt = Date()
        enriched.stoppedByOfficialID = profile?.officialID ?? game.assignedOfficialID
        enriched.stoppedByDeviceReference = deviceReference
        enriched.stopInputSource = source
        enriched.gameClockBefore = before.gameClock.displayText
        enriched.gameClockAfter = state(for: game).gameClock.displayText
        enriched.playClockBefore = before.playClock?.displayText
        enriched.playClockAfter = state(for: game).playClock?.displayText
        if let index = timeoutEvents[game.id, default: []].firstIndex(where: { $0.id == event.id }) {
            timeoutEvents[game.id]?[index] = enriched
        }
        let after = state(for: game).reconciled()
        appendGameEvent(for: game, stateBefore: before, stateAfter: after, type: .timeoutRecorded, subtype: timeoutType.displayName, team: enriched.chargedTeamID.map { ($0, enriched.chargedTeamName ?? "") }, points: nil, details: "Football timeout recorded by Head Referee", profile: profile)
        saveQuietly()
        return enriched
    }

    func stopGameClockAsHeadRef(for game: RefTraceGame, profile: RefTraceOfficialProfile?) throws {
        guard canControlFootballClock(game: game, profile: profile) else { throw RefTraceInGameError.headRefereeRequired }
        stopGameClock(for: game, profile: profile)
        var footballState = footballState(for: game)
        footballState.gameClockState = .stopped
        footballState.gameClockVersion = state(for: game).gameClock.stateVersion
        footballState.lastAuthoritativeClockCommand = UUID()
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
    }

    func resumeGameClockAsHeadRef(for game: RefTraceGame, profile: RefTraceOfficialProfile?) throws {
        guard canControlFootballClock(game: game, profile: profile) else { throw RefTraceInGameError.headRefereeRequired }
        startGameClock(for: game, profile: profile)
        var footballState = footballState(for: game)
        footballState.gameClockState = .running
        footballState.gameClockVersion = state(for: game).gameClock.stateVersion
        footballState.lastAuthoritativeClockCommand = UUID()
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
        let current = state(for: game).reconciled()
        appendGameEvent(for: game, stateBefore: current, stateAfter: current, type: .gameClockResumed, subtype: nil, team: nil, points: nil, details: "Game clock resumed by Head Referee", profile: profile)
        saveQuietly()
    }

    func adjustGameClockAsHeadRef(for game: RefTraceGame, delta: TimeInterval, profile: RefTraceOfficialProfile?, reason: String) throws {
        guard canControlFootballClock(game: game, profile: profile) else { throw RefTraceInGameError.headRefereeRequired }
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RefTraceInGameError.correctionReasonRequired }
        let before = state(for: game).reconciled()
        adjustGameClock(for: game, delta: delta, profile: profile)
        let after = state(for: game).reconciled()
        let correction = GameClockCorrectionEvent(
            gameID: game.id,
            quarter: after.currentPeriod,
            previousClockTime: before.gameClock.displayText,
            correctedClockTime: after.gameClock.displayText,
            differenceMilliseconds: Int(delta * 1000),
            reason: reason,
            correctedByOfficialID: profile?.officialID ?? game.assignedOfficialID ?? "unknown-official",
            correctedByDevice: deviceReference,
            stateVersionBefore: before.gameClock.stateVersion,
            stateVersionAfter: after.gameClock.stateVersion
        )
        clockCorrectionEvents[game.id, default: []].append(correction)
        var footballState = footballState(for: game)
        footballState.gameClockVersion = after.gameClock.stateVersion
        footballState.lastAuthoritativeClockCommand = correction.id
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
        saveQuietly()
    }

    @discardableResult
    func processTwoMinuteWarningIfNeeded(for game: RefTraceGame, previousRemaining: TimeInterval, profile: RefTraceOfficialProfile?) -> TwoMinuteWarningEvent? {
        guard game.sport == .football else { return nil }
        let configuration = FootballGameConfiguration.configuration(for: game)
        let current = state(for: game).reconciled()
        let alreadySent = twoMinuteWarningEvents[game.id, default: []].contains { $0.quarter == current.currentPeriod && $0.warningType == .fiveSecondPreAlert }
        guard twoMinuteCoordinator.shouldSendPreAlert(quarter: current.currentPeriod, previousRemaining: previousRemaining, currentRemaining: current.gameClock.remainingTime, configuration: configuration, alreadySent: alreadySent) else { return nil }
        let targetIDs = ([game.assignedOfficialID] + game.otherOfficials).compactMap { $0 }.filter { !$0.isEmpty }
        let event = TwoMinuteWarningEvent(
            gameID: game.id,
            quarter: current.currentPeriod,
            warningType: .fiveSecondPreAlert,
            gameClockTime: current.gameClock.displayText,
            authoritativeClockVersion: current.gameClock.stateVersion,
            targetOfficialIDs: targetIDs,
            deliveredOfficialIDs: targetIDs,
            deliveredWatchIDs: targetIDs,
            failedRecipientIDs: [],
            triggeredAt: Date()
        )
        twoMinuteWarningEvents[game.id, default: []].append(event)
        var footballState = footballState(for: game)
        footballState.twoMinuteWarningState = .preAlertSent
        footballState.lastSynchronizedAt = Date()
        updateFootballState(footballState)
        appendGameEvent(for: game, stateBefore: current, stateAfter: current, type: .twoMinutePreAlertSent, subtype: current.currentPeriod, team: nil, points: nil, details: "2-Minute Warning in 5 seconds", profile: profile)
        saveQuietly()
        return event
    }

    func authoritativeClockSnapshot(for game: RefTraceGame) -> AuthoritativeClockSnapshot {
        FootballClockCoordinator().snapshot(for: state(for: game).reconciled(), footballState: footballState(for: game))
    }

    func answerRulesQuestion(_ question: String, game: RefTraceGame, profile: RefTraceOfficialProfile?) -> PenaltyRulesAssistantResponse {
        let normalized = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRules = game.ruleDocumentID != nil || game.ruleVersion != nil
        let response: PenaltyRulesAssistantResponse
        if hasRules && (normalized.contains("defensive holding") || normalized.contains("holding")) && (game.sport == .football || game.sport == .flagFootball) {
            response = PenaltyRulesAssistantResponse(
                foulName: "Defensive Holding",
                sport: game.sport,
                league: game.leagueName,
                ruleVersion: game.ruleVersion,
                penalty: "Confirm in approved rule source",
                enforcement: "Supported rule source required for production enforcement",
                additionalResult: "Depends on league rule configuration",
                classification: "Context required",
                exceptions: "Review live-ball/dead-ball and possession context",
                source: "\(game.ruleDocumentID ?? "Cached rules"), version \(game.ruleVersion ?? "Unknown")",
                explanation: "Mock response only. Production answers must be retrieved from the approved game-specific rule set and cited by backend validation.",
                confidenceStatus: .needsContext,
                followUpQuestions: ["Was the ball live or dead?", "Which team had possession?", "Where did the foul occur?"]
            )
        } else if !hasRules {
            response = PenaltyRulesAssistantResponse(
                foulName: "Unconfirmed",
                sport: game.sport,
                league: game.leagueName,
                ruleVersion: nil,
                penalty: "Unavailable",
                enforcement: "Unavailable",
                additionalResult: "Unavailable",
                classification: "Unavailable",
                exceptions: "Unavailable",
                source: "No approved synchronized rules available",
                explanation: "I could not confirm this enforcement from the approved rule set.",
                confidenceStatus: .unsupported,
                followUpQuestions: []
            )
        } else {
            response = PenaltyRulesAssistantResponse(
                foulName: "Unconfirmed",
                sport: game.sport,
                league: game.leagueName,
                ruleVersion: game.ruleVersion,
                penalty: "Unconfirmed",
                enforcement: "Unconfirmed",
                additionalResult: "Unconfirmed",
                classification: "Unconfirmed",
                exceptions: "Unconfirmed",
                source: "\(game.ruleDocumentID ?? "Cached rules"), version \(game.ruleVersion ?? "Unknown")",
                explanation: "I could not confirm this enforcement from the approved rule set.",
                confidenceStatus: .unsupported,
                followUpQuestions: []
            )
        }
        let log = RulesAssistantQueryLog(
            gameID: game.id,
            officialID: profile?.officialID ?? game.assignedOfficialID ?? "unknown-official",
            ruleDocumentID: game.ruleDocumentID,
            ruleVersion: game.ruleVersion,
            questionText: question,
            normalizedQuestion: normalized,
            responseSummary: response.explanation,
            citedRuleItemIDs: response.confidenceStatus == .unsupported ? [] : [game.ruleDocumentID ?? "cached-rules"],
            confidenceStatus: response.confidenceStatus,
            responseReceivedAt: Date(),
            backendRequestID: nil,
            syncStatus: .pending
        )
        rulesQueryLogs[game.id, default: []].append(log)
        saveQuietly()
        return response
    }

    func watchPayload(for game: RefTraceGame) -> RefTraceWatchGameState {
        let current = state(for: game).reconciled()
        return RefTraceWatchGameState(
            gameID: game.id,
            awayTeamName: game.awayTeamName,
            awayTeamAbbreviation: Self.abbreviation(for: game.awayTeamName),
            homeTeamName: game.homeTeamName,
            homeTeamAbbreviation: Self.abbreviation(for: game.homeTeamName),
            awayScore: current.awayScore,
            homeScore: current.homeScore,
            gameClock: current.gameClock,
            playClock: current.playClock,
            currentPeriod: current.currentPeriod,
            timeoutsHome: current.homeTimeouts,
            timeoutsAway: current.awayTimeouts,
            possession: current.possession,
            assignedOfficialPosition: displayPosition(for: game),
            scoreLog: scoreEvents[game.id, default: []],
            lastUpdated: Date(),
            syncVersion: current.gameClock.stateVersion + (current.playClock?.stateVersion ?? 0),
            isFootball: game.sport == .football,
            isHeadReferee: normalizedPosition(for: game) == .headReferee,
            footballClockMode: game.sport == .football ? footballState(for: game).gameClockState : nil,
            pendingTimeoutRequestID: nil,
            watchTimeoutStatus: game.sport == .football ? "Head Referee clock authority" : nil,
            twoMinuteWarningMessage: twoMinuteWarningEvents[game.id, default: []].last?.warningType == .fiveSecondPreAlert ? "2-Minute Warning in 5 seconds" : nil
        )
    }

    func synchronizeWatch(for game: RefTraceGame, manager: RefTraceWatchConnectivityManager) {
        manager.update(gameState: watchPayload(for: game))
        watchSyncStatus = manager.status
    }

    func resetDemoData() {
        states.removeAll()
        scoreEvents.removeAll()
        timeoutEvents.removeAll()
        possessionEvents.removeAll()
        penaltyEvents.removeAll()
        gameEvents.removeAll()
        rulesQueryLogs.removeAll()
        footballStates.removeAll()
        whistleEvents.removeAll()
        endOfPlayEvents.removeAll()
        twoMinuteWarningEvents.removeAll()
        clockCorrectionEvents.removeAll()
        footballPlaySequences.removeAll()
        currentError = nil
        watchSyncStatus = .noActiveGame
        saveQuietly()
    }

    private func appendWhistle(_ event: WhistleDetectionEvent, game: RefTraceGame, profile: RefTraceOfficialProfile?, logType: GameEventType, details: String) {
        whistleEvents[game.id, default: []].append(event)
        let current = state(for: game).reconciled()
        appendGameEvent(for: game, stateBefore: current, stateAfter: current, type: logType, subtype: event.triggeredAction.rawValue, team: nil, points: nil, details: details, profile: profile)
        saveQuietly()
    }

    private func updateFootballState(_ state: FootballInGameState) {
        footballStates[state.gameID] = state
    }

    private func normalizedPosition(for game: RefTraceGame) -> RefTraceOfficialPosition {
        RefTraceOfficialPosition.normalize(game.assignedPosition)
    }

    private func update(_ state: InGamePersistedState, for game: RefTraceGame) {
        states[game.id] = state.reconciled()
        saveQuietly()
    }

    private func appendGameEvent(for game: RefTraceGame, stateBefore: InGamePersistedState, stateAfter: InGamePersistedState, type: GameEventType, subtype: String?, team: (id: String, name: String)?, points: Int?, details: String, profile: RefTraceOfficialProfile?) {
        let sequence = (gameEvents[game.id]?.count ?? 0) + 1
        let event = GameEventRecord(
            gameID: game.id,
            officialEaseGameID: game.officialEaseGameID,
            officialEaseAssignmentID: game.officialEaseAssignmentID,
            seasonID: nil,
            leagueID: game.leagueID,
            sport: game.sport,
            eventType: type,
            eventSubtype: subtype,
            teamID: team?.id,
            teamName: team?.name,
            officialID: profile?.officialID ?? game.assignedOfficialID,
            officialName: profile?.preferredDisplayName ?? game.assignedOfficialName,
            officialPosition: displayPosition(for: game),
            period: stateAfter.currentPeriod,
            gameClockTime: stateBefore.gameClock.displayText,
            playClockTime: stateBefore.playClock?.displayText,
            homeScoreBefore: stateBefore.homeScore,
            awayScoreBefore: stateBefore.awayScore,
            homeScoreAfter: stateAfter.homeScore,
            awayScoreAfter: stateAfter.awayScore,
            homeTimeoutsBefore: stateBefore.homeTimeouts,
            awayTimeoutsBefore: stateBefore.awayTimeouts,
            homeTimeoutsAfter: stateAfter.homeTimeouts,
            awayTimeoutsAfter: stateAfter.awayTimeouts,
            possessionBefore: stateBefore.possession,
            possessionAfter: stateAfter.possession,
            points: points,
            details: details,
            correctionReason: nil,
            relatedEventID: nil,
            sourceDevice: deviceReference,
            sourceApp: "RefTrace iPhone",
            sequenceNumber: sequence,
            correlationID: UUID(),
            syncStatus: .pending
        )
        gameEvents[game.id, default: []].append(event)
    }

    private func isDuplicateScore(gameID: UUID, side: TeamSide, scoreType: ScoreType, points: Int, clock: String) -> Bool {
        scoreEvents[gameID, default: []].contains { event in
            event.scoringTeamID == side.rawValue &&
            event.scoreType.displayName == scoreType.displayName &&
            event.pointValue == points &&
            event.gameClockTime == clock &&
            Date().timeIntervalSince(event.createdAt) < 2
        }
    }

    private func teamName(_ side: TeamSide, game: RefTraceGame) -> String {
        side == .home ? game.homeTeamName : game.awayTeamName
    }

    func displayPosition(for game: RefTraceGame) -> String {
        let normalized = RefTraceOfficialPosition.normalize(game.assignedPosition)
        return normalized == .unknown ? game.assignedPosition : normalized.displayName
    }

    func isAssignedOfficial(game: RefTraceGame, profile: RefTraceOfficialProfile?) -> Bool {
        guard let profile else { return false }
        return game.assignedOfficialID == nil || game.assignedOfficialID == profile.officialID
    }

    private var deviceReference: String {
        "local-device"
    }

    static func abbreviation(for team: String) -> String {
        let words = team.split(separator: " ")
        if words.count > 1 {
            return words.prefix(3).compactMap { $0.first }.map(String.init).joined().uppercased()
        }
        return String(team.prefix(3)).uppercased()
    }

    private func saveQuietly() {
        do {
            let snapshot = RefTraceInGameSnapshot(
                states: states,
                scoreEvents: scoreEvents,
                timeoutEvents: timeoutEvents,
                possessionEvents: possessionEvents,
                penaltyEvents: penaltyEvents,
                gameEvents: gameEvents,
                rulesQueryLogs: rulesQueryLogs,
                footballStates: footballStates,
                whistleEvents: whistleEvents,
                endOfPlayEvents: endOfPlayEvents,
                twoMinuteWarningEvents: twoMinuteWarningEvents,
                clockCorrectionEvents: clockCorrectionEvents,
                footballPlaySequences: footballPlaySequences
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            currentError = "RefTrace could not save the in-game log."
            #if DEBUG
            print("In-game save failed: \(error)")
            #endif
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(RefTraceInGameSnapshot.self, from: data)
            states = snapshot.states
            scoreEvents = snapshot.scoreEvents
            timeoutEvents = snapshot.timeoutEvents
            possessionEvents = snapshot.possessionEvents
            penaltyEvents = snapshot.penaltyEvents
            gameEvents = snapshot.gameEvents
            rulesQueryLogs = snapshot.rulesQueryLogs
            footballStates = snapshot.footballStates
            whistleEvents = snapshot.whistleEvents
            endOfPlayEvents = snapshot.endOfPlayEvents
            twoMinuteWarningEvents = snapshot.twoMinuteWarningEvents
            clockCorrectionEvents = snapshot.clockCorrectionEvents
            footballPlaySequences = snapshot.footballPlaySequences
        } catch {
            currentError = "RefTrace could not read the in-game log."
            #if DEBUG
            print("In-game load failed: \(error)")
            #endif
        }
    }
}

private struct RefTraceInGameSnapshot: Codable {
    var states: [UUID: InGamePersistedState]
    var scoreEvents: [UUID: [ScoreEvent]]
    var timeoutEvents: [UUID: [TimeoutEvent]]
    var possessionEvents: [UUID: [PossessionEvent]]
    var penaltyEvents: [UUID: [PenaltyEventRecord]]
    var gameEvents: [UUID: [GameEventRecord]]
    var rulesQueryLogs: [UUID: [RulesAssistantQueryLog]]
    var footballStates: [UUID: FootballInGameState]
    var whistleEvents: [UUID: [WhistleDetectionEvent]]
    var endOfPlayEvents: [UUID: [EndOfPlayWhistleEvent]]
    var twoMinuteWarningEvents: [UUID: [TwoMinuteWarningEvent]]
    var clockCorrectionEvents: [UUID: [GameClockCorrectionEvent]]
    var footballPlaySequences: [UUID: [FootballPlaySequence]]
}

enum RefTraceInGameError: LocalizedError, Equatable {
    case unassignedOfficial
    case negativeScore
    case duplicateEvent
    case correctionReasonRequired
    case timeoutUnavailable
    case possessionNotAvailable
    case rulesUnavailable
    case headRefereeRequired
    case invalidFootballClockState

    var errorDescription: String? {
        switch self {
        case .unassignedOfficial: return "Only an official assigned to this game can use production game controls."
        case .negativeScore: return "Scores cannot be negative."
        case .duplicateEvent: return "That event was already recorded."
        case .correctionReasonRequired: return "A reason is required for this correction."
        case .timeoutUnavailable: return "No timeouts remain for that team."
        case .possessionNotAvailable: return "Possession is not tracked for this sport."
        case .rulesUnavailable: return "No approved synchronized rules are available for this game."
        case .headRefereeRequired: return "Only the Head Referee may start, stop, resume, adjust, or confirm authoritative Football game-clock actions."
        case .invalidFootballClockState: return "The Football clock state does not allow that action right now."
        }
    }
}

extension InGamePersistedState {
    func reconciled(now: Date = Date()) -> InGamePersistedState {
        var copy = self
        copy.gameClock = gameClock.reconciled(now: now)
        copy.playClock = playClock?.reconciled(now: now)
        copy.lastSavedAt = now
        return copy
    }
}
