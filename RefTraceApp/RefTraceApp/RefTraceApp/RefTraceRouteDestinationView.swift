import SwiftUI

struct RefTraceRouteDestinationView: View {
    @EnvironmentObject private var store: RefTraceGameStore
    let route: RefTraceAppRouter.Route

    var body: some View {
        switch route {
        case .home:
            RefTraceHomeView()
        case .createGame:
            CreateRefTraceGameView()
        case .importOfficialEaseGame:
            OfficialEaseGameImportView()
        case .importPreview(let transferID):
            OfficialEaseGameImportPreviewView(transferID: transferID)
        case .gameManagement(let gameID):
            RefTraceGameManagementView(gameID: gameID)
        case .inGame(let gameID):
            RefTraceInGameView(gameID: gameID)
        case .scoreLog(let gameID):
            RefTraceScoreLogView(gameID: gameID)
        case .gameLog(let gameID):
            RefTraceGameLogView(gameID: gameID)
        case .gameSummary(let gameID):
            RefTraceGameSummaryView(gameID: gameID)
        case .inGameTesting(let gameID):
            #if DEBUG
            RefTraceInGameTestingView(gameID: gameID)
            #else
            RefTraceInGameView(gameID: gameID)
            #endif
        case .officialsCommunication(let gameID):
            OfficialsCommunicationView(gameID: gameID)
        case .communicationSetup(let gameID):
            CommunicationSessionSetupView(gameID: gameID)
        case .communicationJoin(let gameID):
            CommunicationSessionJoinView(gameID: gameID)
        case .communicationParticipants(let gameID):
            CommunicationParticipantsView(gameID: gameID)
        case .communicationHistory(let gameID):
            GameCommunicationHistoryView(gameID: gameID)
        case .communicationTesting(let gameID):
            #if DEBUG
            OfficialsCommunicationTestingView(gameID: gameID)
            #else
            OfficialsCommunicationView(gameID: gameID)
            #endif
        case .activeGame:
            if let activeGame = store.activeGame {
                RefTraceInGameView(gameID: activeGame.id)
            } else {
                ContentUnavailableView("No Active Game", systemImage: "sportscourt")
            }
        case .completedGames:
            RefTraceGameHistoryView(completedOnly: true)
        case .gameHistory:
            RefTraceGameHistoryView(completedOnly: false)
        case .rules:
            RefTraceRulesView()
        case .settings:
            RefTraceSettingsView()
        case .syncStatus:
            RefTraceSyncStatusView()
        case .upcomingGames:
            RefTraceUpcomingGamesView()
        case .homeTesting:
            #if DEBUG
            RefTraceHomeTestingView()
            #else
            RefTraceSettingsView()
            #endif
        case .gameViewerDiscovery:
            GameViewerDiscoveryView()
        case .gameViewer(let publicGameReference):
            CoachParentObserverGameView(publicGameReference: publicGameReference)
        case .gameViewerCode:
            EnterGameViewerCodeView()
        case .gameViewerAccessPreview(let publicGameReference):
            GameViewerAccessPreviewView(publicGameReference: publicGameReference)
        case .gameViewerAccessManagement(let publicGameReference):
            GameViewerAccessManagementView(publicGameReference: publicGameReference)
        case .spectatorPortalTesting:
            #if DEBUG
            CoachParentObserverPortalTestingView()
            #else
            GameViewerDiscoveryView()
            #endif
        }
    }
}
