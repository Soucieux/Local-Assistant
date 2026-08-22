#if DEBUG
import SwiftUI

/// Renders the model readiness states a verified installation never shows.
///
/// Chat, file search, and voice input all report ready once the offline model package is
/// installed, so the not-installed and damaged wording cannot be reviewed by running the
/// app without removing or corrupting installed files. These previews present each state
/// at the smallest supported window size in both appearances instead.
private enum ModelStatusPreview {
    /// Builds Settings with the model section held in one readiness state.
    /// - Parameters:
    ///   - status: Overall readiness shown in the model summary.
    ///   - capabilities: Readiness shown for each listed capability.
    /// - Returns: A Settings screen configured for preview only.
    @MainActor
    internal static func settings(
        status: OfflineStatus,
        capabilities: [LocalModelCapabilityKind: LocalModelCapabilityState]
    ) -> some View {
        let model = AppModel()
        model.offlineStatus = status
        model.modelCapabilities = LocalModelCapabilityKind.allCases.map { kind in
            LocalModelCapabilityStatus(
                kind: kind,
                state: capabilities[kind] ?? .checking,
                byteCount: 0
            )
        }
        return SettingsView().environment(model)
    }

    /// Places the light-only Settings screen at the smallest supported window size.
    /// - Parameters:
    ///   - status: Overall readiness shown in the model summary.
    ///   - capabilities: Readiness shown for each listed capability.
    /// - Returns: The intended light appearance for one readiness state.
    @MainActor
    internal static func lightAppearance(
        status: OfflineStatus,
        capabilities: [LocalModelCapabilityKind: LocalModelCapabilityState]
    ) -> some View {
        settings(status: status, capabilities: capabilities)
            .environment(\.colorScheme, .light)
            .frame(
                width: DesignTokens.Window.minimumWidth,
                height: DesignTokens.Window.minimumHeight
            )
    }

    /// Applies one readiness value to every listed capability.
    /// - Parameter state: Readiness for chat, file search, and voice input.
    /// - Returns: Uniform capability readiness.
    internal static func uniform(
        _ state: LocalModelCapabilityState
    ) -> [LocalModelCapabilityKind: LocalModelCapabilityState] {
        LocalModelCapabilityKind.allCases.reduce(into: [:]) { result, kind in
            result[kind] = state
        }
    }
}

#Preview("Models: everything ready") {
    ModelStatusPreview.lightAppearance(
        status: .ready,
        capabilities: ModelStatusPreview.uniform(.ready)
    )
}

#Preview("Models: not installed") {
    ModelStatusPreview.lightAppearance(
        status: .missingModels,
        capabilities: ModelStatusPreview.uniform(.missing)
    )
}

#Preview("Models: damaged") {
    ModelStatusPreview.lightAppearance(
        status: .integrityFailure,
        capabilities: ModelStatusPreview.uniform(.integrityFailure)
    )
}

#Preview("Models: checking") {
    ModelStatusPreview.lightAppearance(
        status: .checking,
        capabilities: ModelStatusPreview.uniform(.checking)
    )
}

#Preview("Models: voice input missing its tokenizer") {
    ModelStatusPreview.lightAppearance(
        status: .missingModels,
        capabilities: [.chat: .ready, .fileSearch: .ready, .voiceInput: .missing]
    )
}
#endif
