import AVFoundation

/// Makes German test speech with the system's own voice (no recordings, no third-party audio).
final class SpeechSynth: @unchecked Sendable {
    private let synth = AVSpeechSynthesizer()
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    func render(_ text: String) async -> [Float] {
        await withCheckedContinuation { (cont: CheckedContinuation<[Float], Never>) in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
            let lock = NSLock()
            var samples: [Float] = []
            var finished = false
            var converter: AVAudioConverter?
            func finish() {
                lock.lock(); defer { lock.unlock() }
                if !finished { finished = true; cont.resume(returning: samples) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) { finish() }   // never wait forever
            synth.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 { finish(); return }
                if converter == nil { converter = AVAudioConverter(from: pcm.format, to: self.target) }
                let capacity = AVAudioFrameCount(Double(pcm.frameLength) * 16_000 / pcm.format.sampleRate) + 64
                guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: capacity) else { return }
                var supplied = false
                converter?.convert(to: out, error: nil) { _, status in
                    if supplied { status.pointee = .noDataNow; return nil }
                    supplied = true; status.pointee = .haveData; return pcm
                }
                lock.lock()
                samples += Array(UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
                lock.unlock()
            }
        }
    }
}
