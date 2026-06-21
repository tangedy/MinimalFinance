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
        if let overrideCategory { return overrideCategory }
        if kind == .expense { return suggestedCategory ?? fallbackCategory }
        return nil
    }

    private let fallbackCategory: Category?

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

    init(from row: ParsedCSVRow, suggestion: CategorySuggestion?, otherCategory: Category?) {
        id = row.id
        date = row.date
        merchant = row.merchant
        normalizedMerchant = MerchantNormalizer.normalize(row.merchant)
        amount = row.amount
        kind = row.kind
        fallbackCategory = otherCategory
        suggestedCategory = suggestion?.category ?? (row.kind == .expense ? otherCategory : nil)
        confidence = suggestion?.confidence ?? 0
        source = suggestion?.source
        overrideCategory = nil
    }
}

enum CSVAmountStyle {
    case debitCredit
    case signed
    case unsignedPositive
}

struct CSVColumnMapping {
    let dateIndex: Int?
    let descriptionIndex: Int?
    let debitIndex: Int?
    let creditIndex: Int?
    let amountIndex: Int?
    let signedAmountIndex: Int?
    let activityTypeIndex: Int?
    let activitySubTypeIndex: Int?
    let directionIndex: Int?
    let amountStyle: CSVAmountStyle
    let formatLabel: String
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
            mapping = detectHeaderedFormat(headers: firstFields)
            dataLines = lines.dropFirst()
        } else if firstFields.count >= 4, looksLikeDate(firstFields[0]) {
            mapping = tdHeaderlessMapping
            dataLines = lines[...]
        } else {
            mapping = detectHeaderedFormat(headers: firstFields)
            dataLines = lines[...]
        }

        let rows = dataLines.compactMap { line -> ParsedCSVRow? in
            let values = parseCSVFields(line)
            guard !isMetadataRow(values) else { return nil }
            return parseRow(values: values, mapping: mapping)
        }

        return (mapping, rows)
    }

    static func categorize(rows: [ParsedCSVRow], modelContext: ModelContext) -> [ImportPreviewRow] {
        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let rules = (try? modelContext.fetch(FetchDescriptor<CategoryRule>())) ?? []
        let history = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let otherCategory = categories.first { $0.name == "Other" }

        return rows.map { row in
            let suggestion = CategorizationEngine.suggest(
                merchant: row.merchant,
                amount: row.amount,
                kind: row.kind,
                categories: categories,
                rules: rules,
                history: history
            )
            return ImportPreviewRow(from: row, suggestion: suggestion, otherCategory: otherCategory)
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
            signedAmountIndex: nil,
            activityTypeIndex: nil,
            activitySubTypeIndex: nil,
            directionIndex: nil,
            amountStyle: .unsignedPositive,
            formatLabel: "Unknown",
            headers: [],
            hasHeaderRow: false
        )
    }

    private static var tdHeaderlessMapping: CSVColumnMapping {
        CSVColumnMapping(
            dateIndex: 0,
            descriptionIndex: 1,
            debitIndex: 2,
            creditIndex: 3,
            amountIndex: nil,
            signedAmountIndex: nil,
            activityTypeIndex: nil,
            activitySubTypeIndex: nil,
            directionIndex: nil,
            amountStyle: .debitCredit,
            formatLabel: "TD",
            headers: ["Date", "Description", "Debit", "Credit", "Balance"],
            hasHeaderRow: false
        )
    }

    private static func detectHeaderedFormat(headers: [String]) -> CSVColumnMapping {
        let normalizedHeaders = headers.map { cleanField($0).lowercased() }

        if normalizedHeaders.contains("transaction_date"),
           normalizedHeaders.contains("net_cash_amount") {
            return wealthsimpleMapping(headers: headers)
        }

        return genericHeaderedMapping(headers: headers)
    }

    private static func wealthsimpleMapping(headers: [String]) -> CSVColumnMapping {
        CSVColumnMapping(
            dateIndex: headerIndex(in: headers, matching: "transaction_date"),
            descriptionIndex: headerIndex(in: headers, matching: "name"),
            debitIndex: nil,
            creditIndex: nil,
            amountIndex: nil,
            signedAmountIndex: headerIndex(in: headers, matching: "net_cash_amount"),
            activityTypeIndex: headerIndex(in: headers, matching: "activity_type"),
            activitySubTypeIndex: headerIndex(in: headers, matching: "activity_sub_type"),
            directionIndex: headerIndex(in: headers, matching: "direction"),
            amountStyle: .signed,
            formatLabel: "Wealthsimple",
            headers: headers.map(cleanField),
            hasHeaderRow: true
        )
    }

    private static func genericHeaderedMapping(headers: [String]) -> CSVColumnMapping {
        var dateIndex: Int?
        var amountIndex: Int?
        var signedAmountIndex: Int?
        var descriptionIndex: Int?
        var debitIndex: Int?
        var creditIndex: Int?
        var activityTypeIndex: Int?
        var activitySubTypeIndex: Int?
        var directionIndex: Int?

        for (index, header) in headers.enumerated() {
            let normalized = cleanField(header).lowercased()

            if dateIndex == nil,
               normalized.contains("date") || normalized.contains("posted") || normalized == "when" {
                dateIndex = index
            }
            if debitIndex == nil, normalized.contains("debit") || normalized == "withdrawal" || normalized == "out" {
                debitIndex = index
            }
            if creditIndex == nil, normalized.contains("credit") || normalized == "deposit" || normalized == "in" {
                creditIndex = index
            }
            if signedAmountIndex == nil, normalized == "net_cash_amount" || normalized == "net amount" {
                signedAmountIndex = index
            }
            if amountIndex == nil,
               normalized.contains("amount") || normalized == "value" || normalized == "sum" {
                amountIndex = index
            }
            if activityTypeIndex == nil, normalized == "activity_type" || normalized == "type" {
                activityTypeIndex = index
            }
            if activitySubTypeIndex == nil,
               normalized == "activity_sub_type" || normalized == "sub_type" || normalized == "subtype" {
                activitySubTypeIndex = index
            }
            if directionIndex == nil, normalized == "direction" {
                directionIndex = index
            }
            if descriptionIndex == nil,
               normalized.contains("description") || normalized.contains("merchant")
                || normalized.contains("memo") || normalized.contains("payee")
                || normalized == "name" || normalized.contains("details") {
                descriptionIndex = index
            }
        }

        let amountStyle: CSVAmountStyle
        if debitIndex != nil, creditIndex != nil {
            amountStyle = .debitCredit
        } else if signedAmountIndex != nil {
            amountStyle = .signed
        } else {
            amountStyle = .unsignedPositive
        }

        return CSVColumnMapping(
            dateIndex: dateIndex,
            descriptionIndex: descriptionIndex,
            debitIndex: debitIndex,
            creditIndex: creditIndex,
            amountIndex: amountIndex,
            signedAmountIndex: signedAmountIndex,
            activityTypeIndex: activityTypeIndex,
            activitySubTypeIndex: activitySubTypeIndex,
            directionIndex: directionIndex,
            amountStyle: amountStyle,
            formatLabel: "Generic CSV",
            headers: headers.map(cleanField),
            hasHeaderRow: true
        )
    }

    private static func parseRow(values: [String], mapping: CSVColumnMapping) -> ParsedCSVRow? {
        guard let dateIndex = mapping.dateIndex,
              values.indices.contains(dateIndex) else {
            return nil
        }

        let dateString = cleanField(values[dateIndex])
        guard let date = parseDate(dateString) else { return nil }

        guard let merchant = merchantLabel(values: values, mapping: mapping), !merchant.isEmpty else {
            return nil
        }

        switch mapping.amountStyle {
        case .debitCredit:
            return parseDebitCreditRow(
                values: values,
                mapping: mapping,
                date: date,
                merchant: merchant
            )
        case .signed:
            return parseSignedAmountRow(
                values: values,
                mapping: mapping,
                date: date,
                merchant: merchant
            )
        case .unsignedPositive:
            return parseUnsignedAmountRow(
                values: values,
                mapping: mapping,
                date: date,
                merchant: merchant
            )
        }
    }

    private static func parseDebitCreditRow(
        values: [String],
        mapping: CSVColumnMapping,
        date: Date,
        merchant: String
    ) -> ParsedCSVRow? {
        guard let debitIndex = mapping.debitIndex,
              let creditIndex = mapping.creditIndex,
              values.indices.contains(debitIndex),
              values.indices.contains(creditIndex) else {
            return nil
        }

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

    private static func parseSignedAmountRow(
        values: [String],
        mapping: CSVColumnMapping,
        date: Date,
        merchant: String
    ) -> ParsedCSVRow? {
        let amountIndex = mapping.signedAmountIndex ?? mapping.amountIndex
        guard let amountIndex,
              values.indices.contains(amountIndex),
              let signedAmount = parseAmount(cleanField(values[amountIndex])),
              signedAmount != 0 else {
            return nil
        }

        if signedAmount < 0 {
            return ParsedCSVRow(
                date: date,
                merchant: merchant,
                amount: abs(signedAmount),
                kind: .expense
            )
        }

        return ParsedCSVRow(date: date, merchant: merchant, amount: signedAmount, kind: .income)
    }

    private static func parseUnsignedAmountRow(
        values: [String],
        mapping: CSVColumnMapping,
        date: Date,
        merchant: String
    ) -> ParsedCSVRow? {
        guard let amountIndex = mapping.amountIndex,
              values.indices.contains(amountIndex),
              let amount = parseAmount(cleanField(values[amountIndex])),
              amount != 0 else {
            return nil
        }

        if amount < 0 {
            return ParsedCSVRow(date: date, merchant: merchant, amount: abs(amount), kind: .expense)
        }

        if let directionIndex = mapping.directionIndex,
           values.indices.contains(directionIndex) {
            let direction = cleanField(values[directionIndex]).lowercased()
            if direction.contains("in") || direction.contains("credit") || direction.contains("deposit") {
                return ParsedCSVRow(date: date, merchant: merchant, amount: amount, kind: .income)
            }
            if direction.contains("out") || direction.contains("debit") || direction.contains("withdraw") {
                return ParsedCSVRow(date: date, merchant: merchant, amount: amount, kind: .expense)
            }
        }

        return ParsedCSVRow(date: date, merchant: merchant, amount: amount, kind: .expense)
    }

    private static func merchantLabel(values: [String], mapping: CSVColumnMapping) -> String? {
        if let descriptionIndex = mapping.descriptionIndex,
           values.indices.contains(descriptionIndex) {
            let name = cleanField(values[descriptionIndex])
            if !name.isEmpty {
                return name
            }
        }

        var parts: [String] = []

        if let activitySubTypeIndex = mapping.activitySubTypeIndex,
           values.indices.contains(activitySubTypeIndex) {
            let subType = cleanField(values[activitySubTypeIndex])
            if !subType.isEmpty {
                parts.append(humanizedActivityLabel(subType))
            }
        }

        if let activityTypeIndex = mapping.activityTypeIndex,
           values.indices.contains(activityTypeIndex) {
            let activityType = cleanField(values[activityTypeIndex])
            if !activityType.isEmpty, parts.isEmpty || activityType.lowercased() != parts[0].lowercased() {
                parts.insert(humanizedActivityLabel(activityType), at: 0)
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func humanizedActivityLabel(_ raw: String) -> String {
        switch raw.uppercased() {
        case "SPEND": "Spend"
        case "EFT": "Transfer"
        case "INTEREST": "Interest"
        case "DIVIDEND": "Dividend"
        case "MONEYMOVEMENT": "Transfer"
        default:
            raw.replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }

    private static func isMetadataRow(_ values: [String]) -> Bool {
        guard let first = values.first.map(cleanField), !first.isEmpty else { return true }
        let lowered = first.lowercased()
        if lowered.hasPrefix("as of") || lowered.hasPrefix("generated") || lowered.hasPrefix("exported") {
            return true
        }
        return false
    }

    private static func headerIndex(in headers: [String], matching target: String) -> Int? {
        headers.firstIndex {
            cleanField($0).lowercased() == target.lowercased()
        }
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
            "yyyy/MM/dd",
            "dd/MM/yyyy",
            "M/d/yy"
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
