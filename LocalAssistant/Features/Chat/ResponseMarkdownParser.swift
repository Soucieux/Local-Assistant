import Foundation

/// One semantic block extracted from an assistant Markdown response.
enum ResponseMarkdownBlock: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([String])
    case blockQuote(String)
    case code(language: String?, content: String)
    case table(ResponseMarkdownTable)
    case divider
}

/// A normalized pipe table with one header row and zero or more body rows.
struct ResponseMarkdownTable: Hashable, Sendable {
    let header: [String]
    let rows: [[String]]
}

/// Parsed native response document displayed without a web-rendering surface.
struct ResponseMarkdownDocument: Hashable, Sendable {
    let blocks: [ResponseMarkdownBlock]
}

/// Converts the bounded Markdown commonly returned by local and OpenClaw models into native blocks.
struct ResponseMarkdownParser {
    /// Parses headings, paragraphs, lists, quotes, code fences, dividers, and pipe tables.
    /// - Parameter source: Raw assistant response text.
    /// - Returns: Ordered semantic blocks suitable for native SwiftUI rendering.
    internal func parse(_ source: String) -> ResponseMarkdownDocument {
        let normalizedSource = source.replacingOccurrences(
            of: ResponseMarkdownConstants.Syntax.carriageReturn,
            with: AppConstants.Text.empty
        )
        let lines = normalizedSource.components(
            separatedBy: ResponseMarkdownConstants.Syntax.newline
        )
        var blocks: [ResponseMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let trimmedLine = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                index += 1
                continue
            }
            if trimmedLine.hasPrefix(ResponseMarkdownConstants.Syntax.codeFence) {
                blocks.append(parseCodeBlock(lines: lines, index: &index))
                continue
            }
            if isTableStart(lines: lines, index: index) {
                blocks.append(parseTable(lines: lines, index: &index))
                continue
            }
            if let heading = heading(from: trimmedLine) {
                blocks.append(heading)
                index += 1
                continue
            }
            if isDivider(trimmedLine) {
                blocks.append(.divider)
                index += 1
                continue
            }
            if unorderedItem(from: trimmedLine) != nil {
                blocks.append(parseUnorderedList(lines: lines, index: &index))
                continue
            }
            if orderedItem(from: trimmedLine) != nil {
                blocks.append(parseOrderedList(lines: lines, index: &index))
                continue
            }
            if trimmedLine.hasPrefix(ResponseMarkdownConstants.Syntax.blockQuotePrefix) {
                blocks.append(parseBlockQuote(lines: lines, index: &index))
                continue
            }
            blocks.append(parseParagraph(lines: lines, index: &index))
        }

