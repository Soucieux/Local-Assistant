import Foundation

/// Applies the private lifecycle rules for temporary voice recordings.
enum VoiceRecordingFiles {
    /// Creates or repairs the owner-only directory used for recordings.
    /// - Parameter directory: Private voice directory URL.
    /// - Throws: A local file-system error when the directory cannot be protected.
    internal static func prepareDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions],
            ofItemAtPath: directory.path
        )
    }

    /// Applies owner-only permissions to a newly created recording.
    /// - Parameter url: Private temporary recording URL.
    /// - Throws: A local file-system error when permissions cannot be applied.
    internal static func protectRecording(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: AppConstants.Storage.ownerOnlyFilePermissions],
            ofItemAtPath: url.path
        )
    }

    /// Removes abandoned recordings without touching unrelated private files.
    /// - Parameter directory: Owner-only voice directory to inspect.
    /// - Throws: A local file-system error when stale recordings cannot be enumerated or removed.
    internal static func removeStaleRecordings(in directory: URL) throws {
        let candidates = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        for candidate in candidates
            where candidate.lastPathComponent.hasPrefix(VoiceConstants.recordingPrefix)
                && candidate.pathExtension == VoiceConstants.recordingExtension {
            try FileManager.default.removeItem(at: candidate)
        }
    }

    /// Removes one temporary recording if it currently exists.
    /// - Parameter url: Optional recording URL owned by the voice service.
    internal static func removeRecordingIfPresent(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
