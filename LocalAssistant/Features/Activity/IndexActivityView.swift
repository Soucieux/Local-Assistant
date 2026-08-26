import SwiftUI

/// In-window history of automatic monitoring and incremental indexing work.
struct IndexActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTrigger: IndexingTrigger?
    @State private var selectedRootID: UUID?
    @State private var selectedRunState: IndexingRunState?

    var body: some View {
        ZStack {
            CompanionCanvasBackground()

            VStack(spacing: 0) {
                header
                if model.isIndexing {
                    BackgroundIndexingBanner()
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                        overview
                        filters
                        activityRecords
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xLarge)
                    .padding(.vertical, DesignTokens.Spacing.xxLarge)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Places independent monitoring and indexing histories side by side when width permits.
    private var activityRecords: some View {
        Group {
            if filteredEvents.isEmpty {
                indexingHistory
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
                        activityEvents
                            .frame(
                                minWidth: DesignTokens.Window.adaptiveColumnMinimumWidth,
                                maxWidth: .infinity,
                                alignment: .topLeading
                            )
                        indexingHistory
                            .frame(
                                minWidth: DesignTokens.Window.adaptiveColumnMinimumWidth,
                                maxWidth: .infinity,
                                alignment: .topLeading
                            )
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                        activityEvents
                        indexingHistory
                    }
                }
            }
        }
    }

    /// Builds same-window navigation, activity identity, and history deletion.
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                model.showAssistant()
            } label: {
                Label(UIStrings.assistant, systemImage: SystemImages.back)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityLabel(UIStrings.backToAssistant)
            .help(UIStrings.backToAssistant)

            Image(systemName: SystemImages.activity)
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.commandAccent)
                .frame(
                    width: DesignTokens.Control.appIconSize,
                    height: DesignTokens.Control.appIconSize
                )
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(DesignTokens.Color.commandAccent.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.activityTitle)
                    .font(.title3.monospaced().weight(.semibold))
                Text(UIStrings.activityDetail)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
            }

            Spacer()

            Button(UIStrings.clearActivity) {
                model.requestActivityClearConfirmation()
            }
            .buttonStyle(DestructiveActionButtonStyle())
            .disabled(
                model.isIndexing
                    || (model.indexingRuns.isEmpty && model.indexActivityEvents.isEmpty)
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.vertical, DesignTokens.Spacing.medium)
        .background(DesignTokens.Color.commandLightCanvas.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.28))
                .frame(height: 1)
        }
    }

    /// Builds adaptive today and monitoring summary metrics.
    private var overview: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: DesignTokens.Spacing.medium)],
            spacing: DesignTokens.Spacing.medium
        ) {
            activityMetric(
                title: UIStrings.monitoredFolders,
                value: String(model.monitoredRootIDs.count),
                systemImage: SystemImages.monitoring,
                tint: DesignTokens.Color.verifiedLocal
            )
            activityMetric(
                title: UIStrings.newStatus,
                value: String(todayRuns.reduce(0) { $0 + $1.newItems }),
                systemImage: SystemImages.add,
                tint: .blue
            )
            activityMetric(
                title: UIStrings.updatedStatus,
                value: String(todayRuns.reduce(0) { $0 + $1.updatedItems }),
                systemImage: SystemImages.indexedFolders,
                tint: DesignTokens.Color.processing
            )
            activityMetric(
                title: UIStrings.skippedStatus,
                value: String(todayRuns.reduce(0) { $0 + $1.skippedItems }),
                systemImage: SystemImages.stale,
                tint: .red
            )
        }
    }

    /// Builds adaptive source, folder, and run-state filters.
    private var filters: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                    Label(UIStrings.filterHistory, systemImage: SystemImages.filter)
                        .font(.headline.monospaced())
                    Text(UIStrings.filterHistoryDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if hasActiveFilters {
                    Button {
                        clearFilters()
                    } label: {
                        Label(UIStrings.clearFilters, systemImage: SystemImages.reset)
                    }
                    .buttonStyle(
                        TintedActionButtonStyle(tint: DesignTokens.Color.primaryAccent)
                    )
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 180),
                        spacing: DesignTokens.Spacing.medium
                    )
                ],
                spacing: DesignTokens.Spacing.medium
            ) {
                sourceFilter
                folderFilter
                statusFilter
            }
        }
        .padding(DesignTokens.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .fill(DesignTokens.Color.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .stroke(DesignTokens.Color.hairline)
        )
    }

    /// Builds the indexing-source menu field.
    private var sourceFilter: some View {
        filterField(title: UIStrings.sourceFilter, systemImage: SystemImages.source) {
            Picker(UIStrings.sourceFilter, selection: $selectedTrigger) {
                Text(UIStrings.allSources).tag(nil as IndexingTrigger?)
                ForEach(IndexingTrigger.allCases, id: \.self) { trigger in
                    Text(UIStrings.indexingTrigger(trigger)).tag(trigger as IndexingTrigger?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    /// Builds the retained-folder filter, including revoked folders in history.
    private var folderFilter: some View {
        filterField(title: UIStrings.folderFilter, systemImage: SystemImages.folderFilled) {
            Picker(UIStrings.folderFilter, selection: $selectedRootID) {
                Text(UIStrings.allFolders).tag(nil as UUID?)
                ForEach(activityFolders, id: \.id) { folder in
                    Text(folder.name).tag(folder.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    /// Builds the retained run-state filter.
    private var statusFilter: some View {
        filterField(title: UIStrings.statusFilter, systemImage: SystemImages.status) {
            Picker(UIStrings.statusFilter, selection: $selectedRunState) {
                Text(UIStrings.allStatuses).tag(nil as IndexingRunState?)
                ForEach(IndexingRunState.allCases, id: \.self) { state in
                    Text(UIStrings.indexingRunState(state)).tag(state as IndexingRunState?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    /// Wraps one filter menu in a labeled, equal-height field.
    /// - Parameters:
    ///   - title: Visible filter dimension.
    ///   - systemImage: Symbol reinforcing the dimension.
    ///   - content: Native macOS menu picker.
    /// - Returns: Accessible filter field using the activity-card visual language.
    private func filterField<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(DesignTokens.Color.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Color.hairline)
        )
    }

    /// Builds the complete retained monitoring-event timeline.
    private var activityEvents: some View {
        activityCard(title: UIStrings.monitoringEvents) {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                ForEach(filteredEvents) { event in
                    HStack(spacing: DesignTokens.Spacing.medium) {
                        Image(systemName: eventImage(event.kind))
                            .foregroundStyle(eventColor(event.kind))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                            Text(UIStrings.activityEvent(event.kind))
                                .font(.callout.weight(.medium))
                            Text(event.folderName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.occurredAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if event.id != filteredEvents.last?.id { Divider() }
                }
            }
        }
    }

    /// Builds retained run history and its empty state.
    private var indexingHistory: some View {
        activityCard(title: UIStrings.activityHistory) {
            if filteredRuns.isEmpty {
                VStack(spacing: DesignTokens.Spacing.small) {
                    Image(systemName: SystemImages.activity)
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(UIStrings.activityEmptyTitle)
                        .font(.headline)
                    Text(UIStrings.activityEmptyDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.xxLarge)
            } else {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    ForEach(filteredRuns) { run in
                        IndexingRunRow(run: run)
                        if run.id != filteredRuns.last?.id { Divider() }
                    }
                }
            }
        }
    }

    /// Builds one adaptive summary metric tile.
    /// - Parameters:
    ///   - title: Metric label.
    ///   - value: Visible metric value.
    ///   - systemImage: SF Symbol representing the metric.
    ///   - tint: Semantic metric color.
    /// - Returns: Styled metric tile.
    private func activityMetric(
        title: String,
        value: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.monospaced().weight(.bold))
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(tint.opacity(0.13))
        )
    }

    /// Wraps one activity topic in the shared card treatment.
    /// - Parameters:
    ///   - title: Visible card title.
    ///   - content: Activity rows belonging to the topic.
    /// - Returns: Styled activity card.
    private func activityCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(title).font(.headline)
            content()
        }
        .padding(DesignTokens.Spacing.large)
        .cardSurface()
    }

    /// Reports whether any activity filter is narrowing the retained history.
    private var hasActiveFilters: Bool {
        selectedTrigger != nil || selectedRootID != nil || selectedRunState != nil
    }

    /// Restores all activity filter dimensions to their inclusive values.
    private func clearFilters() {
        selectedTrigger = nil
        selectedRootID = nil
        selectedRunState = nil
    }

    /// Returns runs that began today in the current calendar.
    private var todayRuns: [IndexingRunRecord] {
        model.indexingRuns.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    /// Returns runs matching the selected source, folder, and state.
    private var filteredRuns: [IndexingRunRecord] {
        model.indexingRuns.filter { run in
            (selectedTrigger == nil || run.trigger == selectedTrigger)
                && (selectedRootID == nil || run.rootID == selectedRootID)
                && (selectedRunState == nil || run.state == selectedRunState)
        }
    }

    /// Returns automatic monitoring events matching the selected folder.
    private var filteredEvents: [IndexActivityEventRecord] {
        guard selectedTrigger == nil || selectedTrigger == .automatic else { return [] }
        return model.indexActivityEvents.filter { event in
            selectedRootID == nil || event.rootID == selectedRootID
        }
    }

    /// Returns every retained folder identity, including revoked folders.
    private var activityFolders: [(id: UUID, name: String)] {
        var names: [UUID: String] = [:]
        for run in model.indexingRuns { names[run.rootID] = run.folderName }
        for event in model.indexActivityEvents { names[event.rootID] = event.folderName }
        return names.map { (id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Returns a non-color-only symbol for one event kind.
    /// - Parameter kind: Durable event kind.
    /// - Returns: SF Symbol identifier.
    private func eventImage(_ kind: IndexActivityEventKind) -> String {
        switch kind {
        case .monitoringPaused: return SystemImages.paused
        case .monitoringResumed: return SystemImages.resume
        case .indexingFailed: return SystemImages.stale
        case .monitoringUnavailable: return SystemImages.stale
        case .indexingStopped: return SystemImages.paused
        case .changesDetected, .updateScheduled: return SystemImages.automatic
        }
    }

    /// Returns the semantic color for one event kind.
    /// - Parameter kind: Durable event kind.
    /// - Returns: Accessible event tint paired with text and a symbol.
    private func eventColor(_ kind: IndexActivityEventKind) -> Color {
        switch kind {
        case .monitoringPaused, .indexingFailed, .monitoringUnavailable: return .red
        case .indexingStopped: return DesignTokens.Color.processing
        case .monitoringResumed: return DesignTokens.Color.verifiedLocal
        case .changesDetected, .updateScheduled: return DesignTokens.Color.primaryAccent
        }
    }
}

/// Expandable retained summary for one indexing run.
private struct IndexingRunRow: View {
    @Environment(AppModel.self) private var model
    let run: IndexingRunRecord
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                if let items = model.indexingItemsByRun[run.id] {
                    if items.isEmpty {
                        Text(UIStrings.noFileDetails)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
                                Image(systemName: SystemImages.document)
                                    .foregroundStyle(itemColor(item.state))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                                    Text(item.displayName)
                                        .font(.callout.weight(.medium))
                                    Text(item.relativePath)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if let detail = item.detail {
                                        Text(detail)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(UIStrings.indexingItemState(item.state))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(itemColor(item.state))
                            }
                            .padding(.vertical, DesignTokens.Spacing.xSmall)
                        }
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.top, DesignTokens.Spacing.medium)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                        Text(run.folderName).font(.callout.weight(.semibold))
                        Text(run.folderPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    StatusPill(
                        title: UIStrings.indexingRunState(run.state),
                        systemImage: run.state == .completed
                            ? SystemImages.completed
                            : SystemImages.activity,
                        tint: runColor(run.state)
                    )
                }
                HStack {
                    Text(UIStrings.indexingTrigger(run.trigger))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignTokens.Color.primaryAccent)
                    Text(UIStrings.listSeparator)
                    Text(run.startedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                IndexingSummaryBadges(
                    newItems: run.newItems,
                    updatedItems: run.updatedItems,
                    unchangedItems: run.unchangedItems,
                    removedItems: run.removedItems,
                    skippedItems: run.skippedItems
                )
            }
            .padding(.vertical, DesignTokens.Spacing.small)
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                Task { await model.loadIndexingItems(runID: run.id) }
            }
        }
    }

    /// Returns the semantic color for one run lifecycle state.
    /// - Parameter state: Durable run state.
    /// - Returns: Accessible tint paired with the visible state label.
    private func runColor(_ state: IndexingRunState) -> Color {
        switch state {
        case .completed: return DesignTokens.Color.verifiedLocal
        case .running: return DesignTokens.Color.processing
        case .stopped: return .secondary
        case .failed: return .red
        }
    }

    /// Returns the semantic color for one file-level indexing state.
    /// - Parameter state: Durable file state.
    /// - Returns: Accessible tint paired with the visible state label.
    private func itemColor(_ state: IndexingItemState) -> Color {
        switch state {
        case .newWaiting, .newIndexing, .newIndexed: return .blue
        case .modifiedWaiting, .modifiedUpdating, .modifiedUpdated: return .orange
        case .unchanged: return .secondary
        case .missingPendingRemoval, .removedFromIndex: return .purple
        case .skipped: return .red
        }
    }
}
