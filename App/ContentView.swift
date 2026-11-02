import SwiftUI
import Translation

struct ContentView: View {
    @StateObject private var model = Model()

    var body: some View {
        TabView {
            LiveView(model: model).tabItem { Label("Live", systemImage: "waveform") }
            SelfTestView(model: model).tabItem { Label("Self-test", systemImage: "checkmark.seal") }
        }
        .task {
            await model.load()
            if UserDefaults.standard.bool(forKey: "selftest") { await model.runSelfTest() }   // automatic run, for checking from a computer
        }
    }
}

struct LiveView: View {
    @ObservedObject var model: Model
    @State private var showMeter = false   // the technical line is hidden until the status text is tapped

    var body: some View {
        VStack(spacing: 12) {
            Text(model.status).font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                .onTapGesture { showMeter.toggle() }
            if showMeter, !model.meter.isEmpty { Text(model.meter).font(.caption2.monospaced()).foregroundStyle(.secondary) }
            if model.cards.isEmpty {
                Spacer()
                Text("Tap the microphone. German you hear shows up here as text and in English, once the speech model and the language pack are on the phone.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 32)
                Spacer()
            } else {
                List(model.cards.reversed()) { card in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.german).font(.body)
                        Text(card.english ?? "…").font(.callout).foregroundStyle(.indigo)
                    }
                }
            }
            Button { model.toggleListening() } label: {
                Image(systemName: model.listening ? "stop.fill" : "mic.fill")
                    .font(.title).foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(model.listening ? Color.red : Color.indigo, in: Circle())
            }
            .disabled(!model.ready)
            .padding(.bottom, 12)
        }
        .translationTask(model.translation) { session in await model.translatePending(with: session) }
    }
}

struct SelfTestView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(spacing: 12) {
            Text("The app speaks known German sentences with the phone's own voice, listens to itself, and checks the words.")
                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal).padding(.top, 8)
            Button(model.testRunning ? "Running…" : "Run self-test") { Task { await model.runSelfTest() } }
                .buttonStyle(.borderedProminent).disabled(!model.ready || model.testRunning)
            if !model.rows.isEmpty {
                let right = model.rows.map(\.accuracy).reduce(0, +) / Double(model.rows.count)
                let audio = model.rows.map(\.audioSeconds).reduce(0, +)
                let work = model.rows.map(\.whisperSeconds).reduce(0, +)
                Text(String(format: "%d of %d passed · %.0f%% of words right · %.2f s of work per second of speech",
                            model.rows.filter(\.passed).count, model.rows.count, right * 100, audio > 0 ? work / audio : 0))
                    .font(.subheadline.weight(.semibold)).padding(.horizontal)
            }
            List(model.rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: row.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(row.passed ? .green : .red)
                        Text(String(format: "%.0f%%", row.accuracy * 100)).font(.headline)
                        Spacer()
                        Text(String(format: "%.1f s", row.whisperSeconds)).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(row.sentence).font(.footnote)
                    Text(row.heard.isEmpty ? "(nothing heard)" : row.heard).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text(model.status).font(.footnote).foregroundStyle(.secondary).padding(.bottom, 8)
        }
    }
}
