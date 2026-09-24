import Foundation

/// Stable Markdown markers used by the native response parser and renderer.
internal enum ResponseMarkdownConstants {
    internal enum Syntax {
        internal static let carriageReturn = "\r"
        internal static let newline = "\n"
        internal static let paragraphJoiner = " "
        internal static let codeFence = "```"
        internal static let blockQuotePrefix = ">"
        internal static let headingMarker: Character = "#"
        internal static let tableDelimiter: Character = "|"
        internal static let alignmentColon: Character = ":"
        internal static let escapeCharacter: Character = "\\"
        internal static let emphasisMarker: Character = "*"
        internal static let dividerDash: Character = "-"
        internal static let dividerUnderscore: Character = "_"
        internal static let unorderedDashPrefix = "- "
        internal static let unorderedAsteriskPrefix = "* "
        internal static let unorderedPlusPrefix = "+ "
        internal static let orderedPeriod: Character = "."
        internal static let orderedParenthesis: Character = ")"
        internal static let orderedMarkerSuffix = "."
        internal static let minimumDividerLength = 3
        internal static let maximumHeadingLevel = 6
    }
}
