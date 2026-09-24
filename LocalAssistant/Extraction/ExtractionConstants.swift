import Foundation

/// Local extraction paths, XML element names, and normalization values.
internal enum ExtractionConstants {
    /// Identifies the behavior of the current extraction pipeline.
    ///
    /// The value is folded into every file's metadata hash, so raising it re-extracts
    /// already-indexed files once instead of leaving them on superseded results.
    /// Raise it whenever an extraction fix changes the text produced for unchanged files.
    internal static let extractionVersion = 3
    internal static let richTextExtension = "rtf"
    internal static let htmlExtension = "html"
    internal static let htmExtension = "htm"
    internal static let docxExtension = "docx"
    internal static let documentXMLPath = "word/document.xml"
    internal static let spreadsheetSharedStringsPath = "xl/sharedStrings.xml"
    internal static let spreadsheetWorksheetPrefix = "xl/worksheets/"
    internal static let presentationSlidePrefix = "ppt/slides/slide"
    internal static let xmlExtensionSuffix = ".xml"
    internal static let quickLookDirectory = "QuickLook"
    internal static let previewFilenames = ["Thumbnail.jpg", "Thumbnail.png", "Preview.jpg", "Preview.png"]
    internal static let pagesPreviewSection = "Pages preview OCR"
    internal static let imageOCRSection = "Image OCR"
    internal static let pdfPageSectionPrefix = "Page"
    internal static let wordTextElements: Set<String> = ["t"]
    internal static let wordBreakElements: Set<String> = ["p", "tab", "br"]
    internal static let spreadsheetTextElements: Set<String> = ["t", "v"]
    internal static let spreadsheetBreakElements: Set<String> = ["row", "si"]
    internal static let presentationTextElements: Set<String> = ["t"]
    internal static let presentationBreakElements: Set<String> = ["p"]
    internal static let htmlHiddenElements: Set<String> = ["script", "style", "noscript", "template"]
    internal static let htmlBlockElements: Set<String> = [
        "address", "article", "aside", "blockquote", "br", "dd", "div", "dl", "dt",
        "figcaption", "figure", "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header",
        "hr", "li", "main", "nav", "ol", "p", "pre", "section", "table", "td", "th",
        "title", "tr", "ul"
    ]
    internal static let whitespacePattern = "[\\t\\r ]+"
    internal static let excessiveNewlinePattern = "\\n{3,}"
    internal static let doubleNewline = "\n\n"
    internal static let indexingSeparator = FileConstants.Hash.fieldSeparator
    internal static let minimumOCRDimension = 1
    internal static let ocrBitsPerComponent = 8
    internal static let ocrRecognitionLanguages = ["en-US", "zh-Hans"]
    internal static let pdfOCRThumbnailWidth = 2_000
    internal static let pdfOCRThumbnailHeight = 2_600
    internal static let unknownSection = "Extracted text"
    internal static let imageDecodeFailure = "The local image could not be decoded."
    internal static let imageDimensionFailure = "The local image dimensions are unsupported for OCR."
    internal static let xmlNamespaceSeparator: Character = ":"

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
