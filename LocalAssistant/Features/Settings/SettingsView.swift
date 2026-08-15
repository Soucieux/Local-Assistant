import SwiftUI

/// Folder authorization, shortcut, model, and privacy controls.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var rootPendingRevocation: AuthorizedRoot?

    /// Builds same-window Settings with stable navigation and adaptive content.
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignTokens.Color.canvas,
                    DesignTokens.Color.primaryAccent.opacity(0.025),
                    DesignTokens.Color.verifiedLocal.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                settingsHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                        privacySection
                        folderAccessSection
                        modelsSection
                        assistantStatusSection
                    }
                    .frame(maxWidth: DesignTokens.Window.contentMaximumWidth)
                    .padding(.horizontal, DesignTokens.Spacing.xLarge)
                    .padding(.vertical, DesignTokens.Spacing.xxLarge)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .alert(
            UIStrings.revokeAccessTitle,
            isPresented: revocationAlertIsPresented
        ) {
            Button(UIStrings.revokeAccess, role: .destructive) {
                guard let root = rootPendingRevocation else { return }
                rootPendingRevocation = nil
                Task { await model.remove(root: root) }
            }
            Button(UIStrings.cancel, role: .cancel) {
                rootPendingRevocation = nil
            }
        } message: {
            Text(
                UIStrings.revokeAccessMessage(
                    folderName: rootPendingRevocation?.displayName
                        ?? AppConstants.Text.empty
                )
            )
        }
    }

    /// Provides a writable binding for the folder-revocation confirmation alert.
    private var revocationAlertIsPresented: Binding<Bool> {
        Binding(
            get: { rootPendingRevocation != nil },
            set: { isPresented in
                if isPresented == false {
                    rootPendingRevocation = nil
                }
            }
        )
    }

    /// Builds fixed same-panel navigation and a compact Settings identity.
    private var settingsHeader: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                model.showAssistant()
            } label: {
                Label(UIStrings.assistant, systemImage: SystemImages.back)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityLabel(UIStrings.backToAssistant)
            .help(UIStrings.backToAssistant)

            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Color.primaryAction,
                                DesignTokens.Color.voiceFill
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: SystemImages.settings)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(
                width: DesignTokens.Control.appIconSize,
                height: DesignTokens.Control.appIconSize
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.settingsTitle)
                    .font(.title3.weight(.bold))
                Text(UIStrings.settingsDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.vertical, DesignTokens.Spacing.medium)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.hairline)
                .frame(height: 1)
        }
    }

    /// Presents the fixed global shortcut without duplicating model readiness.
    private var assistantStatusSection: some View {
        settingsCard(
            title: UIStrings.assistantStatus,
            detail: UIStrings.assistantStatusDescription,
            systemImage: SystemImages.assistant,
            tint: DesignTokens.Color.primaryAccent
        ) {
            shortcutStatusTile
        }
    }

    /// Presents plain-language readiness for chat, file search, and voice input.
    private var modelsSection: some View {
        settingsCard(
            title: UIStrings.modelStatus,
            detail: UIStrings.modelsSectionDescription,
            systemImage: SystemImages.model,
            tint: modelStatusColor
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.medium) {
                    ZStack {
                        Circle()
                            .fill(modelStatusColor.opacity(0.12))
                        Image(systemName: modelStatusImage)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(modelStatusColor)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                        Text(modelStatusTitle)
                            .font(.headline)
                        Text(modelStatusDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DesignTokens.Spacing.small)

                    StatusPill(
                        title: UIStrings.modelReadinessCount(
                            ready: readyModelCapabilityCount,
                            total: displayedModelCapabilities.count
                        ),
                        systemImage: modelStatusImage,
                        tint: modelStatusColor
                    )
                }

                VStack(spacing: 0) {
                    ForEach(Array(displayedModelCapabilities.enumerated()), id: \.element.id) {
                        index,
                        capability in
                        modelCapabilityRow(capability)
                        if index < displayedModelCapabilities.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(DesignTokens.Color.subtleFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .stroke(DesignTokens.Color.hairline)
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DesignTokens.Spacing.large) {
                        Label(
                            UIStrings.modelStorageUsage(model.modelStorageByteCount),
                            systemImage: SystemImages.localDatabase
                        )
                        Spacer()
                        Label(
                            UIStrings.modelsCheckedOnLaunch,
                            systemImage: SystemImages.localVerified
                        )
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        Label(
                            UIStrings.modelStorageUsage(model.modelStorageByteCount),
                            systemImage: SystemImages.localDatabase
                        )
                        Label(
                            UIStrings.modelsCheckedOnLaunch,
                            systemImage: SystemImages.localVerified
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Builds authorized-folder controls, revocation, and indexing progress.
    private var folderAccessSection: some View {
        settingsCard(
            title: UIStrings.folderAccess,
            detail: UIStrings.folderAccessDescription,
            systemImage: SystemImages.indexedFolders,
            tint: DesignTokens.Color.primaryAccent
        ) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Button {
                    Task { await model.addIndexedRoot() }
                } label: {
                    Label(UIStrings.addFolder, systemImage: SystemImages.add)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(model.isBusy)

                if model.indexedRoots.count > 1 {
                    Button {
                        model.indexAll()
                    } label: {
                        Label(
                            UIStrings.updateAllFolders,
                            systemImage: SystemImages.indexedFolders
                        )
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(model.isBusy)
                }

                Spacer()

                StatusPill(
                    title: UIStrings.readOnlyAccess,
                    systemImage: SystemImages.lock,
                    tint: DesignTokens.Color.verifiedLocal
                )
            }

            if model.indexedRoots.isEmpty {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Image(systemName: SystemImages.folder)
                        .foregroundStyle(DesignTokens.Color.primaryAccent)
                    Text(UIStrings.noAuthorizedFolders)
                        .foregroundStyle(.secondary)
                }
                .padding(DesignTokens.Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(DesignTokens.Color.subtleFill)
                )
            } else {
                ForEach(model.indexedRoots) { root in
                    folderRow(root)
                }
            }

        }
    }

    /// Builds the quick-call tile with individually styled keyboard keys.
    private var shortcutStatusTile: some View {
        statusTile(tint: shortcutStatusColor) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.small) {
                    Label(UIStrings.quickCallShortcut, systemImage: SystemImages.shortcut)
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Color.graphite)

                    Spacer(minLength: DesignTokens.Spacing.small)

                    StatusPill(
                        title: shortcutStatusTitle,
                        systemImage: shortcutStatusImage,
                        tint: shortcutStatusColor
                    )
                }

                Text(
                    model.isShortcutAvailable
                        ? UIStrings.shortcutAvailableDescription
                        : UIStrings.shortcutUnavailableDescription
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DesignTokens.Spacing.small) {
                    shortcutKey(UIStrings.shortcutKeyControl)
                    shortcutKey(UIStrings.shortcutKeyOption)
                    shortcutKey(UIStrings.shortcutKeySpace)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(UIStrings.shortcutAccessibleKeys)
            }
        }
    }

    /// Restores the prominent privacy statement and its supporting local-storage facts.
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Label(UIStrings.privacyTitle, systemImage: SystemImages.localVerified)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DesignTokens.Color.verifiedLocal)
                Text(UIStrings.privacySummary)
                    .font(.title3)
                    .foregroundStyle(DesignTokens.Color.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                privacyRow(UIStrings.privacyNetwork)
                privacyRow(UIStrings.privacyFiles)
                privacyRow(UIStrings.privacyWrites)
            }

            Divider()

            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                Image(systemName: SystemImages.localDatabase)
                    .font(.title3)
                    .foregroundStyle(DesignTokens.Color.primaryAccent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                    Text(UIStrings.localDatabase)
                        .font(.headline)
                    Text(UIStrings.localDatabaseDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DesignTokens.Spacing.xLarge)
        .cardSurface(tint: DesignTokens.Color.verifiedLocal)
    }

    /// Builds one authorized folder with update and confirmed revoke actions.
    /// - Parameter root: Stored read-only folder authorization.
    /// - Returns: Folder settings row.
    private func folderRow(_ root: AuthorizedRoot) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(DesignTokens.Color.primaryAccent.opacity(0.11))
                    Image(systemName: SystemImages.folderFilled)
                        .foregroundStyle(DesignTokens.Color.primaryAccent)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                    Text(root.displayName)
                        .font(.callout.weight(.semibold))
                    Text(root.lastKnownPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                    if let date = root.lastIndexedAt {
                        (Text(UIStrings.lastIndexed + AppConstants.Text.space)
                            + Text(date, style: .relative))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(UIStrings.neverIndexed)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.processing)
                    }
                }

                Spacer()
            }

            HStack(spacing: DesignTokens.Spacing.small) {
                Spacer()

                Button {
                    model.index(root: root)
                } label: {
                    Label(UIStrings.reindex, systemImage: SystemImages.indexedFolders)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(model.indexingIsActive(rootID: root.id))

                Button {
                    Task {
                        if model.monitoringIsActive(rootID: root.id) {
                            await model.pauseMonitoring(rootID: root.id)
                        } else {
                            await model.resumeMonitoring(rootID: root.id)
                        }
                    }
                } label: {
                    Label(
                        monitoringActionTitle(rootID: root.id),
                        systemImage: monitoringActionImage(rootID: root.id)
                    )
                }
                .buttonStyle(
                    TintedActionButtonStyle(tint: monitoringActionTint(rootID: root.id))
                )
                .help(
                    model.monitoringIsActive(rootID: root.id)
                        ? UIStrings.pauseAutomaticUpdates
                        : UIStrings.resumeAutomaticUpdates
                )

                Button {
                    rootPendingRevocation = root
                } label: {
                    Label(UIStrings.revokeAccess, systemImage: SystemImages.removeFolder)
                }
                .buttonStyle(DestructiveActionButtonStyle())
                .disabled(model.indexingIsActive(rootID: root.id))
            }

            if let progress = model.indexingProgressByRoot[root.id],
               progress.state != .idle,
               progress.state != .stopped,
               progress.state != .failed {
                indexingProgress(progress)
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(DesignTokens.Color.subtleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Color.hairline)
        )
    }

    /// Builds the active indexing path and bounded progress feedback.
    /// - Parameter progress: Live progress for the authorized folder.
    /// - Returns: Bounded progress, state metrics, and pause control.
    private func indexingProgress(_ progress: IndexingProgress) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                if progress.state == .stopping {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DesignTokens.Color.processing)
                }
                Text(
                    progress.state == .stopping
                        ? UIStrings.pausingIndexing
                        : UIStrings.indexing
                )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.processing)
                Spacer()
                if progress.totalItems > 0 {
                    Text(
                        UIStrings.indexingProgress(
                            processed: progress.processedItems,
                            total: progress.totalItems,
                            fraction: progress.fractionCompleted
                        )
                    )
                    .font(.caption.weight(.semibold))
                }
            }
            if progress.totalItems > 0 {
                ProgressView(value: progress.fractionCompleted)
                    .tint(DesignTokens.Color.processing)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(progress.currentPath ?? UIStrings.scanningForChanges)
                .font(.caption.monospaced())
                .lineLimit(1)
            if let currentItemState = progress.currentItemState {
                Text(UIStrings.indexingItemState(currentItemState))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.processing)
            }
            IndexingSummaryBadges(
                newItems: progress.newItems,
                updatedItems: progress.updatedItems,
                unchangedItems: progress.unchangedItems,
                removedItems: progress.removedItems,
                skippedItems: progress.skippedItems
            )
            if let rootID = progress.rootID {
                HStack {
                    Spacer()
                    Button(
                        progress.state == .stopping
                            ? UIStrings.pausingIndexing
                            : UIStrings.pauseIndexing
                    ) {
                        model.pauseIndexing(rootID: rootID)
                    }
                    .buttonStyle(
                        TintedActionButtonStyle(tint: DesignTokens.Color.processing)
                    )
                    .disabled(progress.state == .stopping)
                }
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(DesignTokens.Color.processingSurface)
        )
    }

    /// Returns the visible state label for the single automatic-update control.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: Active, paused, or unavailable monitoring copy.
    private func monitoringActionTitle(rootID: UUID) -> String {
        if model.monitoringIsPaused(rootID: rootID) { return UIStrings.monitoringPaused }
        if model.monitoringIsActive(rootID: rootID) { return UIStrings.monitoringActive }
        return UIStrings.monitoringUnavailable
    }

    /// Returns the symbol for the single automatic-update control.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: A monitoring, paused, or attention symbol.
    private func monitoringActionImage(rootID: UUID) -> String {
        if model.monitoringIsPaused(rootID: rootID) { return SystemImages.paused }
        if model.monitoringIsActive(rootID: rootID) { return SystemImages.monitoring }
        return SystemImages.stale
    }

    /// Returns the semantic tint for the single automatic-update control.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: Teal, orange, or red according to monitoring state.
    private func monitoringActionTint(rootID: UUID) -> Color {
        if model.monitoringIsPaused(rootID: rootID) { return DesignTokens.Color.processing }
        if model.monitoringIsActive(rootID: rootID) { return DesignTokens.Color.verifiedLocal }
        return DesignTokens.Color.destructive
    }

    /// Builds one non-color-only privacy guarantee.
    /// - Parameter text: Plain-language enforced guarantee.
    /// - Returns: Labeled privacy row.
    private func privacyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            Image(systemName: SystemImages.localVerified)
                .foregroundStyle(DesignTokens.Color.verifiedLocal)
            Text(text)
                .foregroundStyle(DesignTokens.Color.graphite)
            Spacer()
        }
    }

    /// Builds one calm capability row with purpose and readiness.
    /// - Parameter capability: Local readiness and storage metadata for the capability.
    /// - Returns: Plain-language Settings row.
    private func modelCapabilityRow(
        _ capability: LocalModelCapabilityStatus
    ) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.medium) {
            Image(systemName: SystemImages.modelCapability(capability.kind))
                .font(.callout.weight(.semibold))
                .foregroundStyle(modelCapabilityColor(capability.state))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.modelCapabilityTitle(capability.kind))
                    .font(.callout.weight(.semibold))
                Text(UIStrings.modelCapabilityDescription(capability.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DesignTokens.Spacing.small)

            StatusPill(
                title: modelCapabilityStatusTitle(capability.state),
                systemImage: modelCapabilityStatusImage(capability.state),
                tint: modelCapabilityColor(capability.state)
            )
        }
        .padding(DesignTokens.Spacing.medium)
    }

    /// Wraps one compact status topic in a balanced, lightly tinted surface.
    /// - Parameters:
    ///   - tint: Semantic color identifying the status topic.
    ///   - content: Status summary, detail, and any supporting control.
    /// - Returns: An adaptive tile that aligns with its neighboring status tile.
    private func statusTile<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(DesignTokens.Spacing.medium)
            .frame(
                maxWidth: .infinity,
                minHeight: DesignTokens.Control.statusTileMinimumHeight,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(tint.opacity(0.065))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .stroke(tint.opacity(0.16))
            )
    }

    /// Builds one separated keycap for the fixed quick-call combination.
    /// - Parameter title: Visible keyboard symbol or key name.
    /// - Returns: A compact macOS-style keycap.
    private func shortcutKey(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(DesignTokens.Color.graphite)
            .frame(
                minWidth: DesignTokens.Control.shortcutKeyMinimumWidth,
                minHeight: DesignTokens.Control.shortcutKeyHeight
            )
            .padding(.horizontal, DesignTokens.Spacing.xSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(DesignTokens.Color.elevatedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(DesignTokens.Color.voice.opacity(0.24))
            )
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    /// Wraps a Settings topic in a consistent titled card.
    /// - Parameters:
    ///   - title: Short section name.
    ///   - detail: One-line explanation of the section's purpose.
    ///   - systemImage: SF Symbol representing the section.
    ///   - tint: Semantic section accent.
    ///   - content: Controls and information belonging to the section.
    /// - Returns: An adaptive, elevated Settings card.
    private func settingsCard<Content: View>(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(tint.opacity(0.11))
                    Image(systemName: systemImage)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            content()
        }
        .padding(DesignTokens.Spacing.large)
        .cardSurface()
    }

    /// Returns every required capability in a stable display order.
    private var displayedModelCapabilities: [LocalModelCapabilityStatus] {
        LocalModelCapabilityKind.allCases.map { kind in
            model.modelCapabilities.first { $0.kind == kind }
                ?? LocalModelCapabilityStatus(kind: kind, state: .checking, byteCount: 0)
        }
    }

    /// Returns the number of capabilities that passed local readiness checks.
    private var readyModelCapabilityCount: Int {
        displayedModelCapabilities.filter { $0.state == .ready }.count
    }

    /// Returns the current overall model acknowledgement title.
    private var modelStatusTitle: String {
        switch model.offlineStatus {
        case .checking: UIStrings.modelsChecking
        case .ready: UIStrings.modelsEverythingReady
        case .missingModels, .integrityFailure: UIStrings.modelsNeedAttention
        }
    }

    /// Returns the current overall model acknowledgement detail.
    private var modelStatusDescription: String {
        switch model.offlineStatus {
        case .checking: UIStrings.modelsCheckingDescription
        case .ready: UIStrings.modelsEverythingReadyDescription
        case .missingModels, .integrityFailure: UIStrings.modelsNeedAttentionDescription
        }
    }

    /// Returns the current overall model status symbol.
    private var modelStatusImage: String {
        model.offlineStatus == .ready ? SystemImages.localVerified : SystemImages.stale
    }

    /// Returns the current overall model status color.
    private var modelStatusColor: Color {
        switch model.offlineStatus {
        case .ready: DesignTokens.Color.verifiedLocal
        case .checking: DesignTokens.Color.processing
        case .missingModels, .integrityFailure: DesignTokens.Color.destructive
        }
    }

    /// Returns a plain-language state label for one capability.
    /// - Parameter state: Readiness produced by local integrity checks.
    /// - Returns: Compact status label.
    private func modelCapabilityStatusTitle(
        _ state: LocalModelCapabilityState
    ) -> String {
        switch state {
        case .ready: return UIStrings.modelCapabilityReady
        case .checking: return UIStrings.modelCapabilityChecking
        case .missing, .integrityFailure: return UIStrings.modelCapabilityMissing
        }
    }

    /// Returns a non-color-only status symbol for one capability.
    /// - Parameter state: Readiness produced by local integrity checks.
    /// - Returns: SF Symbol name for the status pill.
    private func modelCapabilityStatusImage(
        _ state: LocalModelCapabilityState
    ) -> String {
        state == .ready ? SystemImages.localVerified : SystemImages.stale
    }

    /// Returns the semantic color for one capability state.
    /// - Parameter state: Readiness produced by local integrity checks.
    /// - Returns: Accessible state color used with a text label and symbol.
    private func modelCapabilityColor(
        _ state: LocalModelCapabilityState
    ) -> Color {
        switch state {
        case .ready: return DesignTokens.Color.verifiedLocal
        case .checking: return DesignTokens.Color.processing
        case .missing, .integrityFailure: return DesignTokens.Color.destructive
        }
    }

    /// Returns the shortcut availability title without repeating its subject.
    private var shortcutStatusTitle: String {
        model.isShortcutAvailable
            ? UIStrings.shortcutAvailable
            : UIStrings.shortcutUnavailable
    }

    /// Returns the shortcut status symbol.
    private var shortcutStatusImage: String {
        model.isShortcutAvailable ? SystemImages.localVerified : SystemImages.stale
    }

    /// Returns the shortcut status color.
    private var shortcutStatusColor: Color {
        model.isShortcutAvailable
            ? DesignTokens.Color.verifiedLocal
            : DesignTokens.Color.processing
    }
}
