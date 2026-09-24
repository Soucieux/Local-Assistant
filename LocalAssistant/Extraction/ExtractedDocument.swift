import Foundation

/// A source-aligned text segment produced entirely on device.
internal struct ExtractedSegment: Hashable, Sendable {
    internal let text: String
    internal let pageNumber: Int?
    internal let sectionName: String?
}

/// Local extraction result for one readable file.
internal struct ExtractedDocument: Sendable {
    internal let segments: [ExtractedSegment]
}
