import Foundation
import SwiftData
import SwiftData

struct RecurrenceSuggestion: Identifiable {
    let id = UUID()
    let label: String
    let normalizedMerchant: String
    let amount: Decimal
    let cadence: RecurrenceCadence
    let category: Category?
    let confidence: Double
}

enum RecurrenceDetector {
    static func detect(
        transactions: [Transaction],
        existingRecurring: [RecurringExpense]
    ) -> [RecurrenceSuggestion] {
        let existingMerchants = Set(existingRecurring.map {
            MerchantNormalizer.normalize($0.label)
        })

        let expenses = transactions.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: expenses) {
            MerchantNormalizer.normalize($0.merchant)
        }

        var suggestions: [RecurrenceSuggestion] = []

        for (merchant, group) in grouped {
            guard !merchant.isEmpty, !existingMerchants.contains(merchant), group.count >= 2 else { continue }

            let sorted = group.sorted { $0.date < $1.date }
            guard let first = sorted.first?.date, let last = sorted.last?.date else { continue }
            guard last.timeIntervalSince(first) >= 28 * 24 * 60 * 60 else { continue }

            let amounts = sorted.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            let median = amounts.sorted()[amounts.count / 2]
            guard median > 0 else { continue }

            let withinTolerance = amounts.filter { abs($0 - median) / median <= 0.10 }
            guard Double(withinTolerance.count) / Double(amounts.count) >= 0.75 else { continue }

            let intervals = zip(sorted, sorted.dropFirst()).map {
                $1.date.timeIntervalSince($0.date) / (24 * 60 * 60)
            }
            guard let cadence = detectCadence(intervals: intervals) else { continue }

            let dominantCategory = dominantCategory(in: sorted)
            let confidence = min(0.95, 0.5 + Double(group.count) * 0.08)

            suggestions.append(RecurrenceSuggestion(
                label: sorted.first?.merchant.trimmingCharacters(in: .whitespacesAndNewlines) ?? merchant,
                normalizedMerchant: merchant,
                amount: Decimal(median),
                cadence: cadence,
                category: dominantCategory,
                confidence: confidence
            ))
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    private static func detectCadence(intervals: [TimeInterval]) -> RecurrenceCadence? {
        guard !intervals.isEmpty else { return nil }
        let average = intervals.reduce(0, +) / Double(intervals.count)

        switch average {
        case 5...10: return .weekly
        case 25...35: return .monthly
        case 80...100: return .quarterly
        case 330...400: return .yearly
        default: return nil
        }
    }

    private static func dominantCategory(in transactions: [Transaction]) -> Category? {
        var counts: [PersistentIdentifier: (Category, Int)] = [:]
        for transaction in transactions {
            guard let category = transaction.category else { continue }
            let current = counts[category.persistentModelID]?.1 ?? 0
            counts[category.persistentModelID] = (category, current + 1)
        }
        return counts.values.max(by: { $0.1 < $1.1 })?.0
    }
}
