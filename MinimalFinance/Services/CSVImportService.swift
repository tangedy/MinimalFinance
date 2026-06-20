import Foundation
import SwiftData

struct ParsedCSVRow: Identifiable {
    let id = UUID()
    let date: Date
    let merchant: String
    let amount: Decimal
    let kind: TransactionKind
}

struct ImportPreviewRow: Identifiable {
    let id: UUID
    let date: Date
    let merchant: String
    let normalizedMerchant: String
    let amount: Decimal
    let kind: TransactionKind
    let suggestedCategory: Category?
    let confidence: Double
    let source: SuggestionSource?
    var overrideCategory: Category?

    var effectiveCategory: Category? {
        overrideCategory ?? suggestedCategory
    }

    var isAutoCategorized: Bool {
        guard kind == .expense else { return false }
        guard let suggestedCategory, let source else { return false }
        return suggestedCategory.name != "Other"
            && confidence >= 0.55
            && source != .fallback
    }

    var needsReview: Bool {
        kind == .expense && !isAutoCategorized
    }

    init(from row: ParsedCSVRow, suggestion: CategorySuggestion?) {
        id = row.id
        date = row.date
        merchant = row.merchant
        normalizedMerchant = MerchantNormalizer.normalize(row.merchant)
        amount = row.amount
        kind = row.kind
        suggestedCategory = suggestion?.category
        confidence = suggestion?.confidence ?? 0
        source = suggestion?.source
        overrideCategory = nil
    }
}

struct CSVColumnMapping {
    let dateIndex: Int?
    let descriptionIndex: Int?
    let debitIndex: Int?
    let creditIndex: Int?
    let amountIndex: Int?
    let headers: [String]
    let hasHeaderRow: Bool
}

enum CSVImportService {
    static func parse(contents: String) -> (mapping: CSVColumnMapping, rows: [ParsedCSVRow]) {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return (emptyMapping, [])
        }

        let firstFields = parseCSVFields(lines[0])
        let hasHeaderRow = !looksLikeDate(firstFields.first ?? "")

        let mapping: CSVColumnMapping
        let dataLines: ArraySlice<String>

        if hasHeaderRow {
            mapping = detectColumnMapping(headers: firstFields)
            dataLines = lines.dropFirst()
        } else if firstFields.count >= 4 {
            mapping = CSVColumnMapping(
                dateIndex: 0,
                descriptionIndex: 1,
                debitIndex: 2,
                creditIndex: 3,
                amountIndex: nil,
                headers: ["Date", "Description", "Debit", "Credit", "Balance"],
                hasHeaderRow: false
            )
            dataLines = lines[...]
        } else {
            mapping = detectColumnMapping(headers: firstFields)
            dataLines = lines[...]
        }

        let rows = dataLines.compactMap { line -> ParsedCSVRow? in
            let values = parseCSVFields(line)
            return parseRow(values: values, mapping: mapping)
        }

        return (mapping, rows)
    }

    static func categorize(rows: [ParsedCSVRow], modelContext: ModelContext) -> [ImportPreviewRow] {
        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let rules = (try? modelContext.fetch(FetchDescriptor<CategoryRule>())) ?? []
        let history = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []

        return rows.map { row in
            let suggestion = CategorizationEngine.suggest(
                merchant: row.merchant,
                amount: row.amount,
                kind: row.kind,
                categories: categories,
                rules: rules,
                history: history
            )
            return ImportPreviewRow(from: row, suggestion: suggestion)
        }
    }

    @discardableResult
    static func importRows(
        _ rows: [ImportPreviewRow],
        fileName: String,
        modelContext: ModelContext
    ) throws -> ImportBatch {
        let batch = ImportBatch(fileName: fileName, rowCount: rows.count)
        modelContext.insert(batch)

        for row in rows {
            if let override = row.overrideCategory, row.kind == .expense {
                CategoryRuleService.learn(merchant: row.merchant, category: override, modelContext: modelContext)
            }

            let transaction = Transaction(
                amount: row.amount,
                date: row.date,
                merchant: row.merchant,
                category: row.kind == .expense ? row.effectiveCategory : nil,
                source: .csv,
                kind: row.kind,
                importBatch: batch
            )
            modelContext.insert(transaction)
        }

        try modelContext.save()
        return batch
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

    private static var emptyMapping: CSVColumnMapping {
        CSVColumnMapping(
            dateIndex: nil,
            descriptionIndex: nil,
            debitIndex: nil,
            creditIndex: nil,
            amountIndex: nil,
            headers: [],
            hasHeaderRow: false
        )
    }

    private static func parseRow(values: [String], mapping: CSVColumnMapping) -> ParsedCSVRow? {
        guard let dateIndex = mapping.dateIndex,
              let descriptionIndex = mapping.descriptionIndex,
              values.indices.contains(dateIndex),
              values.indices.contains(descriptionIndex) else {
            return nil
        }

        let dateString = cleanField(values[dateIndex])
        guard let date = parseDate(dateString) else { return nil }

        let merchant = cleanField(values[descriptionIndex])
        guard !merchant.isEmpty else { return nil }

        if let debitIndex = mapping.debitIndex, let creditIndex = mapping.creditIndex,
           values.indices.contains(debitIndex), values.indices.contains(creditIndex) {
            let debit = parseAmount(cleanField(values[debitIndex]))
            let credit = parseAmount(cleanField(values[creditIndex]))

            if let debit, debit > 0 {
                return ParsedCSVRow(date: date, merchant: merchant, amount: debit, kind: .expense)
            }
            if let credit, credit > 0 {
                return ParsedCSVRow(date: date, merchant: merchant, amount: credit, kind: .income)
            }
            return nil
        }

        if let amountIndex = mapping.amountIndex, values.indices.contains(amountIndex),
           let amount = parseAmount(cleanField(values[amountIndex])), amount > 0 {
            return ParsedCSVRow(date: date, merchant: merchant, amount: amount, kind: .expense)
        }

        return nil
    }

    private static func detectColumnMapping(headers: [String]) -> CSVColumnMapping {
        var dateIndex: Int?
        var amountIndex: Int?
        var descriptionIndex: Int?
        var debitIndex: Int?
        var creditIndex: Int?

        for (index, header) in headers.enumerated() {
            let normalized = cleanField(header).lowercased()
            if dateIndex == nil, normalized.contains("date") || normalized.contains("posted") {
                dateIndex = index
            }
            if debitIndex == nil, normalized.contains("debit") || normalized == "withdrawal" {
                debitIndex = index
            }
            if creditIndex == nil, normalized.contains("credit") || normalized == "deposit" {
                creditIndex = index
            }
            if amountIndex == nil, normalized.contains("amount") {
                amountIndex = index
            }
            if descriptionIndex == nil,
               normalized.contains("description") || normalized.contains("merchant")
                || normalized.contains("memo") || normalized.contains("name") || normalized.contains("payee") {
                descriptionIndex = index
            }
        }

        return CSVColumnMapping(
            dateIndex: dateIndex,
            descriptionIndex: descriptionIndex,
            debitIndex: debitIndex,
            creditIndex: creditIndex,
            amountIndex: amountIndex,
            headers: headers.map(cleanField),
            hasHeaderRow: true
        )
    }

    private static func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for character in line {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == ",", !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        fields.append(current)
        return fields
    }

    private static func cleanField(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private static func looksLikeDate(_ string: String) -> Bool {
        parseDate(cleanField(string)) != nil
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "yyyy/MM/dd"
        ].map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static func parseAmount(_ string: String) -> Decimal? {
        guard !string.isEmpty else { return nil }
        let normalized = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: normalized)
    }
}
