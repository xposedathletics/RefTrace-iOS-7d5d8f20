import SwiftUI

struct GameCommunicationHistoryView: View {
    @EnvironmentObject private var communicationStore: CommunicationStore
    @State private var filter = "All"
    let gameID: UUID

    private let filters = ["All", "Entire Crew", "Private", "Voice", "Text", "Important", "Urgent", "Acknowledged"]
    private var session: CommunicationSession? { communicationStore.activeSession(for: gameID) ?? communicationStore.sessions.first { $0.gameID == gameID } }

    var body: some View {
        List {
            Picker("Filter", selection: $filter) {
                ForEach(filters, id: \.self) { Text($0).tag($0) }
            }

            if let session {
                Section("Messages") {
                    let messages = filteredMessages(sessionID: session.id)
                    if messages.isEmpty { Text("No messages match this filter.").foregroundStyle(.secondary) }
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(message.senderDisplayName) to \(message.recipientDisplayNames.joined(separator: ", "))")
                                .font(.subheadline.weight(.semibold))
                            Text(message.textBody)
                            if let transcript = message.transcriptBody {
                                Text("Automated transcript - may contain errors: \(transcript)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(message.communicationType.rawValue) • \(message.deliveryStatus.rawValue) • \(message.acknowledgmentStatus.rawValue) • \(message.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Voice Metadata") {
                    let transmissions = communicationStore.voiceTransmissions.filter { $0.sessionID == session.id }
                    if transmissions.isEmpty { Text("No voice metadata is available.").foregroundStyle(.secondary) }
                    ForEach(transmissions) { transmission in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(transmission.senderDisplayName) voice transmission")
                                .font(.subheadline.weight(.semibold))
                            Text("Recipient: \(transmission.recipientType.rawValue) • Duration: \(transmission.durationMilliseconds.map { "\($0) ms" } ?? "In progress") • \(transmission.deliveryStatus.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if transmission.transcriptAvailable {
                                Text("Automated transcript available - may contain errors.")
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section("Event Log") {
                    ForEach(communicationStore.logs(for: session.id)) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.eventType.rawValue).font(.subheadline.weight(.semibold))
                            Text(log.detailsSummary).font(.caption).foregroundStyle(.secondary)
                            Text(log.timestamp.formatted(date: .abbreviated, time: .standard)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No communication history is available for this game.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Communication History")
    }

    private func filteredMessages(sessionID: UUID) -> [GameCommunicationMessage] {
        communicationStore.messages(for: sessionID).filter { message in
            switch filter {
            case "Entire Crew": return message.recipientType == .entireCrew
            case "Private": return message.recipientType == .individual || message.recipientType == .headOfficial
            case "Voice": return message.communicationType == .voiceMetadata
            case "Text": return [.text, .dictatedText, .quickMessage].contains(message.communicationType)
            case "Important": return message.priority == .important
            case "Urgent": return message.priority == .urgent
            case "Acknowledged": return message.acknowledgmentStatus == .acknowledged
            default: return true
            }
        }
    }
}
