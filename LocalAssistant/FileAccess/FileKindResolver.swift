import Foundation
import UniformTypeIdentifiers

/// Maps local file metadata to the assistant's broad item categories.
enum FileKindResolver {
    /// Resolves a display category for a local URL.
    /// - Parameters:
    ///   - url: Candidate file or directory.
    ///   - values: Already-fetched resource metadata.
    /// - Returns: Broad indexed item kind.
    internal static func kind(for url: URL, values: URLResourceValues) -> IndexedItemKind {
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == FileConstants.pagesExtension { return .document }
        if values.isDirectory == true { return .folder }
        if pathExtension == FileConstants.pdfExtension { return .pdf }
        if FileConstants.imageExtensions.contains(pathExtension) { return .image }
        if FileConstants.officeExtensions.contains(pathExtension) {
            switch pathExtension {
            case FileConstants.spreadsheetExtension: return .spreadsheet
            case FileConstants.presentationExtension: return .presentation
            default: return .document
            }
        }
        if FileConstants.plainTextExtensions.contains(pathExtension) {
            if UTType(filenameExtension: pathExtension)?.conforms(to: .sourceCode) == true { return .code }
            return .text
        }
        if UTType(filenameExtension: pathExtension)?.conforms(to: .archive) == true { return .archive }
        return .other
    }

    /// Determines whether the current extraction pipeline supports the item.
    /// - Parameters:
    ///   - url: Candidate file URL.
    ///   - kind: Previously resolved item kind.
    /// - Returns: `true` when content extraction is available.
    internal static func isExtractable(url: URL, kind: IndexedItemKind) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        if kind == .folder || kind == .archive || kind == .other { return false }
        return FileConstants.plainTextExtensions.contains(pathExtension)
            || FileConstants.officeExtensions.contains(pathExtension)
            || FileConstants.imageExtensions.contains(pathExtension)
            || pathExtension == FileConstants.pdfExtension
            || pathExtension == FileConstants.pagesExtension
    }
}
