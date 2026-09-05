import SwiftUI

/// Reusable presentation pieces shared by the Connector setup steps.
extension ConnectorSetupView {
    /// Separates Mac actions from server-terminal actions.
    /// - Parameters:
    ///   - title: Visible location name for the owning step.
    ///   - onMac: `true` for a Mac action and `false` for a server-terminal action.
    /// - Returns: A full-width location banner for that step.
    internal func locationBadge(_ title: String, onMac: Bool) -> some View {
        let accent = onMac
            ? ConnectorDesignSystem.serverBlue
            : ConnectorDesignSystem.actionOrange
        return HStack(spacing: 12) {
            Image(
                systemName: onMac
                    ? ConnectorSetupConstants.Symbol.settings
                    : ConnectorSetupConstants.Symbol.server
            )
            .font(.headline)
            .frame(
                width: ConnectorDesignSystem.locationBannerIconSize,
                height: ConnectorDesignSystem.locationBannerIconSize
            )
            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.headline.monospaced().weight(.bold))
                .tracking(0.8)

            Spacer(minLength: 0)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        }
    }

    /// Formats required actions for fast scanning.
    /// - Parameters:
    ///   - bullets: Required actions in the order the user performs them.
    ///   - accent: Semantic accent belonging to the owning step.
    /// - Returns: A compact bulleted action list.
    internal func bulletList(_ bullets: [String], accent: Color) -> some View {
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
    /// - Parameters:
    ///   - title: Field label shown above the control.
    ///   - placeholder: Example value shown while the field is empty.
    ///   - text: Binding holding the entered non-secret value.
    /// - Returns: A labelled single-line text field.
    internal func field(
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
    /// - Parameters:
    ///   - title: Field label shown above the control.
    ///   - text: Binding holding the entered credential, never echoed on screen.
    /// - Returns: A labelled secure field.
    internal func secureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ConnectorDesignSystem.text)
            SecureField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Shows credential persistence without revealing a Keychain value.
    /// - Parameter title: Name of the credential already stored in Keychain.
    /// - Returns: A saved-state row that never displays the stored value.
    internal func savedCredentialRow(_ title: String) -> some View {
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
    /// - Parameters:
    ///   - title: Collapsed question this disclosure answers.
    ///   - answers: Answer points revealed when the disclosure opens.
    ///   - accent: Semantic accent belonging to the owning step.
    /// - Returns: A collapsed question-and-answer surface.
    internal func helpDisclosure(
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
    /// - Parameter value: Exact non-secret command text the user runs.
    /// - Returns: A selectable, copyable command block.
    internal func commandBlock(_ value: String) -> some View {
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
    /// - Parameter text: Plain-language description of what completed.
    /// - Returns: A labelled success row carrying both text and a symbol.
    internal func successLabel(_ text: String) -> some View {
        Label(text, systemImage: ConnectorSetupConstants.Symbol.success)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ConnectorDesignSystem.successGreen)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Shows one credential-free readiness fact with text and symbol.
    /// - Parameters:
    ///   - title: Name of the readiness fact being reported.
    ///   - ready: Whether that fact is currently satisfied.
    /// - Returns: A readiness row carrying both text and a symbol.
    internal func readinessRow(_ title: String, ready: Bool) -> some View {
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
    /// - Parameters:
    ///   - title: Short notice heading.
    ///   - body: One-sentence repair guidance.
    ///   - accent: Semantic accent belonging to the owning step.
    /// - Returns: A compact repair notice card.
    internal func noticeCard(title: String, body: String, accent: Color) -> some View {
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
extension View {
    /// Adds a light-only surface and semantic accent border.
    /// - Parameter accent: Semantic accent belonging to the owning card.
    /// - Returns: The view on a bordered light-only surface.
    internal func cardSurface(accent: Color) -> some View {
        background(ConnectorDesignSystem.surface)
            .clipShape(RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.cornerRadius)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: accent.opacity(0.07), radius: 12, y: 5)
    }

    /// Styles one progressive-disclosure surface with its owning step accent.
    /// - Parameter accent: Semantic accent belonging to the owning step.
    /// - Returns: The view on a tinted disclosure surface.
    internal func disclosureSurface(accent: Color) -> some View {
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
