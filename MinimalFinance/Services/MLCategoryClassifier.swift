import CoreML
import Foundation
import NaturalLanguage

struct MLCategoryHypothesis: Equatable, Sendable {
    let label: String
    let confidence: Double
}

protocol CategoryPredicting: Sendable {
    func hypotheses(for text: String, maximumCount: Int) -> [MLCategoryHypothesis]
}

final class MLCategoryClassifier: CategoryPredicting, @unchecked Sendable {
    static let shared = MLCategoryClassifier()

    static let modelName = "MerchantCategoryClassifier"

    private let model: NLModel?
    private let predictionLock = NSLock()
    let availableLabels: Set<String>

    var isAvailable: Bool {
        model != nil
    }

    init(bundle: Bundle = .main) {
        guard let modelURL = bundle.url(forResource: Self.modelName, withExtension: "mlmodelc"),
              let coreMLModel = try? MLModel(contentsOf: modelURL),
              let naturalLanguageModel = try? NLModel(mlModel: coreMLModel) else {
            model = nil
            availableLabels = []
            return
        }

        model = naturalLanguageModel
        availableLabels = Set((coreMLModel.modelDescription.classLabels as? [String]) ?? [])
    }

    func hypotheses(for text: String, maximumCount: Int = 3) -> [MLCategoryHypothesis] {
        guard let model, !text.isEmpty, maximumCount > 0 else { return [] }

        predictionLock.lock()
        defer { predictionLock.unlock() }

        return model.predictedLabelHypotheses(for: text, maximumCount: maximumCount)
            .map { MLCategoryHypothesis(label: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
    }
}