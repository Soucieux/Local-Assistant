import Foundation
import Testing
import ZIPFoundation

@testable import LocalAssistant

/// A small container must never be allowed to expand without bound during extraction.
struct ArchiveExtractionLimitTests {
    @Test("A highly compressible oversized entry is refused instead of loaded")
    internal func refusesOversizedArchiveEntry() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                ArchiveExtractionTestConstants.directoryPrefix + UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let documentURL = directoryURL.appendingPathComponent(
            ArchiveExtractionTestConstants.documentName
        )
        let archive = try Archive(url: documentURL, accessMode: .create)
        let payload = Data(
            count: AppConstants.Indexing.maximumArchiveEntryBytes
                + ArchiveExtractionTestConstants.overshootBytes
        )
        try archive.addEntry(
            with: ExtractionConstants.documentXMLPath,
            type: .file,
            uncompressedSize: Int64(payload.count),
            compressionMethod: .deflate,
            provider: { position, size in
                payload.subdata(in: Int(position)..<Int(position) + size)
            }
        )

        var refusedAsOversized = false
        do {
            _ = try OfficeTextExtractor().extract(url: documentURL)
        } catch LocalAssistantError.unsupported {
            refusedAsOversized = true
        } catch {
            refusedAsOversized = false
        }

        #expect(refusedAsOversized)
    }

    @Test("An ordinary Word body stays extractable under the same limit")
    internal func stillExtractsOrdinaryDocument() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                ArchiveExtractionTestConstants.directoryPrefix + UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let documentURL = directoryURL.appendingPathComponent(
            ArchiveExtractionTestConstants.documentName
        )
        let archive = try Archive(url: documentURL, accessMode: .create)
        let body = Data(ArchiveExtractionTestConstants.wordBodyXML.utf8)
        try archive.addEntry(
            with: ExtractionConstants.documentXMLPath,
            type: .file,
            uncompressedSize: Int64(body.count),
            compressionMethod: .deflate,
            provider: { position, size in
                body.subdata(in: Int(position)..<Int(position) + size)
            }
        )

        let document = try OfficeTextExtractor().extract(url: documentURL)

        #expect(
            document.segments.first?.text.contains(ArchiveExtractionTestConstants.bodyText) == true
        )
    }
}
