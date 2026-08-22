import Foundation
import Testing

@testable import LocalAssistant

/// The parser decides whether local files are searched at all, and it reads text produced
/// by a model, so malformed and adversarial payloads are covered alongside the happy path.
struct AssistantRouteParserTests {
    private let parser = AssistantRouteParser()

    /// Returns the reply text, or `nil` when the parser chose to search.
    private func reply(_ route: AssistantRoute) -> String? {
        if case let .reply(text) = route { return text }
        return nil
    }

    /// Returns the search plan, or `nil` when the parser chose to reply.
    private func plan(_ route: AssistantRoute) -> LocalSearchPlan? {
        if case let .search(plan) = route { return plan }
        return nil
    }

    @Test("Output without the routing marker is returned as conversation")
    func treatsPlainOutputAsReply() {
        let route = parser.parse(modelOutput: "Swift is a language.", originalQuestion: "what is swift")
        #expect(reply(route) == "Swift is a language.")
    }

    @Test("A folder request recovers when the model returns only an acknowledgement")
    internal func recoversFolderSearchWithoutMarker() {
        let route = parser.parse(
            modelOutput: "Matching results are shown below.",
            originalQuestion: "school folders"
        )
        let parsed = plan(route)
        #expect(parsed?.text == "school")
        #expect(parsed?.filter.kinds == [.folder])
    }

    @Test("A local file possession request recovers without a routing marker")
    internal func recoversFileSearchWithoutMarker() {
        let route = parser.parse(
            modelOutput: "Matching results are shown below.",
            originalQuestion: "I want to know if I have any school files"
        )
        let parsed = plan(route)
        #expect(parsed?.text == "school")
        #expect(parsed?.filter.kinds.isEmpty == true)
    }

    @Test("Surrounding whitespace is trimmed from a conversational reply")
    func trimsReplyWhitespace() {
        let route = parser.parse(modelOutput: "  Hello.  \n", originalQuestion: "hi")
        #expect(reply(route) == "Hello.")
    }

