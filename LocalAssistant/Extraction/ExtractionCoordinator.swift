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
                text = try decodedText(from: data, at: item.url)
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

    /// Decodes text bytes using a detected encoding instead of assuming UTF-8.
    ///
    /// Assuming UTF-8 never fails: undecodable bytes become replacement characters, so a
    /// file saved in another encoding is indexed as noise. Reporting the failure instead
    /// keeps the file discoverable by name while leaving its text unindexed.
    /// - Parameters:
    ///   - data: Raw file bytes already bounded by the configured size limit.
    ///   - url: Source path used for the diagnostic.
    /// - Returns: Decoded text.
    /// - Throws: A local extraction error when no candidate encoding applies.
    private func decodedText(from data: Data, at url: URL) throws -> String {
        for encoding in orderedEncodings(for: data) {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        throw LocalAssistantError.extraction(url.path)
    }

    /// Orders candidate encodings, letting a byte-order mark win before UTF-8 is tried.
    ///
    /// UTF-16 bytes also form valid UTF-8, so without this a UTF-16 export decodes into
    /// text interleaved with null characters rather than failing over to UTF-16.
    /// - Parameter data: Raw file bytes.
    /// - Returns: Encodings to attempt, in order.
    private func orderedEncodings(for data: Data) -> [String.Encoding] {
        let hasUTF16Mark = FileConstants.utf16ByteOrderMarks.contains { data.starts(with: $0) }
        return hasUTF16Mark
            ? [.utf16] + FileConstants.textFallbackEncodings
            : FileConstants.textFallbackEncodings
    }
}
