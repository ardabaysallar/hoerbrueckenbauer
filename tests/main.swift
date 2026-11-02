// Computer-side checks of the shared code. Build and run: tests/run.sh
import Foundation

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print(ok ? "  pass" : "  FAIL", name, ok ? "" : detail)
    if !ok { failures += 1 }
}

print("Word accuracy")
check("same text scores 100%", WordAccuracy.score(reference: "Das Wetter ist gut.", heard: "das wetter ist gut") == 1)
check("one wrong word of four scores 75%", abs(WordAccuracy.score(reference: "Das Wetter ist gut", heard: "Das Wetter ist schlecht") - 0.75) < 1e-9)
check("a missing word counts", abs(WordAccuracy.score(reference: "eins zwei drei vier", heard: "eins zwei drei") - 0.75) < 1e-9)
check("digits match spelled numbers", WordAccuracy.score(reference: "um neun Uhr", heard: "um 9 Uhr") == 1)
check("nothing heard scores 0%", WordAccuracy.score(reference: "Guten Tag", heard: "") == 0)
check("sound notes are removed", WordAccuracy.withoutSoundNotes("[Musik] Hallo *lacht* Welt (Applaus)") == "Hallo Welt")

print("Sentence finder")
func voice(_ seconds: Float, level: Float = 0.08) -> [Float] {
    (0..<Int(seconds * 16_000)).map { i in
        let t = Float(i) / 16_000
        return level * (sin(2 * .pi * 180 * t) + 0.5 * sin(2 * .pi * 540 * t)) * (0.6 + 0.4 * sin(2 * .pi * 3 * t))
    }
}
func quiet(_ seconds: Float) -> [Float] { [Float](repeating: 0, count: Int(seconds * 16_000)) }
func run(_ signal: [Float]) -> [[Float]] {
    let s = SimpleSegmenter()
    var out: [[Float]] = []
    var i = 0
    while i < signal.count { out += s.feed(Array(signal[i..<min(i + 1_365, signal.count)])); i += 1_365 }
    if let rest = s.flush() { out.append(rest) }
    return out
}
let two = run(quiet(1) + voice(2) + quiet(1.5) + voice(2) + quiet(1))
check("two sentences with a pause make two chunks", two.count == 2, "got \(two.count)")
check("a short click is ignored", run(quiet(1) + voice(0.1) + quiet(2)).isEmpty)
let long = run(quiet(1) + voice(20) + quiet(1))
check("20 s of nonstop speech is cut into pieces of 7 s or less", long.count >= 3 && long.allSatisfy { $0.count <= 7 * 16_000 }, "got \(long.map(\.count))")
check("silence gives nothing", run(quiet(5)).isEmpty)
let faint = run(quiet(1) + voice(2, level: 0.004) + quiet(1.5))
check("faint speech (phone microphone level) is found", faint.count == 1, "got \(faint.count)")
let faintRms = faint.first.map { ($0.reduce(0) { $0 + $1 * $1 } / Float($0.count)).squareRoot() } ?? 0
check("a faint chunk is lifted to a normal loudness", faintRms > 0.02, "level \(faintRms)")
var seed: UInt64 = 7
func noise(_ seconds: Float, level: Float) -> [Float] {
    (0..<Int(seconds * 16_000)).map { _ in seed = seed &* 6364136223846793005 &+ 1442695040888963407; return level * (Float(seed >> 40) / Float(1 << 24) * 2 - 1) }
}
check("steady room noise is not mistaken for speech", run(noise(20, level: 0.004)).count <= 1, "got \(run(noise(20, level: 0.004)).count)")
let inNoise = run(noise(2, level: 0.003) + zip(voice(2, level: 0.03), noise(2, level: 0.003)).map { $0 + $1 } + noise(2, level: 0.003))
check("speech in room noise is found", inNoise.count == 1, "got \(inNoise.count)")

print("System voice (test speech)")
let synth = SpeechSynth()
let speech = await synth.render("Heute scheint die Sonne und wir gehen in den Park.")
let seconds = Double(speech.count) / 16_000
check("the voice makes 1 to 8 s of audio", seconds > 1 && seconds < 8, "got \(seconds) s")
let level = (speech.reduce(0) { $0 + $1 * $1 } / Float(max(speech.count, 1))).squareRoot()
check("the audio is not silent", level > 0.005, "level \(level)")
let chunks = run(quiet(1) + speech + quiet(1.5))
check("the finder makes one chunk of it", chunks.count == 1, "got \(chunks.count)")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
