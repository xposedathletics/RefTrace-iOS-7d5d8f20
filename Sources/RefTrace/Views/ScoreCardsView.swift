import SwiftUI

struct ScoreCardsView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack(spacing: 16) {
            TeamScoreCard(
                teamName: gameState.homeTeam,
                score: gameState.homeScore,
                onIncrement: { gameState.incrementHome() },
                onDecrement: { gameState.decrementHome() },
                isHead: gameState.isHeadRef
            )
            TeamScoreCard(
                teamName: gameState.awayTeam,
                score: gameState.awayScore,
                onIncrement: { gameState.incrementAway() },
                onDecrement: { gameState.decrementAway() },
                isHead: gameState.isHeadRef
            )
        }
    }
}

struct TeamScoreCard: View {
    var teamName: String
    var score: Int
    var onIncrement: () -> Void
    var onDecrement: () -> Void
    var isHead: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(teamName)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("\(score)")
                .font(.system(size: 80, weight: .black))
                .foregroundColor(Color(hex: "C9A84C"))
            if isHead {
                HStack(spacing: 24) {
                    Button("-") { onDecrement() }
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(10)
                    Button("+") { onIncrement() }
                        .font(.title.bold())
                        .foregroundColor(.black)
                        .padding()
                        .background(Color(hex: "C9A84C"))
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
    }
}