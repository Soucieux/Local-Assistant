import Foundation

/// Errors that can safely be shown without exposing indexed content.
enum LocalAssistantError: LocalizedError, Sendable {
    case database(String)
    case permission(String)
    case modelMissing(String)
    case modelIntegrity(String)
    case extraction(String)
    case indexing(String)
    case inference(String)
    case voice(String)
    case unsupported(String)
    case fileUnavailable
    case unexpected(String)

    /// Returns a local, human-readable failure reason.
    var errorDescription: String? {
        switch self {
        case .database(let detail): ErrorStrings.database + detail
        case .permission(let detail): ErrorStrings.permission + detail
        case .modelMissing(let detail): ErrorStrings.modelMissing + detail
        case .modelIntegrity(let detail): ErrorStrings.modelIntegrity + detail
        case .extraction(let detail): ErrorStrings.extraction + detail
        case .indexing(let detail): ErrorStrings.indexing + detail
        case .inference(let detail): ErrorStrings.inference + detail
        case .voice(let detail): ErrorStrings.voice + detail
        case .unsupported(let detail): ErrorStrings.unsupported + detail
        case .fileUnavailable: ErrorStrings.fileUnavailable
        case .unexpected(let detail): ErrorStrings.unexpected + detail
        }
    }
}
