import SwiftUI

/// Typography scale used for the live response surface or retained conversation history.
enum ResponseMarkdownPresentation: Sendable {
    case command
    case history
}

/// Native, selectable block-Markdown presentation for local and OpenClaw responses.
struct ResponseMarkdownView: View {
    let text: String
    let presentation: ResponseMarkdownPresentation
    private let parser = ResponseMarkdownParser()

    /// Builds one responsive semantic document without a WebView or active links.
    var body: some View {
        let document = parser.parse(text)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .containerRelativeFrame(
            .horizontal,
            count: DesignTokens.Command.responseTextColumnCount,
            span: DesignTokens.Command.responseTextColumnSpan,
            spacing: 0,
            alignment: .center
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    /// Builds the appropriate native component for one parsed Markdown block.
    /// - Parameter block: Semantic response block to render.
    /// - Returns: A styled native SwiftUI block.
    @ViewBuilder
    private func blockView(_ block: ResponseMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            ResponseInlineMarkdownText(
                text: text,
                font: headingFont(level: level),
                color: DesignTokens.Color.commandInk,
                lineSpacing: DesignTokens.Message.lineSpacing
            )
        case let .paragraph(text):
            ResponseInlineMarkdownText(
                text: text,
                font: bodyFont,
                color: DesignTokens.Color.commandInk,
                lineSpacing: DesignTokens.Message.lineSpacing + 1
            )
        case let .unorderedList(items):
            ResponseMarkdownListView(
                items: items,
                ordered: false,
                font: bodyFont
            )
        case let .orderedList(items):
            ResponseMarkdownListView(
                items: items,
                ordered: true,
                font: bodyFont
            )
        case let .blockQuote(text):
            ResponseMarkdownQuoteView(text: text, font: bodyFont)
        case let .code(language, content):
            ResponseMarkdownCodeView(language: language, content: content)
        case let .table(table):
            ResponseMarkdownTableView(table: table, font: tableFont)
        case .divider:
            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.18))
                .frame(height: DesignTokens.Command.responseTableBorderWidth)
        }
    }

    /// Returns the readable body font for the current response surface.
    private var bodyFont: Font {
        switch presentation {
        case .command:
            return .system(
                size: DesignTokens.Command.responseBodyFontSize,
                weight: .regular,
                design: .rounded
            )
        case .history:
            return .system(
                size: DesignTokens.Command.responseHistoryBodyFontSize,
                weight: .regular,
                design: .rounded
            )
        }
    }

    /// Returns the compact monospaced font used by table cells.
    private var tableFont: Font {
        switch presentation {
        case .command:
            return .system(
                size: DesignTokens.Command.responseHistoryBodyFontSize,
                weight: .regular,
                design: .monospaced
            )
        case .history:
            return .caption.monospaced()
        }
    }

    /// Returns a semantic heading font with a bounded three-level visual hierarchy.
    /// - Parameter level: Markdown heading level from one through six.
    /// - Returns: Monospaced heading font appropriate to the requested level.
    private func headingFont(level: Int) -> Font {
        if level == 1 {
            return .system(
                size: DesignTokens.Command.responseHeadingOneFontSize,
                weight: .bold,
                design: .monospaced
            )
        }
        if level == 2 {
            return .system(
                size: DesignTokens.Command.responseHeadingTwoFontSize,
                weight: .bold,
                design: .monospaced
            )
        }
        return .system(
            size: DesignTokens.Command.responseHeadingThreeFontSize,
            weight: .semibold,
            design: .monospaced
        )
    }
}

/// Selectable inline Markdown with links deliberately rendered inert.
private struct ResponseInlineMarkdownText: View {
    let text: String
    let font: Font
    let color: Color
    let lineSpacing: CGFloat

    /// Builds one selectable line-wrapping text block.
    var body: some View {
        Text(renderedText)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Parses inline emphasis and code while removing active link destinations.
    private var renderedText: AttributedString {
        .inertInlineMarkdown(text)
    }
}

/// Native ordered or unordered Markdown list.
private struct ResponseMarkdownListView: View {
    let items: [String]
    let ordered: Bool
    let font: Font

    /// Builds aligned list markers and selectable item content.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                    Text(marker(for: index))
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(DesignTokens.Color.commandAccent)
                        .frame(minWidth: DesignTokens.Spacing.large, alignment: .trailing)
                    ResponseInlineMarkdownText(
                        text: item,
                        font: font,
                        color: DesignTokens.Color.commandInk,
                        lineSpacing: DesignTokens.Message.lineSpacing
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Returns the visible marker for one list item.
    /// - Parameter index: Zero-based item position.
    /// - Returns: A bullet or one-based numeric marker.
    private func marker(for index: Int) -> String {
        if ordered {
            return String(index + 1) + ResponseMarkdownConstants.Syntax.orderedMarkerSuffix
        }
        return ResponseMarkdownConstants.Presentation.bullet
    }
}

/// Quoted Markdown with a restrained accent rail.
private struct ResponseMarkdownQuoteView: View {
    let text: String
    let font: Font

