import Foundation

/// Reads the visible text of local HTML without the WebKit-backed importer.
///
/// `NSAttributedString` imports HTML through WebKit, which Apple documents as unsupported off
/// the main thread: called from the indexing actor it must synchronize with the main run loop
/// for every file, and it fails when that loop is busy. Parsing the markup directly keeps
/// extraction on the indexing actor, and the parser is told never to load an external entity.
internal struct HTMLTextExtractor: Sendable {
    /// Extracts the text a reader would see, with block elements on their own lines.
    /// - Parameter markup: Decoded HTML, which may be a fragment or malformed.
    /// - Returns: Visible text before whitespace normalization; empty for empty markup.
    /// - Throws: A parser error when the markup cannot be repaired into a document.
    internal func text(fromMarkup markup: String) throws -> String {
        guard markup.isEmpty == false else { return AppConstants.Text.empty }
        let document = try XMLDocument(
            xmlString: markup,
            options: [.documentTidyHTML, .nodeLoadExternalEntitiesNever]
        )
        return document.rootElement().map(visibleText(of:)) ?? AppConstants.Text.empty
    }

    /// Collects the visible text beneath one parsed node.
    /// - Parameter node: Text or element node of the repaired document.
    /// - Returns: The node's text, wrapped in line breaks when the element is a block, and
    ///   empty for scripts, styles, and other content a reader never sees.
    private func visibleText(of node: XMLNode) -> String {
        if node.kind == .text { return node.stringValue ?? AppConstants.Text.empty }
        guard node.kind == .element,
              let name = node.name?.lowercased(),
              ExtractionConstants.htmlHiddenElements.contains(name) == false else {
            return AppConstants.Text.empty
        }
        let inner = (node.children ?? []).map(visibleText(of:)).joined()
        guard ExtractionConstants.htmlBlockElements.contains(name) else { return inner }
        return AppConstants.Text.newline + inner + AppConstants.Text.newline
    }
}
