import Foundation
import Testing

@testable import LocalAssistant

/// Escaping decides whether a query matches at all, so each transform is pinned here.
internal struct SearchTextEscapingTests {
    @Test("Underscores are escaped so they cannot act as single-character wildcards")
    internal func escapesUnderscore() {
        #expect(SearchTextEscaping.escapedLike("budget_2024") == #"budget\_2024"#)
    }

    @Test("Percent signs are escaped so they cannot match everything")
    internal func escapesPercent() {
        #expect(SearchTextEscaping.escapedLike("50%") == #"50\%"#)
    }

    @Test("The escape character is escaped before the wildcards it protects")
    internal func escapesTheEscapeCharacterFirst() {
        // Escaping the wildcards first would turn a literal backslash into an active
        // escape for the character that follows it.
        #expect(SearchTextEscaping.escapedLike(#"a\_b"#) == #"a\\\_b"#)
    }

    @Test("Ordinary text is returned unchanged")
    internal func leavesPlainTextAlone() {
        #expect(SearchTextEscaping.escapedLike("Quarterly Report") == "Quarterly Report")
    }

    @Test("Every whitespace-separated word becomes its own token")
    internal func splitsTokens() {
        #expect(SearchTextEscaping.tokens("  automotive   consulting \n report ")
            == ["automotive", "consulting", "report"])
    }

    @Test("Empty and whitespace-only text yields no tokens")
    internal func yieldsNoTokensForBlankText() {
        #expect(SearchTextEscaping.tokens("").isEmpty)
        #expect(SearchTextEscaping.tokens("   \t\n ").isEmpty)
    }

    @Test("Full-text terms are quoted and combined so every word must appear")
    internal func buildsConjunctiveFTSQuery() {
        #expect(SearchTextEscaping.ftsQuery("automotive consulting")
            == "\"automotive\" AND \"consulting\"")
    }

    @Test("A quote inside a term is doubled rather than closing the token")
    internal func escapesQuotesInFTSTerms() {
        #expect(SearchTextEscaping.ftsQuery("say\"hi") == "\"say\"\"hi\"")
    }

    @Test("FTS operators supplied by the user are treated as literal text")
    internal func treatsOperatorsAsLiterals() {
        // Unquoted, `OR` and `NEAR` would change the query's meaning.
        #expect(SearchTextEscaping.ftsQuery("report OR secret")
            == "\"report\" AND \"OR\" AND \"secret\"")
    }

    @Test("Blank text produces an empty query so callers can skip the search")
    internal func producesEmptyQueryForBlankText() {
        #expect(SearchTextEscaping.ftsQuery("   ").isEmpty)
    }
}
