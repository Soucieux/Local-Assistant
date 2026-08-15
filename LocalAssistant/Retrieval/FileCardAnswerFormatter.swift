import Foundation

/// Keeps assistant prose concise when result cards already present file metadata.
enum FileCardAnswerFormatter {
    /// Replaces model output that duplicates visible card metadata with a concise result count.
    /// - Parameters:
    ///   - answer: Candidate local-model answer.
    ///   - results: Ranked matches displayed as cards beneath the answer.
    /// - Returns: The original answer when it contains no duplicated metadata; otherwise, a card summary.
    internal static func visibleAnswer(
        from answer: String,
        results: [SearchResult]
    ) -> String {
        guard results.isEmpty == false else { return answer }
        let repeatsCardMetadata = results.enumerated().contains { offset, result in
            let sourceMarker = InferenceConstants.sourcePrefix
                + String(offset + 1)
                + InferenceConstants.sourceSuffix
            return answer.localizedCaseInsensitiveContains(result.item.displayName)
                || answer.localizedCaseInsensitiveContains(result.item.url.path)
                || answer.contains(sourceMarker)
        }
        return repeatsCardMetadata
            ? RetrievalStrings.fileCardsReady(matchCount: results.count)
            : answer
    }
}
