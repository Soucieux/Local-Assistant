import Foundation

/// Answers ordinary conversation locally and retrieves file evidence only when requested.
actor GroundedAssistantService {
    private let database: AssistantDatabase
    private let retrieval: HybridRetrievalService
    private let runtime: LlamaCppRuntime
    private let promptBuilder = GroundedPromptBuilder()
    private let routeParser = AssistantRouteParser()

    /// Creates the grounded conversational service.
    /// - Parameters:
    ///   - database: Private SQLite storage.
    ///   - retrieval: Hybrid local search engine.
    ///   - runtime: Embedded llama.cpp runtime.
    internal init(
        database: AssistantDatabase,
        retrieval: HybridRetrievalService,
        runtime: LlamaCppRuntime
    ) {
        self.database = database
        self.retrieval = retrieval
        self.runtime = runtime
    }

    /// Answers a user request and persists the private conversation locally.
    /// - Parameters:
    ///   - question: User's conversational or file-related request.
    ///   - history: Recent local conversation context.
    ///   - persistHistory: Whether the caller wants the turn stored privately.
    /// - Returns: A conversational answer or grounded file response with ranked alternatives.
    /// - Throws: A local database or inference error.
    internal func answer(
        question: String,
        history: [ChatMessage],
        persistHistory: Bool
    ) async throws -> AssistantResponse {
        let userMessage = ChatMessage.user(question)
        if persistHistory { try await database.insertChatMessage(userMessage) }
        let assistantPrompt = promptBuilder.assistantPrompt(question: question, history: history)
        let assistantOutput = cleanedModelOutput(
            from: try await runtime.generate(prompt: assistantPrompt)
        )
        let route = routeParser.parse(modelOutput: assistantOutput, originalQuestion: question)
        let searchPlan: LocalSearchPlan
        switch route {
        case let .reply(reply):
            let response = AssistantResponse(
                answer: reply,
                citations: [],
                alternatives: [],
                confidence: .low
            )
            if persistHistory { try await persist(response: response) }
            return response
        case let .search(plan):
            searchPlan = plan
        }

        let query = SearchQuery(
            text: searchPlan.text,
            filter: searchPlan.filter,
            limit: AppConstants.Chat.evidenceLimit
        )
        let results = try await retrieval.search(query)
        guard results.isEmpty == false else {
            let response = AssistantResponse(
                answer: RetrievalStrings.insufficientEvidence,
                citations: [],
                alternatives: [],
                confidence: .low
            )
            if persistHistory { try await persist(response: response) }
            return response
        }

        let citations = evidence(from: results)
        let prompt = promptBuilder.prompt(question: question, citations: citations, history: history)
        let generatedAnswer = cleanedModelOutput(
            from: try await runtime.generate(prompt: prompt)
        )
        let response = AssistantResponse(
            answer: FileCardAnswerFormatter.visibleAnswer(
                from: generatedAnswer,
                results: results
            ),
            citations: citations,
            alternatives: results,
            confidence: results.first?.confidence ?? .low
        )
        if persistHistory { try await persist(response: response) }
        return response
    }

    /// Creates one bounded evidence list from ranked results.
    /// - Parameter results: Ranked file matches.
    /// - Returns: Deduplicated citations, including path-only fallbacks.
    private func evidence(from results: [SearchResult]) -> [EvidenceCitation] {
        var seen: Set<UUID> = []
        var citations: [EvidenceCitation] = []
        for result in results {
            if let citation = result.citations.first {
                guard seen.insert(citation.itemID).inserted else { continue }
                citations.append(citation)
            } else if seen.insert(result.item.id).inserted {
                citations.append(
                    EvidenceCitation(
                        id: UUID(),
                        itemID: result.item.id,
                        chunkID: nil,
                        absolutePath: result.item.url.path,
                        displayName: result.item.displayName,
                        excerpt: result.explanation,
                        pageNumber: nil,
                        sectionName: nil,
                        modifiedAt: result.item.modifiedAt
                    )
                )
            }
            if citations.count == AppConstants.Chat.evidenceLimit { break }
        }
        return citations
    }

    /// Removes optional Qwen thinking blocks from user-visible output.
    /// - Parameter text: Raw model completion.
    /// - Returns: Visible answer only.
    private func removeThinking(from text: String) -> String {
        guard let openRange = text.range(of: InferenceConstants.thinkingOpenTag),
              let closeRange = text.range(
                of: InferenceConstants.thinkingCloseTag,
                range: openRange.upperBound..<text.endIndex
              ) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var cleaned = text
        cleaned.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes hidden reasoning and prevents Qwen control markers from reaching visible history.
    /// - Parameter text: Raw local model completion.
    /// - Returns: Visible model text or a safe local failure message when no valid text remains.
    private func cleanedModelOutput(from text: String) -> String {
        let withoutThinking = removeThinking(from: text)
        var visibleEnd = withoutThinking.endIndex
        for token in [
            InferenceConstants.chatMessageStartToken,
            InferenceConstants.chatMessageEndToken,
            InferenceConstants.thinkingOpenTag,
            InferenceConstants.thinkingCloseTag
        ] {
            if let range = withoutThinking.range(of: token), range.lowerBound < visibleEnd {
                visibleEnd = range.lowerBound
            }
        }
        let visible = String(withoutThinking[..<visibleEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return visible.isEmpty ? InferenceConstants.invalidModelOutput : visible
    }

    /// Persists one assistant response in private local history.
    /// - Parameter response: Grounded response to store.
    /// - Throws: A local database error when insertion fails.
    private func persist(response: AssistantResponse) async throws {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: response.answer,
            createdAt: Date(),
            citations: response.citations,
            fileMatches: response.alternatives
        )
        try await database.insertChatMessage(message)
    }
}
