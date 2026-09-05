import Foundation

/// Stable Markdown markers used by the native response parser and renderer.
enum ResponseMarkdownConstants {
    enum Syntax {
        static let carriageReturn = "\r"
        static let newline = "\n"
        static let paragraphJoiner = " "
        static let codeFence = "```"
        static let blockQuotePrefix = ">"
        static let headingMarker: Character = "#"
        static let tableDelimiter: Character = "|"
        static let alignmentColon: Character = ":"
        static let escapeCharacter: Character = "\\"
        static let emphasisMarker: Character = "*"
        static let dividerDash: Character = "-"
        static let dividerUnderscore: Character = "_"
        static let unorderedDashPrefix = "- "
        static let unorderedAsteriskPrefix = "* "
        static let unorderedPlusPrefix = "+ "
        static let orderedPeriod: Character = "."
        static let orderedParenthesis: Character = ")"
        static let orderedMarkerSuffix = "."
        static let minimumDividerLength = 3
        static let maximumHeadingLevel = 6
    }
}
