import SwiftUI

struct RefTraceWatchGameView: View {
    let state: RefTraceWatchGameState?
    var openScoreLog: () -> Void = {}
    var requestTimeoutStop: () -> Void = {}

    var body: some View {
        Group {
            if let state {
                VStack(spacing: 8) {
                    Text(state.currentPeriod)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(state.gameClock.reconciled().displayText)
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Text("Game Clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let playClock = state.playClock {
                        Text(playClock.reconciled().displayText)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        Text("Play Clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("\(state.awayTeamAbbreviation) \(state.awayScore)")
                        Spacer()
                        Text("\(state.homeTeamAbbreviation) \(state.homeScore)")
                    }
                    .font(.headline.weight(.bold))
                    if state.isFootball && state.isHeadReferee {
                        Button {
                            requestTimeoutStop()
                        } label: {
                            Text("TIMEOUT")
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .accessibilityLabel("Timeout stop clock")
                    }
                    Button("Score & Log", action: openScoreLog)
                        .buttonStyle(.borderedProminent)
                    if let twoMinuteWarningMessage = state.twoMinuteWarningMessage {
                        Text(twoMinuteWarningMessage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    Text("Updated \(state.lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            } else {
                ContentUnavailableView("No Active Game", systemImage: "sportscourt")
            }
        }
    }
}

struct RefTraceWatchScoreView: View {
    let state: RefTraceWatchGameState
    var openScoreLog: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            Text(state.currentPeriod)
                .font(.caption.weight(.bold))
            HStack(spacing: 12) {
                VStack {
                    Text(state.awayTeamAbbreviation).font(.caption)
                    Text("\(state.awayScore)").font(.title.bold())
                }
                VStack {
                    Text(state.homeTeamAbbreviation).font(.caption)
                    Text("\(state.homeScore)").font(.title.bold())
                }
            }
            Text(state.gameClock.reconciled().displayText)
                .font(.system(.title2, design: .monospaced, weight: .bold))
            if let last = state.scoreLog.sorted(by: { $0.createdAt > $1.createdAt }).first {
                Text("Last: \(last.scoringTeamName) \(last.scoreType.displayName)")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            Button("Score Log", action: openScoreLog)
        }
        .padding(8)
    }
}

struct RefTraceWatchScoreLogView: View {
    let scoreLog: [ScoreEvent]

    var body: some View {
        List(scoreLog.sorted(by: { $0.createdAt > $1.createdAt })) { event in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(event.period) — \(event.gameClockTime)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(event.scoringTeamName) \(event.scoreType.displayName) +\(event.pointValue)")
                    .font(.caption.weight(.bold))
                Text("Home \(event.homeScoreAfter), Away \(event.awayScoreAfter)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("Score Log")
    }
}

struct RefTraceWatchViews_Previews: PreviewProvider {
    static var previews: some View {
        let game = RefTraceGameStore.sampleGames()[0]
        let store = RefTraceInGameStore(storageURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("watch-preview.json"))
        RefTraceWatchGameView(state: store.watchPayload(for: game))
        RefTraceWatchScoreLogView(scoreLog: [])
    }
}