    @Test("A well-formed routing payload becomes a search plan")
    func parsesRoutingPayload() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"quarterly budget","kinds":["pdf"]}"#
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "find the quarterly budget pdf"))
        #expect(parsed?.text == "quarterly budget")
        #expect(parsed?.filter.kinds == Set([IndexedItemKind.pdf]))
    }

    @Test("A payload without kinds searches every file type")
    func parsesPayloadWithoutKinds() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"tax return"}"#
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "find my tax return"))
        #expect(parsed?.text == "tax return")
        #expect(parsed?.filter.kinds.isEmpty == true)
    }

    @Test("Model-invented kinds are ignored instead of becoming hard filters")
    func ignoresModelInventedKinds() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"notes","kinds":["pdf","hologram"]}"#
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "find my notes"))
        #expect(parsed?.filter.kinds.isEmpty == true)
    }

    @Test("A type stated by the user remains a hard filter when the model omits it")
    func preservesExplicitUserKind() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"quarterly budget","kinds":[]}"#
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "find quarterly budget PDFs"))
        #expect(parsed?.filter.kinds == [.pdf])
    }

    @Test("An embedded image request reports the current visual-index limitation")
    func rejectsUnsupportedEmbeddedImageConstraint() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"people","kinds":["pdf"]}"#
        let route = parser.parse(
            modelOutput: output,
            originalQuestion: "find files with images of people inside"
        )
        #expect(reply(route) == RetrievalStrings.visualContentUnavailable)
    }

    @Test("An ordinary visual knowledge question remains conversation")
    func preservesVisualKnowledgeConversation() {
        let output = "A portrait is an image representing a person."
        let route = parser.parse(
            modelOutput: output,
            originalQuestion: "what is an image of a person"
        )
        #expect(reply(route) == output)
    }

    @Test("A malformed payload still searches, using the user's own words")
    func fallsBackWhenPayloadIsNotJSON() {
        let output = "[[SEARCH_LOCAL_FILES]]not json at all"
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "find the roof invoice"))
        #expect(parsed != nil)
        #expect(parsed?.text.contains("roof") == true)
    }

    @Test("The fallback plan recovers file types from the user's question")
    func inferssKindsInFallbackPlan() {
        let output = "[[SEARCH_LOCAL_FILES]]{broken"
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "find the roof invoice pdf"))
        #expect(parsed?.filter.kinds.contains(.pdf) == true)
    }

    @Test("A bare singular file-type request asks for clarification instead of guessing")
    func asksForClarificationOnBareRequest() {
        let route = parser.parse(modelOutput: "[[SEARCH_LOCAL_FILES]]{\"query\":\"pdf\"}", originalQuestion: "open the pdf")
        #expect(reply(route) == RetrievalStrings.ambiguousFileRequest)
    }

    @Test("A request naming a topic is specific enough to search")
    func searchesWhenRequestCarriesDetail() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"insurance"}"#
        let route = parser.parse(modelOutput: output, originalQuestion: "open the insurance pdf")
        #expect(plan(route) != nil)
    }

    @Test("A list request is specific enough and is not treated as ambiguous")
    func searchesForListRequests() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"","kinds":["pdf"]}"#
        let route = parser.parse(modelOutput: output, originalQuestion: "show all pdf")
        #expect(plan(route) != nil)
    }

    @Test("A broad plural type request becomes a type-only search")
    func normalizesBroadPluralTypeRequest() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"any PDFs","kinds":["pdf"]}"#
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "Any PDFs?"))
        #expect(parsed?.text.isEmpty == true)
        #expect(parsed?.filter.kinds == [.pdf])
    }

    @Test("Conversational list wording does not become semantic evidence")
    func normalizesConversationalTypeRequest() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"do you have PDFs","kinds":["pdf"]}"#
        let parsed = plan(parser.parse(modelOutput: output, originalQuestion: "Do I have any PDFs?"))
        #expect(parsed?.text.isEmpty == true)
        #expect(parsed?.filter.kinds == [.pdf])
    }

    @Test("A requested file type keeps its meaningful topic")
    func preservesTopicInTypedRequest() {
        let output = #"[[SEARCH_LOCAL_FILES]]{"query":"PDFs","kinds":["pdf"]}"#
        let parsed = plan(
            parser.parse(
                modelOutput: output,
                originalQuestion: "Show PDFs about insurance"
            )
        )
        #expect(parsed?.text == "insurance")
        #expect(parsed?.filter.kinds == [.pdf])
    }

    @Test("A malformed type-only route still produces a broad listing")
    func normalizesMalformedTypeOnlyRoute() {
        let parsed = plan(
            parser.parse(
                modelOutput: "[[SEARCH_LOCAL_FILES]]{broken",
                originalQuestion: "List all available PDFs"
            )
        )
        #expect(parsed?.text.isEmpty == true)
        #expect(parsed?.filter.kinds == [.pdf])
    }

    @Test("A definition question is answered rather than treated as a file request")
    func answersDefinitionQuestions() {
        let route = parser.parse(modelOutput: "A PDF is a document format.", originalQuestion: "what is a pdf")
        #expect(reply(route) == "A PDF is a document format.")
    }

    @Test("A single bracketed marker routes to search instead of being shown as an answer")
    func acceptsSingleBracketMarker() {
        let output = #"[SEARCH_LOCAL_FILES]{"query":"","kinds":["pdf"]}"#
        let route = parser.parse(modelOutput: output, originalQuestion: "show all pdf")
        #expect(plan(route)?.filter.kinds == [.pdf])
    }

    @Test("A marker on its own line routes to search")
    func acceptsMarkerOnSeparateLine() {
        let output = "[SEARCH_LOCAL_FILES]\n{\"query\":\"budget\",\"kinds\":[]}"
        let route = parser.parse(modelOutput: output, originalQuestion: "find the budget")
        #expect(plan(route)?.text == "budget")
    }

    @Test("An unbracketed marker routes to search")
    func acceptsUnbracketedMarker() {
        let output = #"SEARCH_LOCAL_FILES {"query":"notes","kinds":[]}"#
        let route = parser.parse(modelOutput: output, originalQuestion: "find my notes")
        #expect(plan(route)?.text == "notes")
    }

    @Test("Ordinary prose containing braces is answered, not treated as a file request")
    func answersProseContainingBraces() {
        let output = "JSON looks like {\"key\": \"value\"} in most languages."
        let route = parser.parse(modelOutput: output, originalQuestion: "what is json")
        #expect(reply(route) == output)
    }

    @Test("A marker the reader would see raw never becomes the visible answer")
    func neverShowsRawMarkerAsReply() {
        for output in [
            #"[SEARCH_LOCAL_FILES]{"query":"","kinds":["pdf"]}"#,
            #"[[SEARCH_LOCAL_FILES]]{"query":"","kinds":["pdf"]}"#,
            "[SEARCH_LOCAL_FILES]not json at all"
        ] {
            let route = parser.parse(modelOutput: output, originalQuestion: "show all pdf")
            #expect(plan(route) != nil, "\(output) should route to search")
            #expect(reply(route) == nil)
        }
    }
}
