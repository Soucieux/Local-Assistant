import Foundation

/// Interprets the local model's response as conversation or a constrained file search.
struct AssistantRouteParser: Sendable {
    /// Converts one cleaned local-model response into an assistant action.
    /// - Parameters:
    ///   - modelOutput: Visible output returned by the embedded chat model.
    ///   - originalQuestion: Original user text used only as a safe fallback.
    /// - Returns: A conversational reply or a normalized local search plan.
    internal func parse(modelOutput: String, originalQuestion: String) -> AssistantRoute {
        let output = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if requiresClarification(question: originalQuestion) {
            return .reply(RetrievalStrings.ambiguousFileRequest)
        }
        guard let payload = searchPayload(in: output) else {
            return .reply(output)
        }

        guard let data = payload.data(using: .utf8),
              let encoded = try? JSONDecoder().decode(EncodedSearchPlan.self, from: data) else {
            return .search(fallbackPlan(for: originalQuestion))
        }

        let kinds = Set((encoded.kinds ?? []).compactMap(IndexedItemKind.init(rawValue:)))
        return .search(
            LocalSearchPlan(
                text: encoded.query.trimmingCharacters(in: .whitespacesAndNewlines),
                filter: SearchFilter.with(kinds: kinds)
            )
        )
    }

    /// Extracts the structured payload when the model routed the request to local search.
    ///
    /// The model is asked for a doubled bracket marker but does not reliably reproduce the
    /// brackets, so the marker is matched by its token instead of by literal text. Treating a
    /// near miss as conversation showed the reader the raw marker and payload as the answer.
    /// - Parameter output: Cleaned model output.
    /// - Returns: The JSON payload, or `nil` when the output is ordinary conversation.
    private func searchPayload(in output: String) -> String? {
        let afterBrackets = output.drop {
            InferenceConstants.routingMarkerLeadingCharacters.contains($0)
        }
        guard afterBrackets.hasPrefix(InferenceConstants.localSearchRoutingToken) else {
            return nil
        }
        let payload = afterBrackets
            .dropFirst(InferenceConstants.localSearchRoutingToken.count)
            .drop { InferenceConstants.routingMarkerTrailingCharacters.contains($0) }
        return String(payload)
    }

    /// Detects a singular file-type request that contains no distinguishing detail.
    /// - Parameter question: Original user request.
    /// - Returns: `true` when searching would require an arbitrary guess.
    private func requiresClarification(question: String) -> Bool {
        let components = question.lowercased().components(
            separatedBy: CharacterSet.alphanumerics.inverted
        )
        let orderedTokens = components.filter { $0.isEmpty == false }
        let tokens = Set(orderedTokens)
        guard tokens.isDisjoint(with: RetrievalConstants.singularFileTypeTerms) == false,
              tokens.isDisjoint(with: RetrievalConstants.listIntentTerms) else {
            return false
        }
        if isDefinitionQuestion(tokens: orderedTokens) { return false }
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
        let components = question.lowercased().components(
            separatedBy: CharacterSet.alphanumerics.inverted
        )
        let tokens = Set(components.filter { $0.isEmpty == false })
        let kinds = Set(RetrievalConstants.fileTypeTerms.compactMap { kind, terms in
            tokens.isDisjoint(with: terms) ? nil : kind
        })
        let excludedTerms = RetrievalConstants.searchFillerTerms.union(
            RetrievalConstants.fileTypeTerms.values.reduce(into: Set<String>()) { result, terms in
                result.formUnion(terms)
            }
        )
        let remainingTerms = components.filter {
            $0.isEmpty == false && excludedTerms.contains($0) == false
        }
        let normalizedText = remainingTerms.joined(separator: AppConstants.Text.space)
        return LocalSearchPlan(
            text: normalizedText.isEmpty ? question : normalizedText,
            filter: SearchFilter.with(kinds: kinds)
        )
    }
}

/// Action selected by the embedded local chat model.
enum AssistantRoute: Sendable {
    case reply(String)
    case search(LocalSearchPlan)
}

/// Normalized retrieval request produced before local search begins.
struct LocalSearchPlan: Sendable {
    let text: String
    let filter: SearchFilter
}

/// Codable payload emitted after the local-search routing marker.
private struct EncodedSearchPlan: Decodable {
    let query: String
    let kinds: [String]?
}
