import AVFoundation
import Foundation
import SwiftUI
import Translation

struct Card: Identifiable {
    let id = UUID()
    let german: String
    var english: String?
}

struct TestFile: Codable {
    let finishedAt: Date
    let rows: [TestRow]
}

struct TestRow: Identifiable, Codable {
    var id = UUID()
    let sentence: String
    let heard: String
    let accuracy: Double
    let whisperSeconds: Double
    let audioSeconds: Double
    var passed: Bool { accuracy >= 0.8 }
}

@MainActor
final class Model: ObservableObject {
    @Published var status = "Loading the speech model…"
    @Published var ready = false
    @Published var listening = false
    @Published var cards: [Card] = []
    @Published var translation: TranslationSession.Configuration?
    @Published var rows: [TestRow] = []
    @Published var testRunning = false
    @Published var meter = ""
    private var chunkCount = 0
    private var lastSeconds = 0.0
    private var meterTick = 0

    let engine = Engine()
    private let mic = Mic()
    private let segmenter = SimpleSegmenter()
    private var chain: Task<Void, Never>?

    func load() async {
        do {
            try await engine.load()
            status = String(format: "Ready (model loaded in %.0f s).", engine.loadSeconds)
            ready = true
        } catch {
            status = "Could not load the model: \(error.localizedDescription)"
        }
    }

    // MARK: live listening
    func toggleListening() {
        listening ? stopListening() : startListening()
    }

    private func startListening() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { self.status = "Microphone permission is needed."; return }
                self.mic.onSamples = { [weak self] samples in
                    guard let self else { return }
                    let chunks = self.segmenter.feed(samples)
                    for chunk in chunks { Task { @MainActor in self.enqueue(chunk) } }
                    self.meterTick += 1
                    if self.meterTick % 6 == 0 {   // about twice a second
                        let level = self.segmenter.level, room = self.segmenter.floorLevel
                        Task { @MainActor in
                            self.meter = String(format: "level %.4f · room %.4f · chunks %d · last %.1f s", level, room, self.chunkCount, self.lastSeconds)
                        }
                    }
                }
                do { try self.mic.start(); self.listening = true; self.status = "Listening…" }
                catch { self.status = "Microphone error: \(error.localizedDescription)" }
            }
        }
    }

    private func stopListening() {
        mic.stop()
        if let rest = segmenter.flush() { enqueue(rest) }
        listening = false
        status = "Stopped."
        meter = ""
    }

    /// One chunk at a time, in order, so sentences never swap places.
    private func enqueue(_ chunk: [Float]) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            let heard = await engine.transcribe(chunk)
            chunkCount += 1
            lastSeconds = heard.seconds
            guard !WordAccuracy.words(heard.text).isEmpty else { return }
            cards.append(Card(german: heard.text, english: nil))
            if translation == nil {
                translation = .init(source: Locale.Language(identifier: "de"), target: Locale.Language(identifier: "en"))
            } else { translation?.invalidate() }
        }
    }

    func translatePending(with session: TranslationSession) async {
        for card in cards where card.english == nil {
            if let result = try? await session.translate(card.german),
               let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index].english = result.targetText
            }
        }
    }

    // MARK: self-test
    /// Speaks known sentences with the phone's own voice, runs them through the same steps as live listening,
    /// and scores the words that came back.
    func runSelfTest() async {
        guard ready, !testRunning else { return }
        testRunning = true
        rows = []
        let synth = SpeechSynth()
        for sentence in SelfTestSentences.all {
            status = "Self-test: \(rows.count + 1) of \(SelfTestSentences.all.count)…"
            let speech = await synth.render(sentence)
            let quiet = [Float](repeating: 0, count: 16_000)
            let segmenter = SimpleSegmenter()
            var chunks = segmenter.feed(quiet + speech + quiet + quiet)
            if let rest = segmenter.flush() { chunks.append(rest) }
            let audio = chunks.flatMap { $0 }
            var heard = (text: "", seconds: 0.0)
            if !audio.isEmpty { heard = await engine.transcribe(audio) }
            rows.append(TestRow(sentence: sentence, heard: heard.text,
                                accuracy: WordAccuracy.score(reference: sentence, heard: heard.text),
                                whisperSeconds: heard.seconds, audioSeconds: Double(audio.count) / 16_000))
        }
        testRunning = false
        let passed = rows.filter(\.passed).count
        status = "Self-test done: \(passed) of \(rows.count) passed."
        save(rows)
    }

    /// The result is also written next to the app's files so a computer can read it after an automatic run.
    private func save(_ rows: [TestRow]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? encoder.encode(TestFile(finishedAt: Date(), rows: rows)) else { return }
        try? data.write(to: docs.appendingPathComponent("selftest.json"))
    }
}
