import Foundation
import SwiftData

enum TransferDetector {
    private static let strictTransferPatterns = [
        "SEND E-TFR",
        "E-TRANSFER",
        "E-TFR",
        "INTERAC",
        "TRANSFER",
        "EFT",
        "WIRE",
        "ACH",
        "INTERNAL"
    ]

    private static let relaxedCounterpartPatterns = [
        "WS INVEST",
        "INVESTMENTS",
        "INVEST",
        "SPEND"
    ]

    static func isLikelyTransfer(merchant: String) -> Bool {
        isStrictTransfer(merchant: merchant)
    }

    @discardableResult
    static func neutralizePairs(
        modelContext: ModelContext,
        newTransactions: [Transaction]
    ) -> Int {
        guard !newTransactions.isEmpty else { return 0 }

        let allTransactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let newIDs = Set(newTransactions.map(\.persistentModelID))

        let newCandidates = newTransactions
            .filter { ($0.kind == .expense || $0.kind == .income) && isRelaxedTransferLeg($0) }
            .sorted { $0.date > $1.date }

        var matchedIDs = Set<PersistentIdentifier>()
        var pairCount = 0

        for candidate in newCandidates {
            guard !matchedIDs.contains(candidate.persistentModelID) else { continue }

            let oppositeKind: TransactionKind = candidate.kind == .expense ? .income : .expense

            let matches = allTransactions.filter { other in
                guard other.persistentModelID != candidate.persistentModelID else { return false }
                guard !matchedIDs.contains(other.persistentModelID) else { return false }
                guard other.kind == oppositeKind else { return false }
                guard amountsMatch(other.amount, candidate.amount) else { return false }
                guard datesWithinOneDay(candidate.date, other.date) else { return false }
                guard haveDifferentOrigin(candidate, other) else { return false }
                guard canFormTransferPair(candidate, other) else { return false }
                guard newIDs.contains(candidate.persistentModelID)
                    || newIDs.contains(other.persistentModelID) else { return false }
                return true
            }

            guard let bestMatch = matches.min(by: {
                abs($0.date.timeIntervalSince(candidate.date)) < abs($1.date.timeIntervalSince(candidate.date))
            }) else { continue }

            candidate.kind = .transfer
            candidate.category = nil
            bestMatch.kind = .transfer
            bestMatch.category = nil
            matchedIDs.insert(candidate.persistentModelID)
            matchedIDs.insert(bestMatch.persistentModelID)
            pairCount += 1
        }

        if pairCount > 0 {
            try? modelContext.save()
        }

        return pairCount
    }

    private static func isStrictTransfer(merchant: String) -> Bool {
        let normalized = MerchantNormalizer.normalize(merchant)
        guard !normalized.isEmpty else { return false }

        return strictTransferPatterns.contains { normalized.contains($0) }
    }

    private static func isRelaxedTransferLeg(_ transaction: Transaction) -> Bool {
        if isStrictTransfer(merchant: transaction.merchant) {
            return true
        }

        let normalized = MerchantNormalizer.normalize(transaction.merchant)
        guard !normalized.isEmpty else { return false }

        return relaxedCounterpartPatterns.contains { pattern in
            normalized == pattern || normalized.contains(pattern)
        }
    }

    private static func canFormTransferPair(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        guard isRelaxedTransferLeg(lhs), isRelaxedTransferLeg(rhs) else { return false }
        return isStrictTransfer(merchant: lhs.merchant) || isStrictTransfer(merchant: rhs.merchant)
    }

    private static func amountsMatch(_ lhs: Decimal, _ rhs: Decimal) -> Bool {
        NSDecimalNumber(decimal: lhs).compare(NSDecimalNumber(decimal: rhs)) == .orderedSame
    }

    private static func datesWithinOneDay(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: lhs)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: start),
              let dayAfter = calendar.date(byAdding: .day, value: 1, to: start) else {
            return false
        }
        let otherDay = calendar.startOfDay(for: rhs)
        return otherDay >= dayBefore && otherDay <= dayAfter
    }

    private static func haveDifferentOrigin(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        let lhsBatchID = lhs.importBatch?.persistentModelID
        let rhsBatchID = rhs.importBatch?.persistentModelID

        if let lhsBatchID, let rhsBatchID {
            return lhsBatchID != rhsBatchID
        }

        if lhsBatchID == nil && rhsBatchID == nil {
            return lhs.source != rhs.source
        }

        return true
    }
}
