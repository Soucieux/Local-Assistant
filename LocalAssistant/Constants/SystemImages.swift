import Foundation

/// SF Symbols identifiers used by the focused interface.
enum SystemImages {
    static let indexedFolders = "folder.badge.gearshape"
    static let settings = "gearshape"
    static let activity = "clock.arrow.circlepath"
    static let history = "text.bubble"
    static let monitoring = "wave.3.right.circle.fill"
    static let filter = "line.3.horizontal.decrease"
    static let source = "arrow.triangle.branch"
    static let status = "circle.dotted"
    static let reset = "arrow.counterclockwise"
    static let resume = "play.fill"
    static let automatic = "bolt.fill"
    static let completed = "checkmark.circle.fill"
    static let paused = "pause.circle.fill"
    static let clearConversation = "trash"
    static let back = "chevron.left"
    static let localVerified = "checkmark.shield"
    static let stale = "exclamationmark.triangle"
    static let send = "arrow.up"
    static let microphone = "mic.fill"
    static let stop = "stop.fill"
    static let folder = "folder"
    static let document = "doc.text"
    static let add = "plus"
    static let unchanged = "equal.circle.fill"
    static let removed = "minus.circle.fill"
    static let search = "magnifyingglass"
    static let lock = "lock.fill"
    static let assistant = "sparkles"
    static let results = "doc.text.magnifyingglass"
    static let matchReason = "checkmark.circle.fill"
    static let shortcut = "command"
    static let model = "cpu"
    static let privacy = "hand.raised.fill"
    static let localDatabase = "internaldrive.fill"
    static let prompt = "arrow.turn.down.right"
    static let path = "location.fill"
    static let removeFolder = "folder.badge.minus"
    static let open = "arrow.up.forward.app"
    static let reveal = "folder"
    static let folderFilled = "folder.fill"
    static let richDocument = "doc.richtext.fill"
    static let spreadsheet = "tablecells.fill"
    static let presentation = "rectangle.stack.fill"
    static let pdf = "doc.text.fill"
    static let image = "photo.fill"
    static let code = "chevron.left.forwardslash.chevron.right"
    static let text = "doc.plaintext.fill"
    static let archive = "archivebox.fill"
    static let other = "doc.fill"
    static let refresh = "arrow.clockwise"
    static let deadline = "calendar.badge.clock"
    static let openClaw = "point.3.connected.trianglepath.dotted"
    static let help = "questionmark.circle"

    /// Returns the most recognizable SF Symbol for an indexed item category.
    /// - Parameter kind: Indexed file or folder category.
    /// - Returns: SF Symbol name for the result card.
    internal static func fileType(_ kind: IndexedItemKind) -> String {
        switch kind {
        case .folder: return folderFilled
        case .document: return richDocument
        case .spreadsheet: return spreadsheet
        case .presentation: return presentation
        case .pdf: return pdf
        case .image: return image
        case .code: return code
        case .text: return text
        case .archive: return archive
        case .other: return other
        }
    }

    /// Returns an SF Symbol for one user-visible assistant capability.
    /// - Parameter kind: Capability supplied by an installed local model.
    /// - Returns: Recognizable symbol for the Settings row.
    internal static func modelCapability(_ kind: LocalModelCapabilityKind) -> String {
        switch kind {
        case .chat: return assistant
        case .fileSearch: return results
        case .voiceInput: return microphone
        }
    }
}
