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

    /// One cached integrity result, trusted only while its file identity is unchanged.
    private struct VerifiedAsset: Codable {
        let size: Int64
        let modifiedAt: Double
        let digest: String
        let verifiedAt: Double
    }

    private var verifiedAssets: [String: VerifiedAsset] = [:]
    private var hasLoadedVerificationCache = false
    private var verificationCacheChanged = false

    /// Recomputes model readiness using pinned filenames and SHA-256 values.
    /// - Returns: Current local model status.
    /// - Throws: A local error when the models directory or an installed asset cannot be read.
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
            && hasRequiredTokenizer(at: speechURL)
        let manifestExists = fileManager.fileExists(atPath: try assetManifestURL().path)
        let chatVerified = if chatExists {
            try matchesDigest(url: chatURL, expected: ModelConstants.Chat.sha256)
        } else {
            false
        }
        let embeddingVerified = if embeddingExists {
            try matchesDigest(url: embeddingURL, expected: ModelConstants.Embedding.sha256)
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
        saveVerificationCacheIfNeeded()
        return status
    }

    /// Deletes every installed model file and clears cached verification state.
    /// - Returns: Freshly recomputed status reporting every capability as missing.
    /// - Throws: A local error when installed files cannot be removed or re-created.
    internal func removeInstalledModels() throws -> LocalModelStatus {
        let modelsDirectory = try AppDirectories.modelsDirectory()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.removeItem(at: modelsDirectory)
        }
        try fileManager.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions]
        )
        try fileManager.setAttributes(
            [.posixPermissions: AppConstants.Storage.ownerOnlyDirectoryPermissions],
            ofItemAtPath: modelsDirectory.path
        )
        let manifestURL = try assetManifestURL()
        if fileManager.fileExists(atPath: manifestURL.path) {
            try fileManager.removeItem(at: manifestURL)
        }
        let cacheURL = try verificationCacheURL()
        if fileManager.fileExists(atPath: cacheURL.path) {
            try fileManager.removeItem(at: cacheURL)
        }
        verifiedAssets = [:]
        verificationCacheChanged = false
        return try refreshStatus()
    }

    /// Reports whether the installed speech model carries its own tokenizer.
    ///
    /// The Core ML directory alone is not enough to transcribe anything. Treating it as
    /// enough previously let Settings report voice input as ready on an installation that
    /// could only work by fetching the tokenizer from the network.
    /// - Parameter speechURL: Installed speech model directory.
    /// - Returns: `true` when every required tokenizer file is present.
    private func hasRequiredTokenizer(at speechURL: URL) -> Bool {
        ModelConstants.Speech.requiredTokenizerFiles.allSatisfy { filename in
            FileManager.default.fileExists(atPath: speechURL.appendingPathComponent(filename).path)
        }
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
                  try matchesDigest(url: fileURL, expected: expected) else { return false }
            verifiedCount += 1
        }
        return verifiedCount > 0
    }

    /// Confirms one asset's digest, reusing a recent result while the file is untouched.
    ///
    /// Hashing every installed model on each launch reads gigabytes before the window
    /// appears. A cached result is trusted only while the file's size and modification
    /// time are unchanged and the check is recent, so replacement, truncation, and
    /// partial installs still force a full re-read.
    /// - Parameters:
    ///   - url: Installed asset to verify.
    ///   - expected: Pinned SHA-256 value.
    /// - Returns: `true` when the asset matches its pinned digest.
    /// - Throws: A local file-read or hash error.
    private func matchesDigest(url: URL, expected: String) throws -> Bool {
        loadVerificationCacheIfNeeded()
        let identity = try fileIdentity(at: url)
        if let cached = verifiedAssets[url.path],
           cached.size == identity.size,
           cached.modifiedAt == identity.modifiedAt,
           cached.digest == expected,
           Date().timeIntervalSince1970 - cached.verifiedAt < InferenceConstants.verificationValiditySeconds {
            return true
        }

        let digest = try FileHasher.sha256(of: url)
        verificationCacheChanged = true
        guard digest == expected else {
            verifiedAssets.removeValue(forKey: url.path)
            return false
        }
        verifiedAssets[url.path] = VerifiedAsset(
            size: identity.size,
            modifiedAt: identity.modifiedAt,
            digest: digest,
            verifiedAt: Date().timeIntervalSince1970
        )
        return true
    }

    /// Reads the size and modification time used to detect any change to an asset.
    /// - Parameter url: Installed asset to measure.
    /// - Returns: Size in bytes and modification time as Unix seconds.
    /// - Throws: A local metadata error when the asset cannot be inspected.
    private func fileIdentity(at url: URL) throws -> (size: Int64, modifiedAt: Double) {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return (
            Int64(values.fileSize ?? 0),
            values.contentModificationDate?.timeIntervalSince1970 ?? 0
        )
    }

    /// Loads the private verification cache once per process.
    private func loadVerificationCacheIfNeeded() {
        guard hasLoadedVerificationCache == false else { return }
        hasLoadedVerificationCache = true
        guard let url = try? verificationCacheURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: VerifiedAsset].self, from: data) else {
            return
        }
        verifiedAssets = decoded
    }

    /// Writes the private verification cache with owner-only permissions when it changed.
    private func saveVerificationCacheIfNeeded() {
        guard verificationCacheChanged, let url = try? verificationCacheURL() else { return }
        verificationCacheChanged = false
        guard let data = try? JSONEncoder().encode(verifiedAssets) else { return }
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: AppConstants.Storage.ownerOnlyFilePermissions],
            ofItemAtPath: url.path
        )
    }

    /// Returns the private verification cache URL beside the installed manifest.
    /// - Returns: Cache location inside the app container.
    /// - Throws: A local directory-resolution error.
    private func verificationCacheURL() throws -> URL {
        try AppDirectories.applicationSupport().appendingPathComponent(
            InferenceConstants.verificationCacheFilename
        )
    }
}
