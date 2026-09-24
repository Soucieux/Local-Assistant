import Foundation

/// Stable fixture values for folder indexing and hierarchy tests.
internal enum FolderIndexTestConstants {
    internal static let schoolSearchTerm = "school"
    internal static let transcriptSearchText = "biology transcript"
    internal static let rootID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    internal static let rootItemID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    internal static let childFolderID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    internal static let childFileID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    internal static let schoolName = "School"
    internal static let biologyName = "Biology"
    internal static let transcriptName = "Transcript.pdf"
    internal static let schoolPath = "/Users/example/School"
    internal static let biologyPath = "/Users/example/School/Biology"
    internal static let transcriptPath = "/Users/example/School/Transcript.pdf"
    internal static let scannerDirectoryPrefix = "folder-index-scanner-"
    internal static let noteName = "Notes.txt"
    internal static let noteText = "School notes"
    internal static let folderHash = "folder-hash"
    internal static let bookmarkByte: UInt8 = 1
}
