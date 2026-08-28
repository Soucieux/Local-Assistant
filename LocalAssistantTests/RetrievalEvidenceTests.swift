import Testing

@testable import LocalAssistant

/// Retrieval must never present a type constraint as evidence for a content description.
struct RetrievalEvidenceTests {
    @Test("File type and recency alone do not satisfy a content query")
    internal func rejectsTypeOnlyContentEvidence() {
        let score = ScoreBreakdown(
            exactName: 0,
            path: 0,
            keyword: 0,
            semantic: 0,
            fileType: 1,
            recency: 1,
            reciprocalRank: 1,
            total: 6
        )
        #expect(score.hasQueryEvidence == false)
    }

    @Test("A semantic passage satisfies the content-evidence requirement")
    internal func acceptsSemanticContentEvidence() {
        let score = ScoreBreakdown(
            exactName: 0,
            path: 0,
            keyword: 0,
            semantic: 0.8,
            fileType: 1,
            recency: 0,
            reciprocalRank: 0,
            total: 6.4
        )
        #expect(score.hasQueryEvidence == true)
    }

    @Test("Semantic explanations quote the passage and calibrate uncertainty")
    internal func explainsSemanticEvidence() {
        let explanation = RetrievalStrings.semanticEvidence(
            "A chart compares quarterly revenue across regions.",
            isUncertain: true
        )
        #expect(explanation.contains("Possible semantic relation"))
        #expect(explanation.contains("quarterly revenue"))
    }

    @Test("Folder scope explanations identify the folder that qualified the result")
    internal func explainsFolderScopeEvidence() {
        let explanation = RetrievalStrings.folderScopeEvidence(
            FolderIndexTestConstants.schoolName
        )
        #expect(explanation.contains(FolderIndexTestConstants.schoolName))
    }
}
