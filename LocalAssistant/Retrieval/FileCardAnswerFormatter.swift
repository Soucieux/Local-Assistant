import Foundation

/// Keeps assistant prose concise when result cards already present file metadata.
internal enum FileCardAnswerFormatter {
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
            return repeatsDisplayName(result.item, in: answer)
                || answer.localizedCaseInsensitiveContains(result.item.url.path)
                || answer.contains(sourceMarker)
        }
        return repeatsCardMetadata
            ? RetrievalStrings.fileCardsReady(matchCount: results.count)
            : answer
    }

    /// Reports whether an answer repeats a name distinctive enough to identify one card.
    ///
    /// Folders and extensionless files carry ordinary words as names, so matching them as
    /// substrings discards correct prose. Only a name carrying a file extension is treated
    /// as identifying; a bare name is left to the path and source-marker checks.
    /// - Parameters:
    ///   - item: Indexed item shown as a result card.
    ///   - answer: Candidate local-model answer.
    /// - Returns: `true` when the answer repeats an identifying filename.
    private static func repeatsDisplayName(_ item: IndexedItem, in answer: String) -> Bool {
        guard item.isDirectory == false, item.url.pathExtension.isEmpty == false else {
            return false
        }
        return answer.localizedCaseInsensitiveContains(item.displayName)
    }
}
