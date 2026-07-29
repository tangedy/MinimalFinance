#!/usr/bin/env swift

import CreateML
import Darwin
import Foundation

private struct CorpusRow {
    let text: String
    let label: String
    let merchantFamily: String
    let split: String
}

private struct ScoredPrediction {
    let expected: String
    let probabilities: [String: Double]

    var ranked: [(label: String, confidence: Double)] {
        probabilities
            .map { (label: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
    }
}

private struct Threshold: CustomStringConvertible {
    let confidence: Double
    let margin: Double

    var description: String {
        "confidence=\(format(confidence)) margin=\(format(margin))"
    }
}

private struct GateMetrics {
    let precision: Double
    let coverage: Double
    let runtimeAccuracy: Double
    let acceptedCount: Int
}

private let expectedLabels = [
    "Rent", "Tuition", "Food", "Transport", "Subscriptions", "Other"
]
private let expectedLabelSet = Set(expectedLabels)
private let requiredSplits = Set(["train", "validation", "test"])
private let targetAcceptedPrecision = 0.90
private let fallbackThreshold = Threshold(confidence: 0.70, margin: 0.20)

private let keywordBaseline: [String: [String]] = [
    "Rent": ["RENT", "LANDLORD", "LEASE"],
    "Tuition": ["TUITION", "UNIVERSITY", "COLLEGE", "STUDENT FEES", "STUDENT ACCOUNT"],
    "Food": [
        "STARBUCKS", "TIM HORTONS", "TIMS", "RESTAURANT", "GROCERY", "SUPERMARKET",
        "FOOD", "CAFE", "COFFEE", "MCDONALDS"
    ],
    "Transport": ["UBER", "LYFT", "TRANSIT", "PRESTO", "METROLINX", "FARE", "GAS", "FUEL", "PARKING"],
    "Subscriptions": ["SPOTIFY", "NETFLIX", "APPLE", "ADOBE", "DISNEY", "YOUTUBE", "PREMIUM"]
]

private func run() throws {
    let arguments = CommandLine.arguments
    let inputPath = arguments.count > 1
        ? arguments[1]
        : "MLTrainingData/merchant_categories.csv"
    let outputPath = arguments.count > 2
        ? arguments[2]
        : "MinimalFinance/Resources/Models/MerchantCategoryClassifier.mlmodel"

    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    let rows = try loadCorpus(from: inputURL)
    try validateCorpus(rows)
    printCorpusSummary(rows)

    let trainingRows = rows.filter { $0.split == "train" }
    let validationRows = rows.filter { $0.split == "validation" }
    let testRows = rows.filter { $0.split == "test" }

    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MinimalFinance-ML-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let trainingCSV = temporaryDirectory.appendingPathComponent("training.csv")
    try writeTrainingCSV(trainingRows, to: trainingCSV)
    let trainingData = try MLDataTable(contentsOf: trainingCSV)
    let classifier = try MLTextClassifier(
        trainingData: trainingData,
        textColumn: "text",
        labelColumn: "label"
    )

    let validationPredictions = try predictions(for: validationRows, classifier: classifier)
    let testPredictions = try predictions(for: testRows, classifier: classifier)
    let baselineValidation = validationRows.map(keywordPrediction)
    let baselineTest = testRows.map(keywordPrediction)

    print("\nValidation comparison")
    printClassificationSummary(name: "Keyword baseline", predictions: baselineValidation)
    printClassificationSummary(name: "Create ML", predictions: validationPredictions)

    let selectedThreshold = selectThreshold(from: validationPredictions)
    let validationGate = gateMetrics(validationPredictions, threshold: selectedThreshold)
    let testGate = gateMetrics(testPredictions, threshold: selectedThreshold)

    print("\nSelected runtime gate: \(selectedThreshold)")
    printGateSummary(name: "Validation", metrics: validationGate)
    print("\nUntouched test comparison")
    printClassificationSummary(name: "Keyword baseline", predictions: baselineTest)
    printClassificationSummary(name: "Create ML", predictions: testPredictions)
    printGateSummary(name: "Test", metrics: testGate)

    if validationGate.precision < targetAcceptedPrecision {
        print("WARNING: No validation threshold reached \(format(targetAcceptedPrecision)) accepted precision; using conservative defaults.")
    }

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
    }

    let metadata = MLModelMetadata(
        author: "MinimalFinance",
        shortDescription: "Classifies normalized merchant descriptions into MinimalFinance built-in categories.",
        version: "1.0"
    )
    try classifier.write(to: outputURL, metadata: metadata)

    let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
    print("\nExported \(outputURL.path) (\(bytes) bytes)")
    print("Set CategorizationEngine.mlMinimumConfidence to \(format(selectedThreshold.confidence))")
    print("Set CategorizationEngine.mlMinimumMargin to \(format(selectedThreshold.margin))")
}

private func loadCorpus(from url: URL) throws -> [CorpusRow] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    let lines = contents
        .components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    guard lines.first == "text,label,merchant_family,split" else {
        throw TrainingError.invalidCorpus("Expected header: text,label,merchant_family,split")
    }

