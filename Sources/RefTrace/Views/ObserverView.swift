import SwiftUI

struct ObserverView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        ZStack {
            Color(hex: "0f1e3d").ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Observer View")
                    .font(.title.bold())
                    .foregroundColor(Color(hex: "C9A84C"))
                Text("Period \(gameState.periodLabel)")
                    .foregroundColor(.white)
                HStack(spacing: 40) {
                    VStack {
                        Text(gameState.homeTeam)
                            .foregroundColor(.white)
                        Text("\(gameState.homeScore)")
                            .font(.system(size: 60, weight: .black))
                            .foregroundColor(Color(hex: "C9A84C"))
                    }
                    Text("VS")
                        .foregroundColor(.white.opacity(0.5))
                    VStack {
                        Text(gameState.awayTeam)
                            .foregroundColor(.white)
                        Text("\(gameState.awayScore)")
                            .font(.system(size: 60, weight: .black))
                            .foregroundColor(Color(hex: "C9A84C"))
                    }
                }
                Text("Read Only — Observer Mode")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
