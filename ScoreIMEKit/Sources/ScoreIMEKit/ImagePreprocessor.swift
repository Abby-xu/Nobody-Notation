import UIKit
import CoreGraphics
import VideoToolbox

/// Preprocesses a handwriting canvas image for model inference.
/// Extracts the stroke bounding box, pads to square, resizes to 128x128,
/// then normalizes stroke thickness to match training data.
public struct ImagePreprocessor {

    public static let targetSize = 128
    public static let padding: CGFloat = 20
    public static let targetStrokeThickness = 5  // must match training augment.py

    /// Process a UIImage from the canvas into a 128x128 grayscale CVPixelBuffer ready for Core ML.
    public static func preprocess(_ image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = preprocessToCGImage(image) else { return nil }
        // Normalize stroke thickness to match training data
        guard let normalized = normalizeStrokeThickness(cgImage) else { return nil }
        return cgImageToPixelBuffer(normalized)
    }

    /// Internal: produce a 128x128 grayscale CGImage.
    static func preprocessToCGImage(_ image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Convert to grayscale pixel buffer
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height)

        // Find bounding box of dark pixels (stroke)
        var minX = width, minY = height, maxX = 0, maxY = 0
        let threshold: UInt8 = 200

        for y in 0..<height {
            for x in 0..<width {
                if pixels[y * width + x] < threshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        // No stroke found
        guard minX < maxX && minY < maxY else { return nil }

        // Add padding
        let pad = Int(padding)
        let cropX = max(0, minX - pad)
        let cropY = max(0, minY - pad)
        let cropW = min(width - cropX, (maxX - minX) + 2 * pad)
        let cropH = min(height - cropY, (maxY - minY) + 2 * pad)

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        // Crop
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        // Make square (pad shorter side with white)
        let maxSide = max(cropW, cropH)

        guard let squareContext = CGContext(
            data: nil,
            width: maxSide,
            height: maxSide,
            bitsPerComponent: 8,
            bytesPerRow: maxSide,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        // Fill with white
        squareContext.setFillColor(gray: 1.0, alpha: 1.0)
        squareContext.fill(CGRect(x: 0, y: 0, width: maxSide, height: maxSide))

        // Center the cropped image
        let xOffset = (maxSide - cropW) / 2
        let yOffset = (maxSide - cropH) / 2
        squareContext.draw(cropped, in: CGRect(x: xOffset, y: yOffset, width: cropW, height: cropH))

        guard let squareImage = squareContext.makeImage() else { return nil }

        // Resize to target size (128x128)
        guard let resizeContext = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        resizeContext.interpolationQuality = .high
        resizeContext.draw(squareImage, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        return resizeContext.makeImage()
    }

    // MARK: - Stroke Thickness Normalization

    /// Normalize stroke thickness: skeletonize then dilate to uniform width.
    static func normalizeStrokeThickness(_ cgImage: CGImage) -> CGImage? {
        let w = cgImage.width
        let h = cgImage.height

        // Get pixel data
        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h)

        // Threshold to binary: 1 = stroke (dark), 0 = background (white)
        var binary = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            binary[i] = pixels[i] < 200 ? 1 : 0
        }

        // Check if there are any strokes
        let strokeCount = binary.reduce(0) { $0 + Int($1) }
        if strokeCount == 0 { return cgImage }

        // Skeletonize using morphological thinning
        var skeleton = morphologicalSkeleton(&binary, width: w, height: h)

        // Dilate skeleton to target thickness
        let radius = max(1, targetStrokeThickness / 2)
        let dilated = dilateCircular(&skeleton, width: w, height: h, radius: radius)

        // Write back to pixel buffer
        for i in 0..<(w * h) {
            pixels[i] = dilated[i] > 0 ? 0 : 255
        }

        return context.makeImage()
    }

    /// Morphological skeletonization (erosion-based).
    private static func morphologicalSkeleton(_ binary: inout [UInt8], width w: Int, height h: Int) -> [UInt8] {
        var skeleton = [UInt8](repeating: 0, count: w * h)
        var img = binary

        // 3x3 cross structuring element
        while true {
            // Erode
            var eroded = [UInt8](repeating: 0, count: w * h)
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let idx = y * w + x
                    // Cross element: center + 4 neighbors all must be 1
                    if img[idx] > 0 &&
                       img[idx - 1] > 0 && img[idx + 1] > 0 &&
                       img[idx - w] > 0 && img[idx + w] > 0 {
                        eroded[idx] = 1
                    }
                }
            }

            // Dilate the eroded result (opening = erode then dilate)
            var opened = [UInt8](repeating: 0, count: w * h)
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let idx = y * w + x
                    if eroded[idx] > 0 ||
                       eroded[idx - 1] > 0 || eroded[idx + 1] > 0 ||
                       eroded[idx - w] > 0 || eroded[idx + w] > 0 {
                        opened[idx] = 1
                    }
                }
            }

            // Skeleton = skeleton | (img - opened)
            for i in 0..<(w * h) {
                if img[i] > 0 && opened[i] == 0 {
                    skeleton[i] = 1
                }
            }

            img = eroded

            // Check if eroded image is empty
            let remaining = eroded.reduce(0) { $0 + Int($1) }
            if remaining == 0 { break }
        }

        return skeleton
    }

    /// Dilate binary image with a circular kernel of given radius.
    private static func dilateCircular(_ binary: inout [UInt8], width w: Int, height h: Int, radius: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: w * h)

        // Precompute circular kernel offsets
        var offsets: [(Int, Int)] = []
        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= radius * radius {
                    offsets.append((dx, dy))
                }
            }
        }

        for y in 0..<h {
            for x in 0..<w {
                if binary[y * w + x] > 0 {
                    for (dx, dy) in offsets {
                        let nx = x + dx
                        let ny = y + dy
                        if nx >= 0 && nx < w && ny >= 0 && ny < h {
                            result[ny * w + nx] = 1
                        }
                    }
                }
            }
        }

        return result
    }

    /// Convert a grayscale CGImage to a kCVPixelFormatType_OneComponent8 CVPixelBuffer.
    static func cgImageToPixelBuffer(_ cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        guard let ctx = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
