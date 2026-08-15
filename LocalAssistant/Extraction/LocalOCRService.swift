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
              image.width * image.height <= AppConstants.Indexing.maximumOCRPixelCount else {
            throw LocalAssistantError.extraction(ExtractionConstants.imageDimensionFailure)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            return TextNormalizer.normalize(lines.joined(separator: AppConstants.Text.newline))
        } catch {
            throw LocalAssistantError.extraction(error.localizedDescription)
        }
    }
}
