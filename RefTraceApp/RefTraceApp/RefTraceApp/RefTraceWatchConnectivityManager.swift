import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct RefTraceWatchGameState: Identifiable, Codable, Hashable {
    var id: UUID { gameID }
    var gameID: UUID
    var awayTeamName: String
    var awayTeamAbbreviation: String
    var homeTeamName: String
    var homeTeamAbbreviation: String
    var awayScore: Int
    var homeScore: Int
    var gameClock: GameClockState
    var playClock: PlayClockState?
    var currentPeriod: String
    var timeoutsHome: Int
    var timeoutsAway: Int
    var possession: PossessionState
    var assignedOfficialPosition: String
    var scoreLog: [ScoreEvent]
    var lastUpdated: Date
    var syncVersion: Int
    var isFootball: Bool = false
    var isHeadReferee: Bool = false
    var footballClockMode: FootballClockMode? = nil
    var pendingTimeoutRequestID: UUID? = nil
    var watchTimeoutStatus: String? = nil
    var twoMinuteWarningMessage: String? = nil
}

enum RefTraceWatchSyncStatus: Equatable, Hashable {
    case live
    case updating
    case lastUpdated(Date)
    case disconnected
    case noActiveGame

    var displayText: String {
        switch self {
        case .live: return "Live"
        case .updating: return "Updating"
        case .lastUpdated(let date): return "Last updated \(date.formatted(date: .omitted, time: .shortened))"
        case .disconnected: return "Disconnected"
        case .noActiveGame: return "No active game"
        }
    }
}

@MainActor
final class RefTraceWatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var latestGameState: RefTraceWatchGameState?
    @Published private(set) var status: RefTraceWatchSyncStatus = .noActiveGame

    #if canImport(WatchConnectivity)
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    #endif

    override init() {
        super.init()
        activateIfAvailable()
    }

    func activateIfAvailable() {
        #if canImport(WatchConnectivity)
        guard let session else {
            status = .disconnected
            return
        }
        session.delegate = self
        session.activate()
        #else
        status = .disconnected
        #endif
    }

    func update(gameState: RefTraceWatchGameState) {
        guard shouldAccept(gameState) else { return }
        latestGameState = gameState
        status = .updating
        #if canImport(WatchConnectivity)
        guard let session else {
            status = .disconnected
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(gameState)
            try session.updateApplicationContext(["RefTraceWatchGameState": data])
            session.transferUserInfo(["RefTraceScoreLogVersion": gameState.syncVersion, "gameID": gameState.gameID.uuidString])
            status = session.isReachable ? .live : .lastUpdated(gameState.lastUpdated)
        } catch {
            status = .disconnected
            #if DEBUG
            print("Watch sync failed: \(error)")
            #endif
        }
        #else
        status = .lastUpdated(gameState.lastUpdated)
        #endif
    }

    func shouldAccept(_ incoming: RefTraceWatchGameState) -> Bool {
        guard let latestGameState, latestGameState.gameID == incoming.gameID else { return true }
        return incoming.syncVersion >= latestGameState.syncVersion
    }

    @discardableResult
    func queueHeadRefereeTimeoutRequest(gameID: UUID, source: TimeoutStopInputSource = .watchOnScreenButton) -> UUID {
        let requestID = UUID()
        status = .updating
        #if canImport(WatchConnectivity)
        if let session, session.isReachable {
            session.sendMessage([
                "RefTraceHeadRefTimeoutRequestID": requestID.uuidString,
                "gameID": gameID.uuidString,
                "source": source.rawValue,
                "requestedAt": Date().timeIntervalSince1970
            ], replyHandler: nil) { [weak self] _ in
                Task { @MainActor in self?.status = .disconnected }
            }
        } else {
            session?.transferUserInfo([
                "RefTraceHeadRefTimeoutRequestID": requestID.uuidString,
                "gameID": gameID.uuidString,
                "source": source.rawValue,
                "requestedAt": Date().timeIntervalSince1970
            ])
            status = .lastUpdated(Date())
        }
        #else
        status = .lastUpdated(Date())
        #endif
        return requestID
    }
}

#if canImport(WatchConnectivity)
extension RefTraceWatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if error != nil {
                status = .disconnected
            } else {
                status = activationState == .activated ? .live : .disconnected
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            status = session.isReachable ? .live : .disconnected
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
