import XCTest
@testable import MinimalFinance

final class CategorizationEngineTests: XCTestCase {
    private struct StubPredictor: CategoryPredicting {
        let results: [MLCategoryHypothesis]

        func hypotheses(for text: String, maximumCount: Int) -> [MLCategoryHypothesis] {
            Array(results.prefix(maximumCount))
        }
    }

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
        let suggestion = suggest(
            merchant: "Paycheck",
            kind: .income,
            predictor: StubPredictor(results: [hypothesis("Food", 0.99)])
        )

        XCTAssertNil(suggestion)
    }

    func testExactMerchantRuleWinsOverML() {
        let rule = CategoryRule(ruleType: .merchantExact, pattern: "STARBUCKS", category: food, priority: 200)

        let suggestion = suggest(
            merchant: "Starbucks",
            rules: [rule],
            predictor: StubPredictor(results: [hypothesis("Transport", 0.99)])
        )

        XCTAssertEqual(suggestion?.category.name, "Food")
        XCTAssertEqual(suggestion?.source, .rule)
        XCTAssertEqual(suggestion?.confidence, 0.95)
    }

    func testHistoryMatchWinsOverMLWhenConsistent() {
        let history = (0..<4).map { _ in
            Transaction(amount: 6, merchant: "Local Cafe", category: food, kind: .expense)
        }

        let suggestion = suggest(
            merchant: "Local Cafe",
            history: history,
            predictor: StubPredictor(results: [hypothesis("Transport", 0.99)])
        )

        XCTAssertEqual(suggestion?.category.name, "Food")
        XCTAssertEqual(suggestion?.source, .history)
    }

    func testAcceptedMLPredictionMapsCategoryAndAlternatives() {
        let predictor = StubPredictor(results: [
            hypothesis("Transport", 0.82),
            hypothesis("Food", 0.10),
            hypothesis("Subscriptions", 0.08)
        ])

        let suggestion = suggest(merchant: "City Cab", predictor: predictor)

        XCTAssertEqual(suggestion?.category.name, "Transport")
        XCTAssertEqual(suggestion?.source, .ml)
        XCTAssertEqual(suggestion?.confidence, 0.82)
        XCTAssertEqual(suggestion?.alternatives.map { $0.0.name }, ["Transport", "Food", "Subscriptions"])
    }

    func testMLLabelMatchingIsCaseInsensitive() {
        let predictor = StubPredictor(results: [hypothesis("transport", 0.91)])

        let suggestion = suggest(merchant: "City Cab", predictor: predictor)

        XCTAssertEqual(suggestion?.category.name, "Transport")
        XCTAssertEqual(suggestion?.source, .ml)
    }

    func testLowConfidenceMLPredictionFallsBackToOther() {
        let predictor = StubPredictor(results: [hypothesis("Transport", 0.69)])

        let suggestion = suggest(merchant: "Ambiguous Merchant", predictor: predictor)

        XCTAssertEqual(suggestion?.category.name, "Other")
        XCTAssertEqual(suggestion?.source, .fallback)
    }

    func testNarrowMLMarginFallsBackToOther() {
        let predictor = StubPredictor(results: [
            hypothesis("Transport", 0.75),
            hypothesis("Food", 0.60)
        ])

        let suggestion = suggest(merchant: "Ambiguous Merchant", predictor: predictor)

        XCTAssertEqual(suggestion?.category.name, "Other")
        XCTAssertEqual(suggestion?.source, .fallback)
    }

    func testOtherMLPredictionFallsBackToReviewableOther() {
        let predictor = StubPredictor(results: [
            hypothesis("Other", 0.92),
            hypothesis("Food", 0.04)
        ])

        let suggestion = suggest(merchant: "Unknown Vendor", predictor: predictor)

        XCTAssertEqual(suggestion?.category.name, "Other")
        XCTAssertEqual(suggestion?.source, .fallback)
        XCTAssertEqual(suggestion?.confidence, 0.2)
    }

    func testUnknownMLLabelFallsBackToOther() {
        let predictor = StubPredictor(results: [hypothesis("Entertainment", 0.99)])

        let suggestion = suggest(merchant: "Cinema", predictor: predictor)

        XCTAssertEqual(suggestion?.category.name, "Other")
        XCTAssertEqual(suggestion?.source, .fallback)
    }

    func testCustomCategoryStillWorksThroughUserRule() {
        let medical = Category(name: "Medical")
        let rule = CategoryRule(ruleType: .merchantExact, pattern: "CITY PHARMACY", category: medical, priority: 200)

        let suggestion = CategorizationEngine.suggest(
            merchant: "City Pharmacy",
            amount: 42,
            kind: .expense,
            categories: [food, transport, subscriptions, other, medical],
            rules: [rule],
            history: [],
            predictor: StubPredictor(results: [hypothesis("Other", 0.99)])
        )

        XCTAssertEqual(suggestion?.category.name, "Medical")
        XCTAssertEqual(suggestion?.source, .rule)
    }

    private func suggest(
        merchant: String,
        kind: TransactionKind = .expense,
        rules: [CategoryRule] = [],
        history: [Transaction] = [],
        predictor: some CategoryPredicting
    ) -> CategorySuggestion? {
        CategorizationEngine.suggest(
            merchant: merchant,
            amount: 10,
            kind: kind,
            categories: [food, transport, subscriptions, other],
            rules: rules,
            history: history,
            predictor: predictor
        )
    }

    private func hypothesis(_ label: String, _ confidence: Double) -> MLCategoryHypothesis {
        MLCategoryHypothesis(label: label, confidence: confidence)
    }
}
