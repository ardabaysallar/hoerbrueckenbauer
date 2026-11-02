import Foundation

/// A small, deliberately simple sentence finder.
/// It looks at how loud every 20 ms slice is, guesses the room's background level from the last few seconds,
/// ends a sentence after a short pause, and makes quiet speech louder before the speech model reads it.
/// Feed it 16 kHz mono samples; it hands back finished pieces of speech.
final class SimpleSegmenter {
    private let rate = 16_000
    private let frame = 320                    // 20 ms
    private var carry: [Float] = []
    private var lead: [Float] = []             // the moment just before speech starts
    private var current: [Float] = []
    private var recent: [Float] = []           // slice loudness of the last 4 s
    private var speaking = false
    private var quietFrames = 0
    private var voicedFrames = 0
    private var currentLevels: [Float] = []    // slice loudness inside `current`
    private var leadCount = 0

    /// For the screen: loudness of the last slice and the background estimate.
    private(set) var level: Float = 0
    private(set) var floorLevel: Float = 0.001

    var leadSeconds: Float = 0.25              // audio kept from before the first loud slice
    var pauseSeconds: Float = 0.6              // silence that ends a short sentence
    var longAfterSeconds: Float = 4.0          // once speech is this long...
    var longPauseSeconds: Float = 0.3          // ...a shorter silence ends it
    var maxSeconds: Float = 7                  // hard limit for one piece
    var cutWindowSeconds: Float = 1.8          // where a hard cut may look for a quiet spot
    var targetLevel: Float = 0.04              // quiet pieces are brought up towards this loudness
    var maxGain: Float = 40
    var noiseFactor: Float = 2.2               // speech must beat the background by this factor
    var minLevel: Float = 0.0012               // and be at least this loud
    var floorPercentile = 8                    // background = the quietest 1/N of the recent slices

    func feed(_ samples: [Float]) -> [[Float]] {
        var out: [[Float]] = []
        carry += samples
        while carry.count >= frame {
            let slice = Array(carry.prefix(frame))
            carry.removeFirst(frame)
            level = Self.rms(slice)
            recent.append(level)
            if recent.count > 200 { recent.removeFirst() }
            floorLevel = max(0.0005, recent.sorted()[recent.count / floorPercentile])
            let loud = level > max(minLevel, floorLevel * noiseFactor)
            if !speaking {
                if loud {
                    speaking = true; quietFrames = 0; voicedFrames = 1
                    current = lead + slice
                    leadCount = lead.count; currentLevels = [level]
                    lead = []
                } else {
                    lead += slice
                    let keep = Int(leadSeconds * Float(rate))
                    if lead.count > keep { lead.removeFirst(lead.count - keep) }
                }
                continue
            }
            current += slice
            currentLevels.append(level)
            if loud { quietFrames = 0; voicedFrames += 1 } else { quietFrames += 1 }
            let length = Float(current.count) / Float(rate)
            let needed = length >= longAfterSeconds ? longPauseSeconds : pauseSeconds
            if Float(quietFrames * frame) / Float(rate) >= needed {
                if let piece = finish() { out.append(piece) }
            } else if length >= maxSeconds, let piece = cutAtQuietSpot() {
                out.append(piece)
            }
        }
        return out
    }

    /// Hands back whatever is left when the stream ends.
    func flush() -> [Float]? { speaking ? finish() : nil }

    /// A piece got too long without a pause: cut where the last stretch was quietest and carry on with the rest.
    private func cutAtQuietSpot() -> [Float]? {
        let window = Int(cutWindowSeconds * 50)
        let from = max(0, currentLevels.count - window), to = currentLevels.count - 5
        guard to > from else { return nil }
        var best = from
        for i in from..<to where currentLevels[i] < currentLevels[best] { best = i }
        let cut = leadCount + (best + 1) * frame
        let piece = Array(current[..<cut])
        current = Array(current[cut...])
        currentLevels = Array(currentLevels[(best + 1)...])
        leadCount = 0
        quietFrames = 0
        let kept = voicedFrames
        voicedFrames = currentLevels.count
        return kept >= 5 ? lifted(piece) : nil
    }

    private func finish() -> [Float]? {
        let piece = current
        let voiced = Float(voicedFrames * frame) / Float(rate)
        speaking = false; current = []; currentLevels = []; leadCount = 0; quietFrames = 0; voicedFrames = 0
        guard voiced >= 0.3 else { return nil }
        return lifted(piece)
    }

    /// Scales a quiet piece up so the model gets a comfortable signal (limited gain, no clipping).
    private func lifted(_ piece: [Float]) -> [Float] {
        let gain = min(max(targetLevel / max(Self.rms(piece), 1e-6), 1), maxGain)
        return gain == 1 ? piece : piece.map { max(-1, min(1, $0 * gain)) }
    }

    private static func rms(_ x: [Float]) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
    }
}
