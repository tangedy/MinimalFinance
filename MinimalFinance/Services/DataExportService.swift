import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupCategory: Codable {
    var name: String
    var isBuiltIn: Bool
    var sortOrder: Int
}

struct BackupTransaction: Codable {
    var amount: Decimal
    var date: Date
    var merchant: String
    var categoryName: String?
    var source: String
    var kind: String
    var note: String?
}

struct BackupRecurringExpense: Codable {
    var label: String
    var amount: Decimal
    var cadence: String
    var startDate: Date
    var endDate: Date?
    var categoryName: String?
    var isActive: Bool
}

struct BackupCategoryRule: Codable {
    var ruleType: String
    var pattern: String
    var priority: Int
    var categoryName: String?
}

struct DataBackup: Codable {
    var exportedAt: Date
    var categories: [BackupCategory]
    var transactions: [BackupTransaction]
    var recurringExpenses: [BackupRecurringExpense]
    var rules: [BackupCategoryRule]
}

enum DataExportService {
    static func transactionsCSV(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let transactions = (try? modelContext.fetch(descriptor)) ?? []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var lines = ["Date,Merchant,Amount,Kind,Category,Note,Source"]
        for transaction in transactions {
            let fields = [
                dateFormatter.string(from: transaction.date),
                csvEscape(transaction.merchant),
                NSDecimalNumber(decimal: transaction.amount).stringValue,
                transaction.kind.rawValue,
                csvEscape(transaction.category?.name ?? ""),
                csvEscape(transaction.note ?? ""),
                transaction.source.rawValue
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func fullBackupJSON(modelContext: ModelContext) -> Data {
        let categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let recurringExpenses = (try? modelContext.fetch(FetchDescriptor<RecurringExpense>())) ?? []
        let rules = (try? modelContext.fetch(FetchDescriptor<CategoryRule>())) ?? []

        let backup = DataBackup(
            exportedAt: .now,
            categories: categories.map {
                BackupCategory(name: $0.name, isBuiltIn: $0.isBuiltIn, sortOrder: $0.sortOrder)
            },
            transactions: transactions.map {
                BackupTransaction(
                    amount: $0.amount,
                    date: $0.date,
                    merchant: $0.merchant,
                    categoryName: $0.category?.name,
                    source: $0.source.rawValue,
                    kind: $0.kind.rawValue,
                    note: $0.note
                )
            },
            recurringExpenses: recurringExpenses.map {
                BackupRecurringExpense(
                    label: $0.label,
                    amount: $0.amount,
                    cadence: $0.cadence.rawValue,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    categoryName: $0.category?.name,
                    isActive: $0.isActive
                )
            },
            rules: rules.map {
                BackupCategoryRule(
                    ruleType: $0.ruleType.rawValue,
                    pattern: $0.pattern,
                    priority: $0.priority,
                    categoryName: $0.category?.name
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(backup)) ?? Data()
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
