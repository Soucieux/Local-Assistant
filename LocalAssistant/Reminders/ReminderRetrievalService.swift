import Foundation

/// Ranks cached reminders using deterministic identity, FTS, embeddings, and time.
actor ReminderRetrievalService {
    private let database: AssistantDatabase
    private let embeddings: LocalEmbeddingService
    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    /// Creates the local-only reminder retrieval pipeline.
    /// - Parameters:
    ///   - database: Private complete-snapshot cache.
    ///   - embeddings: Embedded local semantic model.
    ///   - calendar: Calendar used for relative deadline terms.
    internal init(
        database: AssistantDatabase,
        embeddings: LocalEmbeddingService,
        calendar: Calendar = .current
    ) {
        self.database = database
        self.embeddings = embeddings
        self.calendar = calendar
        dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = ReminderConstants.DateText.calendarDateFormat
    }

    /// Searches the latest complete snapshot without contacting CloudBase.
    /// - Parameters:
    ///   - text: Natural-language reminder query.
    ///   - limit: Maximum results returned to the caller.
    ///   - now: Current time used for deterministic temporal ranking.
    /// - Returns: Locally ranked reminder cards.
    /// - Throws: A local database error when the cache cannot be read.
    internal func search(
        text: String,
        limit: Int = ReminderConstants.Retrieval.defaultLimit,
        now: Date = Date()
    ) async throws -> [ReminderSearchResult] {
        guard limit > 0 else { return [] }
        let reminders = try await database.fetchReminders()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return Array(reminders.prefix(limit)).map {
                ReminderSearchResult(
                    item: $0,
                    score: ReminderConstants.Retrieval.temporalScore,
                    explanation: temporalExplanation(for: $0, now: now)
                )
            }
        }

        let keywordIDs = try await database.reminderKeywordSearch(
            text: query,
            limit: ReminderConstants.Retrieval.maximumKeywordCandidates
        )
        let semanticIDs: [String]
        if let queryEmbedding = try? await embeddings.embedQuery(query) {
            semanticIDs = try await database.reminderSemanticSearch(
                embedding: queryEmbedding,
                limit: ReminderConstants.Retrieval.maximumVectorCandidates
            )
        } else {
            semanticIDs = []
        }

        let normalizedQuery = normalized(query)
        let temporalIntent = temporalIntent(in: query, now: now)
        var scores: [String: Double] = [:]
        var explanations: [String: String] = [:]

        for reminder in reminders {
            let normalizedID = normalized(reminder.id)
            let normalizedText = normalized(reminder.text)
            if normalizedID == normalizedQuery || normalizedText == normalizedQuery {
                scores[reminder.id, default: 0] += ReminderConstants.Retrieval.exactIdentifierScore
                explanations[reminder.id] = "Exact reminder match"
            } else if normalizedQuery.count
                        >= ReminderConstants.Retrieval.queryTokenMinimumLength,
                      normalizedText.contains(normalizedQuery)
                        || normalizedQuery.contains(normalizedText) {
                scores[reminder.id, default: 0] += ReminderConstants.Retrieval.keywordScore
                explanations[reminder.id] = "Reminder text match"
            }
            if temporalIntent.matches(
                reminder: reminder,
                formatter: dateFormatter,
                calendar: calendar,
                now: now
            ) {
                scores[reminder.id, default: 0] += ReminderConstants.Retrieval.temporalScore
                explanations[reminder.id] = temporalExplanation(for: reminder, now: now)
            }
        }

        fuse(
            keywordIDs,
            weight: ReminderConstants.Retrieval.keywordScore,
            explanation: "Keyword and field match",
            scores: &scores,
            explanations: &explanations
        )
        fuse(
            semanticIDs,
            weight: ReminderConstants.Retrieval.semanticScore,
            explanation: "Related reminder meaning",
            scores: &scores,
            explanations: &explanations
        )

        return reminders.compactMap { reminder -> ReminderSearchResult? in
            guard let score = scores[reminder.id],
                  score >= ReminderConstants.Retrieval.minimumDisplayScore else {
                return nil
            }
            return ReminderSearchResult(
                item: reminder,
                score: score,
                explanation: explanations[reminder.id] ?? "Local reminder match"
            )
        }
        .sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            return reminderSort(left.item, right.item, now: now)
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Adds reciprocal-rank evidence from one retrieval channel.
    private func fuse(
        _ identifiers: [String],
        weight: Double,
        explanation: String,
        scores: inout [String: Double],
        explanations: inout [String: String]
    ) {
        for (offset, identifier) in identifiers.enumerated() {
            let rank = Double(offset + 1)
            scores[identifier, default: 0] += weight * (
                1 + 1 / (ReminderConstants.Retrieval.reciprocalRankOffset + rank)
            )
            if explanations[identifier] == nil {
                explanations[identifier] = explanation
            }
        }
    }

    /// Normalizes identity and text comparisons without changing stored content.
    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Orders equal-score reminders by actionable deadline and stable text.
    private func reminderSort(_ left: ReminderItem, _ right: ReminderItem, now: Date) -> Bool {
        let leftDate = parsedDate(left.date) ?? .distantFuture
        let rightDate = parsedDate(right.date) ?? .distantFuture
        let today = calendar.startOfDay(for: now)
        let leftBucket = leftDate < today ? 1 : 0
        let rightBucket = rightDate < today ? 1 : 0
        if leftBucket != rightBucket { return leftBucket < rightBucket }
        if leftDate != rightDate { return leftDate < rightDate }
        return left.text.localizedCaseInsensitiveCompare(right.text) == .orderedAscending
    }

    /// Parses one CloudBase calendar date.
    private func parsedDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return dateFormatter.date(from: value)
    }

    /// Creates a concise explanation for the deadline relationship.
    private func temporalExplanation(for reminder: ReminderItem, now: Date) -> String {
        guard let date = parsedDate(reminder.date) else { return ReminderStrings.undated }
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        if date < today { return "Overdue reminder" }
        if calendar.isDate(date, inSameDayAs: today) { return "Due today" }
        if let tomorrow, calendar.isDate(date, inSameDayAs: tomorrow) { return "Due tomorrow" }
        return "Upcoming reminder"
    }

    /// Derives explicit relative or absolute date intent from the query.
    private func temporalIntent(in text: String, now: Date) -> ReminderTemporalIntent {
        let normalizedText = normalized(text)
        if normalizedText.contains(ReminderConstants.DateText.today) {
            return .date(dateFormatter.string(from: calendar.startOfDay(for: now)))
        }
        if normalizedText.contains(ReminderConstants.DateText.tomorrow),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            return .date(dateFormatter.string(from: tomorrow))
        }
        if normalizedText.contains(ReminderConstants.DateText.overdue) {
            return .overdue
        }
        if let range = text.range(
            of: #"\b\d{4}-\d{2}-\d{2}\b"#,
            options: .regularExpression
        ) {
            return .date(String(text[range]))
        }
        return .none
    }
}

/// Explicit temporal constraint recognized in a local reminder query.
private enum ReminderTemporalIntent {
    case none
    case date(String)
    case overdue

    /// Reports whether one reminder satisfies this temporal constraint.
    fileprivate func matches(
        reminder: ReminderItem,
        formatter: DateFormatter,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        switch self {
        case .none:
            return false
        case .date(let value):
            return reminder.date == value
        case .overdue:
            guard let value = reminder.date,
                  let date = formatter.date(from: value) else {
                return false
            }
            return date < calendar.startOfDay(for: now)
        }
    }
}
