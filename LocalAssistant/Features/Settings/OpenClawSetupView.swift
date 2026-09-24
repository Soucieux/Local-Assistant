import SwiftUI

/// Short same-window entry point for the standalone OpenClaw Connector setup.
internal struct OpenClawSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    /// Keeps Local Assistant focused on status while the Connector owns setup actions.
    internal var body: some View {
        ZStack {
            CompanionCanvasBackground()

            VStack(spacing: 0) {
                setupHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                        privacyCard
                        OpenClawHealthSummary(health: model.openClawConnectorHealth)
                        connectorCard
                        enableCard
                        refreshCard
                        troubleshooting
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xLarge)
                    .padding(.vertical, DesignTokens.Spacing.xxLarge)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task { model.refreshOpenClawConnectorAppAvailability() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.refreshOpenClawConnectorAppAvailability()
        }
    }

    /// Builds same-window navigation and setup identity.
    private var setupHeader: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                model.showSettings()
            } label: {
                Label(ReminderStrings.backToSettings, systemImage: SystemImages.back)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(DesignTokens.Color.commandAccent.opacity(0.10))
                Image(systemName: SystemImages.openClaw)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignTokens.Color.commandAccent)
            }
            .frame(
                width: DesignTokens.Control.appIconSize,
                height: DesignTokens.Control.appIconSize
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(ReminderStrings.setupScreenTitle)
                    .font(.title3.monospaced().weight(.semibold))
                Text(ReminderStrings.setupScreenDetail)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
            }
            Spacer()
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

    /// States the one allowed external boundary before setup begins.
    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(ReminderStrings.setupPrivacyTitle, systemImage: SystemImages.localVerified)
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.verifiedLocal)
            bulletList(ReminderStrings.setupPrivacyBullets)

            DisclosureGroup(ReminderStrings.setupPrivacyTechnicalTitle) {
                bulletList(ReminderStrings.setupPrivacyTechnicalBullets)
                    .padding(.top, DesignTokens.Spacing.small)
            }
            .font(.callout.weight(.semibold))
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(tint: DesignTokens.Color.verifiedLocal)
    }

    /// Sends every actionable server and credential step to the matching Connector.
    private var connectorCard: some View {
        setupCard(
            title: ReminderStrings.localSetupConnectorTitle,
            bullets: ReminderStrings.localSetupConnectorBullets
        ) {
            if let issue = model.openClawConnectorAppIssue {
                Label(issue, systemImage: SystemImages.stale)
                    .font(.callout)
                    .foregroundStyle(DesignTokens.Color.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            }
            connectorLaunchButton
        }
    }

    /// Explains the only setting required after Connector verification.
    private var enableCard: some View {
        setupCard(
            title: ReminderStrings.localSetupEnableTitle,
            bullets: ReminderStrings.localSetupEnableBullets
        ) {
            Button {
                model.showSettings()
            } label: {
                Label(ReminderStrings.backToSettings, systemImage: SystemImages.settings)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    /// Separates installation success from the first complete cache refresh.
    private var refreshCard: some View {
        setupCard(
            title: ReminderStrings.localSetupRefreshTitle,
            bullets: ReminderStrings.localSetupRefreshBullets
        )
    }

    /// Keeps common status questions collapsed until needed.
    private var troubleshooting: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(ReminderStrings.troubleshootingTitle, systemImage: SystemImages.help)
                .font(.headline)
            DisclosureGroup(ReminderStrings.refreshAfterVerifyQuestion) {
                bulletList(ReminderStrings.refreshAfterVerifyAnswer)
                    .padding(.top, DesignTokens.Spacing.small)
            }
            .padding(DesignTokens.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(DesignTokens.Color.subtleFill)
            )
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    /// Builds one equal-width, scannable completion card.
    /// - Parameters:
    ///   - title: Short card heading.
    ///   - bullets: Ordered plain-language steps shown in the card.
    ///   - action: Trailing control belonging to this card.
    /// - Returns: An adaptive setup card matching its siblings' width.
    private func setupCard<Action: View>(
        title: String,
        bullets: [String],
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(title)
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.xLarge) {
                    bulletList(bullets)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    action()
                        .frame(
                            minWidth: DesignTokens.Window.adaptiveColumnMinimumWidth,
                            maxWidth: .infinity,
                            alignment: .topLeading
                        )
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    bulletList(bullets)
                    action()
                }
            }
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .cardSurface()
    }

    /// Builds a compact setup card without a separate action region.
    /// - Parameters:
    ///   - title: Numbered setup-stage title.
    ///   - bullets: Short ordered actions or outcomes.
    /// - Returns: Full-width card whose height follows its content.
    private func setupCard(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(title)
                .font(.headline)
            bulletList(bullets)
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .cardSurface()
    }

    /// Formats short setup actions with visible bullets.
    /// - Parameter bullets: Setup actions in the order the user performs them.
    /// - Returns: A bulleted list of those actions.
    private func bulletList(_ bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                    Text(AppConstants.Text.bullet)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(DesignTokens.Color.commandAccent)
                    Text(bullet)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Opens only a Connector whose marketing and build versions match exactly.
    private var connectorLaunchButton: some View {
        Button {
            model.openOpenClawConnectorApp()
        } label: {
            Label(
                ReminderStrings.connectorAppActionTitle(
                    model.openClawConnectorAppAvailability
                ),
                systemImage: SystemImages.open
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(model.openClawConnectorAppAvailability == .checking)
    }
}

/// Reusable, non-color-only summary of the locally observed connector heartbeat.
internal struct OpenClawHealthSummary: View {
    internal let health: OpenClawConnectorHealth

    /// Builds one live status tile shared by Settings and the setup guide.
    internal var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.small) {
                Text(ReminderStrings.connectorHealthTitle)
                    .font(.callout.weight(.semibold))
                Spacer(minLength: DesignTokens.Spacing.small)
                StatusPill(
                    title: ReminderStrings.connectorHealthTitle(health),
                    systemImage: statusImage,
                    tint: statusColor
                )
            }

            Text(ReminderStrings.connectorHealthDetail(health))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(statusColor.opacity(0.065))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(statusColor.opacity(0.16))
        )
    }

    /// Selects a semantic symbol without relying on color alone.
    private var statusImage: String {
        switch health {
        case .off: return SystemImages.lock
        case .checking: return SystemImages.refresh
        case .notDetected, .updateRequired, .needsAttention: return SystemImages.stale
        case .runningUnverified: return SystemImages.status
        case .runningUnreachable: return SystemImages.stale
        case .ready: return SystemImages.localVerified
        }
    }

    /// Selects the established app color for each health class.
    private var statusColor: Color {
        switch health {
        case .off: return DesignTokens.Color.commandMutedInk
        case .checking, .notDetected, .runningUnverified:
            return DesignTokens.Color.processing
        case .updateRequired, .runningUnreachable, .needsAttention:
            return DesignTokens.Color.destructive
        case .ready:
            return DesignTokens.Color.verifiedLocal
        }
    }
}
