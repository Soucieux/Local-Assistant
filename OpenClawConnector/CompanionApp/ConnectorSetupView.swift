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
            .frame(maxWidth: ConnectorDesignSystem.contentMaximumWidth)
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
            .buttonStyle(
                ConnectorPrimaryButtonStyle(accent: ConnectorDesignSystem.successGreen)
            )
            .disabled(model.isBusy)

            Button {
                model.reviewExistingSettings()
            } label: {
                Label(
                    ConnectorSetupConstants.Text.reviewSettings,
                    systemImage: ConnectorSetupConstants.Symbol.settings
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                ConnectorSecondaryButtonStyle(accent: ConnectorDesignSystem.serverBlue)
            )
            .disabled(model.isBusy)

            Divider()

            Button(role: .destructive) {
                showsRemovalConfirmation = true
            } label: {
                Label(
                    ConnectorSetupConstants.Text.removeConnector,
                    systemImage: ConnectorSetupConstants.Symbol.remove
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConnectorDestructiveButtonStyle())
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
                .buttonStyle(
                    ConnectorSecondaryButtonStyle(accent: ConnectorDesignSystem.serverBlue)
                )
                .disabled(model.isBusy)
            } else if model.existingState?.hasExistingData == true {
                noticeCard(
                    title: ConnectorSetupConstants.Text.repairTitle,
                    body: ConnectorSetupConstants.Text.repairBody,
                    accent: ConnectorDesignSystem.actionOrange
                )
            }

            if model.statusMessage.isEmpty == false,
               model.showsVerificationStatus == false {
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
        } footer: {
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
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    model.createAndExportPublicKey()
                } label: {
                    Label(
                        ConnectorSetupConstants.Text.createPublicKey,
                        systemImage: ConnectorSetupConstants.Symbol.credentials
                    )
                }
                .buttonStyle(
                    ConnectorPrimaryButtonStyle(accent: ConnectorDesignSystem.fileCyan)
                )
                .disabled(model.isBusy)

                if model.publicKeyWasExported {
                    successLabel(ConnectorSetupConstants.Text.publicKeyReady)
                } else if model.existingState?.sshIdentityReady == true {
                    successLabel(ConnectorSetupConstants.Text.existingPublicKeyReady)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    model.createServerSetupZIP()
                } label: {
                    Label(
                        ConnectorSetupConstants.Text.createServerSetupZIP,
                        systemImage: ConnectorSetupConstants.Symbol.files
                    )
                }
                .buttonStyle(
                    ConnectorPrimaryButtonStyle(accent: ConnectorDesignSystem.fileCyan)
                )
                .disabled(model.isBusy)

                if model.serverSetupWasExported {
                    successLabel(ConnectorSetupConstants.Text.serverSetupReady)
                }
            }
        } footer: {
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
            Button {
                model.copyServerCommands()
            } label: {
                Label(
                    ConnectorSetupConstants.Text.copyServerCommands,
                    systemImage: ConnectorSetupConstants.Symbol.copy
                )
            }
            .buttonStyle(
                ConnectorPrimaryButtonStyle(accent: ConnectorDesignSystem.actionOrange)
            )

        } footer: {
            DisclosureGroup(ConnectorSetupConstants.Text.transferHelpTitle) {
                VStack(alignment: .leading, spacing: 10) {
                    bulletList(
                        ConnectorSetupConstants.Text.transferHelp,
                        accent: ConnectorDesignSystem.actionOrange
                    )
                    commandBlock(model.transferCommand)
                    Button {
                        model.copyTransferCommand()
                    } label: {
                        Label(
                            ConnectorSetupConstants.Text.copyTransferCommand,
                            systemImage: ConnectorSetupConstants.Symbol.copy
                        )
                    }
                    .buttonStyle(
                        ConnectorSecondaryButtonStyle(
                            accent: ConnectorDesignSystem.actionOrange
                        )
                    )
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
                .buttonStyle(
                    ConnectorSecondaryButtonStyle(
                        accent: ConnectorDesignSystem.credentialTeal
                    )
                )
            }
        } footer: {
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
            if model.statusMessage.isEmpty == false,
               model.showsVerificationStatus {
                statusLabel
            }

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
            .buttonStyle(
                ConnectorPrimaryButtonStyle(accent: ConnectorDesignSystem.successGreen)
            )
            .disabled(model.isBusy)
        } footer: {
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
                ConnectorSetupConstants.Text.a2aQuestion,
                answers: ConnectorSetupConstants.Text.a2aAnswers,
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
    /// - Parameters:
    ///   - number: One-based stage number shown on the rail.
    ///   - title: Short stage heading.
    ///   - bullets: Ordered plain-language actions for this stage.
    ///   - theme: Semantic color role for the stage rail.
    ///   - content: Fields and controls belonging to the stage.
    ///   - footer: Trailing completion cue or action.
    /// - Returns: An adaptive numbered stage card.
    private func stepCard<Content: View, Footer: View>(
        number: Int,
        title: String,
        bullets: [String],
        theme: ConnectorStepTheme,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
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

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    bulletList(bullets, accent: theme.accent)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    VStack(alignment: .leading, spacing: 14) {
                        content()
                    }
                    .frame(
                        minWidth: ConnectorDesignSystem.actionMinimumWidth,
                        maxWidth: .infinity,
                        alignment: .topLeading
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    bulletList(bullets, accent: theme.accent)
                    content()
                }
            }

            footer()
        }
        .padding(ConnectorDesignSystem.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(ConnectorDesignSystem.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(theme.accent)
                .frame(width: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius)
                .stroke(ConnectorDesignSystem.border, lineWidth: 1)
        }
        .shadow(color: theme.accent.opacity(0.08), radius: 12, y: 5)
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
}