        return ResponseMarkdownDocument(blocks: blocks)
    }

    /// Parses one fenced code block, retaining an optional language label.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Current source index, advanced beyond the code block.
    /// - Returns: One code block, including unterminated content through end of input.
    private func parseCodeBlock(
        lines: [String],
        index: inout Int
    ) -> ResponseMarkdownBlock {
        let opening = lines[index].trimmingCharacters(in: .whitespaces)
        let languageValue = String(
            opening.dropFirst(ResponseMarkdownConstants.Syntax.codeFence.count)
        ).trimmingCharacters(in: .whitespaces)
        let language = languageValue.isEmpty ? nil : languageValue
        index += 1
        var content: [String] = []
        while index < lines.count {
            let candidate = lines[index].trimmingCharacters(in: .whitespaces)
            if candidate.hasPrefix(ResponseMarkdownConstants.Syntax.codeFence) {
                index += 1
                break
            }
            content.append(lines[index])
            index += 1
        }
        return .code(
            language: language,
            content: content.joined(separator: ResponseMarkdownConstants.Syntax.newline)
        )
    }

    /// Parses one table beginning at a header and separator pair.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Current header index, advanced beyond all table rows.
    /// - Returns: One normalized table block.
    private func parseTable(
        lines: [String],
        index: inout Int
    ) -> ResponseMarkdownBlock {
        let header = splitTableCells(lines[index])
        index += 2
        var rows: [[String]] = []
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard line.isEmpty == false,
                  line.contains(ResponseMarkdownConstants.Syntax.tableDelimiter) else {
                break
            }
            rows.append(normalizedTableRow(splitTableCells(line), columnCount: header.count))
            index += 1
        }
        return .table(ResponseMarkdownTable(header: header, rows: rows))
    }

    /// Parses consecutive unordered list items.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Current item index, advanced beyond the list.
    /// - Returns: One unordered-list block.
    private func parseUnorderedList(
        lines: [String],
        index: inout Int
    ) -> ResponseMarkdownBlock {
        var items: [String] = []
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard let item = unorderedItem(from: line) else { break }
            items.append(item)
            index += 1
        }
        return .unorderedList(items)
    }

    /// Parses consecutive ordered list items.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Current item index, advanced beyond the list.
    /// - Returns: One ordered-list block.
    private func parseOrderedList(
        lines: [String],
        index: inout Int
    ) -> ResponseMarkdownBlock {
        var items: [String] = []
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard let item = orderedItem(from: line) else { break }
            items.append(item)
            index += 1
        }
        return .orderedList(items)
    }

    /// Parses consecutive quote lines into one semantic quotation.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Current quote index, advanced beyond the quotation.
    /// - Returns: One block-quote block.
    private func parseBlockQuote(
        lines: [String],
        index: inout Int
    ) -> ResponseMarkdownBlock {
        var quotedLines: [String] = []
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(ResponseMarkdownConstants.Syntax.blockQuotePrefix) else { break }
            quotedLines.append(
                String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            )
            index += 1
        }
        return .blockQuote(
            quotedLines.joined(separator: ResponseMarkdownConstants.Syntax.paragraphJoiner)
        )
    }

    /// Parses consecutive prose lines until another block-level construct begins.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Current prose index, advanced beyond the paragraph.
    /// - Returns: One paragraph block with soft line breaks joined by spaces.
    private func parseParagraph(
        lines: [String],
        index: inout Int
    ) -> ResponseMarkdownBlock {
        var paragraphLines: [String] = []
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || (paragraphLines.isEmpty == false && isBlockStart(lines: lines, index: index)) {
                break
            }
            paragraphLines.append(line)
            index += 1
        }
        return .paragraph(
            paragraphLines.joined(separator: ResponseMarkdownConstants.Syntax.paragraphJoiner)
        )
    }

    /// Reports whether one line begins a block that must not merge into preceding prose.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Candidate line index.
    /// - Returns: `true` for every supported block-level construct.
    private func isBlockStart(lines: [String], index: Int) -> Bool {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        return line.hasPrefix(ResponseMarkdownConstants.Syntax.codeFence)
            || isTableStart(lines: lines, index: index)
            || heading(from: line) != nil
            || isDivider(line)
            || unorderedItem(from: line) != nil
            || orderedItem(from: line) != nil
            || line.hasPrefix(ResponseMarkdownConstants.Syntax.blockQuotePrefix)
    }

    /// Extracts a supported ATX heading.
    /// - Parameter line: Trimmed candidate line.
    /// - Returns: A heading block when one through six markers precede text.
    private func heading(from line: String) -> ResponseMarkdownBlock? {
        let markerCount = line.prefix {
            $0 == ResponseMarkdownConstants.Syntax.headingMarker
        }.count
        guard markerCount > 0,
              markerCount <= ResponseMarkdownConstants.Syntax.maximumHeadingLevel else {
            return nil
        }
        let content = line.dropFirst(markerCount)
        guard content.first?.isWhitespace == true else { return nil }
        let text = content.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .heading(level: markerCount, text: text)
    }

    /// Extracts one unordered list item.
    /// - Parameter line: Trimmed candidate line.
    /// - Returns: Item content when a supported marker is present.
    private func unorderedItem(from line: String) -> String? {
        for prefix in [
            ResponseMarkdownConstants.Syntax.unorderedDashPrefix,
            ResponseMarkdownConstants.Syntax.unorderedAsteriskPrefix,
            ResponseMarkdownConstants.Syntax.unorderedPlusPrefix,
        ] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Extracts one ordered list item with a period or closing-parenthesis marker.
    /// - Parameter line: Trimmed candidate line.
    /// - Returns: Item content when the marker is valid.
    private func orderedItem(from line: String) -> String? {
        let digits = line.prefix(while: \.isNumber)
        guard digits.isEmpty == false,
              line.count > digits.count + 1 else {
            return nil
        }
        let markerIndex = line.index(line.startIndex, offsetBy: digits.count)
        let marker = line[markerIndex]
        guard marker == ResponseMarkdownConstants.Syntax.orderedPeriod
                || marker == ResponseMarkdownConstants.Syntax.orderedParenthesis else {
            return nil
        }
        let contentIndex = line.index(after: markerIndex)
        guard line[contentIndex].isWhitespace else { return nil }
        return String(line[line.index(after: contentIndex)...])
            .trimmingCharacters(in: .whitespaces)
    }

    /// Reports whether a line is a Markdown thematic divider.
    /// - Parameter line: Trimmed candidate line.
    /// - Returns: `true` when at least three identical supported markers remain after spaces.
    private func isDivider(_ line: String) -> Bool {
        let compact = line.filter { $0.isWhitespace == false }
        guard compact.count >= ResponseMarkdownConstants.Syntax.minimumDividerLength,
              let marker = compact.first,
              marker == ResponseMarkdownConstants.Syntax.dividerDash
                || marker == ResponseMarkdownConstants.Syntax.emphasisMarker
                || marker == ResponseMarkdownConstants.Syntax.dividerUnderscore else {
            return false
        }
        return compact.allSatisfy { $0 == marker }
    }

    /// Reports whether a header and separator pair begins a valid pipe table.
    /// - Parameters:
    ///   - lines: Complete normalized source lines.
    ///   - index: Candidate header index.
    /// - Returns: `true` when header and separator column counts match.
    private func isTableStart(lines: [String], index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        let header = splitTableCells(lines[index])
        let separator = splitTableCells(lines[index + 1])
        return header.count > 0
            && header.count == separator.count
            && lines[index].contains(ResponseMarkdownConstants.Syntax.tableDelimiter)
            && separator.allSatisfy(isTableSeparatorCell)
    }

    /// Splits a pipe row while retaining escaped delimiters inside cell content.
    /// - Parameter line: Raw table row.
    /// - Returns: Trimmed cell values without structural outer empty cells.
    private func splitTableCells(_ line: String) -> [String] {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        var cells: [String] = []
        var current = AppConstants.Text.empty
        var isEscaped = false
        for character in trimmedLine {
            if isEscaped {
                if character != ResponseMarkdownConstants.Syntax.tableDelimiter {
                    current.append(ResponseMarkdownConstants.Syntax.escapeCharacter)
                }
                current.append(character)
                isEscaped = false
            } else if character == ResponseMarkdownConstants.Syntax.escapeCharacter {
                isEscaped = true
            } else if character == ResponseMarkdownConstants.Syntax.tableDelimiter {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = AppConstants.Text.empty
            } else {
                current.append(character)
            }
        }
        if isEscaped {
            current.append(ResponseMarkdownConstants.Syntax.escapeCharacter)
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        if trimmedLine.first == ResponseMarkdownConstants.Syntax.tableDelimiter,
           cells.first?.isEmpty == true {
            cells.removeFirst()
        }
        if trimmedLine.last == ResponseMarkdownConstants.Syntax.tableDelimiter,
           cells.last?.isEmpty == true {
            cells.removeLast()
        }
        return cells
    }

    /// Reports whether one table separator cell contains a valid dash run.
    /// - Parameter cell: Candidate separator cell.
    /// - Returns: `true` when optional edge colons surround at least three dashes.
    private func isTableSeparatorCell(_ cell: String) -> Bool {
        let withoutAlignment = cell.filter {
            $0 != ResponseMarkdownConstants.Syntax.alignmentColon
        }
        return withoutAlignment.count >= ResponseMarkdownConstants.Syntax.minimumDividerLength
            && withoutAlignment.allSatisfy {
                $0 == ResponseMarkdownConstants.Syntax.dividerDash
            }
    }

    /// Normalizes a table row to the header's column count without discarding overflow content.
    /// - Parameters:
    ///   - cells: Parsed body cells.
    ///   - columnCount: Header-defined table width.
    /// - Returns: A row padded or merged to exactly the requested width.
    private func normalizedTableRow(_ cells: [String], columnCount: Int) -> [String] {
        guard columnCount > 0 else { return [] }
        if cells.count == columnCount { return cells }
        if cells.count < columnCount {
            return cells + Array(
                repeating: AppConstants.Text.empty,
                count: columnCount - cells.count
            )
        }
        var normalized = Array(cells.prefix(columnCount))
        normalized[columnCount - 1] = cells[(columnCount - 1)...].joined(
            separator: ResponseMarkdownConstants.Syntax.paragraphJoiner
                + String(ResponseMarkdownConstants.Syntax.tableDelimiter)
                + ResponseMarkdownConstants.Syntax.paragraphJoiner
        )
        return normalized
    }
}
