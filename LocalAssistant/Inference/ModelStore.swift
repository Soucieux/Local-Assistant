import Foundation

/// Readiness and installed storage for one user-visible assistant capability.
internal struct LocalModelCapabilityStatus: Identifiable, Sendable {
    internal var id: LocalModelCapabilityKind { kind }
    internal let kind: LocalModelCapabilityKind
    internal let state: LocalModelCapabilityState
    internal let byteCount: Int64
}

/// Verified paths and readiness for all model assets in the chosen model folder.
internal struct LocalModelStatus: Sendable {
    internal let state: OfflineStatus
    /// The chosen model folder, at its last known place when it cannot be found; `nil` when none is chosen.
    internal let libraryPath: String?
    internal let chatURL: URL?
    internal let embeddingURL: URL?
    internal let speechURL: URL?
    internal let capabilities: [LocalModelCapabilityStatus]
    internal let totalByteCount: Int64
}

/// Locates and verifies models in the model folder the user chose, reading them where they are.
///
/// The app keeps no model of its own. The folder follows the shared library's layout, and the
/// store holds its read-only security scope for as long as the folder stays chosen, because the
/// runtimes keep reading the files after they load.
internal actor ModelStore {
    internal private(set) var status = LocalModelStatus(
        state: .checking,
        libraryPath: nil,
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
        internal let size: Int64
        internal let modifiedAt: Double
        internal let digest: String
        internal let verifiedAt: Double
    }

    /// The chosen model folder as it is kept between launches.
    private struct StoredLibrary: Codable {
        internal let bookmarkData: Data
        internal let lastKnownPath: String
    }

    private let supportDirectory: URL?
    private var libraryAccess: SecurityScopedAccess?
    private var verifiedAssets: [String: VerifiedAsset] = [:]
    private var hasLoadedVerificationCache = false
    private var verificationCacheChanged = false

    /// Creates the store.
    /// - Parameter supportDirectory: Folder for the store's own records; the app's private
    ///   Application Support folder when omitted.
    internal init(supportDirectory: URL? = nil) {
        self.supportDirectory = supportDirectory
    }

    /// Recomputes model readiness from the chosen model folder.
    /// - Returns: Current local model status; it names a folder that is not chosen or cannot be found.
    /// - Throws: A local error when the store's records or a model file cannot be read.
    internal func refreshStatus() throws -> LocalModelStatus {
        guard let stored = try storedLibrary() else {
            libraryAccess = nil
            return unavailableStatus(.noLibrary, libraryPath: nil)
        }
        guard let libraryURL = openLibrary(stored) else {
            return unavailableStatus(.libraryUnavailable, libraryPath: stored.lastKnownPath)
        }
        return try refreshStatus(libraryURL: libraryURL)
    }

    /// Recomputes model readiness for one model folder, using pinned filenames and SHA-256 values.
    /// - Parameter libraryURL: Readable model folder laid out as the shared library is.
    /// - Returns: Current local model status.
    /// - Throws: A local error when the store's records or a model file cannot be read.
    internal func refreshStatus(libraryURL: URL) throws -> LocalModelStatus {
        let languageModels = libraryURL.appendingPathComponent(
            ModelConstants.Library.languageModelDirectory,
            isDirectory: true
        )
        let chatURL = languageModels.appendingPathComponent(ModelConstants.Chat.filename)
        let embeddingURL = languageModels.appendingPathComponent(ModelConstants.Embedding.filename)
        let speechURL = libraryURL
            .appendingPathComponent(ModelConstants.Library.speechModelDirectory, isDirectory: true)
            .appendingPathComponent(ModelConstants.Speech.directoryName, isDirectory: true)
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
            try verifyInstalledAssetManifest(speechDirectory: speechURL)
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
            libraryPath: libraryURL.path,
            chatURL: chatVerified ? chatURL : nil,
            embeddingURL: embeddingVerified ? embeddingURL : nil,
            speechURL: speechVerified ? speechURL : nil,
            capabilities: capabilities,
            totalByteCount: capabilities.reduce(0) { $0 + $1.byteCount }
        )
        saveVerificationCacheIfNeeded()
        return status
    }

    /// Keeps the folder the user chose and reads the models in it.
    /// - Parameter selection: Read-only bookmark and path of the chosen folder.
    /// - Returns: Freshly recomputed status for that folder.
    /// - Throws: A local error when the choice cannot be saved or a model file cannot be read.
    internal func selectLibrary(_ selection: ModelLibrarySelection) throws -> LocalModelStatus {
        let stored = StoredLibrary(bookmarkData: selection.bookmarkData, lastKnownPath: selection.path)
        let recordURL = try libraryRecordURL()
        try JSONEncoder().encode(stored).write(to: recordURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: AppConstants.Storage.ownerOnlyFilePermissions],
            ofItemAtPath: recordURL.path
        )
        libraryAccess = nil
        return try refreshStatus()
    }

    /// Forgets the chosen model folder; the folder and every file in it are left as they are.
    /// - Returns: Freshly recomputed status reporting that no folder is chosen.
    /// - Throws: A local error when the saved choice cannot be removed.
    internal func forgetLibrary() throws -> LocalModelStatus {
        let recordURL = try libraryRecordURL()
        if FileManager.default.fileExists(atPath: recordURL.path) {
            try FileManager.default.removeItem(at: recordURL)
        }
        libraryAccess = nil
        return try refreshStatus()
    }

    /// Reads the saved choice of model folder.
    /// - Returns: The saved choice, or `nil` when none is saved or it cannot be read.
    /// - Throws: A local directory-resolution error.
    private func storedLibrary() throws -> StoredLibrary? {
        guard let data = try? Data(contentsOf: try libraryRecordURL()) else { return nil }
        return try? JSONDecoder().decode(StoredLibrary.self, from: data)
    }

    /// Opens the saved model folder for reading, reusing the open session while the folder is there.
    ///
    /// A bookmark macOS reports as stale is still used when it resolves to a folder, so a renamed
    /// or remounted folder keeps working.
    /// - Parameter stored: The saved choice.
    /// - Returns: The folder, or `nil` when it was moved, removed, or sits on a drive that is not connected.
    private func openLibrary(_ stored: StoredLibrary) -> URL? {
        if let libraryAccess, isDirectory(libraryAccess.url) { return libraryAccess.url }
        libraryAccess = nil
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: stored.bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), let access = try? SecurityScopedAccess(url: url), isDirectory(url) else {
            return nil
        }
        libraryAccess = access
        return url
    }

    /// Reports whether a location is a folder that exists.
    /// - Parameter url: Location to inspect.
    /// - Returns: `true` when a directory is there.
    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// Records a status in which no model can be read, because no folder is usable.
    /// - Parameters:
    ///   - state: Why no folder is usable.
    ///   - libraryPath: Last known place of the chosen folder, when one is chosen.
    /// - Returns: The recorded status, with every capability missing.
    private func unavailableStatus(_ state: OfflineStatus, libraryPath: String?) -> LocalModelStatus {
        status = LocalModelStatus(
            state: state,
            libraryPath: libraryPath,
            chatURL: nil,
            embeddingURL: nil,
            speechURL: nil,
            capabilities: LocalModelCapabilityKind.allCases.map {
                LocalModelCapabilityStatus(kind: $0, state: .missing, byteCount: 0)
            },
            totalByteCount: 0
        )
        return status
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

    /// Returns the folder holding the store's own records.
    /// - Returns: The injected folder, otherwise the app's private Application Support folder.
    /// - Throws: A local directory-resolution error.
    private func recordsDirectory() throws -> URL {
        try supportDirectory ?? AppDirectories.applicationSupport()
    }

    /// Returns where the choice of model folder is saved.
    /// - Returns: Record location inside the app container.
    /// - Throws: A local directory-resolution error.
    private func libraryRecordURL() throws -> URL {
        try recordsDirectory().appendingPathComponent(AppConstants.Identity.modelLibraryRecordFilename)
    }

    /// Returns the private installed-asset checksum manifest URL.
    /// - Returns: Manifest inside the app container.
    /// - Throws: A local directory-resolution error.
    private func assetManifestURL() throws -> URL {
        try recordsDirectory().appendingPathComponent(
            AppConstants.Identity.modelAssetManifestFilename
        )
    }

    /// Verifies every speech model file against the staging-generated installed manifest.
    /// - Parameter speechDirectory: The speech model's directory in the chosen model folder.
    /// - Returns: `true` only when every safe manifest entry exists and matches.
    /// - Throws: A local file-read or hash error.
    private func verifyInstalledAssetManifest(speechDirectory: URL) throws -> Bool {
        let manifestText = try String(contentsOf: assetManifestURL(), encoding: .utf8)
        var verifiedCount = 0
        for line in manifestText.split(whereSeparator: \.isNewline) {
            let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard fields.count == 2 else { return false }
            let expected = String(fields[0])
            let storedPath = String(fields[1]).trimmingCharacters(in: .whitespaces)
            guard storedPath.hasPrefix(InferenceConstants.assetManifestPrefix) else { return false }
            guard storedPath.hasPrefix(InferenceConstants.speechAssetManifestPrefix) else { continue }
            let relativePath = String(storedPath.dropFirst(InferenceConstants.speechAssetManifestPrefix.count))
            let relativeComponents = relativePath.split(separator: FileConstants.pathSeparatorCharacter)
            guard relativeComponents.contains(FileConstants.parentDirectoryComponent) == false else { return false }
            let fileURL = relativeComponents.reduce(speechDirectory) { partial, component in
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
        try recordsDirectory().appendingPathComponent(
            InferenceConstants.verificationCacheFilename
        )
    }
}
