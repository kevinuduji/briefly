import AVFoundation
import Foundation

@MainActor
final class AudioBriefPlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published var lastError: String?

    private var player: AVAudioPlayer?

    func playBase64MP3(_ base64: String) throws {
        stop()
        guard let data = Data(base64Encoded: base64) else {
            throw BriefError.badAudio
        }
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.prepareToPlay()
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    enum BriefError: Error {
        case badAudio
    }
}

extension AudioBriefPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}
