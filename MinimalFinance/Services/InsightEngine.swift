import Foundation

struct CategoryBreakdown: Identifiable {
    let id: String
    let name: String
    let total: Decimal
}

struct InsightSnapshot {
    let weekTotal: Decimal
    let monthTotal: Decimal
    let yearToDateTotal: Decimal
    let categoryBreakdown: [CategoryBreakdown]
    let recurringTotal: Decimal
    let variableTotal: Decimal
}

enum InsightEngine {
    static func snapshot(
        transactions: [Transaction],
        recurringExpenses: [RecurringExpense],
        now: Date = .now
    ) -> InsightSnapshot {
        let calendar = Calendar.current

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now

        let weekTotal = sum(transactions.filter { $0.date >= weekStart })
        let monthTotal = sum(transactions.filter { $0.date >= monthStart })
        let yearToDateTotal = sum(transactions.filter { $0.date >= yearStart })

        var categoryTotals: [String: Decimal] = [:]
        for transaction in transactions where transaction.date >= monthStart {
            let name = transaction.category?.name ?? "Uncategorized"
            categoryTotals[name, default: 0] += transaction.amount
        }

        let categoryBreakdown = categoryTotals
            .map { CategoryBreakdown(id: $0.key, name: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }

        let activeRecurring = recurringExpenses.filter(\.isActive)
        let recurringTotal = activeRecurring.reduce(Decimal.zero) { $0 + $1.amount }
        let variableTotal = max(monthTotal - recurringTotal, 0)

        return InsightSnapshot(
            weekTotal: weekTotal,
            monthTotal: monthTotal,
            yearToDateTotal: yearToDateTotal,
            categoryBreakdown: categoryBreakdown,
            recurringTotal: recurringTotal,
            variableTotal: variableTotal
        )
    }

    private static func sum(_ transactions: [Transaction]) -> Decimal {
        transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
