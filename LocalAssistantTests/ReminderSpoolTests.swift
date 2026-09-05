import Foundation
import Testing

@testable import LocalAssistant

/// The app-side connector transport is file-only and task-identity bound.
struct ReminderSpoolTests {
    @Test("An absent connector heartbeat is reported as not detected")
    internal func reportsMissingHeartbeat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let spool = ReminderSpoolService(rootURL: root)

        let health = await spool.connectorHealth()

        #expect(health == .notDetected)
    }

    @Test("A live connector without a successful request is not yet verified")
    internal func reportsRunningUnverifiedHeartbeat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try writeStatus(
            to: root,
            lastSeenAt: now,
            lastSuccessAt: nil,
            lastError: nil,
            running: true
        )
        let spool = ReminderSpoolService(rootURL: root)

        let health = await spool.connectorHealth(now: now)

        #expect(health == .runningUnverified)
    }

    @Test("A completed one-shot connector with a successful request is ready")
    internal func reportsReadyHeartbeat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try writeStatus(
            to: root,
            lastSeenAt: now,
            lastSuccessAt: now,
            lastError: nil,
            running: false
        )
        let spool = ReminderSpoolService(rootURL: root)

        let health = await spool.connectorHealth(now: now)

        #expect(health == .ready)
    }

    @Test("A heartbeat from an older runtime requires a Connector update")
    internal func reportsOutdatedRuntimeHeartbeat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try writeStatus(
            to: root,
            lastSeenAt: now,
            lastSuccessAt: now,
            lastError: nil,
            running: false,
            runtimeContractVersion: nil
        )
        let spool = ReminderSpoolService(rootURL: root)

        let health = await spool.connectorHealth(now: now)

        #expect(health == .updateRequired)
    }

    @Test("A completed success remains ready while active and completed failures differ")
    internal func reportsUnhealthyHeartbeats() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let earlierSeenAt = now.addingTimeInterval(-86_400)
        let spool = ReminderSpoolService(rootURL: root)
        try writeStatus(
            to: root,
            lastSeenAt: earlierSeenAt,
            lastSuccessAt: earlierSeenAt,
            lastError: nil,
            running: false
        )

        let completedSuccessHealth = await spool.connectorHealth(now: now)
        try writeStatus(
            to: root,
            lastSeenAt: now,
            lastSuccessAt: now,
            lastError: ReminderStrings.connectorTimedOut,
            running: true
        )
        let activeFailureHealth = await spool.connectorHealth(now: now)
        try writeStatus(
            to: root,
            lastSeenAt: now,
            lastSuccessAt: earlierSeenAt,
            lastError: ReminderStrings.connectorTimedOut,
            running: false
        )
        let completedFailureHealth = await spool.connectorHealth(now: now)

        #expect(completedSuccessHealth == .ready)
        #expect(activeFailureHealth == .runningUnreachable)
        #expect(completedFailureHealth == .needsAttention)
    }

    @Test("One atomically published response is returned only to its matching task")
    internal func exchangesMatchingTaskFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let spool = ReminderSpoolService(rootURL: root)
        let taskID = UUID()
        let request = ReminderConnectorRequest(
            schemaVersion: ReminderConstants.Connector.schemaVersion,
            taskId: taskID,
            contextId: nil,
            skill: ReminderConstants.Identity.reminderSkill,
            operation: ReminderConstants.Routing.operationList,
            idempotencyKey: UUID(),
            calendarPolicy: ReminderConstants.Identity.calendarPolicyNever,
            confirmed: false,
            authorization: nil,
            payload: .empty
        )

        async let response = spool.perform(request)
        let filename = taskID.uuidString.lowercased() + ".json"
        let requestURL = root
            .appendingPathComponent(ReminderConstants.Identity.requestDirectory)
            .appendingPathComponent(filename)
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: requestURL.path) { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(FileManager.default.fileExists(atPath: requestURL.path))

        let responseDirectory = root.appendingPathComponent(
            ReminderConstants.Identity.responseDirectory,
            isDirectory: true
        )
        let responseURL = responseDirectory.appendingPathComponent(filename)
        let document: [String: Any] = [
            "schemaVersion": ReminderConstants.Connector.schemaVersion,
            "taskId": taskID.uuidString.lowercased(),
            "status": ReminderConstants.Connector.completedStatus,
            "calendarChanged": false,
            "payload": ["success": true, "data": []]
        ]
        let data = try JSONSerialization.data(withJSONObject: document)
        try data.write(to: responseURL, options: .atomic)

        let completed = try await response
        #expect(completed.taskId == taskID)
        #expect(completed.calendarChanged == false)
        #expect(completed.payload?.data?.isEmpty == true)
        #expect(FileManager.default.fileExists(atPath: responseURL.path) == false)
    }

    @Test("A connector response symbolic link is rejected without reading its target")
    internal func rejectsSymbolicLinkResponse() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let spool = ReminderSpoolService(rootURL: root)
        let taskID = UUID()
        let request = ReminderConnectorRequest(
            schemaVersion: ReminderConstants.Connector.schemaVersion,
            taskId: taskID,
            contextId: nil,
            skill: ReminderConstants.Identity.reminderSkill,
            operation: ReminderConstants.Routing.operationList,
            idempotencyKey: UUID(),
            calendarPolicy: ReminderConstants.Identity.calendarPolicyNever,
            confirmed: false,
            authorization: nil,
            payload: .empty
        )

        async let result = spool.perform(request)
        let filename = taskID.uuidString.lowercased() + ".json"
        let requestURL = root
            .appendingPathComponent(ReminderConstants.Identity.requestDirectory)
            .appendingPathComponent(filename)
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: requestURL.path) { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        let unrelated = root.appendingPathComponent("unrelated.json")
        try Data("{}".utf8).write(to: unrelated)
        let responseURL = root
            .appendingPathComponent(ReminderConstants.Identity.responseDirectory)
            .appendingPathComponent(filename)
        try FileManager.default.createSymbolicLink(
            at: responseURL,
            withDestinationURL: unrelated
        )

        var rejected = false
        do {
            _ = try await result
        } catch {
            rejected = true
        }

        #expect(rejected)
        #expect(try Data(contentsOf: unrelated) == Data("{}".utf8))
    }

    @Test("Schedule publication is owner-only and scheduled snapshots are one-shot")
    internal func exchangesScheduledSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let spool = ReminderSpoolService(rootURL: root)
        try await spool.updateSchedule(enabled: true, intervalMinutes: 240)

        let scheduleURL = root.appendingPathComponent(
            ReminderConstants.Identity.scheduleFilename
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: scheduleURL.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)

        let responses = root.appendingPathComponent(
            ReminderConstants.Identity.responseDirectory,
            isDirectory: true
        )
        let scheduledURL = responses.appendingPathComponent(
            ReminderConstants.Identity.scheduledSnapshotFilename
        )
        let taskID = UUID()
        let document: [String: Any] = [
            "schemaVersion": ReminderConstants.Connector.schemaVersion,
            "taskId": taskID.uuidString.lowercased(),
            "status": ReminderConstants.Connector.completedStatus,
            "calendarChanged": false,
            "payload": ["success": true, "data": []]
        ]
        try JSONSerialization.data(withJSONObject: document).write(
            to: scheduledURL,
            options: .atomic
        )

        let response = try await spool.takeScheduledSnapshot()
        let secondRead = try await spool.takeScheduledSnapshot()

        #expect(response?.taskId == taskID)
        #expect(response?.payload?.data?.isEmpty == true)
        #expect(secondRead == nil)
    }

    /// Writes one connector-owned status document into an isolated test spool.
    /// - Parameters:
    ///   - root: Isolated spool root.
    ///   - lastSeenAt: Heartbeat timestamp.
    ///   - lastSuccessAt: Optional successful request timestamp.
    ///   - lastError: Optional connector failure detail.
    ///   - running: Whether the connector reports an active run loop.
    ///   - runtimeContractVersion: Contract version the status document declares.
    /// - Throws: A local encoding or filesystem error.
    private func writeStatus(
        to root: URL,
        lastSeenAt: Date,
        lastSuccessAt: Date?,
        lastError: String?,
        running: Bool,
        runtimeContractVersion: Int? = ReminderConstants.Connector.runtimeContractVersion
    ) throws {
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let formatter = ISO8601DateFormatter()
        let document = OpenClawConnectorStatusDocument(
            schemaVersion: ReminderConstants.Connector.schemaVersion,
            runtimeContractVersion: runtimeContractVersion,
            running: running,
            lastSeenAt: formatter.string(from: lastSeenAt),
            lastSuccessAt: lastSuccessAt.map(formatter.string(from:)),
            lastError: lastError,
            pid: Int(Int32.max)
        )
        let data = try JSONEncoder().encode(document)
        let statusURL = root.appendingPathComponent(
            ReminderConstants.Identity.statusFilename,
            isDirectory: false
        )
        try data.write(to: statusURL, options: Data.WritingOptions.atomic)
    }
}
