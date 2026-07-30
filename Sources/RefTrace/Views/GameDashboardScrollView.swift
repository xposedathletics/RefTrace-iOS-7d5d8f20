import SwiftUI

struct GameDashboardScrollView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        ZStack {
            Color(hex: "0f1e3d").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    ScoreCardsView(gameState: gameState)
                    PeriodScrollStrip(gameState: gameState)
                    if gameState.isHeadRef {
                        PenaltyView(gameState: gameState)
                    }
                }
                .padding()
            }
        }
    }
}
