import CoreML
import UIKit
import Accelerate

/// Recognition result for a single symbol.
public struct RecognitionResult {
    public let symbol: String
    public let confidence: Float
}

/// Recognizes handwritten music symbols using Core ML.
/// Supports two modes:
///   1. Direct classification (28-class softmax)
///   2. Personalized nearest-neighbor matching using user prototypes
@MainActor
public final class SymbolRecognizer: ObservableObject {

    @Published public var isCalibrated = false

    private var classifierModel: MLModel?
    private var featureModel: MLModel?

    /// Label mapping: index -> symbol name
    private var idxToClass: [Int: String] = [:]

    /// User prototypes: symbol name -> feature vector (1024-dim)
    private var userPrototypes: [String: [Float]] = [:]

    /// All 28 class names in order
    public private(set) var classNames: [String] = []

    private let prototypesFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("user_prototypes.json")
    }()

    public init() {
        loadModels()
        loadLabelMap()
        loadPrototypes()
    }

    // MARK: - Model Loading

    private func loadModels() {
        // MODIFIED: ScoreIMEKit - Bundle.main → Bundle.module
        if let modelURL = Bundle.module.url(forResource: "ScoreIME", withExtension: "mlmodelc") ??
            Bundle.module.url(forResource: "ScoreIME", withExtension: "mlpackage") {
            classifierModel = try? MLModel(contentsOf: modelURL)
        }

        // MODIFIED: ScoreIMEKit - Bundle.main → Bundle.module
        if let modelURL = Bundle.module.url(forResource: "ScoreIMEFeature", withExtension: "mlmodelc") ??
            Bundle.module.url(forResource: "ScoreIMEFeature", withExtension: "mlpackage") {
            featureModel = try? MLModel(contentsOf: modelURL)
        }
    }

    private func loadLabelMap() {
        // MODIFIED: ScoreIMEKit - Bundle.main → Bundle.module
        guard let url = Bundle.module.url(forResource: "label_map", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idxToClassDict = json["idx_to_class"] as? [String: String] else {
            return
        }

        for (key, value) in idxToClassDict {
            if let idx = Int(key) {
                idxToClass[idx] = value
            }
        }

        classNames = (0..<idxToClass.count).compactMap { idxToClass[$0] }
    }

    // MARK: - Recognition

    /// Recognize a symbol from a UIImage (canvas snapshot).
    /// Returns top-3 results sorted by confidence.
    /// When calibrated, combines base model + personalized prototype scores.
    public func recognize(_ image: UIImage) -> [RecognitionResult] {
        guard let pixelBuffer = ImagePreprocessor.preprocess(image) else {
            print("Preprocess failed")
            return []
        }

        // If calibrated, combine base model + personalized scores
        if isCalibrated, !userPrototypes.isEmpty {
            return recognizeCombined(pixelBuffer)
        }

        // Otherwise, use direct classification only
        return recognizeWithClassifier(pixelBuffer)
    }

    /// Combined recognition: base model softmax + prototype cosine similarity.
    /// This leverages the base model's learned features while adapting to user style.
    private func recognizeCombined(_ pixelBuffer: CVPixelBuffer) -> [RecognitionResult] {
        // Get base model probabilities
        let baseResults = getClassifierProbs(pixelBuffer)

        // Get prototype similarities
        guard let features = extractFeatures(pixelBuffer) else {
            // Fall back to base model only
            let sorted = baseResults.sorted { $0.value > $1.value }
            return sorted.prefix(3).map {
                RecognitionResult(symbol: $0.key, confidence: Float($0.value))
            }
        }

        // Compute cosine similarity with each prototype and convert to probabilities
        var similarities: [String: Float] = [:]
        for (symbol, prototype) in userPrototypes {
            similarities[symbol] = cosineSimilarity(features, prototype)
        }

        // Convert similarities to probabilities via temperature-scaled softmax
        let temperature: Float = 0.1
        let maxSim = similarities.values.max() ?? 0
        var protoProbs: [String: Float] = [:]
        var sumExp: Float = 0
        for (symbol, sim) in similarities {
            let e = exp((sim - maxSim) / temperature)
            protoProbs[symbol] = e
            sumExp += e
        }
        for symbol in protoProbs.keys {
            protoProbs[symbol]! /= sumExp
        }

        // Combine: weighted average of base model and prototype probabilities
        // Lean towards personalized model (70%) since it's calibrated to user's style
        let baseWeight: Float = 0.3
        let protoWeight: Float = 0.7

        var combined: [String: Float] = [:]
        for symbol in classNames {
            let base = Float(baseResults[symbol] ?? 0)
            let proto = protoProbs[symbol] ?? 0
            combined[symbol] = baseWeight * base + protoWeight * proto
        }

        // Sort and return top-3
        let sorted = combined.sorted { $0.value > $1.value }
        let total = sorted.prefix(3).reduce(Float(0)) { $0 + $1.value }
        return sorted.prefix(3).map {
            RecognitionResult(symbol: $0.key, confidence: total > 0 ? $0.value / total : 0)
        }
    }

    /// Get raw classifier probabilities as a dictionary.
    private func getClassifierProbs(_ pixelBuffer: CVPixelBuffer) -> [String: Double] {
        guard let model = classifierModel else { return [:] }

        do {
            let featureValue = MLFeatureValue(pixelBuffer: pixelBuffer)
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "image": featureValue
            ])
            let output = try model.prediction(from: input)

            guard let probs = output.featureValue(for: "classLabel_probs")?.dictionaryValue as? [String: Double] else {
                print("No classLabel_probs in output. Keys: \(output.featureNames)")
                return [:]
            }
            return probs
        } catch {
            print("Classification error: \(error)")
            return [:]
        }
    }

    /// Direct classification using the 28-class model.
    private func recognizeWithClassifier(_ pixelBuffer: CVPixelBuffer) -> [RecognitionResult] {
        let probs = getClassifierProbs(pixelBuffer)
        guard !probs.isEmpty else { return [] }

        let sorted = probs.sorted { $0.value > $1.value }
        return sorted.prefix(3).map {
            RecognitionResult(symbol: $0.key, confidence: Float($0.value))
        }
    }

    // MARK: - Feature Extraction

    /// Extract 1024-dim feature vector from a preprocessed CVPixelBuffer.
    public func extractFeatures(_ pixelBuffer: CVPixelBuffer) -> [Float]? {
        guard let model = featureModel else { return nil }

        do {
            let featureValue = MLFeatureValue(pixelBuffer: pixelBuffer)
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "image": featureValue
            ])
            let output = try model.prediction(from: input)

            // Get the feature vector from the first output
            guard let outputName = model.modelDescription.outputDescriptionsByName.keys.first,
                  let multiArray = output.featureValue(for: outputName)?.multiArrayValue else {
                return nil
            }

            // Convert MLMultiArray to [Float]
            let count = multiArray.count
            var features = [Float](repeating: 0, count: count)
            let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
            for i in 0..<count {
                features[i] = ptr[i]
            }

            // L2 normalize
            var norm: Float = 0
            vDSP_svesq(features, 1, &norm, vDSP_Length(count))
            norm = sqrt(norm)
            if norm > 0 {
                vDSP_vsdiv(features, 1, &norm, &features, 1, vDSP_Length(count))
            }

            return features
        } catch {
            print("Feature extraction error: \(error)")
            return nil
        }
    }

    // MARK: - Calibration (Personalization)

    /// Store a user's handwritten prototype for a given symbol.
    public func calibrate(symbol: String, image: UIImage) -> Bool {
        guard let pixelBuffer = ImagePreprocessor.preprocess(image),
              let features = extractFeatures(pixelBuffer) else {
            return false
        }

        userPrototypes[symbol] = features

        // Check if all symbols are calibrated
        isCalibrated = userPrototypes.count == classNames.count

        return true
    }

    /// Save prototypes to disk.
    public func savePrototypes() {
        // Convert [String: [Float]] to JSON-serializable format
        let data = try? JSONSerialization.data(
            withJSONObject: userPrototypes.mapValues { $0.map { Double($0) } },
            options: []
        )
        try? data?.write(to: prototypesFileURL)
    }

    /// Load prototypes from disk.
    private func loadPrototypes() {
        guard let data = try? Data(contentsOf: prototypesFileURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [Double]] else {
            return
        }

        userPrototypes = dict.mapValues { $0.map { Float($0) } }
        isCalibrated = userPrototypes.count == classNames.count
    }

    /// Reset calibration data.
    public func resetCalibration() {
        userPrototypes.removeAll()
        isCalibrated = false
        try? FileManager.default.removeItem(at: prototypesFileURL)
    }

    // MARK: - Math Utilities

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        // Vectors are already L2-normalized, so dot product = cosine similarity
        return dot
    }
}
