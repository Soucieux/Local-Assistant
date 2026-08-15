import Foundation

/// Main-window destinations that preserve one focused application surface.
enum AppScreen {
    case assistant
    case activity
    case settings
}

/// Broad categories used to present and filter indexed items.
enum IndexedItemKind: String, Codable, CaseIterable, Sendable {
    case folder
    case document
    case spreadsheet
    case presentation
    case pdf
    case image
    case code
    case text
    case archive
    case other
}

/// Calibrated confidence shown with a grounded result.
enum ConfidenceLevel: Int, Codable, Comparable, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    /// Orders confidence values from low to high.
    /// - Parameters:
    ///   - lhs: Left confidence value.
    ///   - rhs: Right confidence value.
    /// - Returns: `true` when the left value is lower.
    internal static func < (lhs: ConfidenceLevel, rhs: ConfidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Current readiness of the deliberately offline runtime.
enum OfflineStatus: String, Codable, Sendable {
    case checking
    case ready
    case missingModels
    case integrityFailure
}

/// User-relevant capabilities supplied by the installed local models.
enum LocalModelCapabilityKind: String, CaseIterable, Sendable {
    case chat
    case fileSearch
    case voiceInput
}

/// Readiness shown for one local assistant capability.
enum LocalModelCapabilityState: String, Sendable {
    case checking
    case ready
    case missing
    case integrityFailure
}

/// Author of a conversation message.
enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Current state of the local indexing pipeline.
enum IndexingState: String, Codable, Sendable {
    case idle
    case scanning
    case extracting
    case embedding
    case saving
    case stopping
    case stopped
    case failed
}

/// Source that requested one incremental indexing run.
enum IndexingTrigger: String, Codable, CaseIterable, Sendable {
    case automatic
    case manual
    case startup
}

/// Final lifecycle state retained for one indexing run.
enum IndexingRunState: String, Codable, CaseIterable, Sendable {
    case running
    case completed
    case stopped
    case failed
}

/// File-level state recorded for an indexing run.
enum IndexingItemState: String, Codable, CaseIterable, Sendable {
    case newWaiting
    case newIndexing
    case newIndexed
    case modifiedWaiting
    case modifiedUpdating
    case modifiedUpdated
    case unchanged
    case missingPendingRemoval
    case removedFromIndex
    case skipped
}

/// Durable monitoring and indexing events shown in the activity timeline.
enum IndexActivityEventKind: String, Codable, Sendable {
    case changesDetected
    case updateScheduled
    case monitoringPaused
    case monitoringResumed
    case indexingStopped
    case indexingFailed
    case monitoringUnavailable
}
