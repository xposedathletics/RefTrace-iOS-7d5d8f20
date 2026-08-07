import Foundation
import Combine

@MainActor
final class CoachParentObserverGameViewModel: ObservableObject {
    @Published private(set) var gameState: SpectatorGameState?
    @Published private(set) var gameClockDisplay = "--:--"
    @Published private(set) var dataStatus: SpectatorDataStatus = .updating
    @Published private(set) var isLoading = false
    @Published var accessError: String?
    @Published var connectionError: String?

    private let clockService: SpectatorClockDisplayService
    private var updateTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?

    init() {
        self.clockService = SpectatorClockDisplayService()
    }

    init(clockService: SpectatorClockDisplayService) {
        self.clockService = clockService
    }

    var homeTeam: String { gameState?.homeTeamName ?? "Home" }
    var awayTeam: String { gameState?.awayTeamName ?? "Away" }
    var homeScore: Int { gameState?.homeScore ?? 0 }
    var awayScore: Int { gameState?.awayScore ?? 0 }
    var currentPeriod: String { gameState?.currentPeriod ?? "Pregame" }
    var possession: PossessionState { gameState?.possession ?? .unknown }
    var gameStatus: SpectatorGameStatus { gameState?.gameStatus ?? .unavailable }
    var lastUpdatedAt: Date? { gameState?.lastUpdatedAt }

    func loadGame(publicGameReference: String, service: SpectatorGameStateService & SpectatorGameAccessService) async {
        isLoading = true
        accessError = nil
        connectionError = nil
        do {
            let validation = try await service.validateAccess(
                SpectatorViewerAPI.ValidateAccessRequest(
                    tokenOrCode: publicGameReference,
                    role: .authorizedViewer,
                    accessMethod: .authenticatedRefTrace
                )
            )
            guard validation.allowed, let reference = validation.publicGameReference else { throw SpectatorPortalError.accessDenied }
            let snapshot = try await service.currentState(publicGameReference: reference)
            processStateSnapshot(snapshot)
            connectToGameUpdates(publicGameReference: reference, service: service)
            startTicker()
        } catch {
            accessError = (error as? LocalizedError)?.errorDescription ?? "Live game viewing is not available for this game."
        }
        isLoading = false
    }

    func validateAccess(codeOrToken: String, role: SpectatorUserRole, service: SpectatorGameAccessService) async -> String? {
        do {
            let validation = try await service.validateAccess(
                SpectatorViewerAPI.ValidateAccessRequest(tokenOrCode: codeOrToken, role: role, accessMethod: .viewerCode)
            )
            return validation.allowed ? validation.publicGameReference : nil
        } catch {
            accessError = (error as? LocalizedError)?.errorDescription ?? "You do not have permission to view this game."
            return nil
        }
    }

    func connectToGameUpdates(publicGameReference: String, service: SpectatorGameStateService) {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            for await state in service.updates(publicGameReference: publicGameReference) {
                if Task.isCancelled { break }
                await MainActor.run {
                    self.processStateSnapshot(state)
                }
            }
        }
    }

    func processStateSnapshot(_ snapshot: SpectatorGameState) {
        guard clockService.shouldAccept(current: gameState, incoming: snapshot) else { return }
        gameState = snapshot
        reconcileState()
    }

    func processScoreUpdate(_ update: SpectatorScoreUpdate) {
        guard var state = gameState, update.stateVersion >= state.stateVersion else { return }
        state.homeScore = update.homeScore
        state.awayScore = update.awayScore
        state.stateVersion = update.stateVersion
        state.lastUpdatedAt = update.occurredAt
        processStateSnapshot(state)
    }

    func processClockUpdate(_ update: SpectatorClockUpdate) {
        guard var state = gameState, update.stateVersion >= state.stateVersion else { return }
        state.gameClockRemaining = update.remainingTime
        state.gameClockIsRunning = update.isRunning
        state.clockReferenceTimestamp = update.referenceTimestamp
        state.currentPeriod = update.currentPeriod
        state.stateVersion = update.stateVersion
        state.lastUpdatedAt = update.occurredAt
        processStateSnapshot(state)
    }

    func processPossessionUpdate(_ update: SpectatorPossessionUpdate) {
        guard var state = gameState, update.stateVersion >= state.stateVersion else { return }
        state.possession = update.possession
        state.stateVersion = update.stateVersion
        state.lastUpdatedAt = update.occurredAt
        processStateSnapshot(state)
    }

    func processGameStatusUpdate(_ update: SpectatorGameStatusUpdate) {
        guard var state = gameState, update.stateVersion >= state.stateVersion else { return }
        state.gameStatus = update.gameStatus
        state.isFinal = update.gameStatus == .completed
        state.dataStatus = state.isFinal ? .final : state.dataStatus
        state.stateVersion = update.stateVersion
        state.lastUpdatedAt = update.occurredAt
        processStateSnapshot(state)
    }

    func reconcileState(now: Date = Date()) {
        guard let state = gameState else {
            gameClockDisplay = "--:--"
            dataStatus = .unavailable
            return
        }
        gameClockDisplay = clockService.displayText(for: state, now: now)
        dataStatus = clockService.dataStatus(for: state, now: now)
    }

    func handleConnectionLoss() {
        connectionError = "Live updates are temporarily unavailable. Showing the last received game state."
        if var state = gameState {
            state.dataStatus = .reconnecting
            gameState = state
        }
        reconcileState()
    }

    func reconnect(publicGameReference: String, service: SpectatorConnectionService) async {
        do {
            let snapshot = try await service.reconnect(publicGameReference: publicGameReference)
            connectionError = nil
            processStateSnapshot(snapshot)
        } catch {
            handleConnectionLoss()
        }
    }

    func stopViewing(publicGameReference: String, service: SpectatorConnectionService) async {
        updateTask?.cancel()
        tickerTask?.cancel()
        await service.stopViewing(publicGameReference: publicGameReference)
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self?.reconcileState()
                }
            }
        }
    }
}
