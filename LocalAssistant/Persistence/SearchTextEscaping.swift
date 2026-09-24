import Foundation

/// Converts untrusted local search text into safe SQLite LIKE and FTS5 expressions.
///
/// Escaping decides whether a search finds anything, so it is kept separate from the
/// database actor to stay directly testable.
internal enum SearchTextEscaping {
    /// Splits a query into whitespace-separated tokens for per-token metadata matching.
    /// - Parameter text: Untrusted local search text.
    /// - Returns: Non-empty tokens in query order.
    internal static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Escapes wildcard characters used in a metadata LIKE expression.
    ///
    /// The escape character is itself escaped first, otherwise escaping a wildcard would
    /// produce a sequence that SQLite reads as a literal backslash followed by a wildcard.
    /// - Parameter value: Untrusted local search text.
    /// - Returns: Text safe to interpolate into a `LIKE ? ESCAPE '\'` pattern.
    internal static func escapedLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: RetrievalConstants.likeEscape, with: RetrievalConstants.escapedLikeEscape)
            .replacingOccurrences(of: RetrievalConstants.wildcard, with: RetrievalConstants.escapedWildcard)
            .replacingOccurrences(
                of: RetrievalConstants.singleCharacterWildcard,
                with: RetrievalConstants.escapedSingleCharacterWildcard
            )
    }

    /// Converts plain user terms to a literal-token FTS expression.
    /// - Parameter text: Untrusted local search text.
    /// - Returns: Quoted tokens joined with an AND operator.
    internal static func ftsQuery(_ text: String) -> String {
        tokens(text).map { token in
            let escaped = token.replacingOccurrences(
                of: RetrievalConstants.quote,
                with: RetrievalConstants.doubledQuote
            )
            return RetrievalConstants.quotedToken(escaped)
        }.joined(separator: RetrievalConstants.matchAllSeparator)
    }
}
