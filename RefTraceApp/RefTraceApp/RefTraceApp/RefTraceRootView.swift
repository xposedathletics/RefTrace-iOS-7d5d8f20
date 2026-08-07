import SwiftUI

struct RefTraceRootView: View {
    @StateObject private var router = RefTraceAppRouter()
    @StateObject private var store: RefTraceGameStore
    @StateObject private var communicationStore = CommunicationStore()
    @StateObject private var inGameStore = RefTraceInGameStore()
    @StateObject private var watchManager = RefTraceWatchConnectivityManager()
    @State private var didApplyUITestRoute = false

    init() {
        _store = StateObject(wrappedValue: Self.makeInitialStore())
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            rootContent
                .navigationDestination(for: RefTraceAppRouter.Route.self) { route in
                    RefTraceRouteDestinationView(route: route)
                }
        }
        .environmentObject(router)
        .environmentObject(store)
        .environmentObject(communicationStore)
        .environmentObject(inGameStore)
        .environmentObject(watchManager)
        .onOpenURL { url in
            router.handleIncomingURL(url)
        }
        .onAppear {
            #if DEBUG
            if !didApplyUITestRoute && (ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_IN_GAME") || ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_VIEWER")) {
                didApplyUITestRoute = true
                store.resetAllTestData()
                store.loadActiveSample()
                communicationStore.resetDemoData()
                inGameStore.resetDemoData()
            } else if ProcessInfo.processInfo.arguments.contains("UITEST_ACTIVE_GAME") {
                store.resetAllTestData()
                store.loadActiveSample()
                communicationStore.resetDemoData()
                inGameStore.resetDemoData()
            } else if ProcessInfo.processInfo.arguments.contains("UITEST_RESET_DATA") {
                store.resetAllTestData()
                store.loadPendingOfficialEaseSample(count: 1)
                communicationStore.resetDemoData()
                inGameStore.resetDemoData()
            }
            #endif
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_IN_GAME"), let activeGame = store.activeGame {
            RefTraceInGameView(gameID: activeGame.id)
        } else if ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_VIEWER"), let activeGame = store.activeGame {
            CoachParentObserverGameView(publicGameReference: SpectatorGameState.publicReference(for: activeGame))
        } else {
            RefTraceHomeView()
        }
        #else
        RefTraceHomeView()
        #endif
    }

    private static func makeInitialStore() -> RefTraceGameStore {
        let store = RefTraceGameStore()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_IN_GAME") || ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_VIEWER") || ProcessInfo.processInfo.arguments.contains("UITEST_ACTIVE_GAME") {
            store.resetAllTestData()
            store.loadActiveSample()
        } else if ProcessInfo.processInfo.arguments.contains("UITEST_RESET_DATA") {
            store.resetAllTestData()
            store.loadPendingOfficialEaseSample(count: 1)
        }
        #endif
        return store
    }
}
