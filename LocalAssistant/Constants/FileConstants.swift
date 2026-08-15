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
    static let excludedNames: Set<String> = [
        ".git", ".svn", ".hg", ".Trash", "node_modules", "DerivedData",
        ".build", "Library", "Caches", "Pods"
    ]

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

    static let officeExtensions: Set<String> = ["docx", "xlsx", "pptx"]
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "bmp", "gif"]
    static let pdfExtension = "pdf"
    static let pagesExtension = "pages"
    static let spreadsheetExtension = "xlsx"
    static let presentationExtension = "pptx"
}
