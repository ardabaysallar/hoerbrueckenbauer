import AVFoundation

/// Microphone to 16 kHz mono samples. Audio is handed on and never stored.
final class Mic {
    private let engine = AVAudioEngine()
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    var onSamples: (([Float]) -> Void)?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)   // keeps the phone's own level control on, so quiet voices stay audible
        try session.setActive(true)
        let input = engine.inputNode
        guard let converter = AVAudioConverter(from: input.outputFormat(forBus: 0), to: target) else { return }
        input.installTap(onBus: 0, bufferSize: 4_096, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            guard let self else { return }
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000 / buffer.format.sampleRate) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: capacity) else { return }
            var supplied = false
            converter.convert(to: out, error: nil) { _, status in
                if supplied { status.pointee = .noDataNow; return nil }
                supplied = true; status.pointee = .haveData; return buffer
            }
            self.onSamples?(Array(UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength))))
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
