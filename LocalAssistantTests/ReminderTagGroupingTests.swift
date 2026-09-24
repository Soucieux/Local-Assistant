import Foundation
import Testing

@testable import LocalAssistant

/// The list summary and the card grid must agree on how many tag sections exist.
///
/// Tags are free text from the remote reminder list, so a tag may spell the untagged label or
/// the untagged identifier. Counting those together with untagged reminders made a summary
/// state fewer groups than the grid showed beneath it.
internal struct ReminderTagGroupingTests {
    @Test("Tags that differ only by case or surrounding space share one section")
    internal func groupsEquivalentTagsTogether() {
        let identifiers = Set(
            ["Work", " work ", "WORK"].map { tagged($0).tagGroupIdentifier }
        )

        #expect(identifiers.count == 1)
    }

    @Test("A blank or absent tag joins the untagged section")
    internal func treatsBlankTagsAsUntagged() {
        for tag in [nil, "", "   \n"] as [String?] {
            let reminder = tagged(tag)

            #expect(reminder.trimmedTag == nil)
            #expect(
                reminder.tagGroupIdentifier
                    == ReminderConstants.Presentation.untaggedGroupIdentifier
            )
        }
    }

    @Test("A tag spelling the untagged label or identifier keeps its own section")
    internal func keepsLookalikeTagsApartFromUntagged() {
        let untagged = tagged(nil).tagGroupIdentifier
        let labelLookalike = tagged(ReminderStrings.noTag).tagGroupIdentifier
        let identifierLookalike = tagged(
            ReminderConstants.Presentation.untaggedGroupIdentifier
        ).tagGroupIdentifier

        #expect(Set([untagged, labelLookalike, identifierLookalike]).count == 3)
    }

    @Test("The shown tag keeps its original capitalization without surrounding space")
    internal func preservesDisplayedTagCapitalization() {
        #expect(tagged("  Home Office ").trimmedTag == "Home Office")
    }

    /// Builds one cached reminder that differs from its siblings only by tag.
    /// - Parameter tag: Stored grouping tag, absent for an untagged reminder.
    /// - Returns: A reminder whose other fields are fixed.
    private func tagged(_ tag: String?) -> ReminderItem {
        ReminderItem(
            id: "reminder-1",
            text: "Renew permit",
            tag: tag,
            ownership: .unknown
        )
    }
}
