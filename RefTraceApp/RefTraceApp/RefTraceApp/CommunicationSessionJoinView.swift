import SwiftUI

struct CommunicationSessionJoinView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var communicationStore: CommunicationStore
    @EnvironmentObject private var router: RefTraceAppRouter
    @State private var sessionCode = ""
    @State private var errorMessage: String?
    let gameID: UUID

    private var game: RefTraceGame? { gameStore.games.first { $0.id == gameID } }

    var body: some View {
        Form {
            Section("Join Options") {
                Text("Join through the current active RefTrace game, OfficialEase assignment, secure invitation, one-time session code, or approved deep link.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Session code", text: $sessionCode)
                    .textInputAutocapitalization(.characters)
                Button("Join Communication Session") { join() }
                    .buttonStyle(.borderedProminent)
            }
            Section("Validation") {
                Text("RefTrace validates official identity, assignment membership, session status, capacity, session code, invitation state, and device registration. Production validation requires the secure backend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Section("Unable to Join") { Text(errorMessage).foregroundStyle(RefTraceTheme.warning) }
            }
        }
        .navigationTitle("Join Communication")
        .onAppear {
            if let active = communicationStore.activeSession(for: gameID) { sessionCode = active.sessionCode }
        }
    }

    private func join() {
        guard let game else { errorMessage = CommunicationError.gameNotFound.localizedDescription; return }
        do {
            try communicationStore.join(sessionCode: sessionCode, game: game, profile: gameStore.profile)
            router.go(.officialsCommunication(game.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
