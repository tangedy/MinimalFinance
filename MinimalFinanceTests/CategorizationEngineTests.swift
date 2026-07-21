import XCTest
@testable import MinimalFinance

final class CategorizationEngineTests: XCTestCase {
    private var food: Category!
    private var transport: Category!
    private var subscriptions: Category!
    private var other: Category!

    override func setUp() {
        super.setUp()
        food = Category(name: "Food")
        transport = Category(name: "Transport")
        subscriptions = Category(name: "Subscriptions")
        other = Category(name: "Other")
    }

    func testIncomeTransactionsAreNeverCategorized() {
        let suggestion = CategorizationEngine.suggest(
            merchant: "Paycheck",
            amount: 1500,
            kind: .income,
            categories: [food, other],
            rules: [],
            history: []
        )
        XCTAssertNil(suggestion)
    }

    func testExactMerchantRuleWins() {
        let rule = CategoryRule(ruleType: .merchantExact, pattern: "STARBUCKS", category: food, priority: 200)

        let suggestion = CategorizationEngine.suggest(
            merchant: "Starbucks",
            amount: 5,
            kind: .expense,
            categories: [food, other],
            rules: [rule],
            history: []
        )

        XCTAssertEqual(suggestion?.category.name, "Food")
        XCTAssertEqual(suggestion?.source, .rule)
        XCTAssertEqual(suggestion?.confidence, 0.95)
    }

    func testHistoryMatchIsUsedWhenConsistent() {
        let history = (0..<4).map { _ in
            Transaction(amount: 6, merchant: "Local Cafe", category: food, kind: .expense)
        }

        let suggestion = CategorizationEngine.suggest(
            merchant: "Local Cafe",
            amount: 6,
            kind: .expense,
            categories: [food, other],
            rules: [],
            history: history
        )

        XCTAssertEqual(suggestion?.category.name, "Food")
        XCTAssertEqual(suggestion?.source, .history)
    }

    func testKeywordScorerMatchesTransportForUber() {
        let suggestion = CategorizationEngine.suggest(
            merchant: "UBER TRIP 12345",
            amount: 15,
            kind: .expense,
            categories: [food, transport, other],
            rules: [],
            history: []
        )

        XCTAssertEqual(suggestion?.category.name, "Transport")
        XCTAssertEqual(suggestion?.source, .scorer)
    }

    func testSubscriptionWhitelistOverridesScoring() {
        let suggestion = CategorizationEngine.suggest(
            merchant: "SPOTIFY USA",
            amount: 9.99,
            kind: .expense,
            categories: [food, subscriptions, other],
            rules: [],
            history: []
        )

        XCTAssertEqual(suggestion?.category.name, "Subscriptions")
    }

    func testFallsBackToOtherWhenNothingMatches() {
        let suggestion = CategorizationEngine.suggest(
            merchant: "Completely Unknown Vendor XYZ",
            amount: 42,
            kind: .expense,
            categories: [food, transport, other],
            rules: [],
            history: []
        )

        XCTAssertEqual(suggestion?.category.name, "Other")
        XCTAssertEqual(suggestion?.source, .fallback)
        XCTAssertEqual(suggestion?.confidence, 0.2)
    }
}
