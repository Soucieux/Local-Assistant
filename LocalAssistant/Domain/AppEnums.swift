import Foundation

/// Main-window destinations that preserve one focused application surface.
internal enum AppScreen: Hashable {
    case assistant
    case history
    case activity
    case settings
    case openClawSetup
}

/// Broad categories used to present and filter indexed items.
internal enum IndexedItemKind: String, Codable, CaseIterable, Sendable {
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
internal enum ConfidenceLevel: Int, Codable, Comparable, CaseIterable, Sendable {
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
internal enum OfflineStatus: String, Codable, Sendable {
    case checking
    case ready
    case missingModels
    case integrityFailure
}

/// User-relevant capabilities supplied by the installed local models.
internal enum LocalModelCapabilityKind: String, CaseIterable, Sendable {
    case chat
    case fileSearch
    case voiceInput
}

/// Readiness shown for one local assistant capability.
internal enum LocalModelCapabilityState: String, Sendable {
    case checking
    case ready
    case missing
    case integrityFailure
}

/// User-selected interaction used to start and finish local speech recognition.
internal enum VoiceInputMode: String, CaseIterable, Sendable {
    case clickToSpeak
    case holdSpace
}

/// Author of a conversation message.
internal enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

/// Current state of the local indexing pipeline.
internal enum IndexingState: String, Codable, Sendable {
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
internal enum IndexingTrigger: String, Codable, CaseIterable, Sendable {
    case automatic
    case manual
    case startup
}

/// Final lifecycle state retained for one indexing run.
internal enum IndexingRunState: String, Codable, CaseIterable, Sendable {
    case running
    case completed
    case stopped
    case failed
}

/// File-level state recorded for an indexing run.
internal enum IndexingItemState: String, Codable, CaseIterable, Sendable {
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
internal enum IndexActivityEventKind: String, Codable, Sendable {
    case changesDetected
    case updateScheduled
    case monitoringPaused
    case monitoringResumed
    case indexingStopped
    case indexingFailed
    case monitoringUnavailable
}
