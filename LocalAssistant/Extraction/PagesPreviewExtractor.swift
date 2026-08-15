import Foundation
import ZIPFoundation

/// Extracts searchable OCR from the locally stored preview of a Pages document.
struct PagesPreviewExtractor: Sendable {
    private let ocrService = LocalOCRService()

    /// Recognizes the available Pages preview without modifying the package.
    /// - Parameter url: Pages package directory or ZIP container.
    /// - Returns: A preview-derived text segment when present.
    /// - Throws: A local extraction error when preview decoding fails.
    internal func extract(url: URL) throws -> ExtractedDocument {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return try extractDirectoryPreview(url: url)
        }
        return try extractArchivePreview(url: url)
    }

    /// Reads a preview image directly from a Pages package directory.
    /// - Parameter url: Pages package directory.
    /// - Returns: Preview-derived document text.
    /// - Throws: A local extraction error when no preview can be read.
    private func extractDirectoryPreview(url: URL) throws -> ExtractedDocument {
        let quickLookURL = url.appendingPathComponent(ExtractionConstants.quickLookDirectory, isDirectory: true)
        for filename in ExtractionConstants.previewFilenames {
            let candidate = quickLookURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return document(text: try ocrService.recognize(url: candidate))
            }
        }
        throw LocalAssistantError.unsupported(url.path)
    }

    /// Reads a preview image from a single-file Pages ZIP container.
    /// - Parameter url: Pages archive URL.
    /// - Returns: Preview-derived document text.
    /// - Throws: A local extraction error when no preview can be read.
    private func extractArchivePreview(url: URL) throws -> ExtractedDocument {
        let archive = try Archive(url: url, accessMode: .read)
        for filename in ExtractionConstants.previewFilenames {
            let path = ExtractionConstants.pagesPreviewPath(filename: filename)
            guard let entry = archive[path] else { continue }
            var data = Data()
            _ = try archive.extract(entry) { data.append($0) }
            return document(text: try ocrService.recognize(data: data))
        }
        throw LocalAssistantError.unsupported(url.path)
    }

    /// Wraps preview OCR in a source-labeled extraction result.
    /// - Parameter text: Normalized OCR text.
    /// - Returns: One Pages preview segment.
    private func document(text: String) -> ExtractedDocument {
        ExtractedDocument(
            segments: [
                ExtractedSegment(
                    text: text,
                    pageNumber: nil,
                    sectionName: ExtractionConstants.pagesPreviewSection
                )
            ]
        )
    }
}
