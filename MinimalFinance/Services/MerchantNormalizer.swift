import Foundation

enum MerchantNormalizer {
    private static let suffixes = ["_M", "_V", "_T", "_INV"]

    static func normalize(_ raw: String) -> String {
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .uppercased()

        if let range = value.range(of: #"\s*#\d+"#, options: .regularExpression) {
            value.removeSubrange(range)
        }

        for suffix in suffixes where value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
        }

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tokens(_ normalized: String) -> [String] {
        normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
    }
}
