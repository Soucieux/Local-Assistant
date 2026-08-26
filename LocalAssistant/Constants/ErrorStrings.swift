import Foundation

/// User-safe prefixes for typed local errors.
enum ErrorStrings {
    static let database = "Database error: "
    static let permission = "Permission error: "
    static let modelMissing = "Required model is missing: "
    static let modelIntegrity = "Model integrity check failed: "
    static let extraction = "Content extraction failed: "
    static let indexing = "Indexing failed: "
    static let inference = "Local inference failed: "
    static let connector = "Connector error: "
    static let voice = "Voice input failed: "
    static let unsupported = "Unsupported content: "
    static let fileUnavailable =
        "This saved file is no longer present in an authorized indexed folder."
    static let unexpected = "Unexpected error: "
}
