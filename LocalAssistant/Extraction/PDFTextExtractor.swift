import AppKit
import Foundation
import PDFKit

/// Extracts PDF text and falls back to local OCR for image-only pages.
struct PDFTextExtractor: Sendable {
    private let ocrService = LocalOCRService()

    /// Extracts source-aligned text from a PDF.
    /// - Parameter url: Readable local PDF URL.
    /// - Returns: One segment per page containing text.
    /// - Throws: A local extraction error when the PDF cannot be opened.
    internal func extract(url: URL) throws -> ExtractedDocument {
        guard let document = PDFDocument(url: url) else {
            throw LocalAssistantError.extraction(url.path)
        }
        var segments: [ExtractedSegment] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let extractedText = TextNormalizer.normalize(page.string ?? AppConstants.Text.empty)
            // A page that cannot be rendered or recognized contributes no text, but must
            // never discard the pages that extracted correctly.
            let text = extractedText.isEmpty
                ? ((try? recognize(page: page)) ?? AppConstants.Text.empty)
                : extractedText
            if text.isEmpty == false {
                let pageNumber = index + 1
                segments.append(
                    ExtractedSegment(
                        text: text,
                        pageNumber: pageNumber,
                        sectionName: ExtractionConstants.pdfPageSection(pageNumber)
                    )
                )
            }
        }
        return ExtractedDocument(segments: segments)
    }

    /// Renders and recognizes one image-only PDF page locally.
    /// - Parameter page: PDF page without usable embedded text.
    /// - Returns: Recognized page text.
    /// - Throws: A local extraction error when rendering fails.
    private func recognize(page: PDFPage) throws -> String {
        let thumbnail = page.thumbnail(
            of: NSSize(
                width: ExtractionConstants.pdfOCRThumbnailWidth,
                height: ExtractionConstants.pdfOCRThumbnailHeight
            ),
            for: .mediaBox
        )
        var proposedRect = NSRect(origin: .zero, size: thumbnail.size)
        guard let image = thumbnail.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            throw LocalAssistantError.extraction(ExtractionConstants.unknownSection)
        }
        return try ocrService.recognize(image: image)
    }
}
