import Foundation
import SwiftData

enum SuggestionSource: String {
    case rule
    case history
    case ml
    case fallback
}

struct CategorySuggestion {
    let category: Category
    let confidence: Double
    let source: SuggestionSource
    let alternatives: [(Category, Double)]
}

enum CategorizationEngine {
    static let mlMinimumConfidence = 0.70
    static let mlMinimumMargin = 0.20

    private static let supportedMLLabels = Set([
        "Rent", "Tuition", "Food", "Transport", "Subscriptions", "Transfer", "Clothes", "Other"
    ])

    static func suggest(
        merchant: String,
        amount: Decimal,
        kind: TransactionKind,
        categories: [Category],
        rules: [CategoryRule],
        history: [Transaction],
        predictor: any CategoryPredicting = MLCategoryClassifier.shared
    ) -> CategorySuggestion? {
        guard kind == .expense else { return nil }

        let normalized = MerchantNormalizer.normalize(merchant)
        let other = categories.first { $0.name == "Other" }

        if let ruleMatch = matchRule(normalized: normalized, rules: rules, categories: categories) {
            return ruleMatch
        }

        if let historyMatch = matchHistory(normalized: normalized, history: history, categories: categories) {
            return historyMatch
        }

        let mlHypotheses = mappedMLHypotheses(
            normalized: normalized,
            categories: categories,
            predictor: predictor
        )
        if let mlMatch = applyMLConfidenceGate(hypotheses: mlHypotheses) {
            return mlMatch
        }

        if let other {
            return CategorySuggestion(
                category: other,
                confidence: 0.2,
                source: .fallback,
                alternatives: mlHypotheses.prefix(3).map { ($0.category, $0.confidence) }
            )
        }

        return nil
    }

    private static func matchRule(
        normalized: String,
        rules: [CategoryRule],
        categories: [Category]
    ) -> CategorySuggestion? {
        let sorted = rules.sorted { $0.priority > $1.priority }

        for rule in sorted {
            guard let category = rule.category else { continue }
            let pattern = rule.pattern.uppercased()

            switch rule.ruleType {
            case .merchantExact where normalized == pattern:
                return CategorySuggestion(category: category, confidence: 0.95, source: .rule, alternatives: [])
            case .keyword, .builtin where normalized.contains(pattern):
                return CategorySuggestion(category: category, confidence: 0.85, source: .rule, alternatives: [])
            case .merchantExact, .keyword, .builtin:
                continue
            }
        }

        return nil
    }

    private static func matchHistory(
        normalized: String,
        history: [Transaction],
        categories: [Category]
    ) -> CategorySuggestion? {
        let matches = history.filter {
            $0.kind == .expense
                && MerchantNormalizer.normalize($0.merchant) == normalized
                && $0.category != nil
        }

        guard !matches.isEmpty else { return nil }

        var counts: [PersistentIdentifier: Int] = [:]
        for transaction in matches {
            guard let category = transaction.category else { continue }
            counts[category.persistentModelID, default: 0] += 1
        }

        guard let top = counts.max(by: { $0.value < $1.value }),
              Double(top.value) / Double(matches.count) >= 0.8,
              let category = matches.first(where: { $0.category?.persistentModelID == top.key })?.category else {
            return nil
        }

        return CategorySuggestion(category: category, confidence: 0.90, source: .history, alternatives: [])
    }

    private static func mappedMLHypotheses(
        normalized: String,
        categories: [Category],
        predictor: any CategoryPredicting
    ) -> [(category: Category, confidence: Double)] {
        predictor.hypotheses(for: normalized, maximumCount: 3).compactMap { hypothesis in
            guard hypothesis.confidence.isFinite,
                  (0...1).contains(hypothesis.confidence),
                  let supportedLabel = supportedMLLabels.first(where: {
                      $0.caseInsensitiveCompare(hypothesis.label) == .orderedSame
                  }),
                  let category = categories.first(where: {
                      $0.name.caseInsensitiveCompare(supportedLabel) == .orderedSame
                  }) else {
                return nil
            }
            return (category, hypothesis.confidence)
        }
        .sorted { $0.confidence > $1.confidence }
    }

    private static func applyMLConfidenceGate(
        hypotheses: [(category: Category, confidence: Double)]
    ) -> CategorySuggestion? {
        guard let top = hypotheses.first,
              top.category.name != "Other",
              top.confidence >= mlMinimumConfidence else {
            return nil
        }

        let secondConfidence = hypotheses.dropFirst().first?.confidence ?? 0
        guard top.confidence - secondConfidence >= mlMinimumMargin else { return nil }

        return CategorySuggestion(
            category: top.category,
            confidence: top.confidence,
            source: .ml,
            alternatives: Array(hypotheses.prefix(3))
        )
    }
}
