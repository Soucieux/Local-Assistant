import Foundation
import Testing

@testable import LocalAssistant

/// The formatter replaces prose that merely repeats a visible card. Replacing prose that
/// does not repeat a card silently deletes the answer, so both directions are pinned.
struct FileCardAnswerFormatterTests {
    @Test("An answer is kept when there are no cards to duplicate")
    internal func keepsAnswerWithoutResults() {
        let answer = "There is nothing indexed yet."
        #expect(FileCardAnswerFormatter.visibleAnswer(from: answer, results: []) == answer)
    }

    @Test("An answer repeating a filename is replaced by the card summary")
    internal func replacesAnswerRepeatingFilename() {
        let result = TestFixtures.result(TestFixtures.item(name: "Report.pdf"))
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: "I found Report.pdf for you.",
            results: [result]
        )
        #expect(visible == RetrievalStrings.fileCardsReady(matchCount: 1))
    }

    @Test("An answer repeating a full path is replaced by the card summary")
    internal func replacesAnswerRepeatingPath() {
        let item = TestFixtures.item(name: "Notes.txt", path: "/Users/example/Documents/Notes.txt")
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: "It lives at /Users/example/Documents/Notes.txt on this Mac.",
            results: [TestFixtures.result(item)]
        )
        #expect(visible == RetrievalStrings.fileCardsReady(matchCount: 1))
    }

    @Test("An answer carrying a source marker is replaced by the card summary")
    internal func replacesAnswerWithSourceMarker() {
        let result = TestFixtures.result(TestFixtures.item(name: "Report.pdf"))
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: "See [1] for details.",
            results: [result]
        )
        #expect(visible == RetrievalStrings.fileCardsReady(matchCount: 1))
    }

    @Test("Ordinary prose is preserved when a folder's name is a common word")
    internal func keepsAnswerMentioningFolderName() {
        // A folder named "Work" must not make every answer containing the word "work"
        // look like a repeat of the card, which previously erased the whole answer.
        let folder = TestFixtures.item(
            name: "Work",
            path: "/Users/example/Work",
            isDirectory: true,
            kind: .folder
        )
        let answer = "That depends on how you want to work with the files."
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: answer,
            results: [TestFixtures.result(folder)]
        )
        #expect(visible == answer)
    }

    @Test("Ordinary prose is preserved when an extensionless file's name is a common word")
    internal func keepsAnswerMentioningExtensionlessFileName() {
        let file = TestFixtures.item(name: "notes", path: "/Users/example/Documents/notes")
        let answer = "I keep notes on that topic in several places."
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: answer,
            results: [TestFixtures.result(file)]
        )
        #expect(visible == answer)
    }

    @Test("A filename match is recognized regardless of letter case")
    internal func matchesFilenameCaseInsensitively() {
        let result = TestFixtures.result(TestFixtures.item(name: "Report.pdf"))
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: "the report.pdf you asked about",
            results: [result]
        )
        #expect(visible == RetrievalStrings.fileCardsReady(matchCount: 1))
    }

    @Test("The summary counts every card, not just the one that matched")
    internal func countsAllResults() {
        let results = [
            TestFixtures.result(TestFixtures.item(name: "Report.pdf")),
            TestFixtures.result(TestFixtures.item(name: "Summary.docx")),
            TestFixtures.result(TestFixtures.item(name: "Notes.txt"))
        ]
        let visible = FileCardAnswerFormatter.visibleAnswer(
            from: "Report.pdf looks closest.",
            results: results
        )
        #expect(visible == RetrievalStrings.fileCardsReady(matchCount: 3))
    }
}
