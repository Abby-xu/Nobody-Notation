import SwiftUI
import PencilKit

/// Guides the user through writing each of the 28 symbols once for personalization.
public struct CalibrationFlow: View {

    @ObservedObject var recognizer: SymbolRecognizer
    var onComplete: () -> Void

    @State private var currentIndex = 0
    @State private var canvasView = PKCanvasView()
    @State private var calibratedCount = 0
    @State private var showError = false
    @State private var hasStrokes = false

    public init(recognizer: SymbolRecognizer, onComplete: @escaping () -> Void) {
        self.recognizer = recognizer
        self.onComplete = onComplete
    }

    private var currentSymbol: String {
        guard currentIndex < recognizer.classNames.count else { return "" }
        return recognizer.classNames[currentIndex]
    }

    private var totalSymbols: Int {
        recognizer.classNames.count
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Progress
            Text("Calibration \(calibratedCount)/\(totalSymbols)")
                .font(.headline)
                .foregroundColor(.secondary)

            ProgressView(value: Double(calibratedCount), total: Double(totalSymbols))
                .padding(.horizontal)

            // Current symbol prompt
            VStack(spacing: 8) {
                Text("Please write:")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(currentSymbol)
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
            }

            // Canvas
            HandwritingCanvas(
                canvasView: $canvasView,
                onStrokeEnd: {},
                onStrokeChanged: { hasStrokes = $0 }
            )
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)

            if showError {
                Text("Recognition failed, please try again")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Action buttons
            HStack(spacing: 20) {
                Button("Clear") {
                    canvasView.clearCanvas()
                    hasStrokes = false
                    showError = false
                }
                .buttonStyle(.bordered)

                Button("Confirm") {
                    confirmCurrentSymbol()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasStrokes)
            }
        }
        .padding()
    }

    private func confirmCurrentSymbol() {
        let image = canvasView.exportAsImage()
        let success = recognizer.calibrate(symbol: currentSymbol, image: image)

        if success {
            showError = false
            calibratedCount += 1
            hasStrokes = false
            canvasView.clearCanvas()

            if currentIndex + 1 < totalSymbols {
                currentIndex += 1
            } else {
                // All symbols calibrated
                recognizer.savePrototypes()
                onComplete()
            }
        } else {
            showError = true
        }
    }
}
