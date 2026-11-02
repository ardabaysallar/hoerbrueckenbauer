import Foundation
import WhisperKit

/// Loads the bundled speech model once and turns audio chunks into German text. Everything runs on the phone.
final class Engine: @unchecked Sendable {
    private var pipe: WhisperKit?
    private(set) var loadSeconds: Double = 0
    private static let folderName = "openai_whisper-small"

    var isReady: Bool { pipe != nil }

    func load() async throws {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("Models/\(Self.folderName)").path else {
            throw NSError(domain: "Engine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model folder missing in the app"])
        }
        let start = Date()
        let loaded = try await WhisperKit(WhisperKitConfig(modelFolder: folder, download: false))
        // The first run compiles the decoder for this phone. Pay that cost now, on noise, not on the first sentence.
        let noise = (0..<48_000).map { _ in Float.random(in: -0.1...0.1) }
        _ = try? await loaded.transcribe(audioArray: noise, decodeOptions: DecodingOptions(language: "de", noSpeechThreshold: nil))
        pipe = loaded
        loadSeconds = Date().timeIntervalSince(start)
    }

    /// German text for one chunk (16 kHz mono) and the seconds the model needed.
    func transcribe(_ audio: [Float]) async -> (text: String, seconds: Double) {
        guard let pipe else { return ("", 0) }
        let start = Date()
        let options = DecodingOptions(task: .transcribe, language: "de", temperature: 0, skipSpecialTokens: true)
        let results = (try? await pipe.transcribe(audioArray: audio, decodeOptions: options)) ?? []
        let text = WordAccuracy.withoutSoundNotes(results.flatMap(\.segments).map(\.text).joined(separator: " "))
        return (text, Date().timeIntervalSince(start))
    }
}
