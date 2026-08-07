import Foundation
import Speech

enum SpeechTranscriptionAuthorizationStatus: String, Hashable {
    case available = "Available"
    case processing = "Processing"
    case unavailable = "Unavailable"
    case permissionDenied = "Permission Denied"
    case networkRequired = "Network Required"
    case lowConfidence = "Low Confidence"
}

struct SpeechTranscriptionResult: Identifiable, Hashable {
    var id = UUID()
    var text: String
    var confidence: Double
    var isMachineGenerated = true
    var status: SpeechTranscriptionAuthorizationStatus
}

final class SpeechTranscriptionService: CommunicationTranscriptionService {
    func requestAuthorization() async -> SpeechTranscriptionAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .available)
                case .denied, .restricted:
                    continuation.resume(returning: .permissionDenied)
                case .notDetermined:
                    continuation.resume(returning: .unavailable)
                @unknown default:
                    continuation.resume(returning: .unavailable)
                }
            }
        }
    }

    func transcribeMock(_ text: String) async -> SpeechTranscriptionResult {
        SpeechTranscriptionResult(text: text, confidence: text.isEmpty ? 0 : 0.92, status: text.isEmpty ? .unavailable : .available)
    }
}
