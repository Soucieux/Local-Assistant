import Foundation

/// Normalizes extracted text while preserving paragraph boundaries.
enum TextNormalizer {
    /// Removes noisy horizontal spacing and excessive blank lines.
    /// - Parameter text: Extracted local text.
    /// - Returns: Trimmed, search-ready text.
    internal static func normalize(_ text: String) -> String {
        let horizontal = text.replacingOccurrences(
            of: ExtractionConstants.whitespacePattern,
            with: AppConstants.Text.space,
            options: .regularExpression
        )
        let paragraphs = horizontal.replacingOccurrences(
            of: ExtractionConstants.excessiveNewlinePattern,
            with: ExtractionConstants.doubleNewline,
            options: .regularExpression
        )
        return paragraphs.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
