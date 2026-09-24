import CoreServices
import Foundation

/// Bridges one FSEvents stream callback to a root-specific Swift closure.
private final class FolderMonitorContext: @unchecked Sendable {
    internal let rootID: UUID
    internal let onChange: @Sendable (UUID) -> Void

    /// Creates a callback context retained for the native stream lifetime.
    /// - Parameters:
    ///   - rootID: Authorized folder identifier forwarded by the callback.
    ///   - onChange: Sendable closure invoked when native events arrive.
    internal init(rootID: UUID, onChange: @escaping @Sendable (UUID) -> Void) {
        self.rootID = rootID
        self.onChange = onChange
    }
}

/// Receives recursive macOS folder-change notifications without reading file content.
@MainActor
internal final class FolderMonitorService {
    private struct Entry {
        internal let stream: FSEventStreamRef
        internal let access: SecurityScopedAccess
        internal let context: FolderMonitorContext
    }

    private var entries: [UUID: Entry] = [:]
    private let eventQueue = DispatchQueue(
        label: AppConstants.Identity.folderMonitorQueueLabel,
        qos: .utility
    )

    /// Starts recursive monitoring for one authorized root while retaining read-only access.
    /// - Parameters:
    ///   - root: Authorized folder to observe recursively.
    ///   - access: Long-lived read-only security scope retained by the stream.
    ///   - onChange: Callback receiving the affected root identifier.
    /// - Throws: A local indexing error when the native stream cannot start.
    internal func start(
        root: AuthorizedRoot,
        access: SecurityScopedAccess,
        onChange: @escaping @Sendable (UUID) -> Void
    ) throws {
        stop(rootID: root.id)
        let callbackContext = FolderMonitorContext(rootID: root.id, onChange: onChange)
        var streamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(callbackContext).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagWatchRoot
                | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            nil,
            folderMonitorCallback,
            &streamContext,
            [access.url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            AppConstants.Indexing.monitorCoalescingSeconds,
            flags
        ) else {
            throw LocalAssistantError.indexing(root.lastKnownPath)
        }
        FSEventStreamSetDispatchQueue(stream, eventQueue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            throw LocalAssistantError.indexing(root.lastKnownPath)
        }
        entries[root.id] = Entry(
            stream: stream,
            access: access,
            context: callbackContext
        )
    }

    /// Stops monitoring one root and releases its read-only security scope.
    /// - Parameter rootID: Identifier of the monitored root to stop.
    internal func stop(rootID: UUID) {
        guard let entry = entries.removeValue(forKey: rootID) else { return }
        FSEventStreamStop(entry.stream)
        FSEventStreamInvalidate(entry.stream)
        FSEventStreamRelease(entry.stream)
        withExtendedLifetime(entry) {
            eventQueue.sync {}
        }
    }

    /// Stops every stream when the app terminates.
    internal func stopAll() {
        for rootID in Array(entries.keys) {
            stop(rootID: rootID)
        }
    }
}

/// Minimal C-compatible FSEvents callback that forwards only the affected root identity.
private let folderMonitorCallback: FSEventStreamCallback = {
    _, info, eventCount, _, _, _ in
    guard eventCount > 0, let info else { return }
    let context = Unmanaged<FolderMonitorContext>.fromOpaque(info).takeUnretainedValue()
    context.onChange(context.rootID)
}
