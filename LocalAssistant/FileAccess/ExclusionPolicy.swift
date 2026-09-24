import Darwin
import Foundation

/// Applies conservative default exclusions before any content is opened.
internal struct ExclusionPolicy: Sendable {
    /// Absolute system directories, resolved once for the life of the process.
    private static let systemDirectoryPaths: Set<String> = makeSystemDirectoryPaths()

    /// Returns a reason when a file or directory must not be indexed.
    /// - Parameters:
    ///   - url: Candidate path.
    ///   - values: Already-fetched resource metadata.
    /// - Returns: Exclusion reason, or `nil` when scanning may continue.
    internal func reason(for url: URL, values: URLResourceValues) -> ExclusionReason? {
        if values.isSymbolicLink == true { return .symbolicLink }
        if values.isHidden == true || url.lastPathComponent.hasPrefix(FileConstants.hiddenNamePrefix) { return .hidden }
        if FileConstants.excludedNames.contains(url.lastPathComponent) { return .systemDirectory }
        if Self.systemDirectoryPaths.contains(url.standardizedFileURL.path) { return .systemDirectory }
        if FileConstants.credentialExtensions.contains(url.pathExtension.lowercased()) {
            return .credentialMaterial
        }
        if values.isReadable == false { return .unreadable }
        return nil
    }

    /// Builds the absolute directories excluded whatever authorized root reaches them.
    /// - Returns: Standardized absolute paths that must never be indexed.
    private static func makeSystemDirectoryPaths() -> Set<String> {
        var paths = FileConstants.absoluteSystemDirectories
        guard let home = realHomeDirectoryPath() else { return paths }
        for directory in FileConstants.homeRelativeSystemDirectories {
            paths.insert(home + FileConstants.pathSeparator + directory)
        }
        return paths
    }

    /// Reads the real user home, which differs from the sandboxed container home.
    /// - Returns: Absolute home path, or `nil` when the user record is unavailable.
    private static func realHomeDirectoryPath() -> String? {
        guard let record = getpwuid(getuid()), let directory = record.pointee.pw_dir else {
            return nil
        }
        return String(cString: directory)
    }
}
