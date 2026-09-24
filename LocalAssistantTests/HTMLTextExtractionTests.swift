import Foundation
import Testing

@testable import LocalAssistant

/// HTML is read by parsing its markup, never through the main-thread-only WebKit importer,
/// so what a reader sees must survive and what a reader never sees must not be indexed.
internal struct HTMLTextExtractionTests {
    private let extractor = HTMLTextExtractor()

    @Test("Visible text is kept and scripts and styles are left out")
    internal func keepsVisibleTextOnly() throws {
        let markup = """
        <html><head><title>Quarterly report</title><style>p { color: red }</style>
        <script>var hidden = "tracking";</script></head>
        <body><h1>Summary</h1><p>Revenue grew.</p></body></html>
        """
        let text = TextNormalizer.normalize(try extractor.text(fromMarkup: markup))

        #expect(text.contains("Quarterly report"))
        #expect(text.contains("Summary"))
        #expect(text.contains("Revenue grew."))
        #expect(text.contains("tracking") == false)
        #expect(text.contains("color") == false)
    }

    @Test("Neighboring blocks stay separate words while inline markup does not split one")
    internal func separatesBlocksButNotInlineRuns() throws {
        let markup = "<ul><li>Alpha</li><li>Beta</li></ul><p>un<b>break</b>able</p>"
        let text = TextNormalizer.normalize(try extractor.text(fromMarkup: markup))

        #expect(text.contains("AlphaBeta") == false)
        #expect(text.contains("Alpha"))
        #expect(text.contains("Beta"))
        #expect(text.contains("unbreakable"))
    }

    @Test("Non-Latin text and character entities are decoded")
    internal func decodesNonLatinTextAndEntities() throws {
        let markup = "<p>第二段 中文内容 &amp; caf&eacute;</p>"
        let text = TextNormalizer.normalize(try extractor.text(fromMarkup: markup))

        #expect(text == "第二段 中文内容 & café")
    }

    @Test("An unclosed fragment is still read")
    internal func readsMalformedFragments() throws {
        let text = TextNormalizer.normalize(
            try extractor.text(fromMarkup: "<p>first<p>second<div>third")
        )

        #expect(text.contains("first"))
        #expect(text.contains("second"))
        #expect(text.contains("third"))
    }

    @Test("Empty markup produces empty text instead of a parser failure")
    internal func returnsEmptyTextForEmptyMarkup() throws {
        #expect(try extractor.text(fromMarkup: "").isEmpty)
    }

    @Test("An HTML file on disk is extracted away from the main thread")
    internal func extractsHTMLFileOffTheMainThread() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("page.html")
        try "<html><body><p>Local page body</p></body></html>".write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        let item = TestFixtures.item(name: "page.html", path: fileURL.path)

        let document = try await Task.detached {
            try ExtractionCoordinator().extract(item: item)
        }.value

        #expect(document.segments.map(\.text) == ["Local page body"])
    }
}
