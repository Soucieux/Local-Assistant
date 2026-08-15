import Foundation

/// Raw full-text hit before score fusion.
struct KeywordHit: Hashable, Sendable {
    let chunkID: UUID
    let itemID: UUID
    let text: String
    let rank: Double
}

/// Raw vector hit before score fusion.
struct SemanticHit: Hashable, Sendable {
    let chunkID: UUID
    let itemID: UUID
    let text: String
    let distance: Double
}
