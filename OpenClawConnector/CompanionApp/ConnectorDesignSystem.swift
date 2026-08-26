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
