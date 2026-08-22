import SwiftUI

/// Model readiness and folder authorization sections of Settings.
extension SettingsView {
    /// Presents plain-language readiness for chat, file search, and voice input.
    internal var modelsSection: some View {
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

                destructiveActionRow(
                    title: UIStrings.removeDownloadedModels,
                    systemImage: SystemImages.model,
                    actionLabel: UIStrings.removeDownloadedModelsAction,
                    detail: UIStrings.modelStorageUsage(model.modelStorageByteCount),
                    isDisabled: model.isBusy || model.isIndexing || model.isListening
                ) {
                    model.requestModelRemovalConfirmation()
                }

                Divider()

                HStack(spacing: DesignTokens.Spacing.small) {
                    Label(
                        UIStrings.modelsCheckedOnLaunch,
                        systemImage: SystemImages.localVerified
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task { await model.checkSystemStatus() }
                    } label: {
                        Label(UIStrings.checkNow, systemImage: SystemImages.refresh)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    /// Builds authorized-folder controls, revocation, and indexing progress.
    internal var folderAccessSection: some View {
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

            Divider()

            Label(
                UIStrings.indexedFileCount(model.indexedFileCount),
                systemImage: SystemImages.localDatabase
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            destructiveActionRow(
                title: UIStrings.clearSearchIndex,
                systemImage: SystemImages.localDatabase,
                actionLabel: UIStrings.clearSearchIndexAction,
                detail: UIStrings.indexStorageUsage(model.indexStorageByteCount),
                isDisabled: model.isIndexing
            ) {
                model.requestSearchIndexClearConfirmation()
            }
        }
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

    /// Builds one destructive Settings action as an icon, name, and confirmation-triggering button.
    /// - Parameters:
    ///   - title: Bold action name.
    ///   - systemImage: Symbol representing the action.
    ///   - actionLabel: Short trailing button label.
    ///   - detail: Storage figure shown beside the button.
    ///   - isDisabled: Whether the action is currently unavailable.
    ///   - action: Confirmation request triggered by the button.
    /// - Returns: One row; the full effect is explained in the confirmation alert.
    private func destructiveActionRow(
        title: String,
        systemImage: String,
        actionLabel: String,
        detail: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.destructive)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.callout.weight(.semibold))

            Spacer(minLength: DesignTokens.Spacing.small)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(actionLabel, action: action)
                .buttonStyle(DestructiveActionButtonStyle())
                .disabled(isDisabled)
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
        case .missingModels: UIStrings.modelsMissing
        case .integrityFailure: UIStrings.modelsDamaged
        }
    }

    /// Returns the current overall model acknowledgement detail.
    private var modelStatusDescription: String {
        switch model.offlineStatus {
        case .checking: UIStrings.modelsCheckingDescription
        case .ready: UIStrings.modelsEverythingReadyDescription
        case .missingModels: UIStrings.modelsMissingDescription
        case .integrityFailure: UIStrings.modelsDamagedDescription
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
        case .missing: return UIStrings.modelCapabilityMissing
        case .integrityFailure: return UIStrings.modelCapabilityDamaged
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
}
