import Foundation

/// SF Symbols identifiers used by the focused interface.
internal enum SystemImages {
    internal static let indexedFolders = "folder.badge.gearshape"
    internal static let settings = "gearshape"
    internal static let activity = "clock.arrow.circlepath"
    internal static let history = "text.bubble"
    internal static let monitoring = "wave.3.right.circle.fill"
    internal static let filter = "line.3.horizontal.decrease"
    internal static let source = "arrow.triangle.branch"
    internal static let status = "circle.dotted"
    internal static let reset = "arrow.counterclockwise"
    internal static let resume = "play.fill"
    internal static let automatic = "bolt.fill"
    internal static let completed = "checkmark.circle.fill"
    internal static let paused = "pause.circle.fill"
    internal static let clearConversation = "trash"
    internal static let back = "chevron.left"
    internal static let localVerified = "checkmark.shield"
    internal static let stale = "exclamationmark.triangle"
    internal static let send = "arrow.up"
    internal static let microphone = "mic.fill"
    internal static let stop = "stop.fill"
    internal static let folder = "folder"
    internal static let document = "doc.text"
    internal static let add = "plus"
    internal static let unchanged = "equal.circle.fill"
    internal static let removed = "minus.circle.fill"
    internal static let search = "magnifyingglass"
    internal static let lock = "lock.fill"
    internal static let assistant = "sparkles"
    internal static let results = "doc.text.magnifyingglass"
    internal static let matchReason = "checkmark.circle.fill"
    internal static let shortcut = "command"
    internal static let model = "cpu"
    internal static let privacy = "hand.raised.fill"
    internal static let localDatabase = "internaldrive.fill"
    internal static let prompt = "arrow.turn.down.right"
    internal static let path = "location.fill"
    internal static let removeFolder = "folder.badge.minus"
    internal static let open = "arrow.up.forward.app"
    internal static let reveal = "folder"
    internal static let folderFilled = "folder.fill"
    internal static let richDocument = "doc.richtext.fill"
    internal static let spreadsheet = "tablecells.fill"
    internal static let presentation = "rectangle.stack.fill"
    internal static let pdf = "doc.text.fill"
    internal static let image = "photo.fill"
    internal static let code = "chevron.left.forwardslash.chevron.right"
    internal static let text = "doc.plaintext.fill"
    internal static let archive = "archivebox.fill"
    internal static let other = "doc.fill"
    internal static let refresh = "arrow.clockwise"
    internal static let deadline = "calendar.badge.clock"
    internal static let reminder = "bell.fill"
    internal static let link = "link"
    internal static let openClaw = "point.3.connected.trianglepath.dotted"
    internal static let help = "questionmark.circle"

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
