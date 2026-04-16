import AVFoundation
import Foundation
import Speech
import SwiftUI

/// Single `AVAudioEngine` session: live Apple Speech transcript + write captured audio to a file for Whisper/OpenAI upload.
@MainActor
final class RambleCaptureEngine: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var isRecording = false
    @Published var liveTranscript = ""
    @Published var waveformLevel: CGFloat = 0
    @Published var errorMessage: String?
    @Published private(set) var recognizerAvailable: Bool = false

    private let engine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var audioFile: AVAudioFile?

    private(set) var outputFileURL: URL?

    override init() {
        super.init()
        speechRecognizer?.delegate = self
        recognizerAvailable = speechRecognizer?.isAvailable ?? false
    }

    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in self.recognizerAvailable = available }
    }

    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                c.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await withCheckedContinuation { c in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    c.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    c.resume(returning: granted)
                }
            }
        }
    }

    func startSession() throws {
        errorMessage = nil
        liveTranscript = ""
        waveformLevel = 0

        guard let speechRecognizer else {
            throw RambleError.recognizerUnavailable
        }
        guard recognizerAvailable else {
            throw RambleError.recognizerUnavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: [])

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("briefly-\(UUID().uuidString).caf")
        outputFileURL = url

        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let recognitionRequest else { throw RambleError.badState }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.liveTranscript = result.bestTranscription.formattedString
                }
                if let error {
                    let nsError = error as NSError
                    let description = error.localizedDescription.lowercased()
                    let isExpectedCancellation =
                        nsError.domain == "kAFAssistantErrorDomain" ||
                        nsError.domain == "SFSpeechErrorDomain" ||
                        description.contains("cancel")
                    if !isExpectedCancellation {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            recognitionRequest.append(buffer)
            try? self.audioFile?.write(from: buffer)

            let level = Self.rmsLevel(buffer: buffer)
            Task { @MainActor in
                self.waveformLevel = CGFloat(level)
            }
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stopSession() {
        engine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil

        engine.stop()
        audioFile = nil
        isRecording = false
    }

    private static func rmsLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?.pointee else { return 0 }
        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return 0 }
        var sum: Float = 0
        for i in 0..<frameCount {
            let s = channel[i]
            sum += s * s
        }
        return sqrt(sum / Float(frameCount))
    }

    enum RambleError: Error {
        case badState
        case recognizerUnavailable
    }
}

extension RambleCaptureEngine.RambleError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .badState:
            return "Could not start recording. Please try again."
        case .recognizerUnavailable:
            return "Failed to initialize recognizer. Check network and try again."
        }
    }
}
