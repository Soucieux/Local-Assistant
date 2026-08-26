import Testing

@testable import LocalAssistant

/// The native parser must preserve semantic response structure without a web renderer.
struct ResponseMarkdownParserTests {
    private let parser = ResponseMarkdownParser()

    @Test("Pipe tables become semantic headers and rows")
    internal func parsesPipeTable() {
        let source = """
            Three standing cases:

            | Item state | Update / delete |
            |---|---|
            | iCloud + has syncPairId | Allowed |
            | iCloud + no syncPairId | Rejected |
            | Any other tag | Rejected |
            """

        let document = parser.parse(source)

        #expect(document.blocks.count == 2)
        #expect(document.blocks[0] == .paragraph("Three standing cases:"))
        #expect(
            document.blocks[1] == .table(
                ResponseMarkdownTable(
                    header: ["Item state", "Update / delete"],
                    rows: [
                        ["iCloud + has syncPairId", "Allowed"],
                        ["iCloud + no syncPairId", "Rejected"],
                        ["Any other tag", "Rejected"],
                    ]
                )
            )
        )
    }

    @Test("Common block Markdown remains structurally distinct")
    internal func parsesRichDocument() {
        let source = """
            # Result

            A **short** explanation.

            - First
            - Second

            1. Prepare
            2. Continue

            > Keep the gateway private.

            ---

            ```swift
            let ready = true
            ```
            """

        let document = parser.parse(source)

        #expect(document.blocks == [
            .heading(level: 1, text: "Result"),
            .paragraph("A **short** explanation."),
            .unorderedList(["First", "Second"]),
            .orderedList(["Prepare", "Continue"]),
            .blockQuote("Keep the gateway private."),
            .divider,
            .code(language: "swift", content: "let ready = true"),
        ])
    }

    @Test("Escaped table delimiters stay inside their cell")
    internal func preservesEscapedPipes() {
        let source = """
            | Expression | Meaning |
            | :--- | ---: |
            | `left\\|right` | one cell |
            """

        let document = parser.parse(source)

        #expect(
            document.blocks == [
                .table(
                    ResponseMarkdownTable(
                        header: ["Expression", "Meaning"],
                        rows: [["`left|right`", "one cell"]]
                    )
                )
            ]
        )
    }

    @Test("Malformed table syntax remains ordinary prose")
    internal func leavesMalformedTableAsParagraph() {
        let source = """
            | Name | State |
            | not a separator | --- |
            """

        let document = parser.parse(source)

        #expect(
            document.blocks == [
                .paragraph("| Name | State | | not a separator | --- |")
            ]
        )
    }

    @Test("Soft response line breaks wrap as one paragraph")
    internal func joinsSoftParagraphLines() {
        let document = parser.parse("One line\ncontinues here.")

        #expect(document.blocks == [.paragraph("One line continues here.")])
    }
}
