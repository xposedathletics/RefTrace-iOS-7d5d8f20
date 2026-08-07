import Foundation

struct VoiceRecipientResolver {
    enum Resolution: Equatable {
        case entireCrew
        case participant(CommunicationParticipant)
        case ambiguous([CommunicationParticipant])
        case notFound
    }

    static let ignoredCommandWords: Set<String> = [
        "send", "to", "talk", "message", "private", "reftrace", "official", "the", "my", "crew", "please"
    ]

    func resolve(_ spokenText: String, participants: [CommunicationParticipant]) -> Resolution {
        let normalized = Self.normalize(spokenText)
        guard !normalized.isEmpty else { return .notFound }
        if ["entire crew", "everyone", "team", "all"].contains(normalized) {
            return .entireCrew
        }
        if normalized == "head official", let head = participants.first(where: \.isHeadOfficial) {
            return .participant(head)
        }

        let reduced = normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !Self.ignoredCommandWords.contains($0) }
            .joined(separator: " ")
        let phrase = reduced.isEmpty ? normalized : reduced

        let fullMatches = participants.filter { Self.normalize($0.displayName) == phrase }
        if fullMatches.count == 1 { return .participant(fullMatches[0]) }
        if fullMatches.count > 1 { return .ambiguous(fullMatches) }

        let lastMatches = participants.filter { Self.normalize($0.officialLastName) == phrase }
        if lastMatches.count == 1 { return .participant(lastMatches[0]) }
        if lastMatches.count > 1 { return .ambiguous(lastMatches) }

        let firstMatches = participants.filter { Self.normalize($0.officialFirstName) == phrase }
        if firstMatches.count == 1 { return .participant(firstMatches[0]) }
        if firstMatches.count > 1 { return .ambiguous(firstMatches) }

        let positionMatches = participants.filter { Self.normalize($0.assignedPosition) == phrase }
        if positionMatches.count == 1 { return .participant(positionMatches[0]) }
        if positionMatches.count > 1 { return .ambiguous(positionMatches) }

        let aliasMatches = participants.filter { $0.normalizedSearchNames.contains(phrase) }
        if aliasMatches.count == 1 { return .participant(aliasMatches[0]) }
        if aliasMatches.count > 1 { return .ambiguous(aliasMatches) }

        return .notFound
    }

    static func normalize(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
