import Foundation
import Testing

@testable import LocalAssistant

/// Covers the boundary that keeps app-generated text out of the model's own history.
///
/// A generated acknowledgement stored as assistant text and replayed as recent conversation
/// taught the model to answer every request with that sentence and no results.
struct PromptHistoryTests {
    private let builder = GroundedPromptBuilder()

    /// Builds one stored assistant message with no cards attached.
    /// - Parameter text: Message text as it would be persisted.
    /// - Returns: An assistant message for history.
    private func assistantMessage(_ text: String) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            role: .assistant,
            text: text,
            createdAt: Date(),
            citations: [],
            fileMatches: []
        )
    }

    @Test("recognizes the singular card acknowledgement")
    func recognizesSingularSummary() {
        #expect(RetrievalStrings.isFileCardSummary(RetrievalStrings.fileCardsReady(matchCount: 1)))
    }

    @Test("recognizes plural card acknowledgements for any count")
    func recognizesPluralSummary() {
        for count in [0, 2, 10, 137] {
            #expect(RetrievalStrings.isFileCardSummary(RetrievalStrings.fileCardsReady(matchCount: count)))
        }
    }

    @Test("treats ordinary assistant prose as model output")
    func ignoresOrdinaryProse() {
        #expect(RetrievalStrings.isFileCardSummary("I'm here and ready to help.") == false)
        #expect(RetrievalStrings.isFileCardSummary("") == false)
    }

    @Test("does not treat a sentence with a missing count as an acknowledgement")
    func ignoresMalformedSummary() {
        #expect(RetrievalStrings.isFileCardSummary("I found  matches. They are shown below.") == false)
        #expect(RetrievalStrings.isFileCardSummary("I found many matches. They are shown below.") == false)
    }

    @Test("keeps a generated acknowledgement out of the routing prompt")
    func replacesSummaryInPrompt() {
        let summary = RetrievalStrings.fileCardsReady(matchCount: 2)
        let prompt = builder.assistantPrompt(
            question: "what else?",
            history: [assistantMessage(summary)]
        )

        #expect(prompt.contains(summary) == false)
        #expect(prompt.contains(InferenceConstants.historyFileResultsNote))
    }

    @Test("keeps ordinary assistant replies in the routing prompt")
    func preservesOrdinaryReplyInPrompt() {
        let reply = "A PDF is a portable document format file."
        let prompt = builder.assistantPrompt(
            question: "what else?",
            history: [assistantMessage(reply)]
        )

        #expect(prompt.contains(reply))
        #expect(prompt.contains(InferenceConstants.historyFileResultsNote) == false)
    }

    @Test("never substitutes a user message that repeats the sentence")
    func preservesUserTextMatchingSummary() {
        let summary = RetrievalStrings.fileCardsReady(matchCount: 2)
        let userMessage = ChatMessage.user(summary)
        let prompt = builder.assistantPrompt(question: "what else?", history: [userMessage])

        #expect(prompt.contains(summary))
    }

    @Test("frames retained messages as real user and assistant turns")
    internal func framesHistoryAsChatTurns() {
        let userMessage = ChatMessage.user("My project is called Atlas.")
        let assistantReply = assistantMessage("I will remember that name.")
        let prompt = builder.assistantPrompt(
            question: "What is it called?",
            history: [userMessage, assistantReply]
        )

        let framedHistory = InferenceConstants.chatUserStart
            + userMessage.text
            + AppConstants.Text.newline
            + InferenceConstants.chatAssistantStart
            + assistantReply.text
            + AppConstants.Text.newline
        #expect(prompt.contains(framedHistory))
    }

    @Test("retains the newest turn when older messages exhaust the budget")
    internal func prioritizesNewestHistory() {
        let oversizedReply = assistantMessage(
            String(repeating: "Earlier response. ", count: 400)
        )
        let latestUser = ChatMessage.user("The latest project name is Beacon.")
        let latestAssistant = assistantMessage("Beacon is the current project name.")
        let prompt = builder.assistantPrompt(
            question: "What is the current project name?",
            history: [oversizedReply, latestUser, latestAssistant]
        )

        #expect(prompt.contains(latestUser.text))
        #expect(prompt.contains(latestAssistant.text))
    }

}
