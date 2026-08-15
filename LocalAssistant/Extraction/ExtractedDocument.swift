import Foundation

/// A source-aligned text segment produced entirely on device.
struct ExtractedSegment: Hashable, Sendable {
    let text: String
    let pageNumber: Int?
    let sectionName: String?
}

/// Local extraction result for one readable file.
struct ExtractedDocument: Sendable {
    let segments: [ExtractedSegment]
}
