import Foundation

/// Stable fixture values for reused-statement tests.
internal enum StatementCacheTestConstants {
    internal static let rootID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    internal static let firstItemID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    internal static let secondItemID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
    internal static let absentItemID = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!
    internal static let rootName = "Archive"
    internal static let rootPath = "/Users/example/Archive"
    internal static let firstName = "Lease.pdf"
    internal static let firstPath = "/Users/example/Archive/Lease.pdf"
    internal static let secondName = "Invoice.pdf"
    internal static let secondPath = "/Users/example/Archive/Invoice.pdf"
    internal static let storedFileCount = 2
    internal static let bookmarkByte: UInt8 = 1
}
