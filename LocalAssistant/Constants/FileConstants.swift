import Foundation

/// File-system names and supported content types.
enum FileConstants {
    enum Hash {
        static let bufferBytes = 1_048_576
        static let hexFormat = "%02x"
        static let fieldSeparator = "\u{1F}"
    }

    static let pathSeparator = "/"
    static let pathSeparatorCharacter: Character = "/"
    static let hiddenNamePrefix = "."
    static let parentDirectoryComponent: Substring = ".."
    /// Directory names safe to exclude wherever they appear, because they never hold user documents.
    static let excludedNames: Set<String> = [
        ".git", ".svn", ".hg", ".Trash", "node_modules", "DerivedData",
        ".build", "Pods"
    ]

    /// Absolute directories that are always operating-system storage.
    ///
    /// These are matched by resolved path rather than by name so an ordinary project
    /// folder named `Library` or `Caches` is still indexed.
    static let absoluteSystemDirectories: Set<String> = [
        "/Library", "/System", "/private", "/bin", "/sbin", "/usr", "/Applications", "/cores"
    ]

    /// Directories excluded only when they sit directly inside the real user home.
    static let homeRelativeSystemDirectories: Set<String> = ["Library"]

    static let credentialExtensions: Set<String> = [
        "pem", "key", "p12", "pfx", "mobileprovision", "kdbx"
    ]

    static let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "csv", "tsv", "json", "jsonl",
        "xml", "yaml", "yml", "toml", "ini", "log", "swift", "m", "mm",
        "h", "hpp", "c", "cpp", "py", "js", "jsx", "ts", "tsx", "java",
        "kt", "kts", "go", "rs", "rb", "php", "sh", "zsh", "fish", "sql",
        "css", "scss", "html", "htm"
    ]

    /// Encodings tried in order when decoding a text file, strictest first.
    static let textFallbackEncodings: [String.Encoding] = [.utf8, .utf16, .windowsCP1252, .isoLatin1]

    /// Byte-order marks that identify UTF-16 content before UTF-8 is attempted.
    static let utf16ByteOrderMarks: [[UInt8]] = [[0xFF, 0xFE], [0xFE, 0xFF]]

    static let officeExtensions: Set<String> = ["docx", "xlsx", "pptx"]
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "bmp", "gif"]
    static let pdfExtension = "pdf"
    static let pagesExtension = "pages"
    static let spreadsheetExtension = "xlsx"
    static let presentationExtension = "pptx"
}
