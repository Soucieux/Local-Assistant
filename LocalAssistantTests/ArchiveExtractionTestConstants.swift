import Foundation

/// Stable fixture values for bounded archive extraction tests.
internal enum ArchiveExtractionTestConstants {
    internal static let directoryPrefix = "archive-limit-"
    internal static let documentName = "Report.docx"
    internal static let overshootBytes = 1_024
    internal static let bodyText = "Quarterly revenue summary"
    internal static let wordBodyXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body><w:p><w:r><w:t>Quarterly revenue summary</w:t></w:r></w:p></w:body>
        </w:document>
        """
}
