import Foundation
import ZIPFoundation

/// Reads visible text from modern Office ZIP containers without executing macros.
internal struct OfficeTextExtractor: Sendable {
    /// Extracts text from DOCX, XLSX, or PPTX files.
    /// - Parameter url: Readable local Office document URL.
    /// - Returns: Source-ordered text segments.
    /// - Throws: A local extraction error when the archive is malformed.
    internal func extract(url: URL) throws -> ExtractedDocument {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            switch url.pathExtension.lowercased() {
            case ExtractionConstants.docxExtension:
                return try extractWord(archive: archive)
            case FileConstants.spreadsheetExtension:
                return try extractSpreadsheet(archive: archive)
            case FileConstants.presentationExtension:
                return try extractPresentation(archive: archive)
            default:
                throw LocalAssistantError.unsupported(url.pathExtension)
            }
        } catch let error as LocalAssistantError {
            throw error
        } catch {
            throw LocalAssistantError.extraction(error.localizedDescription)
        }
    }

    /// Extracts the main Word document body.
    /// - Parameter archive: Open read-only ZIP archive.
    /// - Returns: One Word text segment.
    /// - Throws: A local extraction error when XML is unavailable.
    private func extractWord(archive: Archive) throws -> ExtractedDocument {
        let data = try data(at: ExtractionConstants.documentXMLPath, in: archive)
        let text = try parse(
            data: data,
            textElements: ExtractionConstants.wordTextElements,
            breakElements: ExtractionConstants.wordBreakElements
        )
        return ExtractedDocument(
            segments: [ExtractedSegment(text: text, pageNumber: nil, sectionName: nil)]
        )
    }

    /// Extracts shared strings and worksheet values from a spreadsheet.
    /// - Parameter archive: Open read-only ZIP archive.
    /// - Returns: One text segment per sheet-related XML file.
    /// - Throws: A local extraction error when XML cannot be read.
    private func extractSpreadsheet(archive: Archive) throws -> ExtractedDocument {
        let entries = archive.filter { entry in
            entry.path == ExtractionConstants.spreadsheetSharedStringsPath
                || (entry.path.hasPrefix(ExtractionConstants.spreadsheetWorksheetPrefix)
                    && entry.path.hasSuffix(ExtractionConstants.xmlExtensionSuffix))
        }.sorted { $0.path < $1.path }
        let segments = try entries.compactMap { entry -> ExtractedSegment? in
            let text = try parse(
                data: try archive.boundedData(for: entry),
                textElements: ExtractionConstants.spreadsheetTextElements,
                breakElements: ExtractionConstants.spreadsheetBreakElements
            )
            guard text.isEmpty == false else { return nil }
            return ExtractedSegment(text: text, pageNumber: nil, sectionName: entry.path)
        }
        return ExtractedDocument(segments: segments)
    }

    /// Extracts visible text from presentation slides.
    /// - Parameter archive: Open read-only ZIP archive.
    /// - Returns: One segment per slide.
    /// - Throws: A local extraction error when slide XML cannot be read.
    private func extractPresentation(archive: Archive) throws -> ExtractedDocument {
        let entries = archive.filter { entry in
            entry.path.hasPrefix(ExtractionConstants.presentationSlidePrefix)
                && entry.path.hasSuffix(ExtractionConstants.xmlExtensionSuffix)
        }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let segments = try entries.enumerated().compactMap { offset, entry -> ExtractedSegment? in
            let text = try parse(
                data: try archive.boundedData(for: entry),
                textElements: ExtractionConstants.presentationTextElements,
                breakElements: ExtractionConstants.presentationBreakElements
            )
            guard text.isEmpty == false else { return nil }
            return ExtractedSegment(text: text, pageNumber: offset + 1, sectionName: entry.path)
        }
        return ExtractedDocument(segments: segments)
    }

    /// Loads an archive entry by path.
    /// - Parameters:
    ///   - path: Exact entry path.
    ///   - archive: Open read-only archive.
    /// - Returns: Copied entry bytes.
    /// - Throws: A local extraction error when the entry is missing.
    private func data(at path: String, in archive: Archive) throws -> Data {
        guard let entry = archive[path] else { throw LocalAssistantError.extraction(path) }
        return try archive.boundedData(for: entry)
    }

    /// Parses visible text from a known XML vocabulary.
    /// - Parameters:
    ///   - data: XML bytes.
    ///   - textElements: Element names containing visible text.
    ///   - breakElements: Element names ending logical lines.
    /// - Returns: Normalized visible text.
    /// - Throws: A local extraction error when XML is malformed.
    private func parse(data: Data, textElements: Set<String>, breakElements: Set<String>) throws -> String {
        let delegate = XMLVisibleTextDelegate(textElements: textElements, breakElements: breakElements)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw LocalAssistantError.extraction(parser.parserError?.localizedDescription ?? ExtractionConstants.unknownSection)
        }
        return delegate.result()
    }
}
