import SwiftUI
import PencilKit

/// A PencilKit canvas that detects when the user stops drawing and triggers recognition.
public struct HandwritingCanvas: UIViewRepresentable {

    @Binding var canvasView: PKCanvasView
    var onStrokeEnd: () -> Void
    /// Called immediately when strokes are added or removed; provides current hasStrokes state
    var onStrokeChanged: ((Bool) -> Void)? = nil
    var strokeWidth: CGFloat = 3.0  // Consistent width; thickness normalized in preprocessing
    // MODIFIED: ScoreIMEKit - drawingPolicy 改为可配置参数
    var drawingPolicy: PKCanvasViewDrawingPolicy = .anyInput
    var debounceInterval: TimeInterval = 1.5  // MODIFIED: 可配置 debounce 间隔
    var transparent: Bool = false  // MODIFIED: 透明背景支持，用于覆盖式布局
    var inkColor: UIColor = .black  // MODIFIED: 可配置笔迹颜色

    public init(
        canvasView: Binding<PKCanvasView>,
        onStrokeEnd: @escaping () -> Void,
        onStrokeChanged: ((Bool) -> Void)? = nil,
        strokeWidth: CGFloat = 3.0,
        drawingPolicy: PKCanvasViewDrawingPolicy = .anyInput,
        debounceInterval: TimeInterval = 1.5,
        transparent: Bool = false,
        inkColor: UIColor = .black
    ) {
        self._canvasView = canvasView
        self.onStrokeEnd = onStrokeEnd
        self.onStrokeChanged = onStrokeChanged
        self.strokeWidth = strokeWidth
        self.drawingPolicy = drawingPolicy
        self.debounceInterval = debounceInterval
        self.transparent = transparent
        self.inkColor = inkColor
    }

    public func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = drawingPolicy
        canvasView.tool = PKInkingTool(.pen, color: inkColor, width: strokeWidth)
        canvasView.delegate = context.coordinator
        if transparent {
            canvasView.backgroundColor = .clear
            canvasView.isOpaque = false
        } else {
            canvasView.backgroundColor = .white
            canvasView.isOpaque = true
        }
        return canvasView
    }

    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.onStrokeEnd = onStrokeEnd
        context.coordinator.onStrokeChanged = onStrokeChanged
        // Note: debounceInterval is let, set at init time
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onStrokeEnd: onStrokeEnd, onStrokeChanged: onStrokeChanged, debounceInterval: debounceInterval)
    }

    public class Coordinator: NSObject, PKCanvasViewDelegate {
        var onStrokeEnd: () -> Void
        var onStrokeChanged: ((Bool) -> Void)?
        private var debounceTimer: Timer?
        let debounceInterval: TimeInterval

        init(onStrokeEnd: @escaping () -> Void, onStrokeChanged: ((Bool) -> Void)?, debounceInterval: TimeInterval = 1.5) {
            self.onStrokeEnd = onStrokeEnd
            self.onStrokeChanged = onStrokeChanged
            self.debounceInterval = debounceInterval
        }

        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let hasStrokes = !canvasView.drawing.strokes.isEmpty
            // Notify immediately so UI (e.g. Confirm button) can react
            DispatchQueue.main.async { [weak self] in
                self?.onStrokeChanged?(hasStrokes)
            }
            // Debounce recognition trigger
            debounceTimer?.invalidate()
            guard hasStrokes else { return }
            debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
                self?.onStrokeEnd()
            }
        }
    }
}

// MARK: - Canvas Helper Extension

public extension PKCanvasView {

    /// Export the current drawing as a UIImage with white background.
    func exportAsImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(bounds)
            // Draw the strokes
            drawing.image(from: bounds, scale: UIScreen.main.scale)
                .draw(in: bounds)
        }
    }

    /// Clear all strokes.
    func clearCanvas() {
        drawing = PKDrawing()
    }
}
