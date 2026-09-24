import Foundation

/// File-system names and supported content types.
internal enum FileConstants {
    internal enum Hash {
        internal static let bufferBytes = 1_048_576
        internal static let hexFormat = "%02x"
        internal static let fieldSeparator = "\u{1F}"
    }

    internal enum FolderIndex {
        internal static let version = 1
        internal static let maximumChildNames = 64
        internal static let titlePrefix = "Folder: "
        internal static let pathPrefix = "Path: "
        internal static let contentsPrefix = "Contains: "
        internal static let childSeparator = ", "
        internal static let sectionName = "Folder context"
    }

    internal static let pathSeparator = "/"
    internal static let pathSeparatorCharacter: Character = "/"
    internal static let hiddenNamePrefix = "."
    internal static let parentDirectoryComponent: Substring = ".."
    /// Directory names safe to exclude wherever they appear, because they never hold user documents.
    internal static let excludedNames: Set<String> = [
        ".git", ".svn", ".hg", ".Trash", "node_modules", "DerivedData",
        ".build", "Pods"
    ]

    /// Absolute directories that are always operating-system storage.
    ///
    /// These are matched by resolved path rather than by name so an ordinary project
    /// folder named `Library` or `Caches` is still indexed.
    internal static let absoluteSystemDirectories: Set<String> = [
        "/Library", "/System", "/private", "/bin", "/sbin", "/usr", "/Applications", "/cores"
    ]

    /// Directories excluded only when they sit directly inside the real user home.
    internal static let homeRelativeSystemDirectories: Set<String> = ["Library"]

    internal static let credentialExtensions: Set<String> = [
        "pem", "key", "p12", "pfx", "mobileprovision", "kdbx"
    ]

    internal static let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "csv", "tsv", "json", "jsonl",
        "xml", "yaml", "yml", "toml", "ini", "log", "swift", "m", "mm",
        "h", "hpp", "c", "cpp", "py", "js", "jsx", "ts", "tsx", "java",
        "kt", "kts", "go", "rs", "rb", "php", "sh", "zsh", "fish", "sql",
        "css", "scss", "html", "htm"
    ]

    /// Encodings tried in order when decoding a text file, strictest first.
    internal static let textFallbackEncodings: [String.Encoding] = [.utf8, .utf16, .windowsCP1252, .isoLatin1]

    /// Byte-order marks that identify UTF-16 content before UTF-8 is attempted.
    internal static let utf16ByteOrderMarks: [[UInt8]] = [[0xFF, 0xFE], [0xFE, 0xFF]]

    internal static let officeExtensions: Set<String> = ["docx", "xlsx", "pptx"]
    internal static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "bmp", "gif"]
    internal static let pdfExtension = "pdf"
    internal static let pagesExtension = "pages"
    internal static let spreadsheetExtension = "xlsx"
    internal static let presentationExtension = "pptx"
}
