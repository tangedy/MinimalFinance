import XCTest
@testable import MinimalFinance

final class InsightEngineTests: XCTestCase {
    func testMonthlyEquivalentConversions() {
        let weekly = RecurringExpense(amount: 10, cadence: .weekly, label: "Weekly")
        let monthly = RecurringExpense(amount: 100, cadence: .monthly, label: "Monthly")
        let quarterly = RecurringExpense(amount: 300, cadence: .quarterly, label: "Quarterly")
        let yearly = RecurringExpense(amount: 1200, cadence: .yearly, label: "Yearly")

        XCTAssertEqual(InsightEngine.monthlyEquivalent(for: weekly), 10 * Decimal(string: "4.33")!)
        XCTAssertEqual(InsightEngine.monthlyEquivalent(for: monthly), 100)
        XCTAssertEqual(InsightEngine.monthlyEquivalent(for: quarterly), 100)
        XCTAssertEqual(InsightEngine.monthlyEquivalent(for: yearly), 100)
    }

    func testSnapshotOnlyCountsCurrentMonthTransactions() {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        let previousMonth = calendar.date(byAdding: .day, value: -1, to: monthStart)!

        let food = Category(name: "Food")
        let inMonth = Transaction(amount: 20, date: now, merchant: "In month", category: food, kind: .expense)
        let outOfMonth = Transaction(amount: 999, date: previousMonth, merchant: "Out of month", category: food, kind: .expense)

        let snapshot = InsightEngine.snapshot(transactions: [inMonth, outOfMonth], recurringExpenses: [], now: now)

        XCTAssertEqual(snapshot.monthTotal, 20)
    }

    func testCategoryBreakdownAggregatesOverflowIntoMore() {
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())!.start
        let categories = (1...7).map { Category(name: "Cat\($0)") }
        let transactions = categories.enumerated().map { index, category in
            Transaction(amount: Decimal(70 - index * 10), date: monthStart, merchant: "M\(index)", category: category, kind: .expense)
        }

        let breakdown = InsightEngine.categoryBreakdown(transactions: transactions, monthStart: monthStart, limit: 5)

        XCTAssertEqual(breakdown.count, 6)
        XCTAssertEqual(breakdown.last?.name, "More")
        XCTAssertEqual(breakdown.last?.total, 30)
    }

    func testCategoryBreakdownExcludesOtherCategory() {
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())!.start
        let food = Category(name: "Food")
        let other = Category(name: "Other")
        let transactions = [
            Transaction(amount: 50, date: monthStart, merchant: "Groceries", category: food, kind: .expense),
            Transaction(amount: 20, date: monthStart, merchant: "Misc", category: other, kind: .expense)
        ]

        let breakdown = InsightEngine.categoryBreakdown(transactions: transactions, monthStart: monthStart)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.name, "Food")
    }
}
