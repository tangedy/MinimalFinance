import Foundation
import SwiftData

enum SuggestionSource: String {
    case rule
    case history
    case scorer
    case fallback
}

struct CategorySuggestion {
    let category: Category
    let confidence: Double
    let source: SuggestionSource
    let alternatives: [(Category, Double)]
}

enum CategorizationEngine {
    private static let subscriptionWhitelist = [
        "SPOTIFY", "OBSIDIAN", "APPLE.COM/BILL", "NETFLIX", "DISNEY",
        "AMAZON PRIME", "STEAM", "HBO", "YOUTUBE", "ADOBE"
    ]

    private static let categoryKeywords: [String: [String]] = [
        "Subscriptions": ["SPOTIFY", "OBSIDIAN", "NETFLIX", "STEAM", "APPLE", "BILL", "SUBSCRIPTION", "FANDUEL"],
        "Food": ["TIM HORTONS", "STARBUCKS", "RESTAURANT", "RAMEN", "GROCERY", "FOOD", "EUREST", "MOOSE", "BURGER", "COFFEE", "SQ", "YOGURT", "BUTTER"],
        "Transport": ["UBER", "LYFT", "TRANSIT", "PRESTO", "GO TRANSIT", "TTC"],
        "Rent": ["RENT", "LANDLORD"],
        "Tuition": ["TUITION", "UNIVERSITY", "COLLEGE"]
    ]

    static func suggest(
        merchant: String,
        amount: Decimal,
        kind: TransactionKind,
        categories: [Category],
        rules: [CategoryRule],
        history: [Transaction]
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

        let scored = scoreCategories(normalized: normalized, categories: categories)
        if let gated = applyConfidenceGate(scored: scored, normalized: normalized, categories: categories) {
            return gated
        }

        if let other {
            return CategorySuggestion(
                category: other,
                confidence: 0.2,
                source: .fallback,
                alternatives: scored.prefix(3).map { ($0.category, $0.score) }
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

    private static func scoreCategories(
        normalized: String,
        categories: [Category]
    ) -> [(category: Category, score: Double)] {
        let tokens = Set(MerchantNormalizer.tokens(normalized))

        let scored = categories.compactMap { category -> (Category, Double)? in
            guard category.name != "Other" else { return nil }
            let keywords = categoryKeywords[category.name] ?? [category.name.uppercased()]
            var score = 0.0

            for keyword in keywords {
                if normalized.contains(keyword) {
                    score += 1.0
                }
                for token in tokens where keyword.contains(token) || token.contains(keyword) {
                    score += 0.4
                }
            }

            return score > 0 ? (category, score) : nil
        }

        let maxScore = scored.map(\.1).max() ?? 1
        return scored
            .map { (category: $0.0, score: $0.1 / maxScore) }
            .sorted { $0.score > $1.score }
    }

    private static func applyConfidenceGate(
        scored: [(category: Category, score: Double)],
        normalized: String,
        categories: [Category]
    ) -> CategorySuggestion? {
        guard let top = scored.first else { return nil }
        let secondScore = scored.dropFirst().first?.score ?? 0
        let margin = top.score - secondScore

        let isSubscriptionWhitelist = subscriptionWhitelist.contains { normalized.contains($0) }
        let subscriptions = categories.first { $0.name == "Subscriptions" }

        if isSubscriptionWhitelist, let subscriptions, top.score >= 0.5 || top.category.name == "Subscriptions" {
            return CategorySuggestion(
                category: subscriptions,
                confidence: max(top.score, 0.8),
                source: .scorer,
                alternatives: scored.prefix(3).map { ($0.category, $0.score) }
            )
        }

        if top.score >= 0.55, margin >= 0.15 {
            return CategorySuggestion(
                category: top.category,
                confidence: top.score,
                source: .scorer,
                alternatives: scored.prefix(3).map { ($0.category, $0.score) }
            )
        }

        return nil
    }
}
