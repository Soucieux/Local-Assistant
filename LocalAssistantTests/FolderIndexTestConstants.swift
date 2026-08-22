import Foundation

/// Stable fixture values for folder indexing and hierarchy tests.
enum FolderIndexTestConstants {
    static let schoolSearchTerm = "school"
    static let transcriptSearchText = "biology transcript"
    static let rootID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let rootItemID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let childFolderID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let childFileID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    static let schoolName = "School"
    static let biologyName = "Biology"
    static let transcriptName = "Transcript.pdf"
    static let schoolPath = "/Users/example/School"
    static let biologyPath = "/Users/example/School/Biology"
    static let transcriptPath = "/Users/example/School/Transcript.pdf"
    static let scannerDirectoryPrefix = "folder-index-scanner-"
    static let noteName = "Notes.txt"
    static let noteText = "School notes"
    static let folderHash = "folder-hash"
    static let databaseExtension = "sqlite3"
    static let bookmarkByte: UInt8 = 1
}
