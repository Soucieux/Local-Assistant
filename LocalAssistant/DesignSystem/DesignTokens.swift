import SwiftUI

/// Shared layout, color, motion, and depth tokens for the native macOS interface.
internal enum DesignTokens {
    internal enum Window {
        internal static let minimumWidth: CGFloat = 680
        internal static let minimumHeight: CGFloat = 540
        internal static let defaultWidth: CGFloat = 820
        internal static let defaultHeight: CGFloat = 720
        internal static let adaptiveColumnMinimumWidth: CGFloat = 340
        internal static let startupDetailMaximumWidth: CGFloat = 440
    }

    internal enum Message {
        internal static let maximumWidth: CGFloat = 540
        internal static let avatarSize: CGFloat = 32
        internal static let lineSpacing: CGFloat = 3
    }

    internal enum Control {
        internal static let iconButtonSize: CGFloat = 38
        internal static let compactIconButtonSize: CGFloat = 32
        internal static let appIconSize: CGFloat = 40
        internal static let iconTileSize: CGFloat = 34
        internal static let compactIconTileSize: CGFloat = 28
        internal static let glyphSlotSize: CGFloat = 28
        internal static let shortcutKeyMinimumWidth: CGFloat = 26
        internal static let shortcutKeyHeight: CGFloat = 24
        internal static let disabledOpacity = 0.46
        internal static let pressedScale: CGFloat = 0.98
    }

    internal enum Spacing {
        internal static let xxSmall: CGFloat = 2
        internal static let xSmall: CGFloat = 4
        internal static let small: CGFloat = 8
        internal static let medium: CGFloat = 12
        internal static let large: CGFloat = 16
        internal static let xLarge: CGFloat = 24
        internal static let xxLarge: CGFloat = 32
    }

    internal enum Radius {
        internal static let small: CGFloat = 3
        internal static let medium: CGFloat = 5
        internal static let large: CGFloat = 7
        internal static let xLarge: CGFloat = 10
        internal static let xxLarge: CGFloat = 14
    }

    internal enum Motion {
        internal static let scrollDuration = 0.22
        internal static let controlDuration = 0.12
        internal static let waveformDuration = 0.1
        internal static let commandRelocationDuration = 0.34
        internal static let responseTransitionDuration = 0.24
        internal static let screenTransitionDuration = 0.20
        internal static let trianglePulseDuration = 1.40
        internal static let triangleDimOpacity = 0.22
    }

    internal enum Command {
        internal static let inputMaximumWidth: CGFloat = 560
        internal static let findingMinimumWidth: CGFloat = 228
        internal static let historyFindingMinimumWidth: CGFloat = 300
        internal static let responseTextColumnCount = 12
        internal static let responseTextColumnSpan = 11
        internal static let responseBodyFontSize: CGFloat = 18
        internal static let responseHistoryBodyFontSize: CGFloat = 15
        internal static let responseHeadingOneFontSize: CGFloat = 25
        internal static let responseHeadingTwoFontSize: CGFloat = 21
        internal static let responseHeadingThreeFontSize: CGFloat = 18
        internal static let responseCodeFontSize: CGFloat = 14
        internal static let responseTableMinimumColumnWidth: CGFloat = 150
        internal static let responseTableCornerRadius: CGFloat = 8
        internal static let responseTableBorderWidth: CGFloat = 1
        internal static let responseQuoteRailWidth: CGFloat = 3
        internal static let responseInlineCodeOpacity = 0.075
        internal static let responseQuoteOpacity = 0.05
        internal static let responseTableHeaderOpacity = 0.085
        internal static let reminderSummaryCardHeight: CGFloat = 176
        internal static let reminderFocusedCardHeight: CGFloat = 216
        internal static let triangleWidth: CGFloat = 42
        internal static let triangleHeight: CGFloat = 36
        internal static let headerHeight: CGFloat = 68
        internal static let headerControlHeight: CGFloat = 30
        internal static let headerControlHorizontalPadding: CGFloat = 7
        internal static let sectionRuleWidth: CGFloat = 142
        internal static let acquisitionCornerLength: CGFloat = 17
        internal static let acquisitionCornerWidth: CGFloat = 3
        internal static let scanlineSpacing: CGFloat = 4
        internal static let scanlineOpacity = 0.026
    }

