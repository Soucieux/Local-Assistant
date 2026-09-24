import Foundation

/// User-safe prefixes for typed local errors.
internal enum ErrorStrings {
    internal static let database = "Database error: "
    internal static let permission = "Permission error: "
    internal static let modelMissing = "Required model is missing: "
    internal static let modelIntegrity = "Model integrity check failed: "
    internal static let extraction = "Content extraction failed: "
    internal static let indexing = "Indexing failed: "
    internal static let inference = "Local inference failed: "
    internal static let connector = "Connector error: "
    internal static let voice = "Voice input failed: "
    internal static let unsupported = "Unsupported content: "
    internal static let fileUnavailable =
        "This saved file is no longer present in an authorized indexed folder."
    internal static let unexpected = "Unexpected error: "
}
