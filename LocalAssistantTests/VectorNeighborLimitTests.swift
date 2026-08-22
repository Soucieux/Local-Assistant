import Testing

@testable import LocalAssistant

/// Regression coverage for sqlite-vec nearest-neighbor request limits.
struct VectorNeighborLimitTests {
    @Test("caps an expanded neighbor request at the sqlite-vec ceiling")
    internal func capsExpandedNeighborRequest() {
        #expect(DatabaseConstants.boundedVectorNeighborCount(5_120) == 4_096)
        #expect(
            DatabaseConstants.nextVectorNeighborCount(current: 2_560, available: 5_859)
                == 4_096
        )
        #expect(DatabaseConstants.boundedVectorNeighborCount(40) == 40)
        #expect(DatabaseConstants.boundedVectorNeighborCount(-1) == 0)
    }
}
