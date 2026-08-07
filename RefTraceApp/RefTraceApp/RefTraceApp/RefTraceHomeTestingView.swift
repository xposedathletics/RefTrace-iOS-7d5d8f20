import SwiftUI

#if DEBUG
struct RefTraceHomeTestingView: View {
    @EnvironmentObject private var store: RefTraceGameStore
    @EnvironmentObject private var router: RefTraceAppRouter

    var body: some View {
        List {
            Section("Upcoming Games") {
                Button("No upcoming games") { store.loadNoUpcomingGames() }
                Button("One OfficialEase upcoming game") { store.loadPendingOfficialEaseSample(count: 1) }
                Button("Three upcoming games") { store.loadThreeUpcomingGames() }
                Button("One manual RefTrace game") { store.loadManualUpcomingGame() }
                Button("Duplicate OfficialEase and RefTrace records") { store.loadDuplicateUpcomingRecords() }
                Button("Awaiting response") { store.loadAwaitingResponseUpcoming() }
                Button("Accepted assignment") { store.loadAcceptedUpcoming() }
                Button("Imported game") { store.loadImportedUpcomingGame() }
                Button("Active game") { store.loadActiveSample() }
                Button("Completed game removed from upcoming") { store.loadCompletedGameRemovedFromUpcoming() }
                Button("Offline cached game") { store.loadOfflineCachedUpcomingGame() }
                Button("Sync failure") { store.simulateSyncFailure() }
                Button("Missing mascot") { store.loadMissingMascotUpcoming() }
                Button("Long league and team names") { store.loadLongNameUpcoming() }
            }

            Section("Original Home Fixtures") {
                Button("Load Empty Home Screen") { store.resetAllTestData() }
                Button("Load One Pending OfficialEase Game") { store.loadPendingOfficialEaseSample(count: 1) }
                Button("Load Multiple Pending OfficialEase Games") { store.loadPendingOfficialEaseSample(count: 4) }
                Button("Load One Active Game") { store.loadActiveSample() }
                Button("Load Five Recent Games") { store.loadRecentSamples() }
                Button("Simulate Offline Mode") { store.simulateOffline() }
                Button("Simulate Sync Failure") { store.simulateSyncFailure() }
                Button("Simulate Expired Transfer") { store.simulateExpiredTransfer() }
                Button("Simulate Transfer for Another Official") { store.simulateWrongOfficialTransfer() }
                Button("Create a Manual Game") { router.go(.createGame) }
                Button("Import an OfficialEase Game") { router.go(.importOfficialEaseGame) }
                Button("Resume an Active Game") {
                    if let activeGame = store.activeGame { router.go(.gameManagement(activeGame.id)) }
                }
                Button("Complete a Game") {
                    if let activeGame = store.activeGame { try? store.complete(activeGame) }
                }
                Button("Reset test data", role: .destructive) { store.resetAllTestData() }
            }
        }
        .navigationTitle("Home Testing")
    }
}
#endif
