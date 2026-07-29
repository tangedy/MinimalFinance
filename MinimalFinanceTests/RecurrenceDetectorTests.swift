import XCTest
@testable import MinimalFinance

final class RecurrenceDetectorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(daysFromBase offset: Int) -> Date {
        let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    func testDetectsMonthlySubscription() {
        let subscriptions = Category(name: "Subscriptions")
        let transactions = [0, 30, 60].map {
            Transaction(amount: 9.99, date: date(daysFromBase: $0), merchant: "Spotify", category: subscriptions, kind: .expense)
        }

        let suggestions = RecurrenceDetector.detect(transactions: transactions, existingRecurring: [])

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.cadence, .monthly)
        XCTAssertEqual(suggestions.first?.amount, 9.99)
        XCTAssertEqual(suggestions.first?.category?.name, "Subscriptions")
    }

    func testExistingRecurringExpenseIsExcluded() {
        let transactions = [0, 30, 60].map {
            Transaction(amount: 9.99, date: date(daysFromBase: $0), merchant: "Spotify", kind: .expense)
        }
        let existing = [RecurringExpense(amount: 9.99, cadence: .monthly, label: "Spotify")]

        let suggestions = RecurrenceDetector.detect(transactions: transactions, existingRecurring: existing)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func testSingleOccurrenceIsNotSuggested() {
        let transactions = [
            Transaction(amount: 9.99, date: date(daysFromBase: 0), merchant: "Spotify", kind: .expense)
        ]

        let suggestions = RecurrenceDetector.detect(transactions: transactions, existingRecurring: [])

        XCTAssertTrue(suggestions.isEmpty)
    }

    func testInconsistentAmountsAreNotSuggested() {
        let amounts: [Decimal] = [10, 10, 50]
        let transactions = amounts.enumerated().map { index, amount in
            Transaction(amount: amount, date: date(daysFromBase: index * 30), merchant: "Random Vendor", kind: .expense)
        }

        let suggestions = RecurrenceDetector.detect(transactions: transactions, existingRecurring: [])

        XCTAssertTrue(suggestions.isEmpty)
    }
}
