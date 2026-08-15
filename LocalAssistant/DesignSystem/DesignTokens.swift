import SwiftUI

/// Shared layout, color, motion, and depth tokens for the native macOS interface.
enum DesignTokens {
    enum Window {
        static let minimumWidth: CGFloat = 680
        static let minimumHeight: CGFloat = 540
        static let defaultWidth: CGFloat = 820
        static let defaultHeight: CGFloat = 720
        static let contentMaximumWidth: CGFloat = 780
    }

    enum Message {
        static let maximumWidth: CGFloat = 540
        static let avatarSize: CGFloat = 32
        static let lineSpacing: CGFloat = 3
    }

    enum Control {
        static let iconButtonSize: CGFloat = 38
        static let compactIconButtonSize: CGFloat = 32
        static let appIconSize: CGFloat = 40
        static let statusTileMinimumHeight: CGFloat = 128
        static let shortcutKeyMinimumWidth: CGFloat = 26
        static let shortcutKeyHeight: CGFloat = 24
    }

    enum Spacing {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 7
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let xLarge: CGFloat = 18
        static let xxLarge: CGFloat = 24
    }

    enum Shadow {
        static let cardOpacity = 0.07
        static let cardRadius: CGFloat = 10
        static let cardY: CGFloat = 3
        static let floatingOpacity = 0.12
        static let floatingRadius: CGFloat = 16
        static let floatingY: CGFloat = 5
    }

    enum Motion {
        static let scrollDuration = 0.22
        static let controlDuration = 0.12
    }

    enum Color {
        static let primaryAction = SwiftUI.Color(
            red: 0.29,
            green: 0.34,
            blue: 0.86
        )
        static let primaryActionPressed = SwiftUI.Color(
            red: 0.23,
            green: 0.27,
            blue: 0.72
        )
        static let primaryAccent = SwiftUI.Color(nsColor: .systemIndigo)
        static let voiceFill = SwiftUI.Color(
            red: 0.48,
            green: 0.27,
            blue: 0.82
        )
        static let verifiedLocal = SwiftUI.Color(nsColor: .systemTeal)
        static let voice = SwiftUI.Color(nsColor: .systemPurple)
        static let processing = SwiftUI.Color(nsColor: .systemOrange)
        static let destructive = SwiftUI.Color(nsColor: .systemRed)
        static let graphite = SwiftUI.Color(nsColor: .labelColor)
        static let hairline = SwiftUI.Color(nsColor: .separatorColor).opacity(0.72)
        static let selectedSurface = primaryAccent.opacity(0.11)
        static let canvas = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let elevatedSurface = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let assistantSurface = SwiftUI.Color(nsColor: .textBackgroundColor)
        static let userSurface = primaryAction
        static let subtleFill = SwiftUI.Color.primary.opacity(0.055)
        static let focusRing = primaryAccent.opacity(0.72)
        static let voiceSurface = voice.opacity(0.12)
        static let processingSurface = processing.opacity(0.13)
        static let destructiveSurface = destructive.opacity(0.10)

        /// Returns a restrained identifying color for an indexed item category.
        /// - Parameter kind: Indexed file or folder category.
        /// - Returns: Accessible accent color used alongside a text label.
        internal static func fileType(_ kind: IndexedItemKind) -> SwiftUI.Color {
            switch kind {
            case .folder: return SwiftUI.Color(nsColor: .systemOrange)
            case .pdf: return SwiftUI.Color(nsColor: .systemRed)
            case .image: return SwiftUI.Color(nsColor: .systemPurple)
            case .spreadsheet: return SwiftUI.Color(nsColor: .systemGreen)
            case .presentation: return SwiftUI.Color(nsColor: .systemOrange)
            case .code: return SwiftUI.Color(nsColor: .systemBlue)
            case .archive: return SwiftUI.Color(nsColor: .systemGray)
            case .document, .text, .other: return verifiedLocal
            }
        }
    }
}

