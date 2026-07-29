import XCTest
@testable import MinimalFinance

final class MLCategoryClassifierTests: XCTestCase {
    private final class TestBundleToken {}

    func testMissingModelReturnsNoHypotheses() {
        let classifier = MLCategoryClassifier(bundle: Bundle(for: TestBundleToken.self))

        XCTAssertFalse(classifier.isAvailable)
        XCTAssertTrue(classifier.availableLabels.isEmpty)
        XCTAssertTrue(classifier.hypotheses(for: "STARBUCKS", maximumCount: 3).isEmpty)
    }

    func testBundledModelContractWhenModelIsPresent() throws {
        let classifier = MLCategoryClassifier()
        guard classifier.isAvailable else {
            throw XCTSkip("Run Tools/train_categorization_model.swift and bundle the exported model to enable this smoke test.")
        }

        let expectedLabels = Set(["Rent", "Tuition", "Food", "Transport", "Subscriptions", "Other"])
        XCTAssertEqual(classifier.availableLabels, expectedLabels)

        let hypotheses = classifier.hypotheses(for: "STARBUCKS COFFEE", maximumCount: expectedLabels.count)
        XCTAssertFalse(hypotheses.isEmpty)
        XCTAssertTrue(hypotheses.allSatisfy { $0.confidence.isFinite && (0...1).contains($0.confidence) })
        XCTAssertTrue(hypotheses.allSatisfy { expectedLabels.contains($0.label) })
    }
}