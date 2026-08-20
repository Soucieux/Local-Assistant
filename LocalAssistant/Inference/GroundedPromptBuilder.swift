import Foundation

/// Builds bounded prompts that contain only explicit local evidence.
struct GroundedPromptBuilder: Sendable {
    /// Creates a Qwen prompt that either answers ordinary conversation or requests local retrieval.
    /// - Parameters:
    ///   - question: Current user request.
    ///   - history: Recent private conversation messages.
    /// - Returns: Local assistant-routing prompt for embedded llama.cpp.
    internal func assistantPrompt(question: String, history: [ChatMessage]) -> String {
        InferenceConstants.chatSystemStart
            + InferenceConstants.assistantSystemPrompt
            + InferenceConstants.chatUserStart
            + InferenceConstants.recentConversationHeader
            + boundedHistory(history)
            + InferenceConstants.questionHeader
            + sanitizedUntrustedText(question)
            + AppConstants.Text.newline
            + InferenceConstants.noThinkingInstruction
            + InferenceConstants.chatAssistantStart
    }

    /// Creates a Qwen chat prompt from a question, evidence, and recent local history.
    /// - Parameters:
    ///   - question: Current user request.
    ///   - citations: Bounded local evidence.
    ///   - history: Recent private conversation messages.
    /// - Returns: Chat-template prompt for embedded llama.cpp.
    internal func prompt(
        question: String,
        citations: [EvidenceCitation],
        history: [ChatMessage]
    ) -> String {
        let evidenceText = boundedEvidence(citations)
        let historyText = boundedHistory(history)
        return InferenceConstants.chatSystemStart
            + InferenceConstants.groundedSystemPrompt
            + InferenceConstants.chatUserStart
            + InferenceConstants.contextHeader
            + evidenceText
            + InferenceConstants.recentConversationHeader
            + historyText
            + InferenceConstants.questionHeader
            + sanitizedUntrustedText(question)
            + AppConstants.Text.newline
            + InferenceConstants.noThinkingInstruction
            + InferenceConstants.chatAssistantStart
    }

    /// Formats evidence while enforcing a conservative character budget.
    /// - Parameter citations: Ranked source excerpts.
    /// - Returns: Numbered evidence block.
    private func boundedEvidence(_ citations: [EvidenceCitation]) -> String {
        var output = AppConstants.Text.empty
        for (offset, citation) in citations.enumerated() {
            let block = InferenceConstants.sourcePrefix
                + String(offset + 1)
                + InferenceConstants.sourceSuffix
                + InferenceConstants.sourcePathLabel
                + sanitizedUntrustedText(citation.absolutePath)
                + InferenceConstants.sourceExcerptLabel
                + sanitizedUntrustedText(citation.excerpt)
                + InferenceConstants.sourceSeparator
            if output.count + block.count > InferenceConstants.maximumEvidenceCharacters { break }
            output += block
        }
        return output
    }

    /// Formats recent user and assistant messages under a character budget.
    /// - Parameter history: Private chronological message history.
    /// - Returns: Bounded dialogue text.
    private func boundedHistory(_ history: [ChatMessage]) -> String {
        let recent = history.suffix(InferenceConstants.recentMessageLimit)
        var output = AppConstants.Text.empty
        for message in recent {
            let label = message.role == .user
                ? InferenceConstants.userRoleLabel
                : InferenceConstants.assistantRoleLabel
            let line = label
                + historyText(for: message)
                + AppConstants.Text.newline
            if output.count + line.count > InferenceConstants.maximumHistoryCharacters { break }
            output += line
        }
        return output
    }

    /// Returns the conversation text a prompt may show for one stored message.
    ///
    /// An acknowledgement this app generated is replaced by a bracketed note. Repeating the
    /// sentence itself presents the app's own output as something the model said, which it
    /// then imitates instead of answering the request.
    /// - Parameter message: Stored conversation message.
    /// - Returns: Sanitized text, or a note in place of a generated acknowledgement.
    private func historyText(for message: ChatMessage) -> String {
        guard message.role == .assistant,
              RetrievalStrings.isFileCardSummary(message.text) else {
            return sanitizedUntrustedText(message.text)
        }
        return InferenceConstants.historyFileResultsNote
    }

    /// Neutralizes model control markers inside user, history, path, and excerpt data.
    /// - Parameter text: Untrusted local text inserted inside an existing prompt role.
    /// - Returns: Text that cannot open a Qwen role or inject a local-search route marker.
    private func sanitizedUntrustedText(_ text: String) -> String {
        InferenceConstants.untrustedControlMarkers.reduce(text) { partial, marker in
            partial.replacingOccurrences(of: marker, with: AppConstants.Text.space)
        }
    }
}
