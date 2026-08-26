import SwiftUI

/// Presentational subviews, button styles, and shapes used by the command surface.
///
/// Each type manages its own environment and state; none reads AssistantCommandView's
/// private members, so they live apart from its input-handling logic.
/// Compact live-indexing strip that preserves pause and activity controls.
struct CommandIndexingStrip: View {
    @Environment(AppModel.self) private var model

    /// Builds the background-indexing state in the command visual language.
    var body: some View {
        let progress = model.indexingProgress
        HStack(spacing: DesignTokens.Spacing.medium) {
            Label(
                UIStrings.commandIndexingCompact,
                systemImage: SystemImages.monitoring
            )
            .font(.caption2.monospaced().weight(.bold))
            .tracking(0.8)
            .foregroundStyle(DesignTokens.Color.commandAccent)

            if let folderName = progress.folderName {
                Text(folderName.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if progress.totalItems > 0 {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
                    .tint(DesignTokens.Color.commandAccent)
                    .frame(maxWidth: 170)
                Text(
                    UIStrings.indexingProgress(
                        processed: progress.processedItems,
                        total: progress.totalItems,
                        fraction: progress.fractionCompleted
                    )
                )
                .font(.caption2.monospaced())
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(1)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(DesignTokens.Color.commandAccent)
                Text(UIStrings.scanningForChanges.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
                    .lineLimit(1)
            }

            Button(UIStrings.activity.uppercased()) {
                model.showActivity()
            }
            .buttonStyle(CommandRailButtonStyle())

            if let rootID = progress.rootID {
                Button(
                    progress.state == .stopping
                        ? UIStrings.pausingIndexing.uppercased()
                        : UIStrings.pauseIndexing.uppercased()
                ) {
                    model.pauseIndexing(rootID: rootID)
                }
                .buttonStyle(CommandRailButtonStyle(tint: DesignTokens.Color.commandAccent))
                .disabled(progress.state == .stopping)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(DesignTokens.Color.commandAccent.opacity(0.055))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.commandAccent.opacity(0.32))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Minimal local-processing state shown while the latest answer is prepared.
struct ProcessingIndicator: View {
    /// Builds a centered acquisition signal using the command visual language.
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Text(UIStrings.commandProcessing)
                .font(.caption.monospaced().weight(.bold))
                .tracking(1.6)
                .foregroundStyle(DesignTokens.Color.commandAccent)
            ProgressView()
                .progressViewStyle(.linear)
                .tint(DesignTokens.Color.commandAccent)
                .frame(maxWidth: DesignTokens.Command.sectionRuleWidth * 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

/// Centered latest answer without a conversational bubble.
struct CommandResponseView: View {
    let message: ChatMessage

    /// Builds the current response label and selectable rich text.
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            Text(UIStrings.commandResponse)
                .font(.caption2.monospaced().weight(.bold))
                .tracking(1.6)
                .foregroundStyle(DesignTokens.Color.commandAccent)

            Text(renderedText)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineSpacing(DesignTokens.Message.lineSpacing + 2)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: DesignTokens.Command.responseMaximumWidth)
        .padding(.horizontal, DesignTokens.Spacing.large)
    }

    /// Rich local response text with links rendered inert.
    private var renderedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        var attributedText =
            (try? AttributedString(markdown: message.text, options: options))
            ?? AttributedString(message.text)
        let linkedRanges = attributedText.runs.compactMap { run in
            run.link == nil ? nil : run.range
        }
        for linkedRange in linkedRanges {
            attributedText[linkedRange].link = nil
        }
        return attributedText
    }
}

/// Adaptive grid of the latest files identified for the current request.
struct CommandFindingsGrid: View {
    let results: [SearchResult]

    /// Builds a centered acquisition label and responsive file grid.
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            CommandSectionLabel(
                title: UIStrings.commandFindingsLabel(count: results.count)
            )

            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.medium) {
                ForEach(Array(results.enumerated()), id: \.element.id) { offset, result in
                    CommandFindingCard(result: result, index: offset + 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Responsive columns that place multiple findings in a row when width allows.
    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: DesignTokens.Command.findingMinimumWidth),
                spacing: DesignTokens.Spacing.medium,
                alignment: .top
            )
        ]
    }
}

/// Adaptive grid of reminder matches from the latest local snapshot.
struct CommandReminderFindingsGrid: View {
    let results: [ReminderSearchResult]
    let presentation: ReminderCardPresentation

    /// Builds a focused or tag-grouped reminder result surface.
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            CommandSectionLabel(
                title: ReminderStrings.reminderCount(results.count).uppercased()
            )

            if presentation == .grouped {
                VStack(spacing: DesignTokens.Spacing.xLarge) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                            ReminderTagSectionHeader(group: group)
                            LazyVGrid(
                                columns: columns,
                                alignment: .leading,
                                spacing: DesignTokens.Spacing.medium
                            ) {
                                ForEach(group.results) { result in
                                    CommandReminderSummaryCard(
                                        result: result,
                                        tint: group.tint
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: DesignTokens.Spacing.medium
                ) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { offset, result in
                        CommandReminderCard(result: result, index: offset + 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Responsive columns that reflow continuously with the live window width.
    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: DesignTokens.Command.findingMinimumWidth),
                spacing: DesignTokens.Spacing.medium,
                alignment: .top
            )
        ]
    }

    /// Preserves reminder order while grouping equivalent tags case-insensitively.
    private var groups: [ReminderCardGroup] {
        var groups: [ReminderCardGroup] = []
        var groupIndices: [String: Int] = [:]
        for result in results {
            let suppliedTag = result.item.tag?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? AppConstants.Text.empty
            let isUntagged = suppliedTag.isEmpty
            let normalizedTag = suppliedTag.lowercased()
            let identifier = isUntagged
                ? ReminderConstants.Presentation.untaggedGroupIdentifier
                : ReminderConstants.Presentation.tagGroupPrefix + normalizedTag
            if let index = groupIndices[identifier] {
                groups[index].results.append(result)
            } else {
                groupIndices[identifier] = groups.count
                groups.append(
                    ReminderCardGroup(
                        id: identifier,
                        title: isUntagged ? ReminderStrings.noTag : suppliedTag,
                        isUntagged: isUntagged,
                        results: [result]
                    )
                )
            }
        }
        return groups
    }
}

/// Stable tag section derived from the existing reminder result order.
private struct ReminderCardGroup: Identifiable {
    let id: String
    let title: String
    let isUntagged: Bool
    var results: [ReminderSearchResult]

    /// Deterministic section accent that never acts as the only tag identifier.
    var tint: Color {
        DesignTokens.Color.reminderTag(id, isUntagged: isUntagged)
    }
}

/// Full-width tag identity above one adaptive reminder grid.
private struct ReminderTagSectionHeader: View {
    let group: ReminderCardGroup

    /// Builds tag name, semantic accent, and item count.
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(group.tint)
                .frame(width: 5, height: 24)
            Text(group.title)
                .font(.headline.monospaced())
                .foregroundStyle(DesignTokens.Color.commandInk)
            Spacer()
            Text(ReminderStrings.reminderCount(group.results.count))
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(DesignTokens.Color.commandMutedInk)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Compact reminder used when a list already supplies tag context in its section header.
private struct CommandReminderSummaryCard: View {
    let result: ReminderSearchResult
    let tint: Color

    /// Builds reminder text, deadline status, timing, and optional-link signal.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(tint.opacity(0.14))
                    Image(systemName: SystemImages.reminder)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)

                Spacer(minLength: DesignTokens.Spacing.small)

                Text(urgency.title.uppercased())
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(urgency.tint)
                    .padding(.horizontal, DesignTokens.Spacing.small)
                    .padding(.vertical, DesignTokens.Spacing.xSmall)
                    .background(urgency.tint.opacity(0.11))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                            .stroke(urgency.tint.opacity(0.38), lineWidth: 1)
                    }
            }

            Text(result.item.text)
                .font(.body.monospaced().weight(.semibold))
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
                .textSelection(.enabled)

            Rectangle()
                .fill(tint.opacity(0.72))
                .frame(height: 1)

            HStack(alignment: .center, spacing: DesignTokens.Spacing.small) {
                Label(reminderTiming, systemImage: SystemImages.deadline)
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
                    .lineLimit(1)

                Spacer(minLength: DesignTokens.Spacing.small)

                if hasLink {
                    Label(ReminderStrings.linkIncluded, systemImage: SystemImages.link)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(tint)
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(
            maxWidth: .infinity,
            minHeight: DesignTokens.Command.reminderSummaryCardHeight,
            maxHeight: DesignTokens.Command.reminderSummaryCardHeight,
            alignment: .topLeading
        )
        .background {
            ZStack {
                DesignTokens.Color.commandLightCanvas.opacity(0.90)
                LinearGradient(
                    colors: [tint.opacity(0.14), tint.opacity(0.025)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .stroke(tint.opacity(0.62), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            CommandAcquisitionCorner(tint: tint)
        }
        .overlay(alignment: .bottomTrailing) {
            CommandAcquisitionCorner(tint: tint)
                .rotationEffect(.degrees(180))
        }
        .shadow(color: tint.opacity(0.08), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
    }

    /// Formats the stored CloudBase date and optional start time.
    private var reminderTiming: String {
        let date = result.item.date ?? ReminderStrings.undated
        guard let start = result.item.startTime else { return date }
        return "\(date) · \(start)"
    }

    /// Reports whether the reminder contains a non-empty external link field.
    private var hasLink: Bool {
        guard let link = result.item.link?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) else {
            return false
        }
        return link.isEmpty == false
    }

    /// Deadline relationship derived entirely from the cached calendar date.
    private var urgency: ReminderUrgency {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(
            identifier: ReminderConstants.DateText.posixLocaleIdentifier
        )
        formatter.dateFormat = ReminderConstants.DateText.calendarDateFormat
        formatter.isLenient = false
        guard let value = result.item.date,
              let date = formatter.date(from: value) else {
            return .undated
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if date < today { return .overdue }
        if calendar.isDate(date, inSameDayAs: today) { return .today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return .tomorrow
        }
        return .upcoming
    }
}

/// Compact deadline categories used by reminder-list cards.
private enum ReminderUrgency {
    case overdue
    case today
    case tomorrow
    case upcoming
    case undated

    /// Plain-language urgency label.
    var title: String {
        switch self {
        case .overdue: return ReminderStrings.overdue
        case .today: return ReminderStrings.dueToday
        case .tomorrow: return ReminderStrings.dueTomorrow
        case .upcoming: return ReminderStrings.upcoming
        case .undated: return ReminderStrings.undated
        }
    }

    /// Semantic status color paired with the visible urgency label.
    var tint: Color {
        switch self {
        case .overdue: return DesignTokens.Color.destructive
        case .today: return DesignTokens.Color.commandAccent
        case .tomorrow: return DesignTokens.Color.processing
        case .upcoming: return DesignTokens.Color.verifiedLocal
        case .undated: return DesignTokens.Color.commandMutedInk
        }
    }
}

/// One square-edged reminder match with time and ownership evidence.
struct CommandReminderCard: View {
    let result: ReminderSearchResult
    let index: Int

    /// Builds reminder identity, deadline, ownership, and rank explanation.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(UIStrings.commandFindingNumber(index))
                .font(.title3.monospaced().weight(.bold))
                .foregroundStyle(DesignTokens.Color.commandAccent)

            Text(result.item.text)
                .font(.body.monospaced().weight(.semibold))
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(3)
                .textSelection(.enabled)

            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.72))
                .frame(height: 1)

            Label(reminderTiming, systemImage: SystemImages.deadline)
                .font(.caption2.monospaced().weight(.medium))
                .foregroundStyle(DesignTokens.Color.commandMutedInk)

            Text(ownershipTitle.uppercased())
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(ownershipColor)

            Text(result.explanation)
                .font(.caption2.monospaced())
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(2)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(
            maxWidth: .infinity,
            minHeight: DesignTokens.Command.reminderFocusedCardHeight,
            maxHeight: DesignTokens.Command.reminderFocusedCardHeight,
            alignment: .topLeading
        )
        .background(DesignTokens.Color.commandLightCanvas.opacity(0.86))
        .overlay {
            Rectangle()
                .stroke(DesignTokens.Color.commandInk.opacity(0.72), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            CommandAcquisitionCorner()
        }
        .overlay(alignment: .bottomTrailing) {
            CommandAcquisitionCorner()
                .rotationEffect(.degrees(180))
        }
        .accessibilityElement(children: .contain)
    }

    /// Formats the stored CloudBase date and optional start time.
    private var reminderTiming: String {
        let date = result.item.date ?? ReminderStrings.undated
        guard let start = result.item.startTime else { return date }
        return "\(date) · \(start)"
    }

    /// Maps reminder ownership to explicit card copy.
    private var ownershipTitle: String {
        switch result.item.ownership {
        case .localAssistant: ReminderStrings.ownerLocalAssistant
        case .openClaw: ReminderStrings.ownerOpenClaw
        case .unknown: ReminderStrings.ownerUnknown
        }
    }

    /// Maps reminder ownership to a supporting tint.
    private var ownershipColor: Color {
        switch result.item.ownership {
        case .localAssistant: DesignTokens.Color.verifiedLocal
        case .openClaw: DesignTokens.Color.voice
        case .unknown: DesignTokens.Color.processing
        }
    }
}

/// Hairline label separating the answer from acquired file findings.
struct CommandSectionLabel: View {
    let title: String

    /// Builds a tracked label between two horizontal rules.
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.64))
                .frame(maxWidth: DesignTokens.Command.sectionRuleWidth, maxHeight: 1)
            Text(title)
                .font(.caption2.monospaced().weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(1)
            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.64))
                .frame(maxWidth: DesignTokens.Command.sectionRuleWidth, maxHeight: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// One square-edged file acquisition module with explicit read-only actions.
struct CommandFindingCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var acquired = false
    let result: SearchResult
    let index: Int

    /// Builds file identity, match evidence, actions, and acquisition markers.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(UIStrings.commandFindingNumber(index))
                .font(.title3.monospaced().weight(.bold))
                .foregroundStyle(DesignTokens.Color.commandAccent)

            Text(result.item.displayName)
                .font(.body.monospaced().weight(.semibold))
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(2)
                .textSelection(.enabled)

            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.72))
                .frame(height: 1)

            Label(
                UIStrings.fileType(result.item.kind).uppercased(),
                systemImage: SystemImages.fileType(result.item.kind)
            )
            .font(.caption2.monospaced().weight(.medium))
            .foregroundStyle(DesignTokens.Color.commandMutedInk)

            Text(result.explanation)
                .font(.caption2.monospaced())
                .foregroundStyle(DesignTokens.Color.commandInk)
                .lineLimit(3)

            HStack(spacing: 0) {
                Button(UIStrings.revealInFinder.uppercased()) {
                    Task { await model.reveal(result.item) }
                }
                .buttonStyle(CommandFileActionButtonStyle())
                .disabled(isAvailable == false)

                Rectangle()
                    .fill(DesignTokens.Color.commandInk.opacity(0.72))
                    .frame(width: 1, height: 12)

                Button(UIStrings.openItem(result.item.kind).uppercased()) {
                    Task { await model.open(result.item) }
                }
                .buttonStyle(CommandFileActionButtonStyle())
                .disabled(isAvailable == false)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DesignTokens.Color.commandLightCanvas.opacity(0.86))
        .overlay {
            Rectangle()
                .stroke(DesignTokens.Color.commandInk.opacity(0.72), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            CommandAcquisitionCorner()
        }
        .overlay(alignment: .bottomTrailing) {
            CommandAcquisitionCorner()
                .rotationEffect(.degrees(180))
        }
        .opacity(acquired ? 1 : 0.16)
        .scaleEffect(acquired ? 1 : 0.985)
        .onAppear {
            if reduceMotion {
                acquired = true
            } else {
                withAnimation(
                    .easeOut(duration: DesignTokens.Motion.acquisitionDuration)
                        .delay(Double(index - 1) * DesignTokens.Motion.acquisitionStagger)
                ) {
                    acquired = true
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Whether the saved file still belongs to an authorized current index.
    private var isAvailable: Bool {
        model.isFileMatchAvailable(result.item.id)
    }
}

/// Right-angle marker indicating one acquired result module.
struct CommandAcquisitionCorner: View {
    let tint: Color

    /// Creates a corner with the command accent by default or a semantic card tint.
    /// - Parameter tint: Visible acquisition-marker color.
    internal init(tint: Color = DesignTokens.Color.commandAccent) {
        self.tint = tint
    }

    /// Builds a square corner from two tinted rules.
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(tint)
                .frame(
                    width: DesignTokens.Command.acquisitionCornerLength,
                    height: DesignTokens.Command.acquisitionCornerWidth
                )
            Rectangle()
                .fill(tint)
                .frame(
                    width: DesignTokens.Command.acquisitionCornerWidth,
                    height: DesignTokens.Command.acquisitionCornerLength
                )
        }
        .offset(
            x: -DesignTokens.Command.acquisitionCornerWidth,
            y: -DesignTokens.Command.acquisitionCornerWidth
        )
    }
}

/// Plain telemetry-rail style for header navigation.
struct CommandHeaderButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Builds a restrained header control with a square pressed state.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: Styled header navigation control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DesignTokens.Color.commandInk)
            .padding(.horizontal, DesignTokens.Command.headerControlHorizontalPadding)
            .frame(height: DesignTokens.Command.headerControlHeight)
            .background(
                Rectangle()
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Color.commandInk.opacity(0.08)
                            : Color.clear
                    )
            )
            .opacity(isEnabled ? 1 : 0.42)
            .buttonHoverFeedback(tint: DesignTokens.Color.commandInk)
    }
}

