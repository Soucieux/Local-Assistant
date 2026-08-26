import SwiftUI

/// Semantic visual roles for the light-only Connector workbench.
enum ConnectorDesignSystem {
    static let canvas = Color(red: 0.965, green: 0.975, blue: 0.985)
    static let surface = Color.white
    static let text = Color(red: 0.105, green: 0.135, blue: 0.18)
    static let secondaryText = Color(red: 0.32, green: 0.37, blue: 0.44)
    static let border = Color(red: 0.82, green: 0.85, blue: 0.89)
    static let serverBlue = Color(red: 0.12, green: 0.38, blue: 0.82)
    static let fileCyan = Color(red: 0.00, green: 0.57, blue: 0.72)
    static let actionOrange = Color(red: 0.86, green: 0.38, blue: 0.08)
    static let credentialTeal = Color(red: 0.00, green: 0.48, blue: 0.43)
    static let successGreen = Color(red: 0.08, green: 0.48, blue: 0.25)
    static let dangerRed = Color(red: 0.72, green: 0.12, blue: 0.16)
    static let cornerRadius: CGFloat = 16
    static let compactCornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 20
    internal static let contentMaximumWidth: CGFloat = 1_440
    internal static let actionMinimumWidth: CGFloat = 260
    internal static let locationBannerIconSize: CGFloat = 34
}

/// One distinct setup stage with a stable semantic accent and symbol.
enum ConnectorStepTheme {
    case server
    case files
    case actions
    case credentials
    case verification

    /// Returns the stage's accessible accent color.
    internal var accent: Color {
        switch self {
        case .server: ConnectorDesignSystem.serverBlue
        case .files: ConnectorDesignSystem.fileCyan
        case .actions: ConnectorDesignSystem.actionOrange
        case .credentials: ConnectorDesignSystem.credentialTeal
        case .verification: ConnectorDesignSystem.successGreen
        }
    }

    /// Returns the stage's non-color-only symbol.
    internal var symbol: String {
        switch self {
        case .server: ConnectorSetupConstants.Symbol.server
        case .files: ConnectorSetupConstants.Symbol.files
        case .actions: ConnectorSetupConstants.Symbol.terminal
        case .credentials: ConnectorSetupConstants.Symbol.credentials
        case .verification: ConnectorSetupConstants.Symbol.verification
        }
    }
}

/// Filled action used for a required Connector setup task.
internal struct ConnectorPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accent: Color

    /// Creates a required-action style with the owning step color.
    /// - Parameter accent: Semantic step color used by the button surface.
    internal init(accent: Color) {
        self.accent = accent
    }

    /// Builds a full-width filled control with stable interaction feedback.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: Accessible filled action control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .fill(configuration.isPressed ? accent.opacity(0.78) : accent)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

/// Outlined action used for supporting Connector tasks.
internal struct ConnectorSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accent: Color

    /// Creates a supporting-action style with the owning step color.
    /// - Parameter accent: Semantic step color used by the border and label.
    internal init(accent: Color) {
        self.accent = accent
    }

    /// Builds a full-width bordered control with a visible surface and focusable label.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: Accessible secondary action control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .fill(
                        configuration.isPressed
                            ? accent.opacity(0.14)
                            : accent.opacity(0.07)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .stroke(accent.opacity(0.48), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

/// Warning action reserved for removing Connector-owned local data.
internal struct ConnectorDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Builds a full-width destructive control without making color its only signal.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: Accessible destructive action control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(ConnectorDesignSystem.dangerRed)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .fill(
                        configuration.isPressed
                            ? ConnectorDesignSystem.dangerRed.opacity(0.16)
                            : ConnectorDesignSystem.dangerRed.opacity(0.07)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: ConnectorDesignSystem.compactCornerRadius)
                    .stroke(ConnectorDesignSystem.dangerRed.opacity(0.42), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
