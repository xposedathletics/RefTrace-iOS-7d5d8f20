import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRouteManager: ObservableObject {
    @Published private(set) var currentAudioDevice = "Unknown"
    @Published private(set) var microphoneAvailable = false
    @Published private(set) var bluetoothConnected = false
    @Published private(set) var audioRouteWarning: String?

    init() {
        refreshRoute()
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.refreshRoute()
        }
    }

    func configureForVoiceCommunication() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
        try session.setActive(true)
        refreshRoute()
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        refreshRoute()
    }

    func refreshRoute() {
        let session = AVAudioSession.sharedInstance()
        let inputs = session.currentRoute.inputs
        let outputs = session.currentRoute.outputs
        microphoneAvailable = session.isInputAvailable
        bluetoothConnected = (inputs + outputs).contains { port in
            [.bluetoothHFP, .bluetoothA2DP, .bluetoothLE].contains(port.portType)
        }

        if let input = inputs.first {
            currentAudioDevice = input.portName
        } else if let output = outputs.first {
            currentAudioDevice = output.portName
        } else {
            currentAudioDevice = "Built-in Audio"
        }

        if outputs.contains(where: { $0.portType == .bluetoothA2DP }) && !inputs.contains(where: { $0.portType == .bluetoothHFP }) {
            audioRouteWarning = "Bluetooth output is connected, but an input-capable headset is preferred for two-way communication."
        } else if !microphoneAvailable {
            audioRouteWarning = "Microphone unavailable."
        } else {
            audioRouteWarning = nil
        }
    }
}
