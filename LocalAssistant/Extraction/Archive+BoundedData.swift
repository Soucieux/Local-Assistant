import Foundation
import ZIPFoundation

/// Bounded in-memory extraction shared by every extractor that opens a ZIP container.
extension Archive {
    /// Loads one entry into memory under the fixed decompressed size limit.
    ///
    /// A small container can declare an enormous entry, so the copy is bounded while it is
    /// being written rather than trusting the archive's own size fields. Office documents and
    /// Pages previews both read entries this way, so the limit is enforced in one place.
    /// - Parameter entry: Archive entry to extract.
    /// - Returns: Copied entry bytes.
    /// - Throws: A local unsupported error past the limit, or an archive extraction error.
    internal func boundedData(for entry: Entry) throws -> Data {
        var result = Data()
        _ = try extract(entry) { chunk in
            guard result.count + chunk.count <= AppConstants.Indexing.maximumArchiveEntryBytes else {
                throw LocalAssistantError.unsupported(entry.path)
            }
            result.append(chunk)
        }
        return result
    }
}
