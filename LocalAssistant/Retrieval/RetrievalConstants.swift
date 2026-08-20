import Foundation

/// Search syntax and score calibration values.
enum RetrievalConstants {
    static let matchAllSeparator = " AND "
    static let quote = "\""
    static let doubledQuote = "\"\""
    static let wildcard = "%"
    static let likeEscape = "\\"
    static let escapedLikeEscape = "\\\\"
    static let escapedWildcard = "\\%"
    static let singleCharacterWildcard = "_"
    static let escapedSingleCharacterWildcard = "\\_"
    static let reciprocalRankConstant = 60.0
    static let exactNameWeight = 4.0
    static let pathWeight = 1.5
    static let keywordWeight = 2.5
    static let semanticWeight = 3.0
    static let fileTypeWeight = 4.0
    static let recencyWeight = 0.5
    static let highConfidenceThreshold = 0.72
    static let mediumConfidenceThreshold = 0.42
    static let maximumExcerptCharacters = 480
    static let minimumSemanticSimilarity = 0.18
    static let fileTypeTerms: [IndexedItemKind: Set<String>] = [
        .folder: ["folder", "folders", "directory", "directories"],
        .document: ["document", "documents", "doc", "docx", "word"],
        .spreadsheet: ["spreadsheet", "spreadsheets", "xlsx", "excel"],
        .presentation: ["presentation", "presentations", "pptx", "powerpoint", "slides"],
        .pdf: ["pdf", "pdfs"],
        .image: ["image", "images", "picture", "pictures", "photo", "photos"],
        .code: ["code", "source", "script", "scripts"],
        .text: ["text", "txt", "markdown", "md"],
        .archive: ["archive", "archives", "zip", "compressed"]
    ]
    static let searchFillerTerms: Set<String> = [
        "a", "an", "compare", "file", "files", "find", "for", "give", "is", "locate",
        "me", "my", "of", "open", "please", "reveal", "show", "summarize", "that", "the",
        "to", "what", "which"
    ]
    static let singularFileTypeTerms: Set<String> = [
        "archive", "code", "directory", "doc", "docx", "document", "excel", "folder",
        "image", "markdown", "md", "pdf", "photo", "picture", "powerpoint", "presentation",
        "script", "source", "spreadsheet", "text", "txt", "word", "xlsx", "zip"
    ]
    static let listIntentTerms: Set<String> = ["all", "list", "show"]
    static let definitionQuestionMinimumTokenCount = 3
    static let definitionQuestionPrefixLength = 2
    static let definitionQuestionFirstToken = "what"
    static let definitionQuestionSecondToken = "is"
    static let singularFileToken = "file"
    static let pluralFileToken = "files"
    static let definitionArticles: Set<String> = ["a", "an", "the"]

    /// Wraps text in SQLite wildcard markers.
    /// - Parameter text: Escaped LIKE text.
    /// - Returns: Contains-match pattern.
    internal static func containsPattern(_ text: String) -> String {
        wildcard + text + wildcard
    }

    /// Adds a trailing SQLite wildcard marker.
    /// - Parameter text: Escaped LIKE text.
    /// - Returns: Prefix-match pattern.
    internal static func prefixPattern(_ text: String) -> String {
        text + wildcard
    }

    /// Wraps one literal FTS token in quotes.
    /// - Parameter text: Escaped token.
    /// - Returns: Quoted FTS token.
    internal static func quotedToken(_ text: String) -> String {
        quote + text + quote
    }
}
