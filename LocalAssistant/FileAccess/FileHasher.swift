import CryptoKit
import Foundation

/// Computes streaming hashes while holding files read-only.
enum FileHasher {
    /// Computes a SHA-256 digest without loading the full file into memory.
    /// - Parameter url: Readable local file URL.
    /// - Returns: Lowercase hexadecimal digest.
    /// - Throws: A local extraction error when the file cannot be read.
    internal static func sha256(of url: URL) throws -> String {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let data = try handle.read(upToCount: FileConstants.Hash.bufferBytes), data.isEmpty == false {
                hasher.update(data: data)
            }
            return hasher.finalize().map { String(format: FileConstants.Hash.hexFormat, $0) }.joined()
        } catch {
            throw LocalAssistantError.extraction(error.localizedDescription)
        }
    }

    /// Computes a stable SHA-256 digest for generated local search context.
    /// - Parameter text: Private synthesized text that will be embedded locally.
    /// - Returns: Lowercase hexadecimal digest.
    internal static func sha256(of text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: FileConstants.Hash.hexFormat, $0) }.joined()
    }

    /// Computes a stable hash for cheap file metadata comparisons.
    ///
    /// The extraction version participates so that an unchanged file is still re-read once
    /// after the pipeline that produced its indexed text is corrected.
    /// - Parameters:
    ///   - path: Standardized absolute path.
    ///   - byteCount: File size.
    ///   - modifiedAt: Modification timestamp.
    ///   - kind: Broad item kind.
    /// - Returns: Lowercase SHA-256 hexadecimal digest.
    internal static func metadataHash(
        path: String,
        byteCount: Int64,
        modifiedAt: Date?,
        kind: IndexedItemKind
    ) -> String {
        var fields = [
            path,
            String(byteCount),
            String(modifiedAt?.timeIntervalSince1970 ?? 0),
            kind.rawValue,
            String(ExtractionConstants.extractionVersion)
        ]
        if kind == .folder {
            fields.append(String(FileConstants.FolderIndex.version))
        }
        let value = fields.joined(separator: FileConstants.Hash.fieldSeparator)
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: FileConstants.Hash.hexFormat, $0) }.joined()
    }
}
