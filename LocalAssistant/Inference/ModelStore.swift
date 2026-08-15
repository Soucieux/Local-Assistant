import Foundation

/// Readiness and installed storage for one user-visible assistant capability.
struct LocalModelCapabilityStatus: Identifiable, Sendable {
    var id: LocalModelCapabilityKind { kind }
    let kind: LocalModelCapabilityKind
    let state: LocalModelCapabilityState
    let byteCount: Int64
}

/// Verified paths and readiness for all locally installed model assets.
struct LocalModelStatus: Sendable {
    let state: OfflineStatus
    let chatURL: URL?
    let embeddingURL: URL?
    let speechURL: URL?
    let capabilities: [LocalModelCapabilityStatus]
    let totalByteCount: Int64
}

/// Locates and verifies models only inside the app's private container.
actor ModelStore {
    private(set) var status = LocalModelStatus(
        state: .checking,
        chatURL: nil,
        embeddingURL: nil,
        speechURL: nil,
        capabilities: LocalModelCapabilityKind.allCases.map {
            LocalModelCapabilityStatus(kind: $0, state: .checking, byteCount: 0)
        },
        totalByteCount: 0
    )

    /// Recomputes model readiness using pinned filenames and SHA-256 values.
    /// - Returns: Current local model status.
    internal func refreshStatus() throws -> LocalModelStatus {
        let modelsDirectory = try AppDirectories.modelsDirectory()
        let chatURL = modelsDirectory.appendingPathComponent(ModelConstants.Chat.filename)
        let embeddingURL = modelsDirectory.appendingPathComponent(ModelConstants.Embedding.filename)
        let speechURL = modelsDirectory.appendingPathComponent(
            ModelConstants.Speech.directoryName,
            isDirectory: true
        )
        let fileManager = FileManager.default
        let chatExists = fileManager.fileExists(atPath: chatURL.path)
        let embeddingExists = fileManager.fileExists(atPath: embeddingURL.path)
        let speechExists = fileManager.fileExists(atPath: speechURL.path)
        let manifestExists = fileManager.fileExists(atPath: try assetManifestURL().path)
        let chatVerified = if chatExists {
            try FileHasher.sha256(of: chatURL) == ModelConstants.Chat.sha256
        } else {
            false
        }
        let embeddingVerified = if embeddingExists {
            try FileHasher.sha256(of: embeddingURL) == ModelConstants.Embedding.sha256
        } else {
            false
        }
        let speechVerified = if speechExists && manifestExists {
            try verifyInstalledAssetManifest(modelsDirectory: modelsDirectory)
        } else {
            false
        }

        let capabilities = [
            LocalModelCapabilityStatus(
                kind: .chat,
                state: capabilityState(exists: chatExists, verified: chatVerified),
                byteCount: try installedByteCount(at: chatURL, fileManager: fileManager)
            ),
            LocalModelCapabilityStatus(
                kind: .fileSearch,
                state: capabilityState(exists: embeddingExists, verified: embeddingVerified),
                byteCount: try installedByteCount(at: embeddingURL, fileManager: fileManager)
            ),
            LocalModelCapabilityStatus(
                kind: .voiceInput,
                state: capabilityState(
                    exists: speechExists && manifestExists,
                    verified: speechVerified
                ),
                byteCount: try installedByteCount(at: speechURL, fileManager: fileManager)
            )
        ]
        let hasIntegrityFailure = capabilities.contains { $0.state == .integrityFailure }
        let hasMissingCapability = capabilities.contains { $0.state == .missing }
        let overallState: OfflineStatus = if hasIntegrityFailure {
            .integrityFailure
        } else if hasMissingCapability {
            .missingModels
        } else {
            .ready
        }
        status = LocalModelStatus(
            state: overallState,
            chatURL: chatVerified ? chatURL : nil,
            embeddingURL: embeddingVerified ? embeddingURL : nil,
            speechURL: speechVerified ? speechURL : nil,
            capabilities: capabilities,
            totalByteCount: capabilities.reduce(0) { $0 + $1.byteCount }
        )
        return status
    }

    /// Converts installation and integrity checks into one capability state.
    /// - Parameters:
    ///   - exists: Whether the expected local asset is present.
    ///   - verified: Whether the present asset passed its integrity check.
    /// - Returns: User-relevant readiness for the capability.
    private func capabilityState(
        exists: Bool,
        verified: Bool
    ) -> LocalModelCapabilityState {
        if exists == false { return .missing }
        return verified ? .ready : .integrityFailure
    }

    /// Returns the installed byte count for one file or model directory.
    /// - Parameters:
    ///   - url: Installed model file or directory to measure.
    ///   - fileManager: Local file manager used for metadata enumeration.
    /// - Returns: Total bytes currently stored at the URL, or zero when absent.
    /// - Throws: A local metadata error when an installed item cannot be read.
    private func installedByteCount(
        at url: URL,
        fileManager: FileManager
    ) throws -> Int64 {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }
        if isDirectory.boolValue == false {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? NSNumber)?.int64Value ?? 0
        }

        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var byteCount: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true else { continue }
            byteCount += Int64(values.fileSize ?? 0)
        }
        return byteCount
    }

    /// Returns the private installed-asset checksum manifest URL.
    /// - Returns: Manifest beside the Models directory.
    /// - Throws: A local directory-resolution error.
    private func assetManifestURL() throws -> URL {
        try AppDirectories.applicationSupport().appendingPathComponent(
            AppConstants.Identity.modelAssetManifestFilename
        )
    }

    /// Verifies every model file against the staging-generated installed manifest.
    /// - Parameter modelsDirectory: Private Models directory.
    /// - Returns: `true` only when every safe manifest entry exists and matches.
    /// - Throws: A local file-read or hash error.
    private func verifyInstalledAssetManifest(modelsDirectory: URL) throws -> Bool {
        let manifestText = try String(contentsOf: assetManifestURL(), encoding: .utf8)
        var verifiedCount = 0
        for line in manifestText.split(whereSeparator: \.isNewline) {
            let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard fields.count == 2 else { return false }
            let expected = String(fields[0])
            let storedPath = String(fields[1]).trimmingCharacters(in: .whitespaces)
            guard storedPath.hasPrefix(InferenceConstants.assetManifestPrefix) else { return false }
            guard storedPath.hasPrefix(InferenceConstants.speechAssetManifestPrefix) else { continue }
            let relativePath = String(storedPath.dropFirst(InferenceConstants.assetManifestPrefix.count))
            let relativeComponents = relativePath.split(separator: FileConstants.pathSeparatorCharacter)
            guard relativeComponents.contains(FileConstants.parentDirectoryComponent) == false else { return false }
            let fileURL = relativeComponents.reduce(modelsDirectory) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  try FileHasher.sha256(of: fileURL) == expected else { return false }
            verifiedCount += 1
        }
        return verifiedCount > 0
    }
}
