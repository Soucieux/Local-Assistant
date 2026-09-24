import Carbon.HIToolbox
import Foundation
import SwiftUI

/// Fixed local quick-call registration values.
internal enum ShortcutConstants {
    internal static let identifier: UInt32 = 1
    internal static let signature: OSType = 0x4C_41_53_54
    internal static let keyCode = UInt32(kVK_Space)
    internal static let modifiers = UInt32(controlKey | optionKey)
    internal static let settingsKey = KeyEquivalent(",")
}
