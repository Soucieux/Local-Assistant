import Foundation

/// Stable fixture values for bounded archive extraction tests.
enum ArchiveExtractionTestConstants {
    static let directoryPrefix = "archive-limit-"
    static let documentName = "Report.docx"
    static let overshootBytes = 1_024
    static let bodyText = "Quarterly revenue summary"
    static let wordBodyXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body><w:p><w:r><w:t>Quarterly revenue summary</w:t></w:r></w:p></w:body>
        </w:document>
        """
}
