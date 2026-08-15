import CryptoKit
import Foundation

/// Derives stable UUIDs from local paths without disclosing those paths.
enum StableIdentifier {
    /// Produces a deterministic UUID from an arbitrary local string.
    /// - Parameter value: Local value such as an absolute path.
    /// - Returns: UUID derived from the first 16 SHA-256 bytes.
    internal static func uuid(for value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
