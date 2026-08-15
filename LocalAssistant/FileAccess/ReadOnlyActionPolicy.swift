import Foundation

/// Resolves explicit file actions without allowing a stale path to escape its root.
enum ReadOnlyActionPolicy {
    /// Resolves current symlink targets and validates the result against an authorized root.
    /// - Parameters:
    ///   - itemURL: Previously indexed file or folder URL.
    ///   - rootURL: Active bookmark-resolved authorized root URL.
    /// - Returns: Existing current target contained by the authorized root.
    /// - Throws: A safe unavailable error when the target is missing or outside the root.
    internal static func resolvedActionURL(
        for itemURL: URL,
        inside rootURL: URL
    ) throws -> URL {
        let resolvedRootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedItemURL = itemURL.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = resolvedRootURL.path
        let itemPath = resolvedItemURL.path
        let isInsideRoot = itemPath == rootPath
            || itemPath.hasPrefix(rootPath + FileConstants.pathSeparator)
        guard isInsideRoot,
              FileManager.default.fileExists(atPath: itemPath) else {
            throw LocalAssistantError.fileUnavailable
        }
        return resolvedItemURL
    }
}
