import SwiftUI

/// Credential-safe setup and update workbench for the separately packaged Connector.
struct ConnectorSetupView: View {
    @StateObject private var model = ConnectorSetupModel()
    @State private var showsRemovalConfirmation = false

    /// Presents loading, existing-install, or complete setup content.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                privacyCard
                switch model.mode {
                case .loading:
                    loadingCard
                case .existing:
                    existingConnectorCard
                case .setup:
                    setupFlow
                }
            }
            .padding(30)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(ConnectorDesignSystem.canvas)
        .frame(minWidth: 700, minHeight: 720)
        .preferredColorScheme(.light)
        .task {
            await model.loadExistingSetup()
        }
        .alert(
            ConnectorSetupConstants.Text.removeTitle,
            isPresented: $showsRemovalConfirmation
        ) {
            Button(ConnectorSetupConstants.Text.removeCancel, role: .cancel) {}
            Button(ConnectorSetupConstants.Text.removeConfirm, role: .destructive) {
                model.removeConnectorData()
            }
        } message: {
            Text(ConnectorSetupConstants.Text.removeMessage)
        }
    }

    /// Identifies the workbench and its single purpose.
    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(ConnectorSetupConstants.Text.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(ConnectorDesignSystem.text)
            Text(ConnectorSetupConstants.Text.subtitle)
                .font(.title3)
                .foregroundStyle(ConnectorDesignSystem.secondaryText)
        }
    }

    /// States the privacy boundary without requiring networking vocabulary.
    private var privacyCard: some View {
        Label(
            ConnectorSetupConstants.Text.privacyNote,
            systemImage: ConnectorSetupConstants.Symbol.privacy
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(ConnectorDesignSystem.credentialTeal)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ConnectorDesignSystem.credentialTeal.opacity(0.09),
            in: RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                .stroke(ConnectorDesignSystem.credentialTeal.opacity(0.24), lineWidth: 1)
        }
    }

    /// Gives immediate feedback while the app checks local non-secret state.
    private var loadingCard: some View {
        HStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(ConnectorDesignSystem.serverBlue)
            VStack(alignment: .leading, spacing: 4) {
                Text(ConnectorSetupConstants.Text.loadingTitle)
                    .font(.headline)
                    .foregroundStyle(ConnectorDesignSystem.text)
                Text(ConnectorSetupConstants.Text.loadingBody)
                    .font(.callout)
                    .foregroundStyle(ConnectorDesignSystem.secondaryText)
            }
        }
        .padding(ConnectorDesignSystem.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(accent: ConnectorDesignSystem.serverBlue)
    }

    /// Offers the short update path without asking for saved credentials again.
    private var existingConnectorCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: ConnectorSetupConstants.Symbol.verification)
                    .font(.title2)
                    .foregroundStyle(ConnectorDesignSystem.successGreen)
                    .frame(width: 36, height: 36)
                    .background(
                        ConnectorDesignSystem.successGreen.opacity(0.11),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 5) {
                    Text(ConnectorSetupConstants.Text.existingTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ConnectorDesignSystem.text)
                    Text(ConnectorSetupConstants.Text.existingBody)
                        .font(.callout)
                        .foregroundStyle(ConnectorDesignSystem.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                readinessRow(
                    ConnectorSetupConstants.Text.serverSettingsReady,
                    ready: model.existingState?.configured == true
                )
                readinessRow(
                    ConnectorSetupConstants.Text.sshIdentityReady,
                    ready: model.existingState?.sshIdentityReady == true
                )
                readinessRow(
                    ConnectorSetupConstants.Text.credentialsReady,
                    ready: model.credentialsAreSaved
                )
            }

            if model.statusMessage.isEmpty == false {
                statusLabel
            }

            Button {
                model.updateExistingConnector()
            } label: {
                Label(
                    model.isBusy
                        ? ConnectorSetupConstants.Text.updateWorking
                        : ConnectorSetupConstants.Text.updateExisting,
                    systemImage: ConnectorSetupConstants.Symbol.verification
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ConnectorDesignSystem.successGreen)
            .controlSize(.large)
            .disabled(model.isBusy)

            HStack(spacing: 12) {
                Button {
                    model.reviewExistingSettings()
                } label: {
                    Label(
                        ConnectorSetupConstants.Text.reviewSettings,
                        systemImage: ConnectorSetupConstants.Symbol.settings
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)

                Button {
                    model.beginCredentialReplacement()
                } label: {
                    Label(
                        ConnectorSetupConstants.Text.replaceCredentials,
                        systemImage: ConnectorSetupConstants.Symbol.saved
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)
            }

            Text(ConnectorSetupConstants.Text.replaceCredentialsHelp)
                .font(.caption)
                .foregroundStyle(ConnectorDesignSystem.secondaryText)

            Divider()

            Button(role: .destructive) {
                showsRemovalConfirmation = true
            } label: {
                Label(
                    ConnectorSetupConstants.Text.removeConnector,
                    systemImage: ConnectorSetupConstants.Symbol.remove
                )
            }
            .foregroundStyle(ConnectorDesignSystem.dangerRed)
            .disabled(model.isBusy)
        }
        .padding(ConnectorDesignSystem.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(accent: ConnectorDesignSystem.successGreen)
    }

    /// Builds the five-step path used only for first setup, repair, or review.
    private var setupFlow: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.isReviewingExistingSetup {
                Button {
                    model.returnToExistingConnector()
                } label: {
                    Label(
                        ConnectorSetupConstants.Text.returnToExisting,
                        systemImage: ConnectorSetupConstants.Symbol.back
                    )
                }
                .buttonStyle(.borderless)
                .disabled(model.isBusy)
            } else if model.existingState?.hasExistingData == true {
                noticeCard(
                    title: ConnectorSetupConstants.Text.repairTitle,
                    body: ConnectorSetupConstants.Text.repairBody,
                    accent: ConnectorDesignSystem.actionOrange
                )
            }

            if model.statusMessage.isEmpty == false {
                statusLabel
            }

            locationBadge(ConnectorSetupConstants.Text.serverBadge, onMac: true)
            connectionCard
            filesCard
            locationBadge(ConnectorSetupConstants.Text.remoteBadge, onMac: false)
            transferCard
            locationBadge(ConnectorSetupConstants.Text.serverBadge, onMac: true)
            credentialsCard
            verificationCard
        }
    }

    /// Collects only the server endpoint already used from this Mac.
    private var connectionCard: some View {
        stepCard(
            number: 1,
            title: ConnectorSetupConstants.Text.connectionTitle,
            bullets: ConnectorSetupConstants.Text.connectionBullets,
            theme: .server
        ) {
            field(
                title: ConnectorSetupConstants.Text.sshHostLabel,
                placeholder: ConnectorSetupConstants.Text.sshHostPlaceholder,
                text: $model.sshHost
            )
            field(
                title: ConnectorSetupConstants.Text.sshPortLabel,
                placeholder: ConnectorSetupConstants.Configuration.defaultSSHPort,
                text: $model.sshPort
            )
            helpDisclosure(
                ConnectorSetupConstants.Text.addressHelpTitle,
                answers: ConnectorSetupConstants.Text.addressHelp,
                accent: ConnectorDesignSystem.serverBlue
            )
        }
    }

    /// Lets the user deliberately create both transferable server files.
    private var filesCard: some View {
        stepCard(
            number: 2,
            title: ConnectorSetupConstants.Text.filesTitle,
            bullets: ConnectorSetupConstants.Text.filesBullets,
            theme: .files
        ) {
            Button(ConnectorSetupConstants.Text.createPublicKey) {
                model.createAndExportPublicKey()
            }
            .buttonStyle(.borderedProminent)
            .tint(ConnectorDesignSystem.fileCyan)
            .disabled(model.isBusy)

            if model.publicKeyWasExported {
                successLabel(ConnectorSetupConstants.Text.publicKeyReady)
            } else if model.existingState?.sshIdentityReady == true {
                successLabel(ConnectorSetupConstants.Text.existingPublicKeyReady)
            }

            Button(ConnectorSetupConstants.Text.createServerSetupZIP) {
                model.createServerSetupZIP()
            }
            .buttonStyle(.bordered)
            .tint(ConnectorDesignSystem.fileCyan)
            .disabled(model.isBusy)

            if model.serverSetupWasExported {
                successLabel(ConnectorSetupConstants.Text.serverSetupReady)
            }

            helpDisclosure(
                ConnectorSetupConstants.Text.filesHelpTitle,
                answers: ConnectorSetupConstants.Text.filesHelp,
                accent: ConnectorDesignSystem.fileCyan
            )
        }
    }

    /// Keeps file transfer, server actions, and server recovery together.
    private var transferCard: some View {
        stepCard(
            number: 3,
            title: ConnectorSetupConstants.Text.transferTitle,
            bullets: ConnectorSetupConstants.Text.transferBullets,
            theme: .actions
        ) {
            commandBlock(ConnectorSetupConstants.Text.serverCommands)
            Button(ConnectorSetupConstants.Text.copyServerCommands) {
                model.copyServerCommands()
            }
            .buttonStyle(.borderedProminent)
            .tint(ConnectorDesignSystem.actionOrange)

            DisclosureGroup(ConnectorSetupConstants.Text.transferHelpTitle) {
                VStack(alignment: .leading, spacing: 10) {
                    bulletList(
                        ConnectorSetupConstants.Text.transferHelp,
                        accent: ConnectorDesignSystem.actionOrange
                    )
                    commandBlock(model.transferCommand)
                    Button(ConnectorSetupConstants.Text.copyTransferCommand) {
                        model.copyTransferCommand()
                    }
                    .buttonStyle(.bordered)
                    .tint(ConnectorDesignSystem.actionOrange)
                }
                .padding(.top, 10)
            }
            .disclosureSurface(accent: ConnectorDesignSystem.actionOrange)

            helpDisclosure(
                ConnectorSetupConstants.Text.serverSetupQuestion,
                answers: ConnectorSetupConstants.Text.serverSetupAnswers,
                accent: ConnectorDesignSystem.actionOrange
            )
        }
    }

    /// Collects public host identity and optionally new credentials.
    private var credentialsCard: some View {
        stepCard(
            number: 4,
            title: ConnectorSetupConstants.Text.resultsTitle,
            bullets: ConnectorSetupConstants.Text.resultsBullets,
            theme: .credentials
        ) {
            field(
                title: ConnectorSetupConstants.Text.sshHostKeyLabel,
                placeholder: ConnectorSetupConstants.Text.sshHostKeyPlaceholder,
                text: $model.sshHostKey
            )

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: ConnectorSetupConstants.Symbol.saved)
                    .foregroundStyle(ConnectorDesignSystem.credentialTeal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(ConnectorSetupConstants.Text.restrictedUserLabel)
                        .font(.callout.weight(.semibold))
                    Text(ConnectorSetupConstants.Identity.restrictedSSHUser)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                    Text(ConnectorSetupConstants.Text.restrictedUserSummary)
                        .font(.caption)
                        .foregroundStyle(ConnectorDesignSystem.secondaryText)
                }
            }

            if model.shouldEnterCredentials {
                secureField(
                    title: ConnectorSetupConstants.Text.reminderTokenLabel,
                    text: $model.reminderToken
                )
                secureField(
                    title: ConnectorSetupConstants.Text.agentTokenLabel,
                    text: $model.agentToken
                )
            } else {
                savedCredentialRow(ConnectorSetupConstants.Text.reminderTokenLabel)
                savedCredentialRow(ConnectorSetupConstants.Text.agentTokenLabel)
                Button(ConnectorSetupConstants.Text.replaceCredentials) {
                    model.beginCredentialReplacement()
                }
                .buttonStyle(.bordered)
                .tint(ConnectorDesignSystem.credentialTeal)
            }

            helpDisclosure(
                ConnectorSetupConstants.Text.credentialHelpTitle,
                answers: ConnectorSetupConstants.Text.credentialHelp,
                accent: ConnectorDesignSystem.credentialTeal
            )
            helpDisclosure(
                ConnectorSetupConstants.Text.restrictedAccountQuestion,
                answers: ConnectorSetupConstants.Text.restrictedAccountAnswers,
                accent: ConnectorDesignSystem.credentialTeal
            )
        }
    }

    /// Verifies the tunnel and provides step-owned recovery help.
    private var verificationCard: some View {
        stepCard(
            number: 5,
            title: ConnectorSetupConstants.Text.localTitle,
            bullets: ConnectorSetupConstants.Text.localBullets,
            theme: .verification
        ) {
            Button {
                model.saveAndStart()
            } label: {
                Label(
                    model.isBusy
                        ? ConnectorSetupConstants.Text.working
                        : ConnectorSetupConstants.Text.saveAndStart,
                    systemImage: ConnectorSetupConstants.Symbol.verification
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ConnectorDesignSystem.successGreen)
            .controlSize(.large)
            .disabled(model.isBusy)

            if model.statusMessage.isEmpty == false {
                statusLabel
            }

            Label(
                ConnectorSetupConstants.Text.troubleshootingTitle,
                systemImage: ConnectorSetupConstants.Symbol.question
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(ConnectorDesignSystem.secondaryText)

            helpDisclosure(
                ConnectorSetupConstants.Text.tunnelQuestion,
                answers: ConnectorSetupConstants.Text.tunnelAnswers,
                accent: ConnectorDesignSystem.successGreen
            )
            helpDisclosure(
                ConnectorSetupConstants.Text.authenticationQuestion,
                answers: ConnectorSetupConstants.Text.authenticationAnswers,
                accent: ConnectorDesignSystem.successGreen
            )
            helpDisclosure(
                ConnectorSetupConstants.Text.laterRefreshQuestion,
                answers: ConnectorSetupConstants.Text.laterRefreshAnswers,
                accent: ConnectorDesignSystem.successGreen
            )
            helpDisclosure(
                ConnectorSetupConstants.Text.advancedTitle,
                answers: ConnectorSetupConstants.Text.advancedDetails,
                accent: ConnectorDesignSystem.successGreen
            )
        }
    }

    /// Builds one equal-width numbered stage with a semantic leading rail.
    private func stepCard<Content: View>(
        number: Int,
        title: String,
        bullets: [String],
        theme: ConnectorStepTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.accent)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text(String(number))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(theme.accent, in: Circle())
                    Image(systemName: theme.symbol)
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ConnectorDesignSystem.text)
                }
                bulletList(bullets, accent: theme.accent)
                content()
            }
            .padding(ConnectorDesignSystem.cardPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ConnectorDesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius)
                .stroke(ConnectorDesignSystem.border, lineWidth: 1)
        }
        .shadow(color: theme.accent.opacity(0.08), radius: 12, y: 5)
    }

    /// Separates Mac actions from server-terminal actions.
    private func locationBadge(_ title: String, onMac: Bool) -> some View {
        Label(
            title,
            systemImage: onMac
                ? ConnectorSetupConstants.Symbol.settings
                : ConnectorSetupConstants.Symbol.server
        )
        .font(.caption.monospaced().weight(.bold))
        .foregroundStyle(
            onMac ? ConnectorDesignSystem.serverBlue : ConnectorDesignSystem.actionOrange
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            (onMac ? ConnectorDesignSystem.serverBlue : ConnectorDesignSystem.actionOrange)
                .opacity(0.09),
            in: Capsule()
        )
    }

    /// Formats required actions for fast scanning.
    private func bulletList(_ bullets: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                    Text(bullet)
                        .font(.callout)
                        .foregroundStyle(ConnectorDesignSystem.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Builds one labelled non-secret field without inline paragraph copy.
    private func field(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ConnectorDesignSystem.text)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Builds one non-echoing credential field.
    private func secureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ConnectorDesignSystem.text)
            SecureField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Shows credential persistence without revealing a Keychain value.
    private func savedCredentialRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ConnectorSetupConstants.Symbol.saved)
                .foregroundStyle(ConnectorDesignSystem.credentialTeal)
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
            Text(ConnectorSetupConstants.Text.savedCredential)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ConnectorDesignSystem.credentialTeal)
        }
        .padding(11)
        .background(
            ConnectorDesignSystem.credentialTeal.opacity(0.07),
            in: RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
        )
    }

    /// Presents optional explanations and recovery in a collapsed, step-owned surface.
    private func helpDisclosure(
        _ title: String,
        answers: [String],
        accent: Color
    ) -> some View {
        DisclosureGroup(title) {
            bulletList(answers, accent: accent)
                .padding(.top, 10)
        }
        .disclosureSurface(accent: accent)
    }

    /// Formats selectable commands without requiring source files.
    private func commandBlock(_ value: String) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .foregroundStyle(ConnectorDesignSystem.text)
            .textSelection(.enabled)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.black.opacity(0.045),
                in: RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .stroke(ConnectorDesignSystem.border, lineWidth: 1)
            }
    }

    /// Shows one completed action without relying on color alone.
    private func successLabel(_ text: String) -> some View {
        Label(text, systemImage: ConnectorSetupConstants.Symbol.success)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ConnectorDesignSystem.successGreen)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Shows one setup or update result in a high-visibility semantic banner.
    private var statusLabel: some View {
        Label(model.statusMessage, systemImage: statusSystemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(statusColor)
            .textSelection(.enabled)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                statusColor.opacity(0.09),
                in: RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .stroke(statusColor.opacity(0.24), lineWidth: 1)
            }
    }

    /// Selects a non-color-only symbol for the latest result.
    private var statusSystemImage: String {
        switch model.statusTone {
        case .neutral: ConnectorSetupConstants.Symbol.loading
        case .success: ConnectorSetupConstants.Symbol.success
        case .failure: ConnectorSetupConstants.Symbol.failure
        }
    }

    /// Selects an accessible semantic color for the latest result.
    private var statusColor: Color {
        switch model.statusTone {
        case .neutral: ConnectorDesignSystem.serverBlue
        case .success: ConnectorDesignSystem.successGreen
        case .failure: ConnectorDesignSystem.dangerRed
        }
    }

    /// Shows one credential-free readiness fact with text and symbol.
    private func readinessRow(_ title: String, ready: Bool) -> some View {
        Label(
            title,
            systemImage: ready
                ? ConnectorSetupConstants.Symbol.success
                : ConnectorSetupConstants.Symbol.failure
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(
            ready ? ConnectorDesignSystem.successGreen : ConnectorDesignSystem.dangerRed
        )
    }

    /// Shows a short repair notice without expanding the primary instructions.
    private func noticeCard(title: String, body: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ConnectorDesignSystem.text)
            Text(body)
                .font(.callout)
                .foregroundStyle(ConnectorDesignSystem.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(accent: accent)
    }
}

/// Shared bordered surface used by non-step cards.
private extension View {
    /// Adds a light-only surface and semantic accent border.
    func cardSurface(accent: Color) -> some View {
        background(ConnectorDesignSystem.surface)
            .clipShape(RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: accent.opacity(0.07), radius: 12, y: 5)
    }

    /// Styles one progressive-disclosure surface with its owning step accent.
    func disclosureSurface(accent: Color) -> some View {
        font(.callout.weight(.medium))
            .foregroundStyle(ConnectorDesignSystem.text)
            .padding(12)
            .background(
                accent.opacity(0.06),
                in: RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            }
    }
}
