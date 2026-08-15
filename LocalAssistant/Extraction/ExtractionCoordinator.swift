import AppKit
import Foundation

/// Selects the safest local extractor for a supported file type.
struct ExtractionCoordinator: Sendable {
    private let pdfExtractor = PDFTextExtractor()
    private let officeExtractor = OfficeTextExtractor()
    private let pagesExtractor = PagesPreviewExtractor()
    private let ocrService = LocalOCRService()

    /// Extracts searchable text from one read-only file.
    /// - Parameter item: Indexed metadata for the file.
    /// - Returns: Source-aligned document text.
    /// - Throws: A local extraction error for unreadable or unsupported content.
    internal func extract(item: IndexedItem) throws -> ExtractedDocument {
        let pathExtension = item.url.pathExtension.lowercased()
        if pathExtension == FileConstants.pdfExtension {
            return try pdfExtractor.extract(url: item.url)
        }
        if FileConstants.officeExtensions.contains(pathExtension) {
            return try officeExtractor.extract(url: item.url)
        }
        if pathExtension == FileConstants.pagesExtension {
            return try pagesExtractor.extract(url: item.url)
        }
        if FileConstants.imageExtensions.contains(pathExtension) {
            return ExtractedDocument(
                segments: [
                    ExtractedSegment(
                        text: try ocrService.recognize(url: item.url),
                        pageNumber: nil,
                        sectionName: ExtractionConstants.imageOCRSection
                    )
                ]
            )
        }
        if FileConstants.plainTextExtensions.contains(pathExtension) {
            return try extractText(item: item, pathExtension: pathExtension)
        }
        throw LocalAssistantError.unsupported(pathExtension)
    }

    /// Extracts plain, rich-text, or HTML content under the configured size limit.
    /// - Parameters:
    ///   - item: Indexed file metadata.
    ///   - pathExtension: Normalized file extension.
    /// - Returns: One normalized text segment.
    /// - Throws: A local extraction error when content cannot be decoded.
    private func extractText(item: IndexedItem, pathExtension: String) throws -> ExtractedDocument {
        guard item.byteCount <= AppConstants.Indexing.maximumTextFileBytes else {
            throw LocalAssistantError.unsupported(item.url.path)
        }
        do {
            let text: String
            if pathExtension == ExtractionConstants.richTextExtension
                || pathExtension == ExtractionConstants.htmlExtension
                || pathExtension == ExtractionConstants.htmExtension {
                text = try NSAttributedString(
                    url: item.url,
                    options: [:],
                    documentAttributes: nil
                ).string
            } else {
                let data = try Data(contentsOf: item.url, options: [.mappedIfSafe])
                text = String(decoding: data, as: UTF8.self)
            }
            return ExtractedDocument(
                segments: [
                    ExtractedSegment(
                        text: TextNormalizer.normalize(text),
                        pageNumber: nil,
                        sectionName: nil
                    )
                ]
            )
        } catch {
            throw LocalAssistantError.extraction(error.localizedDescription)
        }
    }
}