    /// Builds a selectable quotation with semantic visual separation.
    var body: some View {
        ResponseInlineMarkdownText(
            text: text,
            font: font.italic(),
            color: DesignTokens.Color.commandMutedInk,
            lineSpacing: DesignTokens.Message.lineSpacing
        )
        .padding(DesignTokens.Spacing.medium)
        .padding(.leading, DesignTokens.Spacing.small)
        .background(DesignTokens.Color.commandInk.opacity(DesignTokens.Command.responseQuoteOpacity))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DesignTokens.Color.commandAccent)
                .frame(width: DesignTokens.Command.responseQuoteRailWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Command.responseTableCornerRadius))
    }
}

/// Horizontally scrollable native fenced-code presentation.
private struct ResponseMarkdownCodeView: View {
    let language: String?
    let content: String

    /// Builds a labelled code surface that preserves whitespace exactly.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            if let language {
                Text(language.uppercased())
                    .font(.caption2.monospaced().weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(DesignTokens.Color.commandAccent)
            }
            ScrollView(.horizontal) {
                Text(content)
                    .font(
                        .system(
                            size: DesignTokens.Command.responseCodeFontSize,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(DesignTokens.Color.commandInk)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.commandInk.opacity(
                DesignTokens.Command.responseInlineCodeOpacity
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Command.responseTableCornerRadius))
    }
}

/// Responsive native pipe-table presentation with a semantic header row.
private struct ResponseMarkdownTableView: View {
    let table: ResponseMarkdownTable
    let font: Font

    /// Builds a full-width table that scrolls only when its columns cannot fit readably.
    var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                row(table.header, isHeader: true, drawsBottomBorder: true)
                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, cells in
                    row(
                        cells,
                        isHeader: false,
                        drawsBottomBorder: index < table.rows.count - 1
                    )
                }
            }
            .containerRelativeFrame(.horizontal, alignment: .leading)
            .frame(minWidth: minimumTableWidth)
            .background(DesignTokens.Color.commandLightCanvas.opacity(0.55))
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.Command.responseTableCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Command.responseTableCornerRadius)
                    .stroke(
                        DesignTokens.Color.commandInk.opacity(0.22),
                        lineWidth: DesignTokens.Command.responseTableBorderWidth
                    )
            }
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    /// Builds one equal-width table row with stable cell separators.
    /// - Parameters:
    ///   - cells: Normalized cell content.
    ///   - isHeader: Whether to apply header emphasis and fill.
    ///   - drawsBottomBorder: Whether a horizontal separator follows the row.
    /// - Returns: One native table row.
    private func row(
        _ cells: [String],
        isHeader: Bool,
        drawsBottomBorder: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                ResponseInlineMarkdownText(
                    text: cell,
                    font: isHeader ? font.bold() : font,
                    color: DesignTokens.Color.commandInk,
                    lineSpacing: DesignTokens.Message.lineSpacing
                )
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.small + 2)
                .frame(
                    minWidth: DesignTokens.Command.responseTableMinimumColumnWidth,
                    maxWidth: .infinity,
                    alignment: .topLeading
                )
                .background(
                    isHeader
                        ? DesignTokens.Color.commandAccent.opacity(
                            DesignTokens.Command.responseTableHeaderOpacity
                        )
                        : Color.clear
                )
                .overlay(alignment: .trailing) {
                    if index < cells.count - 1 {
                        Rectangle()
                            .fill(DesignTokens.Color.commandInk.opacity(0.14))
                            .frame(width: DesignTokens.Command.responseTableBorderWidth)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if drawsBottomBorder {
                Rectangle()
                    .fill(DesignTokens.Color.commandInk.opacity(0.14))
                    .frame(height: DesignTokens.Command.responseTableBorderWidth)
            }
        }
    }

    /// Returns the minimum readable table width derived from its column count.
    private var minimumTableWidth: CGFloat {
        CGFloat(table.header.count) * DesignTokens.Command.responseTableMinimumColumnWidth
    }
}

extension AttributedString {
    /// Parses inline Markdown while removing every active link destination.
    ///
    /// Response text is untrusted and the interface must never present a followable link.
    /// Both the assistant document and the user bubble render through this one path so the
    /// link-stripping cannot drift between them.
    /// - Parameter text: Local or OpenClaw text that may contain inline Markdown.
    /// - Returns: Inline-styled text whose links cannot be followed.
    internal static func inertInlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        var attributedText =
            (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
        let linkedRanges = attributedText.runs.compactMap { run in
            run.link == nil ? nil : run.range
        }
        for linkedRange in linkedRanges {
            attributedText[linkedRange].link = nil
        }
        return attributedText
    }
}
