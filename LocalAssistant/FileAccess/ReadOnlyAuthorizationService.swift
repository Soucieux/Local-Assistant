import AppKit
import Foundation

/// Creates and resolves app-scoped, read-only bookmarks selected by the user.
@MainActor
internal final class ReadOnlyAuthorizationService {
    /// Presents a directory picker and returns a persistable read-only root.
    /// - Returns: Newly authorized root, or `nil` when the user cancels.
    /// - Throws: A local permission error when bookmark creation fails.
    internal func authorizeNewRoot() async throws -> AuthorizedRoot? {
        let panel = NSOpenPanel()
        panel.title = UIStrings.folderPickerTitle
        panel.message = UIStrings.folderPickerMessage
        panel.prompt = UIStrings.folderPickerPrompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        let response = await withCheckedContinuation { continuation in
            panel.begin { result in
                continuation.resume(returning: result)
            }
        }
        guard response == .OK, let url = panel.url else { return nil }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return AuthorizedRoot(
                id: StableIdentifier.uuid(for: url.standardizedFileURL.path),
                displayName: url.lastPathComponent,
                lastKnownPath: url.path,
                bookmarkData: bookmark,
                addedAt: Date(),
                lastIndexedAt: nil,
                isAvailable: true
            )
        } catch {
            throw LocalAssistantError.permission(error.localizedDescription)
        }
    }

    /// Resolves a bookmark and starts a bounded read session.
    /// - Parameter root: Stored authorization record.
    /// - Returns: A lifetime token containing the resolved directory URL.
    /// - Throws: A local permission error when the bookmark cannot be resolved.
    internal func beginAccess(to root: AuthorizedRoot) throws -> SecurityScopedAccess {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: root.bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard isStale == false else {
                throw LocalAssistantError.permission(root.lastKnownPath)
            }
            return try SecurityScopedAccess(url: url)
        } catch let error as LocalAssistantError {
            throw error
        } catch {
            throw LocalAssistantError.permission(error.localizedDescription)
        }
    }
}
