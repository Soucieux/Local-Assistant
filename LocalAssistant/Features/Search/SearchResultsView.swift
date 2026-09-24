import SwiftUI

/// Compact ranked matches with direct, explicit file actions.
internal struct SearchResultsView: View {
    internal let results: [SearchResult]

    /// Builds the best match followed by a short alternatives list.
    internal var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(spacing: DesignTokens.Spacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(DesignTokens.Color.selectedSurface)
                    Image(systemName: SystemImages.results)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Color.primaryAccent)
                }
                .frame(
                    width: DesignTokens.Control.compactIconTileSize,
                    height: DesignTokens.Control.compactIconTileSize
                )

                Text(UIStrings.searchResults)
                    .font(.headline)

                Text(UIStrings.matchingFilesCount(results.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignTokens.Spacing.small)
                    .padding(.vertical, DesignTokens.Spacing.xSmall)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                            .fill(DesignTokens.Color.subtleFill)
                    )

                Spacer()
            }

            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: DesignTokens.Spacing.medium
            ) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    ResultRow(result: result, isTopResult: index == 0)
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.small)
    }

    /// Columns that continuously reflow file and folder cards with window width.
    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: DesignTokens.Command.historyFindingMinimumWidth),
                spacing: DesignTokens.Spacing.medium,
                alignment: .top
            )
        ]
    }
}

/// One actionable local file or folder match.
private struct ResultRow: View {
    @Environment(AppModel.self) private var model
    internal let result: SearchResult
    internal let isTopResult: Bool

    /// Semantic accent identifying this match's indexed item category.
    private var typeTint: Color {
        DesignTokens.Color.fileType(result.item.kind)
    }

    /// Whether the saved match still resolves to a currently indexed item.
    private var isAvailable: Bool {
        model.isFileMatchAvailable(result.item.id)
    }

    /// Confidence or unavailability wording shown in the status pill.
    private var statusText: String {
        guard isAvailable else { return UIStrings.unavailableMatch }
        return result.confidence >= .medium ? UIStrings.topMatch : UIStrings.possibleMatch
    }

    /// Status-pill color reflecting availability and calibrated confidence.
    private var statusTint: Color {
        guard isAvailable else { return DesignTokens.Color.destructive }
        return result.confidence >= .medium
            ? DesignTokens.Color.verifiedLocal
            : DesignTokens.Color.processing
    }

    /// Builds the match name, path, concise reason, and explicit actions.
    internal var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(typeTint.opacity(0.13))
                    Image(systemName: SystemImages.fileType(result.item.kind))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(typeTint)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    Text(result.item.displayName)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                        .textSelection(.enabled)

                    HStack(spacing: DesignTokens.Spacing.small) {
                        Text(UIStrings.fileType(result.item.kind))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(typeTint)
                            .padding(.horizontal, DesignTokens.Spacing.small)
                            .padding(.vertical, DesignTokens.Spacing.xSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                    .fill(typeTint.opacity(0.11))
                            )

                        if isTopResult || isAvailable == false {
                            StatusPill(
                                title: statusText,
                                systemImage: isAvailable && result.confidence >= .medium
                                    ? SystemImages.localVerified
                                    : SystemImages.stale,
                                tint: statusTint
                            )
                        }
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.small)
            }

            HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
                Image(systemName: SystemImages.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, DesignTokens.Spacing.xxSmall)
                Text(result.item.url.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            .padding(DesignTokens.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(DesignTokens.Color.subtleFill)
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.large) {
                    matchReason
                    Spacer(minLength: DesignTokens.Spacing.medium)
                    resultActions
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    matchReason
                    resultActions
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .cardSurface(
            tint: isTopResult
                ? DesignTokens.Color.primaryAccent
                : nil
        )
    }

    /// Builds one labeled, plain-language explanation of the strongest match signals.
    private var matchReason: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            Image(systemName: SystemImages.matchReason)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
                .padding(.top, DesignTokens.Spacing.xxSmall)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text(UIStrings.whyItMatches)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(result.explanation)
                    .font(.callout)
                    .foregroundStyle(DesignTokens.Color.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    /// Builds the explicit Finder and default-application actions for one match.
    private var resultActions: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Button {
                Task { await model.reveal(result.item) }
            } label: {
                Label(UIStrings.revealInFinder, systemImage: SystemImages.reveal)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isAvailable == false)
            .help(isAvailable ? UIStrings.revealInFinder : UIStrings.unavailableMatchHelp)

            Button {
                Task { await model.open(result.item) }
            } label: {
                Label(UIStrings.openItem(result.item.kind), systemImage: SystemImages.open)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isAvailable == false)
            .help(
                isAvailable
                    ? UIStrings.openItem(result.item.kind)
                    : UIStrings.unavailableMatchHelp
            )
        }
    }
}
