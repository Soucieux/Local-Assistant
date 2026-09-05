import SwiftUI

/// Retained conversation interface for reviewing earlier requests and results.
struct ConversationHistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Builds the history header and complete retained conversation.
    var body: some View {
        ZStack {
            CompanionCanvasBackground()

            VStack(spacing: 0) {
                header
                GeometryReader { viewport in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(
                                alignment: .leading,
                                spacing: DesignTokens.Spacing.large
                            ) {
                                if model.messages.isEmpty {
                                    historyEmptyState
                                        .frame(maxWidth: .infinity)
                                }
                                ForEach(model.messages) { message in
                                    VStack(
                                        alignment: .leading,
                                        spacing: DesignTokens.Spacing.medium
                                    ) {
                                        MessageBubble(message: message)
                                        if message.fileMatches.isEmpty == false {
                                            SearchResultsView(results: message.fileMatches)
                                        }
                                        if message.reminderMatches.isEmpty == false {
                                            CommandReminderFindingsGrid(
                                                results: message.reminderMatches,
                                                presentation: message.reminderPresentation
                                            )
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Color.clear
                                    .frame(height: DesignTokens.Spacing.xSmall)
                                    .id(ChatScrollTarget.bottom)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xLarge)
                            .padding(.vertical, DesignTokens.Spacing.xxLarge)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: viewport.size.height,
                                alignment: model.messages.isEmpty ? .center : .topLeading
                            )
                        }
                        .defaultScrollAnchor(model.messages.isEmpty ? .center : .bottom)
                        .onChange(of: model.messages.count) { _, _ in
                            scrollToBottom(using: scrollProxy, animated: true)
                        }
                    }
                }
            }
        }
    }

    /// Builds navigation, history identity, and destructive history action.
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                model.showAssistant()
            } label: {
                Label(UIStrings.assistant, systemImage: SystemImages.back)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(DesignTokens.Color.commandAccent.opacity(0.10))
                Image(systemName: SystemImages.history)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(DesignTokens.Color.commandAccent)
            }
            .frame(
                width: DesignTokens.Control.appIconSize,
                height: DesignTokens.Control.appIconSize
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.historyTitle)
                    .font(.title3.monospaced().weight(.semibold))
                Text(UIStrings.historyDetail)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.commandMutedInk)
            }

            Spacer()

            Button {
                model.requestConversationClearConfirmation()
            } label: {
                Image(systemName: SystemImages.clearConversation)
            }
            .buttonStyle(
                IconActionButtonStyle(
                    tint: DesignTokens.Color.destructive,
                    fill: DesignTokens.Color.destructiveSurface,
                    size: DesignTokens.Control.compactIconButtonSize
                )
            )
            .disabled(
                model.messages.isEmpty
                    || model.isBusy
                    || model.isListening
            )
            .accessibilityLabel(UIStrings.clearConversation)
            .help(UIStrings.clearConversation)

        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.vertical, DesignTokens.Spacing.medium)
        .background(DesignTokens.Color.commandLightCanvas.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.28))
                .frame(height: 1)
        }
    }

    /// Builds the explanation shown before any retained messages exist.
    private var historyEmptyState: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: SystemImages.history)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(DesignTokens.Color.commandAccent)
            Text(UIStrings.historyEmptyTitle)
                .font(.title3.monospaced().weight(.semibold))
            Text(UIStrings.historyEmptyDetail)
                .font(.body)
                .foregroundStyle(DesignTokens.Color.commandMutedInk)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.xxLarge)
    }

    /// Moves the conversation to its newest visible content.
    /// - Parameters:
    ///   - proxy: Reader proxy for the conversation scroll view.
    ///   - animated: Whether ordinary motion should accompany the update.
    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool) {
        if animated && reduceMotion == false {
            withAnimation(.easeOut(duration: DesignTokens.Motion.scrollDuration)) {
                proxy.scrollTo(ChatScrollTarget.bottom, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(ChatScrollTarget.bottom, anchor: .bottom)
        }
    }
}

/// One compact conversation message with explicit role-based alignment.
private struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    private var senderLabel: String {
        isUser ? UIStrings.userMessageSender : UIStrings.assistantMessageSender
    }

    private var senderLabelColor: Color {
        isUser ? Color.white.opacity(0.78) : DesignTokens.Color.commandAccent
    }

    /// Builds a readable message anchored to the correct side of the conversation.
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            if isUser == false {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(DesignTokens.Color.commandAccent.opacity(0.10))
                    Image(systemName: SystemImages.assistant)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Color.commandAccent)
                }
                .frame(
                    width: DesignTokens.Message.avatarSize,
                    height: DesignTokens.Message.avatarSize
                )
            }

            VStack(
                alignment: isUser ? .trailing : .leading,
                spacing: DesignTokens.Spacing.xSmall
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                    Text(senderLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(senderLabelColor)
                        .textCase(.uppercase)
                        .tracking(0.45)

                    StyledMessageText(text: displayText, isUser: isUser)
                }
                .padding(.horizontal, DesignTokens.Spacing.large)
                .padding(.vertical, DesignTokens.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        isUser
                            ? DesignTokens.Color.userSurface
                            : DesignTokens.Color.assistantSurface
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .stroke(
                        isUser
                            ? Color.white.opacity(0.16)
                            : DesignTokens.Color.commandInk.opacity(0.22)
                    )
                )
                .shadow(
                    color: .black.opacity(0.025),
                    radius: 3,
                    y: 1
                )
                .frame(
                    maxWidth: isUser ? DesignTokens.Message.maximumWidth : .infinity,
                    alignment: isUser ? .trailing : .leading
                )
                .fixedSize(horizontal: false, vertical: true)

                Text(UIStrings.messageTimestamp(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xSmall)
            }
            .frame(
                maxWidth: isUser ? DesignTokens.Message.maximumWidth : .infinity,
                alignment: isUser ? .trailing : .leading
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: isUser ? .trailing : .leading
        )
        .accessibilityElement(children: .combine)
    }

    /// Replaces verbose saved list prose when reminder cards already carry every item detail.
    private var displayText: String {
        guard isUser == false,
              message.reminderMatches.isEmpty == false,
              message.reminderPresentation == .grouped
                || message.reminderMatches.count > 1 else {
            return message.text
        }
        let tags = Set(message.reminderMatches.map { result in
            let tag = result.item.tag?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? AppConstants.Text.empty
            return tag.isEmpty
                ? ReminderConstants.Presentation.untaggedGroupIdentifier
                : tag.lowercased()
        })
        return ReminderStrings.reminderListSummary(
            count: message.reminderMatches.count,
            groupCount: tags.count
        )
    }
}

/// Selectable local rich text for user and assistant conversation content.
private struct StyledMessageText: View {
    let text: String
    let isUser: Bool

    /// Parses user-message inline Markdown while removing active link destinations.
    private var renderedUserText: AttributedString {
        .inertInlineMarkdown(text)
    }

    /// Builds user inline text or the shared native assistant document renderer.
    @ViewBuilder
    var body: some View {
        if isUser {
            Text(renderedUserText)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .lineSpacing(DesignTokens.Message.lineSpacing)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ResponseMarkdownView(text: text, presentation: .history)
        }
    }
}

/// Stable scroll destination placed after the newest conversation content.
private enum ChatScrollTarget: Hashable {
    case bottom
}
