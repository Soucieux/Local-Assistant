import Foundation

/// Collects visible textual XML nodes without retaining document structure.
internal final class XMLVisibleTextDelegate: NSObject, XMLParserDelegate {
    private let textElements: Set<String>
    private let breakElements: Set<String>
    private var activeTextDepth = 0
    private var fragments: [String] = []

    /// Creates an XML collector for a known document vocabulary.
    /// - Parameters:
    ///   - textElements: Local element names containing visible text.
    ///   - breakElements: Local element names that end a logical line.
    internal init(textElements: Set<String>, breakElements: Set<String>) {
        self.textElements = textElements
        self.breakElements = breakElements
    }

    /// Receives the beginning of an XML element.
    /// - Parameters:
    ///   - parser: Active parser.
    ///   - elementName: Qualified element name.
    ///   - namespaceURI: Optional namespace URI.
    ///   - qName: Optional qualified name.
    ///   - attributeDict: Element attributes.
    internal func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if textElements.contains(localName(elementName)) { activeTextDepth += 1 }
    }

    /// Receives visible character data from an active text element.
    /// - Parameters:
    ///   - parser: Active parser.
    ///   - string: Parsed character fragment.
    internal func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeTextDepth > 0 { fragments.append(string) }
    }

    /// Receives the end of an XML element and records logical breaks.
    /// - Parameters:
    ///   - parser: Active parser.
    ///   - elementName: Qualified element name.
    ///   - namespaceURI: Optional namespace URI.
    ///   - qName: Optional qualified name.
    internal func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(elementName)
        if textElements.contains(name) {
            activeTextDepth = max(0, activeTextDepth - 1)
            fragments.append(AppConstants.Text.space)
        }
        if breakElements.contains(name) { fragments.append(AppConstants.Text.newline) }
    }

    /// Returns normalized collected text.
    /// - Returns: Visible text assembled in source order.
    internal func result() -> String {
        TextNormalizer.normalize(fragments.joined())
    }

    /// Removes an optional XML namespace prefix.
    /// - Parameter name: Qualified or local XML element name.
    /// - Returns: Local element name.
    private func localName(_ name: String) -> String {
        name.split(separator: ExtractionConstants.xmlNamespaceSeparator).last.map(String.init) ?? name
    }
}
