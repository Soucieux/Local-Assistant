import Darwin
import Foundation

/// Exchanges bounded JSON tasks with the optional connector through local files only.
actor ReminderSpoolService {
    private let rootOverride: URL?
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let statusDateFormatter = ISO8601DateFormatter()

    /// Creates the production spool or an isolated spool for focused tests.
    /// - Parameter rootURL: Optional explicit connector root.
    internal init(rootURL: URL? = nil) {
        rootOverride = rootURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    /// Returns the exact directory the separate connector must be configured to use.
    /// - Returns: Absolute local spool URL.
    /// - Throws: A local permission error when the directory cannot be prepared.
    internal func spoolURL() throws -> URL {
        let root = try resolvedRootURL()
        try prepare(root: root)
        return root
    }

    /// Reads and validates the connector heartbeat without following links or opening a network.
    /// - Parameter now: Reference time used to reject stale or future heartbeats.
    /// - Returns: Current connector health derived from the local status document.
    internal func connectorHealth(now: Date = Date()) -> OpenClawConnectorHealth {
        let root: URL
        do {
            root = try resolvedRootURL()
            try prepare(root: root)
        } catch {
            return .needsAttention
        }
        let statusURL = root.appendingPathComponent(
            ReminderConstants.Identity.statusFilename,
            isDirectory: false
        )
        guard FileManager.default.fileExists(atPath: statusURL.path) else {
            return .notDetected
        }
        do {
            let data = try readBoundedRegularFile(
                at: statusURL,
                maximumByteCount: ReminderConstants.Connector.maximumRequestBytes
            )
            let document = try decoder.decode(
                OpenClawConnectorStatusDocument.self,
                from: data
            )
            guard document.schemaVersion == ReminderConstants.Connector.schemaVersion,
                  document.pid > 0,
                  let lastSeenAt = statusDateFormatter.date(from: document.lastSeenAt),
                  (document.lastError?.count ?? 0)
                    <= ReminderConstants.Connector.maximumStatusErrorCharacters else {
                return .needsAttention
            }
            guard document.runtimeContractVersion
                == ReminderConstants.Connector.runtimeContractVersion else {
                return .updateRequired
            }
            let age = now.timeIntervalSince(lastSeenAt)
            guard age >= -ReminderConstants.Connector.maximumFutureClockSkewSeconds else {
                return .needsAttention
            }
            if document.running, document.lastError?.isEmpty == false {
                return .runningUnreachable
            }
            if document.running {
                return .runningUnverified
            }
            if document.lastError?.isEmpty == false {
                return .needsAttention
            }
            guard let lastSuccessAt = document.lastSuccessAt,
                  statusDateFormatter.date(from: lastSuccessAt) != nil else {
                return .needsAttention
            }
            return .ready
        } catch {
            return .needsAttention
        }
    }

    /// Publishes the user's non-secret enablement and interval for launchd catch-up runs.
    /// - Parameters:
    ///   - enabled: Whether scheduled snapshots are allowed.
    ///   - intervalMinutes: One allowlisted multi-hour interval.
    internal func updateSchedule(enabled: Bool, intervalMinutes: Int) throws {
        guard ReminderConstants.Preferences.allowedSyncIntervalMinutes
            .contains(intervalMinutes) else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        let root = try resolvedRootURL()
        try prepare(root: root)
        let target = root.appendingPathComponent(
            ReminderConstants.Identity.scheduleFilename,
            isDirectory: false
        )
        let temporary = root.appendingPathComponent(
            ReminderConstants.Identity.scheduleFilename
                + ReminderConstants.Identity.temporarySuffix,
            isDirectory: false
        )
        let document: [String: Any] = [
            ReminderConstants.ScheduleKey.schemaVersion:
                ReminderConstants.Connector.schemaVersion,
            ReminderConstants.ScheduleKey.enabled: enabled,
            ReminderConstants.ScheduleKey.intervalMinutes: intervalMinutes
        ]
        let data = try JSONSerialization.data(withJSONObject: document)
        do {
            try? FileManager.default.removeItem(at: temporary)
            try data.write(to: temporary, options: .withoutOverwriting)
            try protectFile(temporary)
            guard temporary.path.withCString({ source in
                target.path.withCString { destination in
                    Darwin.rename(source, destination)
                }
            }) == 0 else {
                throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    /// Takes the latest timer-originated snapshot response, if one is waiting.
    /// - Returns: A response published atomically by the one-shot connector.
    internal func takeScheduledSnapshot() throws -> ReminderConnectorResponse? {
        let root = try resolvedRootURL()
        try prepare(root: root)
        let target = responseDirectory(root: root).appendingPathComponent(
            ReminderConstants.Identity.scheduledSnapshotFilename,
            isDirectory: false
        )
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        let data = try readBoundedRegularFile(
            at: target,
            maximumByteCount: ReminderConstants.Connector.maximumResponseBytes
        )
        let response: ReminderConnectorResponse
        do {
            response = try decoder.decode(ReminderConnectorResponse.self, from: data)
        } catch {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        try FileManager.default.removeItem(at: target)
        return response
    }

    /// Publishes one task and waits for its matching bounded response file.
    /// - Parameter request: Typed reminder or OpenClaw task.
    /// - Returns: Response whose task identity matches the request.
    /// - Throws: A local connector error on timeout, unsafe files, or invalid JSON.
    internal func perform(_ request: ReminderConnectorRequest) async throws -> ReminderConnectorResponse {
        let root = try resolvedRootURL()
        try prepare(root: root)
        let filename = request.taskId.uuidString.lowercased()
            + ReminderConstants.Identity.jsonSuffix
        let requests = requestDirectory(root: root)
        let responses = responseDirectory(root: root)
        let target = requests.appendingPathComponent(filename, isDirectory: false)
        let temporary = requests.appendingPathComponent(
            filename + ReminderConstants.Identity.temporarySuffix,
            isDirectory: false
        )
        let responseURL = responses.appendingPathComponent(filename, isDirectory: false)
        let data: Data
        do {
            data = try encoder.encode(request)
        } catch {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        guard data.count <= ReminderConstants.Connector.maximumRequestBytes else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }

        do {
            try data.write(to: temporary, options: .withoutOverwriting)
            try protectFile(temporary)
            try FileManager.default.moveItem(at: temporary, to: target)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw LocalAssistantError.connector(error.localizedDescription)
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(
            by: .seconds(ReminderConstants.Connector.responseTimeoutSeconds)
        )
        while clock.now < deadline {
            if FileManager.default.fileExists(atPath: responseURL.path) {
                defer { try? FileManager.default.removeItem(at: responseURL) }
                let response = try readResponse(at: responseURL)
                guard response.taskId == request.taskId,
                      response.contextId == request.contextId,
                      response.schemaVersion == ReminderConstants.Connector.schemaVersion else {
                    throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
                }
                return response
            }
            try await Task.sleep(
                nanoseconds: ReminderConstants.Connector.responsePollNanoseconds
            )
        }

        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: target)
        }
        throw LocalAssistantError.connector(ReminderStrings.connectorTimedOut)
    }

    /// Decodes one bounded response without following a symbolic link.
    /// - Parameter url: Response file published by the one-shot connector.
    /// - Returns: The decoded typed response.
    /// - Throws: A local connector error when the file is unsafe, oversized, or malformed.
    private func readResponse(at url: URL) throws -> ReminderConnectorResponse {
        let data = try readBoundedRegularFile(
            at: url,
            maximumByteCount: ReminderConstants.Connector.maximumResponseBytes
        )
        do {
            return try decoder.decode(ReminderConnectorResponse.self, from: data)
        } catch {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
    }

    /// Reads one regular file after enforcing its configured size ceiling.
    /// - Parameters:
    ///   - url: File opened without following a symbolic link.
    ///   - maximumByteCount: Hard ceiling applied to the file and to the bytes read.
    /// - Returns: File contents within the ceiling.
    /// - Throws: A local connector error when the path is not a bounded regular file.
    private func readBoundedRegularFile(at url: URL, maximumByteCount: Int) throws -> Data {
        let descriptor = Darwin.open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        do {
            var metadata = stat()
            guard Darwin.fstat(descriptor, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFREG,
                  metadata.st_size >= 0,
                  metadata.st_size <= off_t(maximumByteCount) else {
                throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
            }
            var data = Data()
            while data.count <= maximumByteCount {
                let remaining = maximumByteCount + 1 - data.count
                guard let chunk = try handle.read(
                    upToCount: min(ReminderConstants.Connector.readChunkBytes, remaining)
                ), chunk.isEmpty == false else {
                    break
                }
                data.append(chunk)
            }
            guard data.count <= maximumByteCount else {
                throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
            }
            return data
        } catch let error as LocalAssistantError {
            throw error
        } catch {
            throw LocalAssistantError.connector(error.localizedDescription)
        }
    }

    /// Creates and protects the exact spool tree shared with the connector.
    /// - Parameter root: Resolved connector spool root.
    /// - Throws: A local permission error when a directory cannot be created or protected.
    private func prepare(root: URL) throws {
        let directories = [
            root,
            requestDirectory(root: root),
            processingDirectory(root: root),
            responseDirectory(root: root)
        ]
        do {
            for directory in directories {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [
                        .posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions
                    ]
                )
                try protectDirectory(directory)
            }
        } catch {
            throw LocalAssistantError.permission(error.localizedDescription)
        }
    }

    /// Applies owner-only permissions to one request file before publication.
    /// - Parameter url: Request file staged inside the spool.
    /// - Throws: A local connector error when the path is not an ownable regular file.
    private func protectFile(_ url: URL) throws {
        let descriptor = Darwin.open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        defer { Darwin.close(descriptor) }
        var metadata = stat()
        guard Darwin.fstat(descriptor, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              Darwin.fchmod(
                descriptor,
                mode_t(AppConstants.Storage.ownerOnlyFilePermissions)
              ) == 0 else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
    }

    /// Verifies and protects one shared directory without following a symlink.
    /// - Parameter url: Directory inside the shared spool tree.
    /// - Throws: A local connector error when the path is not an ownable directory.
    private func protectDirectory(_ url: URL) throws {
        let descriptor = Darwin.open(
            url.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        defer { Darwin.close(descriptor) }
        var metadata = stat()
        guard Darwin.fstat(descriptor, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              Darwin.fchmod(
                descriptor,
                mode_t(AppConstants.Storage.ownerOnlyDirectoryPermissions)
              ) == 0 else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
    }

    /// Resolves the production connector root unless a test supplied one.
    /// - Returns: Absolute connector spool root.
    /// - Throws: A local directory-resolution error for the production path.
    private func resolvedRootURL() throws -> URL {
        if let rootOverride { return rootOverride }
        return try AppDirectories.connectorDirectory()
    }

    /// Builds the request queue URL beneath one resolved root.
    /// - Parameter root: Resolved connector spool root.
    /// - Returns: Directory the app writes task files into.
    private func requestDirectory(root: URL) -> URL {
        root.appendingPathComponent(
            ReminderConstants.Identity.requestDirectory,
            isDirectory: true
        )
    }

    /// Builds the processing queue URL beneath one resolved root.
    /// - Parameter root: Resolved connector spool root.
    /// - Returns: Directory the connector claims task files into.
    private func processingDirectory(root: URL) -> URL {
        root.appendingPathComponent(
            ReminderConstants.Identity.processingDirectory,
            isDirectory: true
        )
    }

    /// Builds the response queue URL beneath one resolved root.
    /// - Parameter root: Resolved connector spool root.
    /// - Returns: Directory the connector publishes responses into.
    private func responseDirectory(root: URL) -> URL {
        root.appendingPathComponent(
            ReminderConstants.Identity.responseDirectory,
            isDirectory: true
        )
    }
}
