import Foundation

/// Ranks cached reminders using deterministic identity, FTS, embeddings, and time.
internal actor ReminderRetrievalService {
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
        dateFormatter.locale = Locale(
            identifier: ReminderConstants.DateText.posixLocaleIdentifier
        )
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
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return Array((try await completeList(now: now)).prefix(limit))
        }
        let reminders = try await database.fetchReminders()

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
                explanations[reminder.id] = ReminderStrings.exactReminderMatch
            } else if normalizedQuery.count
                        >= ReminderConstants.Retrieval.queryTokenMinimumLength,
                      normalizedText.contains(normalizedQuery)
                        || normalizedQuery.contains(normalizedText) {
                scores[reminder.id, default: 0] += ReminderConstants.Retrieval.keywordScore
                explanations[reminder.id] = ReminderStrings.reminderTextMatch
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
            explanation: ReminderStrings.reminderKeywordMatch,
            scores: &scores,
            explanations: &explanations
        )
        fuse(
            semanticIDs,
            weight: ReminderConstants.Retrieval.semanticScore,
            explanation: ReminderStrings.reminderSemanticMatch,
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
                explanation: explanations[reminder.id] ?? ReminderStrings.reminderFallbackMatch
            )
        }
        .sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            return reminderSort(left.item, right.item, now: now)
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Returns every row from the latest committed complete snapshot with no retrieval cap.
    /// - Parameter now: Current time used for visible deadline explanations.
    /// - Returns: One result for every cached reminder in database display order.
    /// - Throws: A local database error when the cached snapshot cannot be read.
    internal func completeList(now: Date = Date()) async throws -> [ReminderSearchResult] {
        try await database.fetchReminders().map {
            ReminderSearchResult(
                item: $0,
                score: ReminderConstants.Retrieval.temporalScore,
                explanation: temporalExplanation(for: $0, now: now)
            )
        }
    }

    /// Adds reciprocal-rank evidence from one retrieval channel.
    /// - Parameters:
    ///   - identifiers: Reminder identifiers in that channel's rank order.
    ///   - weight: Channel weight applied before the rank bonus.
    ///   - explanation: Visible reason recorded for a reminder's first matching channel.
    ///   - scores: Accumulated per-reminder scores updated in place.
    ///   - explanations: Accumulated per-reminder explanations updated in place.
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
    /// - Parameter text: Reminder identifier, reminder text, or user query.
    /// - Returns: Case- and diacritic-folded text with surrounding whitespace removed.
    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Orders equal-score reminders by actionable deadline and stable text.
    /// - Parameters:
    ///   - left: First reminder being compared.
    ///   - right: Second reminder being compared.
    ///   - now: Reference time separating overdue reminders from the rest.
    /// - Returns: `true` when the first reminder sorts ahead of the second.
    private func reminderSort(_ left: ReminderItem, _ right: ReminderItem, now: Date) -> Bool {
        let leftDate = parsedDate(left.date) ?? .distantFuture
        let rightDate = parsedDate(right.date) ?? .distantFuture
        let today = calendar.startOfDay(for: now)
        let leftBucket = leftDate < today ? 1 : 0
        let rightBucket = rightDate < today ? 1 : 0
        if leftBucket != rightBucket { return leftBucket < rightBucket }
        if leftDate != rightDate { return leftDate < rightDate }
        let order = left.text.localizedCaseInsensitiveCompare(right.text)
        if order != .orderedSame { return order == .orderedAscending }
        return left.id < right.id
    }

    /// Parses one CloudBase calendar date.
    /// - Parameter value: Optional stored calendar date in `yyyy-MM-dd` form.
    /// - Returns: Parsed date, or `nil` when the reminder is undated or malformed.
    private func parsedDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return dateFormatter.date(from: value)
    }

    /// Creates a concise explanation for the deadline relationship.
    /// - Parameters:
    ///   - reminder: Cached reminder whose deadline is being described.
    ///   - now: Reference time used to resolve today and tomorrow.
    /// - Returns: Visible overdue, today, tomorrow, upcoming, or undated wording.
    private func temporalExplanation(for reminder: ReminderItem, now: Date) -> String {
        guard let date = parsedDate(reminder.date) else { return ReminderStrings.undated }
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        if date < today { return ReminderStrings.overdueReminderMatch }
        if calendar.isDate(date, inSameDayAs: today) { return ReminderStrings.dueTodayReminderMatch }
        if let tomorrow, calendar.isDate(date, inSameDayAs: tomorrow) {
            return ReminderStrings.dueTomorrowReminderMatch
        }
        return ReminderStrings.upcomingReminderMatch
    }

    /// Derives explicit relative or absolute date intent from the query.
    /// - Parameters:
    ///   - text: Natural-language reminder query.
    ///   - now: Reference time used to resolve relative deadline terms.
    /// - Returns: The recognized temporal constraint, or `.none` when the query states none.
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
            of: ReminderConstants.Pattern.embeddedCalendarDate,
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
    /// - Parameters:
    ///   - reminder: Cached reminder being tested.
    ///   - formatter: Formatter matching the stored calendar-date format.
    ///   - calendar: Calendar used to resolve the start of the current day.
    ///   - now: Reference time used for the overdue comparison.
    /// - Returns: `true` when the reminder satisfies this constraint.
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
