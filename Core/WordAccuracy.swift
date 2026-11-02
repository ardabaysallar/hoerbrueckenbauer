import Foundation

/// Share of reference words that were heard right (1 minus word edit distance over reference length).
enum WordAccuracy {
    /// German number words (0 to 12), so that "9 Uhr" and "neun Uhr" count as the same words.
    private static let digits = ["0": "null", "1": "eins", "2": "zwei", "3": "drei", "4": "vier", "5": "fünf", "6": "sechs",
                                 "7": "sieben", "8": "acht", "9": "neun", "10": "zehn", "11": "elf", "12": "zwölf"]

    static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.union(.decimalDigits).inverted)
            .filter { !$0.isEmpty }
            .map { digits[$0] ?? $0 }
    }

    static func score(reference: String, heard: String) -> Double {
        let r = words(reference), h = words(heard)
        guard !r.isEmpty else { return h.isEmpty ? 1 : 0 }
        var row = Array(0...h.count)
        for i in 1...r.count {
            var diagonal = row[0]
            row[0] = i
            for j in h.isEmpty ? [] : Array(1...h.count) {
                let above = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, diagonal + (r[i - 1] == h[j - 1] ? 0 : 1))
                diagonal = above
            }
        }
        return max(0, 1 - Double(row[h.count]) / Double(r.count))
    }

    /// Whisper writes notes like [Musik] or *lacht* for non-speech; they are not words.
    static func withoutSoundNotes(_ text: String) -> String {
        text.replacingOccurrences(of: #"\[[^\]]*\]|\*[^*]*\*|\([^)]*\)"#, with: " ", options: .regularExpression)
            .split(separator: " ").joined(separator: " ")
    }
}
