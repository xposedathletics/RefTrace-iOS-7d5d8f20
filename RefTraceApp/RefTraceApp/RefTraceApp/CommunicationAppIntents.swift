import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, *)
struct OpenOfficialsCommunicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open RefTrace Communications"
    static var description = IntentDescription("Opens the active RefTrace officials communication screen when a session exists.")

    func perform() async throws -> some IntentResult {
        .result(dialog: "Open RefTrace and choose Officials Communication for the active game.")
    }
}

@available(iOS 16.0, *)
struct StartCrewTransmissionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Crew Transmission"
    static var description = IntentDescription("Starts a crew transmission when an active approved session exists. Production voice requires Push to Talk configuration.")

    func perform() async throws -> some IntentResult {
        .result(dialog: "Start crew transmission requires an active RefTrace communication session.")
    }
}

@available(iOS 16.0, *)
struct StopCrewTransmissionIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Crew Transmission"

    func perform() async throws -> some IntentResult {
        .result(dialog: "Stopped RefTrace transmission if one was active.")
    }
}

@available(iOS 16.0, *)
struct StartPrivateTransmissionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Private Transmission"
    @Parameter(title: "Recipient") var recipient: String

    func perform() async throws -> some IntentResult {
        .result(dialog: "Private transmission to \(recipient) requires an active RefTrace communication session.")
    }
}

@available(iOS 16.0, *)
struct SelectCommunicationRecipientIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Communication Recipient"
    @Parameter(title: "Recipient") var recipient: String

    func perform() async throws -> some IntentResult {
        .result(dialog: "Selected \(recipient) when an active RefTrace communication session is open.")
    }
}

@available(iOS 16.0, *)
struct SendCrewTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Crew Text"
    @Parameter(title: "Message") var message: String

    func perform() async throws -> some IntentResult {
        .result(dialog: "Crew text requires an active RefTrace communication session and review in the app.")
    }
}
@available(iOS 16.0, watchOS 9.0, *)
struct HeadRefereeTimeoutIntent: AppIntent {
    static var title: LocalizedStringResource = "RefTrace Timeout Stop Clock"
    static var description = IntentDescription("Requests a Football timeout clock stop for the active game. The app validates that the current official is the Head Referee before the authoritative clock changes.")

    func perform() async throws -> some IntentResult {
        .result(dialog: "RefTrace timeout requested. Open the active game to confirm the Head Referee clock-stop state.")
    }
}

@available(iOS 16.0, watchOS 9.0, *)
struct OpenHeadRefClockControlsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open RefTrace Head Ref Clock Controls"
    static var description = IntentDescription("Opens RefTrace so the Head Referee can use authorized Football clock controls.")

    func perform() async throws -> some IntentResult {
        .result(dialog: "Open RefTrace and choose the active Football game to use Head Referee clock controls.")
    }
}
#endif