    return try lines.dropFirst().enumerated().map { index, line in
        let fields = parseCSVFields(line)
        guard fields.count == 4 else {
            throw TrainingError.invalidCorpus("Line \(index + 2) has \(fields.count) columns; expected 4")
        }
        return CorpusRow(
            text: fields[0].trimmingCharacters(in: .whitespacesAndNewlines),
            label: fields[1].trimmingCharacters(in: .whitespacesAndNewlines),
            merchantFamily: fields[2].trimmingCharacters(in: .whitespacesAndNewlines),
            split: fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private func validateCorpus(_ rows: [CorpusRow]) throws {
    guard !rows.isEmpty else { throw TrainingError.invalidCorpus("Corpus is empty") }

    let labels = Set(rows.map(\.label))
    guard labels == expectedLabelSet else {
        throw TrainingError.invalidCorpus("Labels must be exactly \(expectedLabels); found \(labels.sorted())")
    }

    let splits = Set(rows.map(\.split))
    guard splits == requiredSplits else {
        throw TrainingError.invalidCorpus("Splits must be exactly \(requiredSplits.sorted()); found \(splits.sorted())")
    }

    guard rows.allSatisfy({ !$0.text.isEmpty && !$0.merchantFamily.isEmpty }) else {
        throw TrainingError.invalidCorpus("Text and merchant_family values must not be empty")
    }

    let duplicateTexts = Dictionary(grouping: rows, by: { $0.text.uppercased() })
        .filter { $0.value.count > 1 }
        .keys
    guard duplicateTexts.isEmpty else {
        throw TrainingError.invalidCorpus("Duplicate text examples: \(duplicateTexts.sorted())")
    }

    let familySplits = Dictionary(grouping: rows, by: \.merchantFamily)
        .mapValues { Set($0.map(\.split)) }
        .filter { $0.value.count > 1 }
    guard familySplits.isEmpty else {
        throw TrainingError.invalidCorpus("Merchant families cross splits: \(familySplits.keys.sorted())")
    }

    for label in expectedLabels {
        for split in requiredSplits {
            guard rows.contains(where: { $0.label == label && $0.split == split }) else {
                throw TrainingError.invalidCorpus("Missing \(label) examples in \(split)")
            }
        }
    }
}

private func printCorpusSummary(_ rows: [CorpusRow]) {
    print("Corpus: \(rows.count) examples")
    for label in expectedLabels {
        let counts = requiredSplits.sorted().map { split in
            "\(split)=\(rows.filter { $0.label == label && $0.split == split }.count)"
        }
        print("  \(label): \(counts.joined(separator: " "))")
    }
}

private func writeTrainingCSV(_ rows: [CorpusRow], to url: URL) throws {
    let lines = rows.map { "\(csvEscape($0.text)),\(csvEscape($0.label))" }
    try (["text,label"] + lines).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
}

private func predictions(
    for rows: [CorpusRow],
    classifier: MLTextClassifier
) throws -> [ScoredPrediction] {
    try rows.map { row in
        ScoredPrediction(
            expected: row.label,
            probabilities: try classifier.predictionWithConfidence(from: row.text)
        )
    }
}

private func keywordPrediction(_ row: CorpusRow) -> ScoredPrediction {
    let normalized = row.text.uppercased()
    let label = keywordBaseline.first(where: { _, keywords in
        keywords.contains(where: normalized.contains)
    })?.key ?? "Other"
    return ScoredPrediction(expected: row.label, probabilities: [label: 1])
}

private func selectThreshold(from predictions: [ScoredPrediction]) -> Threshold {
    let confidenceCandidates = [0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90]
    let marginCandidates = [0.00, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30]
    let candidates = confidenceCandidates.flatMap { confidence in
        marginCandidates.map { Threshold(confidence: confidence, margin: $0) }
    }

    let eligible = candidates
        .map { ($0, gateMetrics(predictions, threshold: $0)) }
        .filter { $0.1.acceptedCount > 0 && $0.1.precision >= targetAcceptedPrecision }

    return eligible.max { left, right in
        if left.1.coverage != right.1.coverage {
            return left.1.coverage < right.1.coverage
        }
        if left.1.precision != right.1.precision {
            return left.1.precision < right.1.precision
        }
        if left.0.confidence != right.0.confidence {
            return left.0.confidence < right.0.confidence
        }
        return left.0.margin < right.0.margin
    }?.0 ?? fallbackThreshold
}

private func gateMetrics(_ predictions: [ScoredPrediction], threshold: Threshold) -> GateMetrics {
    let results = predictions.map { prediction -> (accepted: String?, runtime: String) in
        let ranked = prediction.ranked
        guard let top = ranked.first,
              top.label != "Other",
              top.confidence >= threshold.confidence else {
            return (nil, "Other")
        }
        let secondConfidence = ranked.dropFirst().first?.confidence ?? 0
        guard top.confidence - secondConfidence >= threshold.margin else {
            return (nil, "Other")
        }
        return (top.label, top.label)
    }

    let accepted = zip(predictions, results).filter { $0.1.accepted != nil }
    let acceptedCorrect = accepted.filter { $0.0.expected == $0.1.accepted }.count
    let runtimeCorrect = zip(predictions, results).filter { $0.0.expected == $0.1.runtime }.count

    return GateMetrics(
        precision: accepted.isEmpty ? 0 : Double(acceptedCorrect) / Double(accepted.count),
        coverage: predictions.isEmpty ? 0 : Double(accepted.count) / Double(predictions.count),
        runtimeAccuracy: predictions.isEmpty ? 0 : Double(runtimeCorrect) / Double(predictions.count),
        acceptedCount: accepted.count
    )
}

private func printClassificationSummary(name: String, predictions: [ScoredPrediction]) {
    let predictedLabels = predictions.map { $0.ranked.first?.label ?? "Other" }
    let correct = zip(predictions, predictedLabels).filter { $0.0.expected == $0.1 }.count
    let accuracy = predictions.isEmpty ? 0 : Double(correct) / Double(predictions.count)

    var macroPrecision = 0.0
    var macroRecall = 0.0
    var macroF1 = 0.0
    for label in expectedLabels {
        let truePositive = zip(predictions, predictedLabels).filter { $0.0.expected == label && $0.1 == label }.count
        let falsePositive = zip(predictions, predictedLabels).filter { $0.0.expected != label && $0.1 == label }.count
        let falseNegative = zip(predictions, predictedLabels).filter { $0.0.expected == label && $0.1 != label }.count
        let precision = ratio(truePositive, truePositive + falsePositive)
        let recall = ratio(truePositive, truePositive + falseNegative)
        let f1 = precision + recall == 0 ? 0 : 2 * precision * recall / (precision + recall)
        macroPrecision += precision
        macroRecall += recall
        macroF1 += f1
    }

    let divisor = Double(expectedLabels.count)
    print(
        "  \(name): accuracy=\(format(accuracy)) "
            + "macro_precision=\(format(macroPrecision / divisor)) "
            + "macro_recall=\(format(macroRecall / divisor)) "
            + "macro_f1=\(format(macroF1 / divisor))"
    )
    printConfusionMatrix(predictions: predictions, predictedLabels: predictedLabels)
}

private func printConfusionMatrix(predictions: [ScoredPrediction], predictedLabels: [String]) {
    print("    confusion rows=expected columns=predicted")
    print("    label\t\(expectedLabels.joined(separator: "\t"))")
    for expected in expectedLabels {
        let counts = expectedLabels.map { predicted in
            zip(predictions, predictedLabels).filter { $0.0.expected == expected && $0.1 == predicted }.count
        }
        print("    \(expected)\t\(counts.map(String.init).joined(separator: "\t"))")
    }
}

private func printGateSummary(name: String, metrics: GateMetrics) {
    print(
        "  \(name) gate: accepted_precision=\(format(metrics.precision)) "
            + "coverage=\(format(metrics.coverage)) runtime_accuracy=\(format(metrics.runtimeAccuracy)) "
            + "accepted=\(metrics.acceptedCount)"
    )
}

private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
    denominator == 0 ? 0 : Double(numerator) / Double(denominator)
}

private func format(_ value: Double) -> String {
    String(format: "%.3f", value)
}

private func parseCSVFields(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    var index = line.startIndex

    while index < line.endIndex {
        let character = line[index]
        if character == "\"" {
            let next = line.index(after: index)
            if inQuotes, next < line.endIndex, line[next] == "\"" {
                current.append("\"")
                index = next
            } else {
                inQuotes.toggle()
            }
        } else if character == ",", !inQuotes {
            fields.append(current)
            current = ""
        } else {
            current.append(character)
        }
        index = line.index(after: index)
    }

    fields.append(current)
    return fields
}

private func csvEscape(_ value: String) -> String {
    guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
    return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

private enum TrainingError: LocalizedError {
    case invalidCorpus(String)

    var errorDescription: String? {
        switch self {
        case .invalidCorpus(let message): message
        }
    }
}

do {
    try run()
} catch {
    fputs("Training failed: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}