import PencilKit
import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit

struct PencilCanvasViewRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChange: { updatedData in
            drawingData = updatedData
        })
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        configure(canvasView)
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing(from: drawingData)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.onDrawingChange = { updatedData in
            drawingData = updatedData
        }

        let currentData = uiView.drawing.dataRepresentation()
        if currentData != drawingData {
            uiView.drawing = drawing(from: drawingData)
        }
    }

    private func configure(_ canvasView: PKCanvasView) {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
    }

    private func drawing(from data: Data) -> PKDrawing {
        (try? PKDrawing(data: data)) ?? PKDrawing()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChange: (Data) -> Void

        init(onDrawingChange: @escaping (Data) -> Void) {
            self.onDrawingChange = onDrawingChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChange(canvasView.drawing.dataRepresentation())
        }
    }
}

enum HandwritingSnapshotExporter {
    static func image(from drawingData: Data, targetSize: CGSize, scale: CGFloat = 2) -> UIImage? {
        let drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        let rect = CGRect(origin: .zero, size: targetSize)
        return drawing.image(from: rect, scale: scale)
    }

    static func cgImage(from drawingData: Data, targetSize: CGSize, scale: CGFloat = 2) -> CGImage? {
        image(from: drawingData, targetSize: targetSize, scale: scale)?.cgImage
    }

    static func pngData(from drawingData: Data, targetSize: CGSize, scale: CGFloat = 2) -> Data? {
        image(from: drawingData, targetSize: targetSize, scale: scale)?.pngData()
    }
}

#elseif os(macOS)
import AppKit

struct PencilCanvasViewRepresentable: NSViewRepresentable {
    @Binding var drawingData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChange: { updatedData in
            drawingData = updatedData
        })
    }

    func makeNSView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        configure(canvasView)
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing(from: drawingData)
        return canvasView
    }

    func updateNSView(_ nsView: PKCanvasView, context: Context) {
        context.coordinator.onDrawingChange = { updatedData in
            drawingData = updatedData
        }

        let currentData = nsView.drawing.dataRepresentation()
        if currentData != drawingData {
            nsView.drawing = drawing(from: drawingData)
        }
    }

    private func configure(_ canvasView: PKCanvasView) {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
    }

    private func drawing(from data: Data) -> PKDrawing {
        (try? PKDrawing(data: data)) ?? PKDrawing()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChange: (Data) -> Void

        init(onDrawingChange: @escaping (Data) -> Void) {
            self.onDrawingChange = onDrawingChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChange(canvasView.drawing.dataRepresentation())
        }
    }
}

enum HandwritingSnapshotExporter {
    static func cgImage(from drawingData: Data, targetSize: CGSize, scale: CGFloat = 2) -> CGImage? {
        let drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        let rect = CGRect(origin: .zero, size: targetSize)
        let image = drawing.image(from: rect, scale: scale)
        var proposedRect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}
#endif
