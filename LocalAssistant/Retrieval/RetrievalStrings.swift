import Foundation

/// User-facing explanations generated deterministically by retrieval.
enum RetrievalStrings {
    static let exactNameMatch = "the exact filename"
    static let nameMatch = "the filename"
    static let pathMatch = "the folder path"
    static let keywordMatch = "the document text"
    static let semanticMatch = "the document meaning"
    static let fileTypeMatch = "Matches the requested file type."
    static let aliasMatch = "your terminology"
    static let fallbackMatch = "Best available match from the current index."
    static let savedReference = "Referenced by this saved answer."
    static let insufficientEvidence = "I could not find enough indexed evidence to answer that."
    static let ambiguousFileRequest = "Which file do you mean? Add a topic, filename, folder, or date so I do not guess."
    static let singleFileCardReady = "I found one match. It is shown below."
    static let multipleFileCardsReadyFormat = "I found %d matches. They are shown below."

    /// Creates a concise acknowledgement for results already represented by file cards.
    /// - Parameter matchCount: Number of result cards shown beneath the assistant message.
    /// - Returns: Singular or plural result acknowledgement without repeated file metadata.
    internal static func fileCardsReady(matchCount: Int) -> String {
        guard matchCount != 1 else { return singleFileCardReady }
        return String(format: multipleFileCardsReadyFormat, matchCount)
    }

    /// Combines the strongest retrieval signals into one readable sentence.
    /// - Parameters:
    ///   - reasons: Ordered, non-file-type match signals.
    ///   - matchesFileType: Whether the requested file type was a hard match.
    /// - Returns: A concise explanation without duplicating the visible rank label.
    internal static func matchSummary(
        reasons: [String],
        matchesFileType: Bool
    ) -> String {
        let strongestReasons = Array(reasons.prefix(3))
        guard strongestReasons.isEmpty == false else {
            return matchesFileType ? fileTypeMatch : fallbackMatch
        }

        let joinedReasons: String
        switch strongestReasons.count {
        case 1:
            joinedReasons = strongestReasons[0]
        case 2:
            joinedReasons = strongestReasons.joined(separator: " and ")
        default:
            joinedReasons = strongestReasons.dropLast().joined(separator: ", ")
                + ", and "
                + strongestReasons[strongestReasons.count - 1]
        }
        return "Matched by \(joinedReasons)."
    }
}
