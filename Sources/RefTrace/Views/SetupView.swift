import SwiftUI

struct SetupView: View {
    @ObservedObject var gameState: GameState
    @Binding var isSetup: Bool

    var body: some View {
        ZStack {
            Color(hex: "0f1e3d").ignoresSafeArea()
            VStack(spacing: 24) {
                Text("RefTrace")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color(hex: "C9A84C"))

                TextField("Home Team", text: $gameState.homeTeam)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextField("Away Team", text: $gameState.awayTeam)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextField("Session Code", text: $gameState.sessionCode)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Picker("Role", selection: $gameState.position) {
                    Text("Head Referee").tag("Head Referee")
                    Text("Crew").tag("Crew")
                    Text("Observer").tag("Observer")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Button("Start Game") {
                    isSetup = false
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "C9A84C"))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
}
