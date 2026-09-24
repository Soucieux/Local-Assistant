import Foundation

/// Interprets local-model output as conversation, file search, or reminder intent.
internal struct AssistantRouteParser: Sendable {
    /// Accepts clear standalone confirmation language or one exact local-model label.
    /// - Parameters:
    ///   - reply: User's newest conversational confirmation reply.
    ///   - modelOutput: Cleaned embedded-model output.
    /// - Returns: Confirm, decline, or a safe unclear fallback.
    internal func reminderConfirmationDecision(
        reply: String,
        modelOutput: String
    ) -> ReminderConfirmationDecision {
        let normalizedReply = orderedTokens(reply).joined(separator: AppConstants.Text.space)
        if ReminderConstants.Routing.confirmationAffirmativePhrases.contains(normalizedReply) {
            return .confirm
        }
        if ReminderConstants.Routing.confirmationDeclinePhrases.contains(normalizedReply) {
            return .decline
        }
        switch modelOutput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case InferenceConstants.confirmationOutput:
            return .confirm
        case InferenceConstants.declineOutput:
            return .decline
        default:
            return .unclear
        }
    }

    /// Converts one cleaned local-model response into an assistant action.
    /// - Parameters:
    ///   - modelOutput: Visible output returned by the embedded chat model.
    ///   - originalQuestion: Original user text used only as a safe fallback.
    /// - Returns: Conversational reply, local search, local reminder read, or gated mutation.
    internal func parse(modelOutput: String, originalQuestion: String) -> AssistantRoute {
        let output = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let payload = routingPayload(
            in: output,
            token: ReminderConstants.Routing.reminderToken
        ) {
            return parseReminder(
                payload: payload,
                originalQuestion: originalQuestion
            )
        }
        if let reminderPlan = inferredReminderPlan(question: originalQuestion) {
            return .reminder(reminderPlan)
        }
        if requiresClarification(question: originalQuestion) {
            return .reply(RetrievalStrings.ambiguousFileRequest)
        }
        let payload = routingPayload(
            in: output,
            token: InferenceConstants.localSearchRoutingToken
        )
        let recoversLocalSearch = shouldRecoverLocalSearch(
            modelOutput: output,
            question: originalQuestion
        )
        guard payload != nil || recoversLocalSearch else {
            return .reply(output)
        }
        if requiresVisualUnderstanding(question: originalQuestion) {
            return .reply(RetrievalStrings.visualContentUnavailable)
        }

        guard let payload else {
            return .search(fallbackPlan(for: originalQuestion))
        }

        guard let data = payload.data(using: .utf8),
              let encoded = try? JSONDecoder().decode(EncodedSearchPlan.self, from: data) else {
            return .search(fallbackPlan(for: originalQuestion))
        }

        let kinds = explicitlyRequestedKinds(question: originalQuestion)
        return .search(
            LocalSearchPlan(
                text: normalizedSearchText(
                    modelQuery: encoded.query,
                    originalQuestion: originalQuestion,
                    kinds: kinds
                ),
                filter: SearchFilter.with(kinds: kinds)
            )
        )
    }

    /// Detects the standalone OpenClaw name used by explicit non-reminder requests.
    /// - Parameter text: Typed or locally transcribed user request.
    /// - Returns: `true` for `OpenClaw` or adjacent `Open Claw` words, case-insensitively.
    internal func isExplicitOpenClawRequest(_ text: String) -> Bool {
        let tokens = orderedTokens(text)
        for (index, token) in tokens.enumerated() {
            if token == ReminderConstants.Routing.openClawCombinedToken {
                return true
            }
            if token == ReminderConstants.Routing.openClawFirstToken,
               index + 1 < tokens.count,
               tokens[index + 1] == ReminderConstants.Routing.openClawSecondToken {
                return true
            }
        }
        return false
    }

    /// Removes request wording and hard file-type terms from one model-routed search.
    /// - Parameters:
    ///   - modelQuery: Search text proposed by the embedded routing model.
    ///   - originalQuestion: User wording used to distinguish a broad type listing from a topic search.
    ///   - kinds: File kinds explicitly requested by the user.
    /// - Returns: Topic terms only, or an empty string for a broad type-only listing.
    private func normalizedSearchText(
        modelQuery: String,
        originalQuestion: String,
        kinds: Set<IndexedItemKind>
    ) -> String {
        let originalTerms = distinguishingTerms(in: originalQuestion, kinds: kinds)
        guard originalTerms.isEmpty == false else { return AppConstants.Text.empty }
        let modelTerms = distinguishingTerms(in: modelQuery, kinds: kinds)
        return (modelTerms.isEmpty ? originalTerms : modelTerms).joined(
            separator: AppConstants.Text.space
        )
    }

    /// Extracts words that describe the requested subject rather than the search action or kind.
    /// - Parameters:
    ///   - text: User or model search wording.
    ///   - kinds: File kinds whose recognized names should not become semantic evidence.
    /// - Returns: Ordered lowercase topic terms.
    private func distinguishingTerms(
        in text: String,
        kinds: Set<IndexedItemKind>
    ) -> [String] {
        let requestedTypeTerms = kinds.reduce(into: Set<String>()) { result, kind in
            result.formUnion(RetrievalConstants.fileTypeTerms[kind] ?? [])
        }
        let excludedTerms = RetrievalConstants.searchFillerTerms.union(requestedTypeTerms)
        return orderedTokens(text).filter { excludedTerms.contains($0) == false }
    }

    /// Derives hard item kinds from the user's words rather than trusting model-generated kinds.
    /// - Parameter question: Original user request.
    /// - Returns: File kinds explicitly requested as result types.
    private func explicitlyRequestedKinds(question: String) -> Set<IndexedItemKind> {
        let tokens = orderedTokens(question)
        return Set(RetrievalConstants.fileTypeTerms.compactMap { kind, terms in
            let requested = tokens.enumerated().contains { index, token in
                terms.contains(token) && isEmbeddedContentReference(at: index, tokens: tokens) == false
            }
            return requested ? kind : nil
        })
    }

    /// Reports whether a file-type word describes content inside another file.
    /// - Parameters:
    ///   - index: Position of the candidate file-type term.
    ///   - tokens: Ordered lowercase words from the original request.
    /// - Returns: `true` when the term follows a container-content relationship.
    private func isEmbeddedContentReference(at index: Int, tokens: [String]) -> Bool {
        guard index > 0,
              let relationIndex = tokens[..<index].lastIndex(where: {
                  RetrievalConstants.embeddedContentRelationTerms.contains($0)
              }) else {
            return false
        }
        return tokens[..<relationIndex].contains {
            RetrievalConstants.containerTerms.contains($0)
        }
    }

    /// Detects a request whose required evidence is unavailable to the text-only index.
    /// - Parameter question: Original user request.
    /// - Returns: `true` for embedded-image or visual-subject constraints.
    private func requiresVisualUnderstanding(question: String) -> Bool {
        let tokens = orderedTokens(question)
        let visualIndices = tokens.indices.filter {
            RetrievalConstants.visualItemTerms.contains(tokens[$0])
        }
        return visualIndices.contains { index in
            isEmbeddedContentReference(at: index, tokens: tokens)
                || tokens[(index + 1)...].contains {
                    RetrievalConstants.visualSubjectRelationTerms.contains($0)
                }
        }
    }

    /// Splits user text into ordered lowercase alphanumeric words.
    /// - Parameter text: Arbitrary user-entered text.
    /// - Returns: Non-empty normalized tokens in source order.
    private func orderedTokens(_ text: String) -> [String] {
        text.lowercased().components(
            separatedBy: CharacterSet.alphanumerics.inverted
        ).filter { $0.isEmpty == false }
    }

    /// Extracts the structured payload when the model routed the request to local search.
    ///
    /// The model is asked for a doubled bracket marker but does not reliably reproduce the
    /// brackets, so the marker is matched by its token instead of by literal text. Treating a
    /// near miss as conversation showed the reader the raw marker and payload as the answer.
    /// - Parameters:
    ///   - output: Cleaned model output.
    ///   - token: Routing marker token the payload must follow.
    /// - Returns: The JSON payload, or `nil` when the output is ordinary conversation.
    private func routingPayload(in output: String, token: String) -> String? {
        let afterBrackets = output.drop {
            InferenceConstants.routingMarkerLeadingCharacters.contains($0)
        }
        guard afterBrackets.hasPrefix(token) else {
            return nil
        }
        let payload = afterBrackets
            .dropFirst(token.count)
            .drop { InferenceConstants.routingMarkerTrailingCharacters.contains($0) }
        return String(payload)
    }

    /// Converts a model-emitted reminder JSON object into a field-limited plan.
    /// - Parameters:
    ///   - payload: Model-emitted reminder routing object.
    ///   - originalQuestion: Exact user wording retained for confirmation-gated writes.
    /// - Returns: Safe local read, confirmation request, or clarification response.
    private func parseReminder(
        payload: String,
        originalQuestion: String
    ) -> AssistantRoute {
        guard let data = payload.data(using: .utf8),
              let encoded = try? JSONDecoder().decode(EncodedReminderPlan.self, from: data) else {
            return .reply(ReminderStrings.invalidReminderRoute)
        }
        let query = (encoded.query ?? encoded.id ?? AppConstants.Text.empty)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch encoded.operation {
        case ReminderConstants.Routing.operationList:
            return .reminder(.list(query: query))
        case ReminderConstants.Routing.operationGet:
            guard query.isEmpty == false else {
                return .reply(ReminderStrings.invalidReminderRoute)
            }
            return .reminder(.get(query: query))
        case ReminderConstants.Routing.operationCreate,
             ReminderConstants.Routing.operationAdd:
            return reminderMutation(
                kind: .create,
                originalQuestion: originalQuestion
            )
        case ReminderConstants.Routing.operationUpdate,
             ReminderConstants.Routing.operationComplete:
            return reminderMutation(
                kind: .update,
                originalQuestion: originalQuestion
            )
        case ReminderConstants.Routing.operationRemove,
             ReminderConstants.Routing.operationDelete:
            return reminderMutation(
                kind: .remove,
                originalQuestion: originalQuestion
            )
        default:
            return .reply(ReminderStrings.invalidReminderRoute)
        }
    }

    /// Builds a confirmation-gated reminder mutation from exact user wording.
    /// - Parameters:
    ///   - kind: Create, update, or remove operation inferred locally.
    ///   - originalQuestion: Exact text that may later be sent after confirmation.
    /// - Returns: Safe mutation plan or clarification when the text is empty.
    private func reminderMutation(
        kind: ReminderMutationKind,
        originalQuestion: String
    ) -> AssistantRoute {
        let request = originalQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard request.isEmpty == false else {
            return .reply(ReminderStrings.invalidReminderRoute)
        }
        return .reminder(.mutate(kind: kind, request: request))
    }

    /// Recovers common English reminder wording when the model omits its routing marker.
    /// - Parameter question: Original typed or locally transcribed request.
    /// - Returns: Conservative reminder plan, or `nil` when ordinary conversation is plausible.
    private func inferredReminderPlan(question: String) -> ReminderAssistantPlan? {
        let tokens = orderedTokens(question)
        guard tokens.isEmpty == false,
              isReminderDefinition(tokens) == false else {
            return nil
        }
        let tokenSet = Set(tokens)
        let hasReminderTerm = tokenSet.isDisjoint(
            with: ReminderConstants.Routing.explicitReminderTerms
        ) == false

        if hasReminderTerm {
            if tokenSet.isDisjoint(with: ReminderConstants.Routing.reminderRemoveTerms) == false {
                return .mutate(kind: .remove, request: question)
            }
            if tokenSet.isDisjoint(with: ReminderConstants.Routing.reminderUpdateTerms) == false {
                return .mutate(kind: .update, request: question)
            }
            if tokenSet.isDisjoint(with: ReminderConstants.Routing.reminderCreateTerms) == false {
                return .mutate(kind: .create, request: question)
            }
            if tokenSet.isDisjoint(with: ReminderConstants.Routing.reminderReadTerms) == false {
                return .list(query: inferredReminderQuery(tokens: tokens))
            }
        }

        guard let needIndex = sequenceIndex(
            ReminderConstants.Routing.needToDoSequence,
            in: tokens
        ) else {
            return nil
        }
        let followingIndex = needIndex + ReminderConstants.Routing.needToDoSequence.count
        if followingIndex < tokens.count,
           tokens[followingIndex] == ReminderConstants.Routing.infinitiveToken {
            return nil
        }
        guard tokenSet.isDisjoint(with: ReminderConstants.Routing.reminderReadTerms) == false
                || followingIndex == tokens.count else {
            return nil
        }
        if followingIndex == tokens.count {
            return .list(query: AppConstants.Text.empty)
        }
        return .list(query: question)
    }

    /// Removes read-action filler while preserving subjects and temporal expressions.
    /// - Parameter tokens: Ordered normalized request tokens.
    /// - Returns: Empty text for a complete list or distinguishing reminder terms.
    private func inferredReminderQuery(tokens: [String]) -> String {
        let tokenSet = Set(tokens)
        if tokenSet.isDisjoint(with: ReminderConstants.Routing.reminderTemporalTerms) == false {
            return tokens.joined(separator: AppConstants.Text.space)
        }
        let fillerTerms = ReminderConstants.Routing.reminderQueryFillerTerms.union(
            ReminderConstants.Routing.explicitReminderTerms
        )
        return tokens.filter {
            fillerTerms.contains($0) == false
        }.joined(separator: AppConstants.Text.space)
    }

    /// Finds one exact contiguous token sequence.
    /// - Parameters:
    ///   - sequence: Ordered phrase tokens.
    ///   - tokens: Normalized request tokens.
    /// - Returns: Start index of the phrase, or `nil` when absent.
    private func sequenceIndex(_ sequence: [String], in tokens: [String]) -> Int? {
        guard sequence.isEmpty == false, tokens.count >= sequence.count else { return nil }
        for index in 0...(tokens.count - sequence.count) {
            if Array(tokens[index..<(index + sequence.count)]) == sequence {
                return index
            }
        }
        return nil
    }

    /// Excludes general questions about the meaning of reminders.
    /// - Parameter tokens: Normalized request tokens.
    /// - Returns: `true` for a short "what is a reminder" definition form.
    private func isReminderDefinition(_ tokens: [String]) -> Bool {
        guard tokens.count <= ReminderConstants.Routing.reminderDefinitionMaximumTokenCount,
              tokens.starts(with: ReminderConstants.Routing.reminderDefinitionPrefix),
              let last = tokens.last else {
            return false
        }
        return ReminderConstants.Routing.explicitReminderTerms.contains(last)
    }

    /// Recovers an explicit local-item request when the routing model returns only an acknowledgement.
    /// - Parameters:
    ///   - modelOutput: Visible model text that omitted the structured routing marker.
    ///   - question: Original user request used to confirm local-item intent.
    /// - Returns: `true` when the request should use deterministic local search fallback.
    private func shouldRecoverLocalSearch(modelOutput: String, question: String) -> Bool {
        let tokens = orderedTokens(question)
        let itemTerms = RetrievalConstants.fileTypeTerms.values.reduce(
            into: Set([RetrievalConstants.singularFileToken, RetrievalConstants.pluralFileToken])
        ) { result, terms in
            result.formUnion(terms)
        }
        guard tokens.contains(where: itemTerms.contains) else { return false }
        let hasExplicitIntent = tokens.contains(where: RetrievalConstants.localSearchIntentTerms.contains)
        let acknowledgedSearch = modelOutput.lowercased().contains(
            InferenceConstants.localSearchAcknowledgement
        )
        return hasExplicitIntent || acknowledgedSearch
    }

    /// Detects a singular file-type request that contains no distinguishing detail.
    /// - Parameter question: Original user request.
    /// - Returns: `true` when searching would require an arbitrary guess.
    private func requiresClarification(question: String) -> Bool {
        let questionTokens = orderedTokens(question)
        let tokens = Set(questionTokens)
        guard tokens.isDisjoint(with: RetrievalConstants.singularFileTypeTerms) == false,
              tokens.isDisjoint(with: RetrievalConstants.listIntentTerms) else {
            return false
        }
        if isDefinitionQuestion(tokens: questionTokens) { return false }
        let excludedTerms = RetrievalConstants.searchFillerTerms.union(
            RetrievalConstants.fileTypeTerms.values.reduce(into: Set<String>()) { result, terms in
                result.formUnion(terms)
            }
        )
        return tokens.subtracting(excludedTerms).isEmpty
    }

    /// Distinguishes a general knowledge question from a request for one local file.
    /// - Parameter tokens: Lowercased user tokens in their original order.
    /// - Returns: `true` for forms such as "what is a PDF?" that should be answered normally.
    private func isDefinitionQuestion(tokens: [String]) -> Bool {
        guard tokens.count >= RetrievalConstants.definitionQuestionMinimumTokenCount,
              tokens[0] == RetrievalConstants.definitionQuestionFirstToken,
              tokens[1] == RetrievalConstants.definitionQuestionSecondToken,
              tokens.contains(RetrievalConstants.singularFileToken) == false,
              tokens.contains(RetrievalConstants.pluralFileToken) == false else {
            return false
        }
        let definitionTerms = Set(
            tokens.dropFirst(RetrievalConstants.definitionQuestionPrefixLength)
        ).subtracting(RetrievalConstants.definitionArticles)
        return definitionTerms.count == 1
            && definitionTerms.isDisjoint(with: RetrievalConstants.singularFileTypeTerms) == false
    }

    /// Builds a deterministic plan when the local model omits its structured payload.
    /// - Parameter question: Original user request.
    /// - Returns: A bounded search plan that still enforces recognized file types.
    private func fallbackPlan(for question: String) -> LocalSearchPlan {
        let kinds = explicitlyRequestedKinds(question: question)
        return LocalSearchPlan(
            text: normalizedSearchText(
                modelQuery: question,
                originalQuestion: question,
                kinds: kinds
            ),
            filter: SearchFilter.with(kinds: kinds)
        )
    }
}

/// Action selected by the embedded local chat model.
internal enum AssistantRoute: Sendable {
    case reply(String)
    case search(LocalSearchPlan)
    case reminder(ReminderAssistantPlan)
}

/// Normalized retrieval request produced before local search begins.
internal struct LocalSearchPlan: Sendable {
    internal let text: String
    internal let filter: SearchFilter
}

/// Codable payload emitted after the local-search routing marker.
private struct EncodedSearchPlan: Decodable {
    internal let query: String
}

/// Field-limited JSON emitted for one reminder intent.
private struct EncodedReminderPlan: Decodable {
    internal let operation: String
    internal let query: String?
    internal let id: String?
}
