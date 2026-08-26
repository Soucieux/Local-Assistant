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
            + InferenceConstants.currentDatePrefix
            + currentDateText()
            + AppConstants.Text.newline
            + boundedHistory(history)
            + InferenceConstants.chatUserStart
            + sanitizedUntrustedText(question)
            + AppConstants.Text.newline
            + InferenceConstants.noThinkingInstruction
            + InferenceConstants.chatAssistantStart
    }

    /// Formats today's Gregorian date for time-sensitive reminder routing.
    /// - Parameter date: Current local date, injectable for deterministic tests.
    /// - Returns: A YYYY-MM-DD calendar date.
    private func currentDateText(_ date: Date = Date()) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: date
        )
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
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
            + historyText
            + InferenceConstants.chatUserStart
            + InferenceConstants.contextHeader
            + evidenceText
            + InferenceConstants.questionHeader
            + sanitizedUntrustedText(question)
            + AppConstants.Text.newline
            + InferenceConstants.noThinkingInstruction
            + InferenceConstants.chatAssistantStart
    }

    /// Creates a local prompt grounded only in cached CloudBase reminder evidence.
    /// - Parameters:
    ///   - question: Current reminder question.
    ///   - matches: Ranked records from the hidden reminder index.
    ///   - history: Recent private conversation messages.
    /// - Returns: Chat-template prompt containing bounded reminder evidence.
    internal func reminderPrompt(
        question: String,
        matches: [ReminderSearchResult],
        history: [ChatMessage]
    ) -> String {
        InferenceConstants.chatSystemStart
            + InferenceConstants.reminderGroundedSystemPrompt
            + boundedHistory(history)
            + InferenceConstants.chatUserStart
            + InferenceConstants.reminderContextHeader
            + boundedReminderEvidence(matches)
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

    /// Formats ranked reminder records under the same conservative evidence budget.
    /// - Parameter matches: Ranked reminder records selected from the local cache.
    /// - Returns: Numbered field-limited reminder evidence.
    private func boundedReminderEvidence(_ matches: [ReminderSearchResult]) -> String {
        var output = AppConstants.Text.empty
        for (offset, match) in matches.enumerated() {
            let item = match.item
            let block = InferenceConstants.sourcePrefix
                + String(offset + 1)
                + InferenceConstants.sourceSuffix
                + InferenceConstants.reminderIdentifierLabel
                + sanitizedUntrustedText(item.id)
                + InferenceConstants.reminderTextLabel
                + sanitizedUntrustedText(item.text)
                + InferenceConstants.reminderDateLabel
                + sanitizedUntrustedText(item.date ?? InferenceConstants.reminderMissingValue)
                + InferenceConstants.reminderStartLabel
                + sanitizedUntrustedText(item.startTime ?? InferenceConstants.reminderMissingValue)
                + InferenceConstants.reminderEndLabel
                + sanitizedUntrustedText(item.endTime ?? InferenceConstants.reminderMissingValue)
                + InferenceConstants.reminderTagLabel
                + sanitizedUntrustedText(item.tag ?? InferenceConstants.reminderMissingValue)
                + InferenceConstants.reminderLinkLabel
                + sanitizedUntrustedText(item.link ?? InferenceConstants.reminderMissingValue)
                + InferenceConstants.sourceSeparator
            if output.count + block.count > InferenceConstants.maximumEvidenceCharacters { break }
            output += block
        }
        return output
    }

    /// Formats recent user and assistant messages as real Qwen chat turns.
    /// - Parameter history: Private chronological message history.
    /// - Returns: Bounded role-framed dialogue that prioritizes the newest messages.
    private func boundedHistory(_ history: [ChatMessage]) -> String {
        var blocks: [String] = []
        var characterCount = 0
        let recent = history
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(InferenceConstants.recentMessageLimit)
        for message in recent.reversed() {
            let visibleText = String(
                historyText(for: message)
                    .prefix(InferenceConstants.maximumHistoryMessageCharacters)
            )
            let block = historyRoleStart(for: message.role)
                + visibleText
                + AppConstants.Text.newline
            guard characterCount + block.count <= InferenceConstants.maximumHistoryCharacters else {
                break
            }
            blocks.insert(block, at: 0)
            characterCount += block.count
        }
        return blocks.joined()
    }

    /// Returns the Qwen role boundary for one retained conversation message.
    /// - Parameter role: User or assistant author of the message.
    /// - Returns: Chat-template prefix that closes the prior role and opens this one.
    private func historyRoleStart(for role: MessageRole) -> String {
        role == .user
            ? InferenceConstants.chatUserStart
            : InferenceConstants.chatAssistantStart
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
