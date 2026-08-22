import Foundation

/// User-facing explanations generated deterministically by retrieval.
enum RetrievalStrings {
    static let fileTypeMatch = "Matches the requested file type."
    static let fallbackMatch = "Best available match from the current index."
    static let exactNameEvidence = "The filename exactly matches the search."
    static let nameEvidence = "The filename contains the search terms."
    static let pathEvidence = "The folder path contains the search terms."
    static let folderScopeEvidenceFormat = "Inside the “%@” folder."
    static let keywordEvidenceFormat = "Indexed text contains the search terms: “%@”"
    static let semanticEvidenceFormat = "Indexed text is semantically related to the description: “%@”"
    static let possibleSemanticEvidenceFormat = "Possible semantic relation in indexed text: “%@”"
    static let savedReference = "Referenced by this saved answer."
    static let insufficientEvidence = "I could not find enough indexed evidence to answer that."
    static let visualContentUnavailable = "I cannot verify visual subjects or embedded images inside files yet. I can search filenames, readable document text, and words recognized in standalone images."
    static let ambiguousFileRequest = "Which file do you mean? Add a topic, filename, folder, or date so I do not guess."
    static let singleFileCardReady = "I found one match. It is shown below."
    static let multipleFileCardsReadyFormat = "I found %d matches. They are shown below."
    private static let countPlaceholder = "%d"

    /// Creates a concise acknowledgement for results already represented by file cards.
    /// - Parameter matchCount: Number of result cards shown beneath the assistant message.
    /// - Returns: Singular or plural result acknowledgement without repeated file metadata.
    internal static func fileCardsReady(matchCount: Int) -> String {
        guard matchCount != 1 else { return singleFileCardReady }
        return String(format: multipleFileCardsReadyFormat, matchCount)
    }

    /// Reports whether text is an acknowledgement this app generated rather than model prose.
    ///
    /// These sentences are written by `fileCardsReady(matchCount:)`, not by the model. Feeding
    /// one back as recent conversation teaches the model to repeat it as its own reply, after
    /// which every request returns the same sentence and no results.
    /// - Parameter text: Stored assistant message text.
    /// - Returns: `true` when the text is a generated card acknowledgement.
    internal static func isFileCardSummary(_ text: String) -> Bool {
        if text == singleFileCardReady { return true }
        let parts = multipleFileCardsReadyFormat.components(separatedBy: countPlaceholder)
        guard parts.count == 2, text.hasPrefix(parts[0]), text.hasSuffix(parts[1]) else {
            return false
        }
        let count = text.dropFirst(parts[0].count).dropLast(parts[1].count)
        return count.isEmpty == false && count.allSatisfy(\.isNumber)
    }

    /// Explains an exact keyword hit using the indexed passage that produced it.
    /// - Parameter evidence: Bounded source text from the matching passage.
    /// - Returns: A concrete keyword-match explanation for a result card.
    internal static func keywordEvidence(_ evidence: String) -> String {
        String(format: keywordEvidenceFormat, evidence)
    }

    /// Explains a semantic hit using the closest indexed passage.
    /// - Parameters:
    ///   - evidence: Bounded source text from the closest passage.
    ///   - isUncertain: Whether the calibrated result confidence is low.
    /// - Returns: A concrete semantic explanation with uncertainty stated when necessary.
    internal static func semanticEvidence(_ evidence: String, isUncertain: Bool) -> String {
        String(
            format: isUncertain ? possibleSemanticEvidenceFormat : semanticEvidenceFormat,
            evidence
        )
    }

    /// Explains that a result belongs to a folder strongly matched by the request.
    /// - Parameter folderName: Visible matched folder name.
    /// - Returns: Concise hierarchy evidence for a result card.
    internal static func folderScopeEvidence(_ folderName: String) -> String {
        String(format: folderScopeEvidenceFormat, folderName)
    }

}
