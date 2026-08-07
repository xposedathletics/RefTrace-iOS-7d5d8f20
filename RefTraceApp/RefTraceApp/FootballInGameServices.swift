import Foundation
import AVFoundation
import Combine

struct RefTraceHeadRefereeAuthorizationService: HeadRefereeAuthorizationService {
    func canControlFootballClock(game: RefTraceGame, profile: RefTraceOfficialProfile?) -> Bool {
        guard game.sport == .football, let profile else { return false }
        if let assignedID = game.assignedOfficialID, assignedID != profile.officialID {
            return false
        }
        return RefTraceOfficialPosition.normalize(game.assignedPosition) == .headReferee
    }
}

struct StandardGameClockService: GameClockService {
    func start(_ clock: GameClockState, now: Date = Date()) -> GameClockState {
        guard !clock.isRunning, clock.remainingTime > 0 else { return clock }
        var copy = clock.reconciled(now: now)
        copy.isRunning = true
        copy.referenceStartTimestamp = now
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    func stop(_ clock: GameClockState, now: Date = Date()) -> GameClockState {
        guard clock.isRunning else { return clock.reconciled(now: now) }
        var copy = clock.reconciled(now: now)
        copy.isRunning = false
        copy.referenceStartTimestamp = nil
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    func adjust(_ clock: GameClockState, delta: TimeInterval, now: Date = Date()) -> GameClockState {
        var copy = clock.reconciled(now: now)
        copy.remainingTime = min(copy.duration, max(0, copy.remainingTime + delta))
        copy.referenceStartTimestamp = copy.isRunning ? now : nil
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }
}

struct FootballPlayClockService: PlayClockService {
    func start25(_ clock: PlayClockState, now: Date = Date()) -> PlayClockState {
        var copy = clock.reconciled(now: now)
        copy.duration = 25
        copy.remainingTime = 25
        copy.isRunning = true
        copy.referenceStartTimestamp = now
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    func stop(_ clock: PlayClockState, now: Date = Date()) -> PlayClockState {
        guard clock.isRunning else { return clock.reconciled(now: now) }
        var copy = clock.reconciled(now: now)
        copy.isRunning = false
        copy.referenceStartTimestamp = nil
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    func reset25(_ clock: PlayClockState, now: Date = Date()) -> PlayClockState {
        var copy = clock.reconciled(now: now)
        copy.duration = 25
        copy.remainingTime = 25
        copy.isRunning = false
        copy.referenceStartTimestamp = nil
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    func manuallyAdjust(_ clock: PlayClockState, remaining: TimeInterval, now: Date = Date()) -> PlayClockState {
        var copy = clock.reconciled(now: now)
        copy.remainingTime = min(copy.duration, max(0, remaining))
        copy.referenceStartTimestamp = copy.isRunning ? now : nil
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }

    func processEndOfPlayWhistle(_ clock: PlayClockState, configuration: FootballGameConfiguration, now: Date = Date()) -> PlayClockState {
        var copy = clock.reconciled(now: now)
        copy.duration = configuration.playClockDuration
        copy.remainingTime = configuration.playClockDuration
        copy.isRunning = true
        copy.referenceStartTimestamp = now
        copy.stateVersion += 1
        copy.lastSynchronizedTimestamp = now
        return copy
    }
}

struct CrewWhistleDeduplicator: CrewWhistleAggregationService {
    func isDuplicate(_ event: WhistleDetectionEvent, acceptedEvents: [WhistleDetectionEvent], configuration: FootballGameConfiguration) -> Bool {
        acceptedEvents.contains { accepted in
            accepted.gameID == event.gameID && abs(accepted.detectedAt.timeIntervalSince(event.detectedAt)) <= configuration.whistleDebounceInterval
        }
    }

    func merge(events: [WhistleDetectionEvent], configuration: FootballGameConfiguration) -> [WhistleDetectionEvent] {
        let sorted = events.sorted { $0.detectedAt < $1.detectedAt }
        var merged: [WhistleDetectionEvent] = []
        for event in sorted {
            if let last = merged.last, abs(last.detectedAt.timeIntervalSince(event.detectedAt)) <= configuration.simultaneousWhistleMergeWindow {
                var duplicate = event
                duplicate.accepted = false
                duplicate.mergedIntoEventID = last.id
                duplicate.triggeredAction = .ignoredDuplicate
                merged.append(duplicate)
            } else {
                merged.append(event)
            }
        }
        return merged
    }
}

struct TwoMinuteWarningCoordinator: TwoMinuteWarningService {
    func shouldSendPreAlert(quarter: String, previousRemaining: TimeInterval, currentRemaining: TimeInterval, configuration: FootballGameConfiguration, alreadySent: Bool) -> Bool {
        guard configuration.twoMinuteWarningEnabled else { return false }
        guard configuration.twoMinuteWarningQuarters.contains(quarter) else { return false }
        guard !alreadySent else { return false }
        let preAlertThreshold = configuration.twoMinuteWarningThreshold + configuration.twoMinutePreAlertSeconds
        return previousRemaining > preAlertThreshold && currentRemaining <= preAlertThreshold
    }
}

struct FootballClockCoordinator: AuthoritativeFootballClockService {
    func snapshot(for state: InGamePersistedState, footballState: FootballInGameState) -> AuthoritativeClockSnapshot {
        AuthoritativeClockSnapshot(
            gameID: state.gameID,
            quarter: state.currentPeriod,
            remainingGameTime: state.gameClock.remainingTime,
            gameClockIsRunning: state.gameClock.isRunning,
            gameClockReferenceTimestamp: state.gameClock.referenceStartTimestamp,
            remainingPlayClockTime: state.playClock?.remainingTime,
            playClockIsRunning: state.playClock?.isRunning ?? false,
            playClockReferenceTimestamp: state.playClock?.referenceStartTimestamp,
            gameClockVersion: state.gameClock.stateVersion,
            playClockVersion: state.playClock?.stateVersion ?? 0,
            authoritativeOfficialID: footballState.headRefereeID,
            authoritativeDeviceReference: footballState.authoritativeDeviceID,
            lastCommandID: footballState.lastAuthoritativeClockCommand,
            lastUpdatedAt: Date()
        )
    }
}

@MainActor
final class MockWhistleDetectionService: ObservableObject, WhistleDetectionService {
    @Published private(set) var state: WhistleDetectionState = .inactive

    func requestMicrophoneAccess() async -> Bool { true }

    func startListening(for gameID: UUID, officialID: String) async throws {
        state = .listening
    }

    func stopListening() async {
        state = .inactive
    }
}

final class WhistleAudioCaptureService: WhistleDetectionService {
    private(set) var state: WhistleDetectionState = .inactive

    func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func startListening(for gameID: UUID, officialID: String) async throws {
        state = .listening
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothHFP, .defaultToSpeaker])
        try session.setActive(true)
    }

    func stopListening() async {
        state = .inactive
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
final class RefTraceGameAudioCoordinator: ObservableObject {
    @Published private(set) var whistleDetectionState: WhistleDetectionState = .inactive
    @Published private(set) var lastAudioRouteWarning: String?

    private let audioRouteManager: AudioRouteManager

    init() {
        self.audioRouteManager = AudioRouteManager()
    }

    init(audioRouteManager: AudioRouteManager) {
        self.audioRouteManager = audioRouteManager
    }

    func prepareForFootballWhistleDetection() {
        if audioRouteManager.microphoneAvailable {
            whistleDetectionState = .listening
            lastAudioRouteWarning = nil
        } else {
            whistleDetectionState = .microphoneUnavailable
            lastAudioRouteWarning = "Microphone unavailable. Use manual clock controls."
        }
    }

    func pauseWhistleDetectionForCommunication() {
        whistleDetectionState = .disabled
        lastAudioRouteWarning = "Whistle automation paused while communication audio is active."
    }
}

struct MockWatchGameControlService: WatchGameControlService {
    func requestHeadRefereeTimeout(gameID: UUID, source: TimeoutStopInputSource) async throws -> UUID {
        UUID()
    }
}

struct MockCrewSynchronizationService: CrewGameSynchronizationService {
    func publish(snapshot: AuthoritativeClockSnapshot) async throws {}
    func queue(event: GameEventRecord) async {}
}
