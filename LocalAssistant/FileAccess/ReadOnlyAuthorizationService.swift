import AppKit
import Foundation

/// Creates and resolves app-scoped, read-only bookmarks selected by the user.
@MainActor
internal final class ReadOnlyAuthorizationService {
    /// Presents a directory picker and returns a persistable read-only root.
    /// - Returns: Newly authorized root, or `nil` when the user cancels.
    /// - Throws: A local permission error when bookmark creation fails.
    internal func authorizeNewRoot() async throws -> AuthorizedRoot? {
        guard let url = await chooseDirectory(
            title: UIStrings.folderPickerTitle,
            message: UIStrings.folderPickerMessage,
            prompt: UIStrings.folderPickerPrompt
        ) else { return nil }
        return AuthorizedRoot(
            id: StableIdentifier.uuid(for: url.standardizedFileURL.path),
            displayName: url.lastPathComponent,
            lastKnownPath: url.path,
            bookmarkData: try readOnlyBookmark(for: url),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
    }

    /// Presents a directory picker and returns the folder Local Assistant reads its models from.
    /// - Returns: The chosen model folder, or `nil` when the user cancels.
    /// - Throws: A local permission error when bookmark creation fails.
    internal func authorizeModelLibrary() async throws -> ModelLibrarySelection? {
        guard let url = await chooseDirectory(
            title: UIStrings.modelLibraryPickerTitle,
            message: UIStrings.modelLibraryPickerMessage,
            prompt: UIStrings.modelLibraryPickerPrompt
        ) else { return nil }
        return ModelLibrarySelection(bookmarkData: try readOnlyBookmark(for: url), path: url.path)
    }

    /// Presents a picker for one existing directory.
    /// - Parameters:
    ///   - title: Panel title.
    ///   - message: Sentence explaining what the choice grants.
    ///   - prompt: Label of the confirming button.
    /// - Returns: The chosen directory, or `nil` when the user cancels.
    private func chooseDirectory(title: String, message: String, prompt: String) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
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
        guard response == .OK else { return nil }
        return panel.url
    }

    /// Creates a persistable bookmark that grants read-only access to a chosen directory.
    /// - Parameter url: Directory the user chose in a picker.
    /// - Returns: App-scoped, read-only bookmark data.
    /// - Throws: A local permission error when bookmark creation fails.
    private func readOnlyBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
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
