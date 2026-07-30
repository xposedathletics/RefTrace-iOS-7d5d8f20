import SwiftUI

struct PeriodScrollStrip: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(gameState.periods.enumerated()), id: \.element.id) { index, period in
                Button(period.label) {
                    gameState.periodIdx = index
                    gameState.clock = period.maxSecs
                    gameState.running = false
                }
                .font(.headline.bold())
                .foregroundColor(gameState.periodIdx == index ? .black : Color(hex: "C9A84C"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gameState.periodIdx == index ? Color(hex: "C9A84C") : Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            Button("OT") {
                gameState.addOT()
            }
            .font(.headline.bold())
            .foregroundColor(gameState.periodLabel.hasPrefix("OT") ? .black : Color(hex: "C9A84C"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(gameState.periodLabel.hasPrefix("OT") ? Color(hex: "C9A84C") : Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            if gameState.periods.isEmpty {
                gameState.resetForSport()
            }
        }
    }
}