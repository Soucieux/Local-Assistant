import SwiftUI

/// Folder authorization, shortcut, model, and privacy controls.
struct SettingsView: View {
    @Environment(AppModel.self) var model
    @State var rootPendingRevocation: AuthorizedRoot?

    /// Builds same-window Settings with stable navigation and adaptive content.
    var body: some View {
        ZStack {
            CompanionCanvasBackground()

            VStack(spacing: 0) {
                settingsHeader

                ScrollView {
                    settingsContent
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

    /// Uses one ordered column when narrow and balanced intrinsic-height columns when wide.
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            privacySection
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                        openClawSection
                        modelsSection
                        voiceInputSection
                    }
                    .frame(
                        minWidth: DesignTokens.Window.adaptiveColumnMinimumWidth,
                        maxWidth: .infinity,
                        alignment: .topLeading
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                        folderAccessSection
                        assistantStatusSection
                    }
                    .frame(
                        minWidth: DesignTokens.Window.adaptiveColumnMinimumWidth,
                        maxWidth: .infinity,
                        alignment: .topLeading
                    )
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                    openClawSection
                    folderAccessSection
                    modelsSection
                    voiceInputSection
                    assistantStatusSection
                }
            }
        }
    }

    /// Presents all OpenClaw controls in one standalone section below Privacy.
    private var openClawSection: some View {
        settingsCard(
            title: ReminderStrings.openClawSettingsTitle,
            detail: ReminderStrings.openClawSettingsDetail,
            systemImage: SystemImages.openClaw,
            tint: DesignTokens.Color.commandAccent
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                Toggle(
                    ReminderStrings.enableConnector,
                    isOn: Binding(
                        get: { model.reminderConnectorEnabled },
                        set: { model.setReminderConnectorEnabled($0) }
                    )
                )

                Text(ReminderStrings.connectorPrivacyDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                OpenClawHealthSummary(health: model.openClawConnectorHealth)

                Divider()

                HStack(spacing: DesignTokens.Spacing.medium) {
                    Text(ReminderStrings.syncInterval)
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Picker(
                        ReminderStrings.syncInterval,
                        selection: Binding(
                            get: { model.reminderSyncIntervalMinutes },
                            set: { model.setReminderSyncInterval($0) }
                        )
                    ) {
                        ForEach(
                            ReminderConstants.Preferences.allowedSyncIntervalMinutes,
                            id: \.self
                        ) { minutes in
                            Text(ReminderStrings.syncInterval(minutes: minutes))
                                .tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .disabled(model.reminderConnectorEnabled == false)
                }

                Button {
                    Task { await model.syncReminders() }
                } label: {
                    Label(
                        model.reminderSyncState == .syncing
                            ? ReminderStrings.refreshingNow
                            : ReminderStrings.refreshNow,
                        systemImage: SystemImages.refresh
                    )
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(
                    model.reminderConnectorEnabled == false
                        || model.reminderSyncState == .syncing
                )

                if model.reminderSyncState == .failed {
                    Label(
                        ReminderStrings.cachedSnapshotOutdated,
                        systemImage: SystemImages.stale
                    )
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.destructive)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text(ReminderStrings.connectorAgentDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    model.showOpenClawSetup()
                } label: {
                    Label(
                        model.openClawConnectorHealth == .ready
                            ? ReminderStrings.reviewSetup
                            : ReminderStrings.openSetup,
                        systemImage: SystemImages.openClaw
                    )
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
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
                    .fill(DesignTokens.Color.commandAccent.opacity(0.10))
                Image(systemName: SystemImages.settings)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignTokens.Color.commandAccent)
            }
            .frame(
                width: DesignTokens.Control.appIconSize,
                height: DesignTokens.Control.appIconSize
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.settingsTitle)
                    .font(.title3.monospaced().weight(.semibold))
                Text(UIStrings.settingsDetail)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
            }

            Spacer()

            Text(UIStrings.displayVersion(settingsVersion))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.commandAccent)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .padding(.vertical, DesignTokens.Spacing.xSmall)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(DesignTokens.Color.commandAccent.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .stroke(DesignTokens.Color.commandAccent.opacity(0.20))
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

    /// Returns the installed marketing version for the Settings identity.
    private var settingsVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: AppConstants.Identity.bundleShortVersionKey
        ) as? String ?? AppConstants.Identity.fallbackVersion
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

    /// Presents the persistent click-to-speak and hold-Space interaction choices.
    private var voiceInputSection: some View {
        settingsCard(
            title: UIStrings.voiceInputModeTitle,
            detail: UIStrings.voiceInputModeDescription,
            systemImage: SystemImages.microphone,
            tint: DesignTokens.Color.voice
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                Picker(
                    UIStrings.voiceInputModeTitle,
                    selection: voiceInputModeBinding
                ) {
                    ForEach(VoiceInputMode.allCases, id: \.self) { mode in
                        Text(voiceInputModeTitle(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(model.isListening || model.isBusy)

                Text(voiceInputModeDescription(model.voiceInputMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Provides a writable Settings binding for the AppModel-owned voice preference.
    private var voiceInputModeBinding: Binding<VoiceInputMode> {
        Binding(
            get: { model.voiceInputMode },
            set: { model.setVoiceInputMode($0) }
        )
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
                privacyRow(UIStrings.privacyOpenClawException)
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
    internal func settingsCard<Content: View>(
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

    /// Returns the shortcut availability title without repeating its subject.
    private var shortcutStatusTitle: String {
        model.isShortcutAvailable
            ? UIStrings.shortcutAvailable
            : UIStrings.shortcutUnavailable
    }

    /// Returns the concise title for one voice interaction choice.
    /// - Parameter mode: Persisted voice interaction mode.
    /// - Returns: Plain-language picker label.
    private func voiceInputModeTitle(_ mode: VoiceInputMode) -> String {
        switch mode {
        case .clickToSpeak: return UIStrings.voiceClickToSpeak
        case .holdSpace: return UIStrings.voiceHoldSpace
        }
    }

    /// Returns operating guidance for one voice interaction choice.
    /// - Parameter mode: Persisted voice interaction mode.
    /// - Returns: Plain-language explanation below the picker.
    private func voiceInputModeDescription(_ mode: VoiceInputMode) -> String {
        switch mode {
        case .clickToSpeak: return UIStrings.voiceClickToSpeakDescription()
        case .holdSpace: return UIStrings.voiceHoldSpaceDescription
        }
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