/// Filled style for the most important action in a local workflow.
struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Builds the filled action appearance for the current interaction state.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: A colored, accessible action control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Color.primaryActionPressed
                            : DesignTokens.Color.primaryAction
                    )
            )
            .opacity(isEnabled ? 1 : 0.46)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
    }
}

/// Outlined style for supporting actions that should remain visually secondary.
struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Builds the supporting action appearance for the current interaction state.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: A lightly filled, bordered action control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(DesignTokens.Color.graphite)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Color.selectedSurface
                            : DesignTokens.Color.elevatedSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .stroke(DesignTokens.Color.hairline)
            )
            .opacity(isEnabled ? 1 : 0.46)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
    }
}

/// Tinted outlined style for a reversible stateful action such as monitoring or pausing work.
struct TintedActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tint: Color

    /// Builds a semantic action appearance without implying destructive behavior.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: A tinted, bordered action control with pressed and disabled feedback.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(tint.opacity(configuration.isPressed ? 0.17 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .stroke(tint.opacity(configuration.isPressed ? 0.32 : 0.20))
            )
            .opacity(isEnabled ? 1 : 0.46)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
    }
}

/// Tinted icon-only button style for compact toolbar and composer controls.
struct IconActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tint: Color
    let fill: Color
    let size: CGFloat

    /// Creates a reusable compact icon action style.
    /// - Parameters:
    ///   - tint: Foreground color for the icon.
    ///   - fill: Resting background color for the control.
    ///   - size: Fixed width and height for the control.
    internal init(tint: Color, fill: Color, size: CGFloat = DesignTokens.Control.iconButtonSize) {
        self.tint = tint
        self.fill = fill
        self.size = size
    }

    /// Builds the icon action appearance for the current interaction state.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: A circular icon control with pressed and disabled feedback.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? fill.opacity(0.72) : fill)
            )
            .overlay(Circle().stroke(tint.opacity(0.12)))
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
    }
}

/// Outlined destructive style for explicit, recoverability-sensitive actions.
struct DestructiveActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Builds the destructive action appearance for the current interaction state.
    /// - Parameter configuration: SwiftUI button state and label.
    /// - Returns: A red, clearly labeled destructive control.
    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(DesignTokens.Color.destructive)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Color.destructive.opacity(0.16)
                            : DesignTokens.Color.destructiveSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .stroke(DesignTokens.Color.destructive.opacity(0.20))
            )
            .opacity(isEnabled ? 1 : 0.46)
    }
}

/// Compact, non-color-only status label shared by the assistant and Settings.
struct StatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    /// Creates a status label with text, symbol, and semantic tint.
    /// - Parameters:
    ///   - title: Visible status text.
    ///   - systemImage: SF Symbol reinforcing the status without relying on color.
    ///   - tint: Semantic accent color for the status.
    internal init(title: String, systemImage: String, tint: Color) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    /// Builds the compact labeled status surface.
    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.xSmall)
            .background(Capsule().fill(tint.opacity(0.10)))
            .overlay(Capsule().stroke(tint.opacity(0.13)))
    }
}

/// Reusable elevated card treatment for related local information and controls.
private struct CardSurfaceModifier: ViewModifier {
    let tint: Color?

    /// Wraps content in an adaptive surface with restrained depth.
    /// - Parameter content: View content receiving the card treatment.
    /// - Returns: An adaptive elevated surface with optional semantic tint.
    internal func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                    .fill(
                        tint?.opacity(0.065)
                            ?? DesignTokens.Color.elevatedSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                    .stroke(tint?.opacity(0.20) ?? DesignTokens.Color.hairline)
            )
            .shadow(
                color: .black.opacity(DesignTokens.Shadow.cardOpacity),
                radius: DesignTokens.Shadow.cardRadius,
                y: DesignTokens.Shadow.cardY
            )
    }
}

extension View {
    /// Applies the shared card treatment with an optional semantic accent.
    /// - Parameter tint: Optional accent identifying an emphasized card state.
    /// - Returns: The receiving view on an adaptive elevated surface.
    internal func cardSurface(tint: Color? = nil) -> some View {
        modifier(CardSurfaceModifier(tint: tint))
    }
}
