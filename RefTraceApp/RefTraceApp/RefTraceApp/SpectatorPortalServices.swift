import Foundation
import Combine

protocol SpectatorGameStateService {
    func currentState(publicGameReference: String) async throws -> SpectatorGameState
    func updates(publicGameReference: String) -> AsyncStream<SpectatorGameState>
}

protocol SpectatorGameAccessService {
    func validateAccess(_ request: SpectatorViewerAPI.ValidateAccessRequest) async throws -> SpectatorViewerAPI.ValidateAccessResponse
}

protocol SpectatorGameDiscoveryService {
    func availableGames(role: SpectatorUserRole) async throws -> [SpectatorGameSummary]
    func liveGames(role: SpectatorUserRole) async throws -> [SpectatorGameSummary]
    func upcomingGames(role: SpectatorUserRole) async throws -> [SpectatorGameSummary]
}

protocol SpectatorConnectionService {
    func reconnect(publicGameReference: String) async throws -> SpectatorGameState
    func stopViewing(publicGameReference: String) async
}

protocol SpectatorViewerTokenService {
    func validate(codeOrToken: String, role: SpectatorUserRole) async throws -> GameViewerToken
    func removeExpiredTokens() async
}

protocol SpectatorAccessLogRepository {
    func record(_ log: SpectatorAccessLog) async
    func logs(publicGameReference: String) async -> [SpectatorAccessLog]
}

struct SpectatorClockDisplayService {
    var safeStaleInterval: TimeInterval = 45

    func displayText(for state: SpectatorGameState, now: Date = Date()) -> String {
        let remaining = renderedRemainingTime(for: state, now: now)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func renderedRemainingTime(for state: SpectatorGameState, now: Date = Date()) -> TimeInterval {
        guard state.gameClockIsRunning, let reference = state.clockReferenceTimestamp, !state.isFinal else {
            return max(0, state.gameClockRemaining)
        }
        guard now.timeIntervalSince(state.lastUpdatedAt) <= safeStaleInterval else {
            return max(0, state.gameClockRemaining)
        }
        return max(0, state.gameClockRemaining - max(0, now.timeIntervalSince(reference)))
    }

    func dataStatus(for state: SpectatorGameState, now: Date = Date()) -> SpectatorDataStatus {
        if state.isFinal { return .final }
        if state.dataStatus == .reconnecting { return .reconnecting }
        if now.timeIntervalSince(state.lastUpdatedAt) > safeStaleInterval { return .unavailable }
        return state.dataStatus
    }

    func shouldAccept(current: SpectatorGameState?, incoming: SpectatorGameState) -> Bool {
        guard let current else { return true }
        guard current.publicGameReference == incoming.publicGameReference else { return true }
        return incoming.stateVersion >= current.stateVersion
    }
}

@MainActor
final class LocalSpectatorGameStateService: SpectatorGameStateService, SpectatorGameDiscoveryService, SpectatorGameAccessService, SpectatorConnectionService, SpectatorViewerTokenService, SpectatorAccessLogRepository {
    private let gameStore: RefTraceGameStore
    private let inGameStore: RefTraceInGameStore
    private var accessPolicies: [String: SpectatorAccessPolicy] = [:]
    private var tokens: [String: GameViewerToken] = [:]
    private var accessLogs: [String: [SpectatorAccessLog]] = [:]

    init(gameStore: RefTraceGameStore, inGameStore: RefTraceInGameStore) {
        self.gameStore = gameStore
        self.inGameStore = inGameStore
        seedTokens()
    }

    func currentState(publicGameReference: String) async throws -> SpectatorGameState {
        guard let game = game(matching: publicGameReference) else { throw SpectatorPortalError.gameUnavailable }
        let policy = accessPolicies[publicGameReference] ?? SpectatorAccessPolicy()
        guard policy.accessLevel != .private else { throw SpectatorPortalError.viewerAccessDisabled }
        return SpectatorGameState.from(game: game, state: inGameStore.displayState(for: game), policy: policy)
    }

    func updates(publicGameReference: String) -> AsyncStream<SpectatorGameState> {
        AsyncStream { continuation in
            Task { @MainActor in
                if let state = try? await currentState(publicGameReference: publicGameReference) {
                    continuation.yield(state)
                }
                continuation.finish()
            }
        }
    }

    func availableGames(role: SpectatorUserRole) async throws -> [SpectatorGameSummary] {
        gameStore.games.map { summary(for: $0) }.sorted { $0.scheduledStartTime < $1.scheduledStartTime }
    }

    func liveGames(role: SpectatorUserRole) async throws -> [SpectatorGameSummary] {
        try await availableGames(role: role).filter { [.active, .clockStopped, .halftime, .overtime].contains($0.gameStatus) }
    }

    func upcomingGames(role: SpectatorUserRole) async throws -> [SpectatorGameSummary] {
        try await availableGames(role: role).filter { $0.gameStatus == .scheduled }
    }