/// Small square-edged action used by the live-indexing rail.
struct CommandRailButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let tint: Color

    /// Creates a rail action with an optional semantic tint.
    /// - Parameter tint: Foreground and border color for the action.
    internal init(tint: Color = DesignTokens.Color.commandInk) {
        self.tint = tint
    }

    /// Builds the compact bordered rail action.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: Square-edged action with pressed and disabled feedback.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.xSmall)
            .background(
                Rectangle()
                    .fill(tint.opacity(configuration.isPressed ? 0.12 : 0.035))
            )
            .overlay {
                Rectangle()
                    .stroke(tint.opacity(0.68), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.42)
            .buttonHoverFeedback(tint: tint)
    }
}

/// Equal-width text action used inside an acquired file module.
struct CommandFileActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Builds a plain file action with stable square geometry.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: Equal-width text action with pressed and disabled feedback.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(DesignTokens.Color.commandInk)
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(
                Rectangle()
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Color.commandInk.opacity(0.08)
                            : Color.clear
                    )
            )
            .opacity(isEnabled ? 1 : 0.38)
            .buttonHoverFeedback(tint: DesignTokens.Color.commandInk)
    }
}

/// Triangular voice and submit marker adapted from the supplied visual reference.
struct CommandTriangle: Shape {
    /// Draws a centered triangle inside the offered rectangle.
    /// - Parameter rect: Bounds available for the marker.
    /// - Returns: Closed triangular path.
    internal func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