    /// Geometry for the live microphone level meter shown in place of the composer field.
    internal enum Waveform {
        /// Most the live indicator grows at full volume, as a fraction of its resting size.
        internal static let indicatorScaleRange: CGFloat = 0.18

        /// Newest level samples the indicator reacts to.
        internal static let indicatorSampleCount = 3

        internal static let height: CGFloat = 30
    }

    internal enum Color {
        internal static let primaryAction = graphite
        internal static let primaryActionPressed = SwiftUI.Color(
            red: 0.18,
            green: 0.18,
            blue: 0.18
        )
        internal static let primaryAccent = SwiftUI.Color(
            red: 0.84,
            green: 0.10,
            blue: 0.13
        )
        internal static let verifiedLocal = SwiftUI.Color(nsColor: .systemTeal)
        internal static let voice = SwiftUI.Color(nsColor: .systemPurple)
        internal static let processing = SwiftUI.Color(nsColor: .systemOrange)
        internal static let destructive = SwiftUI.Color(nsColor: .systemRed)
        internal static let newContent = SwiftUI.Color(nsColor: .systemBlue)
        internal static let graphite = SwiftUI.Color(
            red: 0.082,
            green: 0.082,
            blue: 0.082
        )
        internal static let hairline = graphite.opacity(0.18)
        internal static let selectedSurface = primaryAccent.opacity(0.11)
        internal static let canvas = SwiftUI.Color(
            red: 0.945,
            green: 0.941,
            blue: 0.925
        )
        internal static let elevatedSurface = SwiftUI.Color.white.opacity(0.72)
        internal static let assistantSurface = SwiftUI.Color.white.opacity(0.68)
        internal static let userSurface = primaryAction
        internal static let subtleFill = SwiftUI.Color.primary.opacity(0.055)
        internal static let processingSurface = processing.opacity(0.13)
        internal static let destructiveSurface = destructive.opacity(0.10)
        /// Same color as `primaryAccent`; aliased so the command surface can be retinted
        /// independently if its visual language ever diverges from the rest of the app.
        internal static let commandAccent = primaryAccent
        internal static let commandLightCanvas = canvas
        internal static let commandInk = graphite
        internal static let commandMutedInk = SwiftUI.Color(
            red: 0.34,
            green: 0.34,
            blue: 0.33
        )
        private static let reminderTagPalette = [
            SwiftUI.Color(nsColor: .systemRed),
            SwiftUI.Color(nsColor: .systemOrange),
            SwiftUI.Color(nsColor: .systemGreen),
            SwiftUI.Color(nsColor: .systemTeal),
            SwiftUI.Color(nsColor: .systemBlue),
            SwiftUI.Color(nsColor: .systemPurple)
        ]

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

        /// Returns a stable semantic accent for one reminder tag section.
        /// - Parameters:
        ///   - identifier: Normalized tag identifier.
        ///   - isUntagged: Whether the group represents reminders without a tag.
        /// - Returns: Neutral gray for untagged items or a deterministic palette color.
        internal static func reminderTag(
            _ identifier: String,
            isUntagged: Bool
        ) -> SwiftUI.Color {
            guard isUntagged == false else {
                return SwiftUI.Color(nsColor: .systemGray)
            }
            let index = identifier.unicodeScalars.reduce(0) { partial, scalar in
                (partial * 31 + Int(scalar.value)) % reminderTagPalette.count
            }
            return reminderTagPalette[index]
        }
    }
}

/// Filled style for the most important action in a local workflow.
internal struct PrimaryActionButtonStyle: ButtonStyle {
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
            .opacity(isEnabled ? 1 : DesignTokens.Control.disabledOpacity)
            .scaleEffect(configuration.isPressed ? DesignTokens.Control.pressedScale : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
            .buttonHoverFeedback(tint: DesignTokens.Color.primaryAction)
    }
}

/// Outlined style for supporting actions that should remain visually secondary.
internal struct SecondaryActionButtonStyle: ButtonStyle {
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
            .opacity(isEnabled ? 1 : DesignTokens.Control.disabledOpacity)
            .scaleEffect(configuration.isPressed ? DesignTokens.Control.pressedScale : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
            .buttonHoverFeedback(tint: DesignTokens.Color.graphite)
    }
}

