import Foundation

/// Raw full-text hit before score fusion.
internal struct KeywordHit: Hashable, Sendable {
    internal let chunkID: UUID
    internal let itemID: UUID
    internal let text: String
    internal let rank: Double
}

/// Raw vector hit before score fusion.
internal struct SemanticHit: Hashable, Sendable {
    internal let chunkID: UUID
    internal let itemID: UUID
    internal let text: String
    internal let distance: Double
}
