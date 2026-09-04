import Foundation

/// Keeps one security-scoped read session alive without granting write access.
final class SecurityScopedAccess: @unchecked Sendable {
    let url: URL
    private let didStart: Bool

    /// Starts access to a resolved read-only security-scoped URL.
    /// - Parameter url: URL resolved from an app-scoped bookmark.
    /// - Throws: `LocalAssistantError.permission` when the scoped resource cannot be opened.
    internal init(url: URL) throws {
        self.url = url
        didStart = url.startAccessingSecurityScopedResource()
        guard didStart else {
            throw LocalAssistantError.permission(url.path)
        }
    }

    deinit {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
