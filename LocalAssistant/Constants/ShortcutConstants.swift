import Carbon.HIToolbox
import Foundation
import SwiftUI

/// Fixed local quick-call registration values.
enum ShortcutConstants {
    static let identifier: UInt32 = 1
    static let signature: OSType = 0x4C_41_53_54
    static let keyCode = UInt32(kVK_Space)
    static let modifiers = UInt32(controlKey | optionKey)
    static let settingsKey = KeyEquivalent(",")
}
