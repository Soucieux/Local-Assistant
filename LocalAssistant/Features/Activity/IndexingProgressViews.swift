import SwiftUI

/// Compact summary badges shared by live and retained indexing activity.
struct IndexingSummaryBadges: View {
    let newItems: Int
    let updatedItems: Int
    let unchangedItems: Int
    let removedItems: Int
    let skippedItems: Int

    /// Builds adaptive file-state badges for narrow and wide surfaces.
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 118), spacing: DesignTokens.Spacing.small)],
            alignment: .leading,
            spacing: DesignTokens.Spacing.small
        ) {
            badge(UIStrings.newStatus, count: newItems, systemImage: SystemImages.add, tint: .blue)
            badge(
                UIStrings.updatedStatus,
                count: updatedItems,
                systemImage: SystemImages.indexedFolders,
                tint: DesignTokens.Color.processing
            )
            badge(
                UIStrings.unchangedStatus,
                count: unchangedItems,
                systemImage: SystemImages.unchanged,
                tint: .secondary
            )
            badge(
                UIStrings.removedStatus,
                count: removedItems,
                systemImage: SystemImages.removed,
                tint: DesignTokens.Color.voice
            )
            badge(
                UIStrings.skippedStatus,
                count: skippedItems,
                systemImage: SystemImages.stale,
                tint: DesignTokens.Color.destructive
            )
        }
    }

    /// Builds one compact file-state metric tile.
    /// - Parameters:
    ///   - title: Visible file-state label.
    ///   - count: Number of items in the state.
    ///   - systemImage: Non-color-only symbol for the state.
    ///   - tint: Semantic state color.
    /// - Returns: Styled metric that remains readable without color alone.
    private func badge(
        _ title: String,
        count: Int,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(count, format: .number)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.small)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(tint.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(tint.opacity(0.16))
        )
        .accessibilityElement(children: .combine)
    }
}

/// Informative assistant-screen banner for background indexing.
struct BackgroundIndexingBanner: View {
    @Environment(AppModel.self) private var model

    /// Builds live progress, activity navigation, and a safe pause control.
    var body: some View {
        let progress = model.indexingProgress
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: SystemImages.monitoring)
                .font(.title3)
                .foregroundStyle(DesignTokens.Color.processing)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                HStack {
                    Text(UIStrings.indexingInBackground)
                        .font(.callout.weight(.semibold))
                    if let folderName = progress.folderName {
                        Text(UIStrings.indexingFolderLabel(folderName))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if progress.totalItems > 0 {
                    ProgressView(value: progress.fractionCompleted)
                        .tint(DesignTokens.Color.processing)
                    Text(
                        UIStrings.indexingProgress(
                            processed: progress.processedItems,
                            total: progress.totalItems,
                            fraction: progress.fractionCompleted
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text(UIStrings.scanningForChanges)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let currentPath = progress.currentPath {
                    Text(currentPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let currentItemState = progress.currentItemState {
                    Text(UIStrings.indexingItemState(currentItemState))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.processing)
                }
            }

            Spacer()

            Button(UIStrings.viewActivity) {
                model.showActivity()
            }
            .buttonStyle(SecondaryActionButtonStyle())

            if let rootID = progress.rootID {
                Button(
                    progress.state == .stopping
                        ? UIStrings.pausingIndexing
                        : UIStrings.pauseIndexing
                ) {
                    model.pauseIndexing(rootID: rootID)
                }
                .buttonStyle(TintedActionButtonStyle(tint: DesignTokens.Color.processing))
                .disabled(progress.state == .stopping)
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(DesignTokens.Color.processingSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.processing.opacity(0.20))
                .frame(height: 1)
        }
    }
}
