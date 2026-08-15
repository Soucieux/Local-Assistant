import Foundation

/// Local extraction paths, XML element names, and normalization values.
enum ExtractionConstants {
    static let richTextExtension = "rtf"
    static let htmlExtension = "html"
    static let htmExtension = "htm"
    static let docxExtension = "docx"
    static let documentXMLPath = "word/document.xml"
    static let spreadsheetSharedStringsPath = "xl/sharedStrings.xml"
    static let spreadsheetWorksheetPrefix = "xl/worksheets/"
    static let presentationSlidePrefix = "ppt/slides/slide"
    static let xmlExtensionSuffix = ".xml"
    static let quickLookDirectory = "QuickLook"
    static let previewFilenames = ["Thumbnail.jpg", "Thumbnail.png", "Preview.jpg", "Preview.png"]
    static let pagesPreviewSection = "Pages preview OCR"
    static let imageOCRSection = "Image OCR"
    static let pdfPageSectionPrefix = "Page"
    static let wordTextElements: Set<String> = ["t"]
    static let wordBreakElements: Set<String> = ["p", "tab", "br"]
    static let spreadsheetTextElements: Set<String> = ["t", "v"]
    static let spreadsheetBreakElements: Set<String> = ["row", "si"]
    static let presentationTextElements: Set<String> = ["t"]
    static let presentationBreakElements: Set<String> = ["p"]
    static let whitespacePattern = "[\\t\\r ]+"
    static let excessiveNewlinePattern = "\\n{3,}"
    static let doubleNewline = "\n\n"
    static let indexingSeparator = "\u{1F}"
    static let minimumOCRDimension = 1
    static let pdfOCRThumbnailWidth = 2_000
    static let pdfOCRThumbnailHeight = 2_600
    static let unknownSection = "Extracted text"
    static let imageDecodeFailure = "The local image could not be decoded."
    static let imageDimensionFailure = "The local image dimensions are unsupported for OCR."
    static let xmlNamespaceSeparator: Character = ":"

    /// Formats a PDF page section label.
    /// - Parameter pageNumber: One-based PDF page number.
    /// - Returns: Source section label.
    internal static func pdfPageSection(_ pageNumber: Int) -> String {
        pdfPageSectionPrefix + AppConstants.Text.space + String(pageNumber)
    }

    /// Builds a read-only Pages Quick Look entry path.
    /// - Parameter filename: Known preview filename.
    /// - Returns: Relative archive entry path.
    internal static func pagesPreviewPath(filename: String) -> String {
        quickLookDirectory + FileConstants.pathSeparator + filename
    }
}
