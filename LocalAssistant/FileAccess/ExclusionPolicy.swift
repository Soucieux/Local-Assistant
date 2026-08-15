import Foundation

/// Applies conservative default exclusions before any content is opened.
struct ExclusionPolicy: Sendable {
    /// Returns a reason when a file or directory must not be indexed.
    /// - Parameters:
    ///   - url: Candidate path.
    ///   - values: Already-fetched resource metadata.
    /// - Returns: Exclusion reason, or `nil` when scanning may continue.
    internal func reason(for url: URL, values: URLResourceValues) -> ExclusionReason? {
        if values.isSymbolicLink == true { return .symbolicLink }
        if values.isHidden == true || url.lastPathComponent.hasPrefix(FileConstants.hiddenNamePrefix) { return .hidden }
        if FileConstants.excludedNames.contains(url.lastPathComponent) { return .systemDirectory }
        if FileConstants.credentialExtensions.contains(url.pathExtension.lowercased()) {
            return .credentialMaterial
        }
        if values.isReadable == false { return .unreadable }
        return nil
    }
}
