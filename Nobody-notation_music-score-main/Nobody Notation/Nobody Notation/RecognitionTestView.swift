import SwiftUI
import PencilKit
import ScoreIMEKit

// MODIFIED: 集成 ScoreIMEKit - 识别测试面板，画布大小与 Calibration 一致
struct RecognitionTestView: View {
    @ObservedObject var recognizer: SymbolRecognizer

    @State private var canvasView = PKCanvasView()
    @State private var results: [RecognitionResult] = []

    var body: some View {
        VStack(spacing: 16) {
            // 状态指示
            HStack {
                Circle()
                    .fill(recognizer.isCalibrated ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(recognizer.isCalibrated ? "Personalized" : "Base Model")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            // 识别结果
            HStack(spacing: 12) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    VStack(spacing: 4) {
                        Text(SymbolDisplayMap.displayString(for: result.symbol))
                            .font(.system(size: index == 0 ? 40 : 24,
                                         weight: index == 0 ? .bold : .regular,
                                         design: .monospaced))
                            .foregroundColor(index == 0 ? .primary : .secondary)
                        Text("\(result.symbol) \(Int(result.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 60)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(index == 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                }

                if results.isEmpty {
                    Text("Draw a symbol below")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }

                Spacer()
            }
            .frame(height: 80)
            .padding(.horizontal)

            // 画布（和 Calibration 一样大小 250pt）
            HandwritingCanvas(
                canvasView: $canvasView,
                onStrokeEnd: { performRecognition() }
            )
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)

            // 清除按钮
            Button {
                canvasView.clearCanvas()
                results = []
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
        }
        .padding()
    }

    private func performRecognition() {
        let image = canvasView.exportAsImage()
        results = recognizer.recognize(image)
    }
}
