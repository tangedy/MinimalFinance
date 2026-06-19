import Foundation

struct ParsedCSVRow: Identifiable {
    let id = UUID()
    let date: String
    let amount: String
    let description: String
    let rawValues: [String]
}

struct CSVColumnMapping {
    let dateIndex: Int?
    let amountIndex: Int?
    let descriptionIndex: Int?
    let headers: [String]
}

enum CSVImportService {
    static func parse(contents: String) -> (mapping: CSVColumnMapping, rows: [ParsedCSVRow]) {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let headerLine = lines.first else {
            return (CSVColumnMapping(dateIndex: nil, amountIndex: nil, descriptionIndex: nil, headers: []), [])
        }

        let headers = splitCSVRow(headerLine)
        let mapping = detectColumnMapping(headers: headers)

        let dataRows = lines.dropFirst().map { line -> ParsedCSVRow in
            let values = splitCSVRow(line)
            return ParsedCSVRow(
                date: value(at: mapping.dateIndex, in: values),
                amount: value(at: mapping.amountIndex, in: values),
                description: value(at: mapping.descriptionIndex, in: values),
                rawValues: values
            )
        }

        return (mapping, dataRows)
    }

    static func readContents(from url: URL) throws -> String {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func detectColumnMapping(headers: [String]) -> CSVColumnMapping {
        var dateIndex: Int?
        var amountIndex: Int?
        var descriptionIndex: Int?

        for (index, header) in headers.enumerated() {
            let normalized = header.lowercased()
            if dateIndex == nil, normalized.contains("date") || normalized.contains("posted") {
                dateIndex = index
            }
            if amountIndex == nil, normalized.contains("amount") || normalized.contains("debit") || normalized.contains("credit") {
                amountIndex = index
            }
            if descriptionIndex == nil,
               normalized.contains("description") || normalized.contains("merchant") || normalized.contains("memo") || normalized.contains("name") {
                descriptionIndex = index
            }
        }

        return CSVColumnMapping(
            dateIndex: dateIndex,
            amountIndex: amountIndex,
            descriptionIndex: descriptionIndex,
            headers: headers
        )
    }

    private static func splitCSVRow(_ row: String) -> [String] {
        row.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private static func value(at index: Int?, in values: [String]) -> String {
        guard let index, values.indices.contains(index) else { return "" }
        return values[index]
    }
}
