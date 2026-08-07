import Foundation
import SwiftUI
import Combine

@MainActor
final class RefTraceAppRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var pendingDeepLinkTransferID: String?
    @Published var pendingViewerToken: String?

    enum Route: Hashable {
        case home
        case createGame
        case importOfficialEaseGame
        case importPreview(String)
        case gameManagement(UUID)
        case inGame(UUID)
        case scoreLog(UUID)
        case gameLog(UUID)
        case gameSummary(UUID)
        case inGameTesting(UUID)
        case officialsCommunication(UUID)
        case communicationSetup(UUID)
        case communicationJoin(UUID)
        case communicationParticipants(UUID)
        case communicationHistory(UUID)
        case communicationTesting(UUID)
        case activeGame
        case completedGames
        case gameHistory
        case rules
        case settings
        case syncStatus
        case upcomingGames
        case homeTesting
        case gameViewerDiscovery
        case gameViewer(String)
        case gameViewerCode
        case gameViewerAccessPreview(String)
        case gameViewerAccessManagement(String)
        case spectatorPortalTesting
    }

    func go(_ route: Route) {
        if route == .home {
            path = NavigationPath()
        } else {
            path.append(route)
        }
    }

    func handleIncomingURL(_ url: URL) {
        if let viewerToken = Self.viewerToken(from: url) {
            pendingViewerToken = viewerToken
            path = NavigationPath()
            path.append(Route.gameViewerAccessPreview(viewerToken))
            return
        }

        guard let transferID = Self.transferID(from: url) else { return }
        pendingDeepLinkTransferID = transferID
        path = NavigationPath()
        path.append(Route.importPreview(transferID))
    }

    static func transferID(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let transferID = components?.queryItems?.first(where: { $0.name == "transferID" })?.value
        let validScheme = url.scheme == "reftrace" || url.host == "reftrace.com"
        let validPath = url.path == "/game/start" || url.host == "game"
        guard validScheme, validPath, let transferID, !transferID.isEmpty else { return nil }
        return transferID
    }

    static func viewerToken(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let token = components?.queryItems?.first(where: { $0.name == "token" })?.value
        if url.scheme == "reftrace", url.host == "view-game", let token, !token.isEmpty {
            return token
        }
        if url.host == "reftrace.com", url.path.hasPrefix("/view-game/") {
            let value = String(url.path.dropFirst("/view-game/".count))
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