/// Tinted outlined style for a reversible stateful action such as monitoring or pausing work.
internal struct TintedActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    internal let tint: Color

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
            .opacity(isEnabled ? 1 : DesignTokens.Control.disabledOpacity)
            .scaleEffect(configuration.isPressed ? DesignTokens.Control.pressedScale : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
            .buttonHoverFeedback(tint: tint)
    }
}

/// Tinted icon-only button style for compact toolbar and composer controls.
internal struct IconActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    internal let tint: Color
    internal let fill: Color
    internal let size: CGFloat

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
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(configuration.isPressed ? fill.opacity(0.72) : fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(tint.opacity(0.18))
            )
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: configuration.isPressed
            )
            .buttonHoverFeedback(tint: tint)
    }
}

/// Outlined destructive style for explicit, recoverability-sensitive actions.
internal struct DestructiveActionButtonStyle: ButtonStyle {
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
            .opacity(isEnabled ? 1 : DesignTokens.Control.disabledOpacity)
            .buttonHoverFeedback(tint: DesignTokens.Color.destructive)
    }
}

/// Stable hover feedback shared by every custom in-window button style.
private struct ButtonHoverFeedbackModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    internal let tint: Color

    /// Adds visible pointer feedback without shifting the surrounding layout.
    /// - Parameter content: Styled button content receiving hover feedback.
    /// - Returns: Content with restrained brightness, depth, and optional scale feedback.
    internal func body(content: Content) -> some View {
        content
            .brightness(isEnabled && isHovered ? 0.025 : 0)
            .shadow(
                color: tint.opacity(isEnabled && isHovered ? 0.18 : 0),
                radius: isEnabled && isHovered ? 5 : 0,
                y: isEnabled && isHovered ? 1 : 0
            )
            .scaleEffect(isEnabled && isHovered && reduceMotion == false ? 1.012 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.controlDuration),
                value: isHovered
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Compact, non-color-only status label shared by the assistant and Settings.
internal struct StatusPill: View {
    internal let title: String
    internal let systemImage: String
    internal let tint: Color

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
    internal var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.xSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(tint.opacity(0.20))
            )
    }
}

/// Reusable elevated card treatment for related local information and controls.
private struct CardSurfaceModifier: ViewModifier {
    internal let tint: Color?

    /// Wraps content in an adaptive surface with restrained depth.
    /// - Parameter content: View content receiving the card treatment.
    /// - Returns: An adaptive elevated surface with optional semantic tint.
    internal func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        tint?.opacity(0.065)
                            ?? DesignTokens.Color.elevatedSurface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .stroke(
                        tint?.opacity(0.24)
                            ?? DesignTokens.Color.commandInk.opacity(0.22)
                    )
            )
            .shadow(
                color: .black.opacity(0.025),
                radius: 3,
                y: 1
            )
    }
}

/// Fixed light application canvas with a restrained analogue scan texture.
internal struct CompanionCanvasBackground: View {
    /// Builds the shared background for the command, history, activity, and Settings screens.
    internal var body: some View {
        ZStack {
            DesignTokens.Color.commandLightCanvas

            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(
                        path,
                        with: .color(
                            DesignTokens.Color.commandInk.opacity(
                                DesignTokens.Command.scanlineOpacity
                            )
                        ),
                        lineWidth: 0.5
                    )
                    y += DesignTokens.Command.scanlineSpacing
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the shared hover response to a custom button surface.
    /// - Parameter tint: Color used for the restrained hover depth.
    /// - Returns: The receiving custom button with enabled-state-aware feedback.
    internal func buttonHoverFeedback(tint: Color) -> some View {
        modifier(ButtonHoverFeedbackModifier(tint: tint))
    }

    /// Applies the shared card treatment with an optional semantic accent.
    /// - Parameter tint: Optional accent identifying an emphasized card state.
    /// - Returns: The receiving view on an adaptive elevated surface.
    internal func cardSurface(tint: Color? = nil) -> some View {
        modifier(CardSurfaceModifier(tint: tint))
    }
}
