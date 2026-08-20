import Darwin
import Foundation
import Testing

@testable import LocalAssistant

/// Exercised against real files so the resource values are the ones a live scan sees.
final class ExclusionPolicyTests {
    private let policy = ExclusionPolicy()
    private let root: URL
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
        .isHiddenKey, .isReadableKey, .fileSizeKey
    ]

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("exclusion-policy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    /// Creates a regular file and returns the reason the policy gives for it.
    private func reason(forFileNamed name: String, contents: String = "text") throws -> ExclusionReason? {
        let url = root.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return policy.reason(for: url, values: try url.resourceValues(forKeys: Self.resourceKeys))
    }

    @Test("An ordinary readable document is not excluded")
    func allowsOrdinaryFile() throws {
        #expect(try reason(forFileNamed: "Report.txt") == nil)
    }

    @Test("A symbolic link is excluded so a scan cannot be redirected outside its root")
    func excludesSymbolicLink() throws {
        let target = root.appendingPathComponent("target.txt")
        try "text".write(to: target, atomically: true, encoding: .utf8)
        let link = root.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let values = try link.resourceValues(forKeys: Self.resourceKeys)
        #expect(policy.reason(for: link, values: values) == .symbolicLink)
    }

    @Test("A dot-prefixed file is excluded as hidden")
    func excludesHiddenFile() throws {
        #expect(try reason(forFileNamed: ".secret.txt") == .hidden)
    }

    @Test("Credential material is excluded by extension")
    func excludesCredentialMaterial() throws {
        #expect(try reason(forFileNamed: "server.pem") == .credentialMaterial)
    }

    @Test("Build and version-control directories are excluded by name")
    func excludesKnownDirectoryNames() {
        for name in ["node_modules", "DerivedData", "Pods", ".build"] {
            let url = root.appendingPathComponent(name, isDirectory: true)
            #expect(
                policy.reason(for: url, values: URLResourceValues()) != nil,
                "\(name) should be excluded"
            )
        }
    }

    @Test("A user folder merely named Library is still indexed")
    func allowsUserFolderNamedLibrary() {
        // Only the real system paths are excluded, so a project folder called "Library"
        // or "Caches" inside a chosen root stays searchable.
        for name in ["Library", "Caches"] {
            let url = root.appendingPathComponent(name, isDirectory: true)
            #expect(
                policy.reason(for: url, values: URLResourceValues()) == nil,
                "\(name) should be indexed"
            )
        }
    }

    @Test("Absolute system directories are excluded wherever a root reaches them")
    func excludesAbsoluteSystemDirectories() {
        for path in ["/System", "/Library", "/usr", "/bin", "/Applications"] {
            #expect(
                policy.reason(for: URL(fileURLWithPath: path), values: URLResourceValues()) == .systemDirectory,
                "\(path) should be excluded"
            )
        }
    }

    @Test("The real home Library is excluded even though a nested Library is not")
    func excludesHomeLibrary() throws {
        // The test host is sandboxed, so HOME and NSHomeDirectory() both point at the
        // container. The policy resolves the real account home, so the test must too.
        let record = try #require(getpwuid(getuid()))
        let home = String(cString: record.pointee.pw_dir)
        let homeLibrary = URL(fileURLWithPath: home).appendingPathComponent("Library", isDirectory: true)
        #expect(policy.reason(for: homeLibrary, values: URLResourceValues()) == .systemDirectory)
    }
}