    func validateAccess(_ request: SpectatorViewerAPI.ValidateAccessRequest) async throws -> SpectatorViewerAPI.ValidateAccessResponse {
        if let token = tokens[request.tokenOrCode] {
            if token.isRevoked { throw SpectatorPortalError.revokedCode }
            if token.isExpired { throw SpectatorPortalError.expiredCode }
            recordAccess(publicGameReference: token.publicGameReference, role: request.role, method: request.accessMethod, result: .allowed, tokenReference: token.tokenReference)
            return SpectatorViewerAPI.ValidateAccessResponse(allowed: true, publicGameReference: token.publicGameReference, tokenReference: token.tokenReference, expiresAt: token.expiresAt, errorCode: nil)
        }
        if game(matching: request.tokenOrCode) != nil {
            recordAccess(publicGameReference: request.tokenOrCode, role: request.role, method: request.accessMethod, result: .allowed, tokenReference: nil)
            return SpectatorViewerAPI.ValidateAccessResponse(allowed: true, publicGameReference: request.tokenOrCode, tokenReference: nil, expiresAt: nil, errorCode: nil)
        }
        throw SpectatorPortalError.invalidCode
    }

    func reconnect(publicGameReference: String) async throws -> SpectatorGameState {
        var state = try await currentState(publicGameReference: publicGameReference)
        state.dataStatus = .live
        return state
    }

    func stopViewing(publicGameReference: String) async {
        recordAccess(publicGameReference: publicGameReference, role: .observer, method: .authenticatedRefTrace, result: .allowed, tokenReference: nil, ended: true)
    }

    func validate(codeOrToken: String, role: SpectatorUserRole) async throws -> GameViewerToken {
        guard let token = tokens[codeOrToken] else { throw SpectatorPortalError.invalidCode }
        if token.isRevoked { throw SpectatorPortalError.revokedCode }
        if token.isExpired { throw SpectatorPortalError.expiredCode }
        return token
    }

    func removeExpiredTokens() async {
        tokens = tokens.filter { !$0.value.isExpired }
    }

    func record(_ log: SpectatorAccessLog) async {
        accessLogs[log.publicGameReference, default: []].append(log)
    }

    func logs(publicGameReference: String) async -> [SpectatorAccessLog] {
        accessLogs[publicGameReference, default: []]
    }

    func setPolicy(_ policy: SpectatorAccessPolicy, publicGameReference: String) {
        accessPolicies[publicGameReference] = policy
    }

    func generateViewerCode(publicGameReference: String, role: SpectatorUserRole = .authorizedViewer, expiresAt: Date = Date().addingTimeInterval(3600)) -> String {
        let code = "VIEW-\(Int.random(in: 1000...9999))"
        tokens[code] = GameViewerToken(tokenReference: code, publicGameReference: publicGameReference, role: role, expiresAt: expiresAt)
        return code
    }

    func revokeViewerCode(_ code: String) {
        guard var token = tokens[code] else { return }
        token.revokedAt = Date()
        tokens[code] = token
    }

    private func seedTokens() {
        for game in gameStore.games {
            let reference = SpectatorGameState.publicReference(for: game)
            tokens[reference] = GameViewerToken(tokenReference: reference, publicGameReference: reference, role: .authorizedViewer, expiresAt: Date().addingTimeInterval(24 * 3600))
        }
    }

    private func summary(for game: RefTraceGame) -> SpectatorGameSummary {
        let state = inGameStore.displayState(for: game)
        let policy = accessPolicies[SpectatorGameState.publicReference(for: game)] ?? SpectatorAccessPolicy()
        return SpectatorGameSummary(
            publicGameReference: SpectatorGameState.publicReference(for: game),
            sport: game.sport,
            leagueName: game.leagueName,
            homeTeamName: game.homeTeamName,
            homeTeamMascotReference: policy.allowTeamMascots ? game.homeTeamMascot : "",
            awayTeamName: game.awayTeamName,
            awayTeamMascotReference: policy.allowTeamMascots ? game.awayTeamMascot : "",
            scheduledStartTime: game.scheduledStartTime,
            gameStatus: SpectatorGameStatus(status: state.status, game: game),
            dataStatus: game.status == .completed ? .final : .live,
            accessPolicy: policy
        )
    }

    private func game(matching publicGameReference: String) -> RefTraceGame? {
        gameStore.games.first { SpectatorGameState.publicReference(for: $0) == publicGameReference || $0.id.uuidString == publicGameReference }
    }

    private func recordAccess(publicGameReference: String, role: SpectatorUserRole, method: SpectatorAccessMethod, result: SpectatorAccessResult, tokenReference: String?, ended: Bool = false) {
        let game = game(matching: publicGameReference)
        let log = SpectatorAccessLog(
            publicGameReference: publicGameReference,
            gameID: game?.id,
            viewerUserID: nil,
            viewerRole: role,
            accessMethod: method,
            accessResult: result,
            sessionStartedAt: ended ? nil : Date(),
            sessionEndedAt: ended ? Date() : nil,
            lastSeenAt: Date(),
            deviceReference: "local-viewer-device",
            tokenReference: tokenReference,
            failureReasonCode: result == .allowed ? nil : result.rawValue
        )
        accessLogs[publicGameReference, default: []].append(log)
    }
}

struct BackendSpectatorGameStateService: SpectatorGameStateService {
    func currentState(publicGameReference: String) async throws -> SpectatorGameState {
        throw SpectatorPortalError.networkUnavailable
    }

    func updates(publicGameReference: String) -> AsyncStream<SpectatorGameState> {
        AsyncStream { continuation in continuation.finish() }
    }
}

struct MockSpectatorGameStateService: SpectatorGameStateService {
    var state: SpectatorGameState

    func currentState(publicGameReference: String) async throws -> SpectatorGameState { state }
    func updates(publicGameReference: String) -> AsyncStream<SpectatorGameState> {
        AsyncStream { continuation in
            continuation.yield(state)
            continuation.finish()
        }
    }
}
