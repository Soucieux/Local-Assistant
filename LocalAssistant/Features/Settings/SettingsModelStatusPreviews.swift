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

    /// Places light and dark copies side by side at the smallest supported window size.
    ///
    /// Both appearances render together so contrast, wrapping, and status-pill width can
    /// be compared without switching the system appearance between reviews.
    /// - Parameters:
    ///   - status: Overall readiness shown in the model summary.
    ///   - capabilities: Readiness shown for each listed capability.
    /// - Returns: Both appearances of one readiness state.
    @MainActor
    internal static func appearances(
        status: OfflineStatus,
        capabilities: [LocalModelCapabilityKind: LocalModelCapabilityState]
    ) -> some View {
        HStack(spacing: 0) {
            settings(status: status, capabilities: capabilities)
                .environment(\.colorScheme, .light)
            settings(status: status, capabilities: capabilities)
                .environment(\.colorScheme, .dark)
        }
        .frame(
            width: DesignTokens.Window.minimumWidth * 2,
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
    ModelStatusPreview.appearances(
        status: .ready,
        capabilities: ModelStatusPreview.uniform(.ready)
    )
}

#Preview("Models: not installed") {
    ModelStatusPreview.appearances(
        status: .missingModels,
        capabilities: ModelStatusPreview.uniform(.missing)
    )
}

#Preview("Models: damaged") {
    ModelStatusPreview.appearances(
        status: .integrityFailure,
        capabilities: ModelStatusPreview.uniform(.integrityFailure)
    )
}

#Preview("Models: checking") {
    ModelStatusPreview.appearances(
        status: .checking,
        capabilities: ModelStatusPreview.uniform(.checking)
    )
}

#Preview("Models: voice input missing its tokenizer") {
    ModelStatusPreview.appearances(
        status: .missingModels,
        capabilities: [.chat: .ready, .fileSearch: .ready, .voiceInput: .missing]
    )
}
#endif
