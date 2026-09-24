import Foundation

/// Search syntax and score calibration values.
internal enum RetrievalConstants {
    internal static let matchAllSeparator = " AND "
    internal static let quote = "\""
    internal static let doubledQuote = "\"\""
    internal static let wildcard = "%"
    internal static let likeEscape = "\\"
    internal static let escapedLikeEscape = "\\\\"
    internal static let escapedWildcard = "\\%"
    internal static let singleCharacterWildcard = "_"
    internal static let escapedSingleCharacterWildcard = "\\_"
    internal static let reciprocalRankConstant = 60.0
    internal static let exactNameWeight = 4.0
    internal static let pathWeight = 5.0
    internal static let keywordWeight = 2.5
    internal static let semanticWeight = 3.0
    internal static let fileTypeWeight = 4.0
    internal static let recencyWeight = 0.5
    internal static let highConfidenceThreshold = 0.72
    internal static let mediumConfidenceThreshold = 0.42
    internal static let maximumExcerptCharacters = 480
    internal static let minimumSemanticSimilarity = 0.18
    internal static let minimumFolderScopeSemanticSimilarity = 0.50
    internal static let metadataExactNameMatch = 1.00
    internal static let metadataNameMatch = 0.65
    internal static let metadataTokenMatch = 0.35
    internal static let metadataPathMatch = 1.20
    internal static let metadataPathTokenMatch = 0.80
    internal static let exactFolderScopeMatch = 1.25
    internal static let nameFolderScopeMatch = 1.10
    internal static let pathFolderScopeMatch = 1.00
    internal static let maximumFolderScopeCount = 3
    internal static let maximumExplanationEvidenceCharacters = 180
    internal static let scoreNormalizationDivisor = 10.0
    internal static let recencyDecayDays = 365.0
    internal static let secondsPerDay = 86_400.0
    internal static let fileTypeTerms: [IndexedItemKind: Set<String>] = [
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
    internal static let searchFillerTerms: Set<String> = [
        "a", "about", "all", "an", "any", "are", "available", "compare", "do", "file",
        "files", "find", "for", "give", "have", "i", "if", "is", "know", "list", "locate", "me", "my", "of",
        "open", "please", "reveal", "show", "summarize", "that", "the", "there", "to", "what",
        "want", "which", "you"
    ]
    internal static let singularFileTypeTerms: Set<String> = [
        "archive", "code", "directory", "doc", "docx", "document", "excel", "folder",
        "image", "markdown", "md", "pdf", "photo", "picture", "powerpoint", "presentation",
        "script", "source", "spreadsheet", "text", "txt", "word", "xlsx", "zip"
    ]
    internal static let listIntentTerms: Set<String> = ["all", "list", "show"]
    internal static let localSearchIntentTerms: Set<String> = [
        "any", "available", "find", "have", "list", "locate", "open", "reveal", "show"
    ]
    internal static let definitionQuestionMinimumTokenCount = 3
    internal static let definitionQuestionPrefixLength = 2
    internal static let definitionQuestionFirstToken = "what"
    internal static let definitionQuestionSecondToken = "is"
    internal static let singularFileToken = "file"
    internal static let pluralFileToken = "files"
    internal static let containerTerms: Set<String> = [
        "document", "documents", "file", "files", "pdf", "pdfs", "presentation",
        "presentations", "spreadsheet", "spreadsheets"
    ]
    internal static let embeddedContentRelationTerms: Set<String> = [
        "contain", "containing", "contains", "embedded", "has", "include", "includes",
        "including", "inside", "with"
    ]
    internal static let visualSubjectRelationTerms: Set<String> = [
        "depicting", "of", "showing"
    ]
    internal static let visualItemTerms: Set<String> = [
        "image", "images", "photo", "photos", "picture", "pictures"
    ]
    internal static let definitionArticles: Set<String> = ["a", "an", "the"]

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
