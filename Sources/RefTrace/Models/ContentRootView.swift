import SwiftUI

struct ContentRootView: View {
    @StateObject var gameState = GameState()
    @State var isSetup = true

    var body: some View {
        if isSetup {
            SetupView(gameState: gameState, isSetup: $isSetup)
        } else {
            if gameState.position == "Observer" {
                ObserverView(gameState: gameState)
            } else {
                GameDashboardScrollView(gameState: gameState)
            }
        }
    }
}
