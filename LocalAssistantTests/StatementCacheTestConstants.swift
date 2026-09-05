import Foundation

/// Stable fixture values for reused-statement tests.
enum StatementCacheTestConstants {
    static let rootID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let firstItemID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    static let secondItemID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
    static let absentItemID = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!
    static let rootName = "Archive"
    static let rootPath = "/Users/example/Archive"
    static let firstName = "Lease.pdf"
    static let firstPath = "/Users/example/Archive/Lease.pdf"
    static let secondName = "Invoice.pdf"
    static let secondPath = "/Users/example/Archive/Invoice.pdf"
    static let storedFileCount = 2
    static let bookmarkByte: UInt8 = 1
}
