import SwiftUI

struct FootballGameClockLogView: View {
    @EnvironmentObject private var gameStore: RefTraceGameStore
    @EnvironmentObject private var inGameStore: RefTraceInGameStore
    let gameID: UUID
    @State private var filter: FootballClockLogFilter = .all

    private var events: [GameEventRecord] {
        inGameStore.gameEvents[gameID, default: []]
            .filter { filter.matches($0) }
            .sorted { $0.sequenceNumber > $1.sequenceNumber }
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(FootballClockLogFilter.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            if events.isEmpty {
                ContentUnavailableView("No Football Clock Events", systemImage: "timer")
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.eventType.rawValue)
                                .font(.headline)
                            Spacer()
                            Text("#\(event.sequenceNumber)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(event.period) - \(event.gameClockTime)")
                            .font(.subheadline.weight(.semibold))
                        Text(event.details)
                            .font(.body)
                        HStack {
                            if let officialName = event.officialName {
                                Text(officialName)
                            }
                            if let officialPosition = event.officialPosition {
                                Text(officialPosition)
                            }
                            Text(event.sourceApp)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Football Clock Log")
    }
}

enum FootballClockLogFilter: String, CaseIterable, Identifiable {
    case all
    case whistles
    case gameClock
    case playClock
    case timeouts
    case corrections
    case twoMinuteWarning
    case deviceEvents

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .all: return "All"
        case .whistles: return "Whistles"
        case .gameClock: return "Game Clock"
        case .playClock: return "Play Clock"
        case .timeouts: return "Timeouts"
        case .corrections: return "Corrections"
        case .twoMinuteWarning: return "2-Minute"
        case .deviceEvents: return "Devices"
        }
    }

    func matches(_ event: GameEventRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .whistles:
            return [.openingWhistleArmed, .openingWhistleDetected, .openingWhistleRejected, .crewWhistleDetected, .crewWhistleMerged, .crewWhistleRejected, .endOfPlayDetected].contains(event.eventType)
        case .gameClock:
            return [.startGameSelected, .gameClockStarted, .gameClockStopped, .gameClockResumed, .gameClockAdjusted].contains(event.eventType)
        case .playClock:
            return [.playClockStarted, .playClockStopped, .playClockReset, .playClockExpired].contains(event.eventType)
        case .timeouts:
            return [.timeoutRequested, .timeoutClockStopped, .timeoutRecorded, .timeoutTaken, .timeoutCorrected].contains(event.eventType)
        case .corrections:
            return [.gameClockAdjusted, .timeoutCorrected].contains(event.eventType)
        case .twoMinuteWarning:
            return [.twoMinutePreAlertSent, .twoMinuteWarningReached].contains(event.eventType)
        case .deviceEvents:
            return [.watchClockCommand, .watchCommandPending, .watchCommandConfirmed, .watchCommandFailed, .deviceDisconnected, .deviceReconnected].contains(event.eventType)
        }
    }
}
