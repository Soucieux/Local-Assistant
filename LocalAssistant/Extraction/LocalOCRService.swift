import AppKit
import Foundation
import ImageIO
import Vision

/// Performs accurate Vision text recognition entirely on the Mac.
struct LocalOCRService: Sendable {
    /// Recognizes text in an image file.
    /// - Parameter url: Readable local image URL.
    /// - Returns: Normalized recognized text.
    /// - Throws: A local extraction error when the image cannot be decoded.
    internal func recognize(url: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LocalAssistantError.extraction(url.path)
        }
        return try recognize(image: image)
    }

    /// Recognizes text in encoded image data.
    /// - Parameter data: Local encoded image bytes.
    /// - Returns: Normalized recognized text.
    /// - Throws: A local extraction error when the image cannot be decoded.
    internal func recognize(data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LocalAssistantError.extraction(ExtractionConstants.imageDecodeFailure)
        }
        return try recognize(image: image)
    }

    /// Recognizes text in a decoded bitmap with an on-device Vision request.
    /// - Parameter image: Bitmap to inspect.
    /// - Returns: Normalized recognized text.
    /// - Throws: A local extraction error when Vision fails.
    internal func recognize(image: CGImage) throws -> String {
        guard image.width >= ExtractionConstants.minimumOCRDimension,
              image.height >= ExtractionConstants.minimumOCRDimension,
              let recognizable = fitted(image) else {
            throw LocalAssistantError.extraction(ExtractionConstants.imageDimensionFailure)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ExtractionConstants.ocrRecognitionLanguages
        let handler = VNImageRequestHandler(cgImage: recognizable, options: [:])
        do {
            try handler.perform([request])
            let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            return TextNormalizer.normalize(lines.joined(separator: AppConstants.Text.newline))
        } catch {
            throw LocalAssistantError.extraction(error.localizedDescription)
        }
    }

    /// Scales an oversized bitmap down to the supported recognition budget.
    ///
    /// High-resolution camera images exceed the recognition limit, so they are reduced
    /// rather than rejected; a rejected page or photo would index with no text at all.
    /// - Parameter image: Decoded bitmap of any size.
    /// - Returns: The original image when already within budget, a reduced copy when not,
    ///   or `nil` when no drawing context could be created.
    private func fitted(_ image: CGImage) -> CGImage? {
        let pixelCount = image.width * image.height
        let budget = AppConstants.Indexing.maximumOCRPixelCount
        guard pixelCount > budget else { return image }

        let scale = (Double(budget) / Double(pixelCount)).squareRoot()
        let width = max(ExtractionConstants.minimumOCRDimension, Int(Double(image.width) * scale))
        let height = max(ExtractionConstants.minimumOCRDimension, Int(Double(image.height) * scale))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: ExtractionConstants.ocrBitsPerComponent,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
