import SwiftUI

/// Focused conversational interface for local file and folder retrieval.
struct ChatView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var queryIsFocused: Bool

    /// Builds the assistant header, conversation, ranked matches, and composer.
    var body: some View {
        @Bindable var model = model
        ZStack {
            LinearGradient(
                colors: [
                    DesignTokens.Color.canvas,
                    DesignTokens.Color.primaryAccent.opacity(0.025),
                    DesignTokens.Color.voice.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if model.isIndexing {
                    BackgroundIndexingBanner()
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(
                            alignment: .leading,
                            spacing: DesignTokens.Spacing.large
                        ) {
                            if model.messages.isEmpty {
                                AssistantWelcomeView()
                                    .frame(maxWidth: .infinity, minHeight: 390)
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
                                }
                            }
                            Color.clear
                                .frame(height: DesignTokens.Spacing.xSmall)
                                .id(ChatScrollTarget.bottom)
                        }
                        .frame(maxWidth: DesignTokens.Window.contentMaximumWidth)
                        .padding(.horizontal, DesignTokens.Spacing.xLarge)
                        .padding(.vertical, DesignTokens.Spacing.xxLarge)
                        .frame(maxWidth: .infinity)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: model.messages.count) { _, _ in
                        scrollToBottom(using: proxy, animated: true)
                    }
                    .onChange(of: model.isBusy) { _, isBusy in
                        if isBusy == false {
                            scrollToBottom(using: proxy, animated: true)
                        }
                    }
                }
                composer
            }
        }
        .onAppear { queryIsFocused = true }
        .onChange(of: model.inputFocusRequest) { _, _ in
            queryIsFocused = true
        }
    }

    /// Builds the app identity, offline status, and Settings entry point.
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Color.primaryAction,
                                DesignTokens.Color.voiceFill
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: SystemImages.assistant)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(
                width: DesignTokens.Control.appIconSize,
                height: DesignTokens.Control.appIconSize
            )
            .shadow(
                color: DesignTokens.Color.primaryAccent.opacity(0.22),
                radius: 8,
                y: 3
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.appName)
                    .font(.headline.weight(.semibold))
                Text(UIStrings.assistantSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusPill(
                title: UIStrings.localOnly,
                systemImage: SystemImages.localVerified,
                tint: DesignTokens.Color.verifiedLocal
            )

            Button {
                model.showActivity()
            } label: {
                Image(systemName: SystemImages.activity)
            }
            .buttonStyle(
                IconActionButtonStyle(
                    tint: model.isIndexing
                        ? DesignTokens.Color.processing
                        : DesignTokens.Color.primaryAccent,
                    fill: model.isIndexing
                        ? DesignTokens.Color.processingSurface
                        : DesignTokens.Color.selectedSurface,
                    size: DesignTokens.Control.compactIconButtonSize
                )
            )
            .accessibilityLabel(UIStrings.activity)
            .help(UIStrings.activity)

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

            Button {
                model.showSettings()
            } label: {
                Image(systemName: SystemImages.settings)
            }
            .buttonStyle(
                IconActionButtonStyle(
                    tint: DesignTokens.Color.graphite,
                    fill: DesignTokens.Color.subtleFill,
                    size: DesignTokens.Control.compactIconButtonSize
                )
            )
            .accessibilityLabel(UIStrings.settings)
            .help(UIStrings.settings)
        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.vertical, DesignTokens.Spacing.medium)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.hairline)
                .frame(height: 1)
        }
    }

    /// Builds the text, voice, busy-state, and submit controls.
    private var composer: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            if model.isBusy || model.isListening {
                HStack(spacing: DesignTokens.Spacing.small) {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(DesignTokens.Color.processing)
                    }
                    Text(model.isListening ? UIStrings.listening : UIStrings.workingLocally)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            model.isListening
                                ? DesignTokens.Color.voice
                                : DesignTokens.Color.processing
                        )
                }
                .padding(.horizontal, DesignTokens.Spacing.xSmall)
            }

            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.medium) {
                Button {
                    Task {
                        if model.isListening {
                            await model.stopListening()
                        } else {
                            await model.startListening()
                        }
                    }
                } label: {
                    Image(
                        systemName: model.isListening
                            ? SystemImages.stop
                            : SystemImages.microphone
                    )
                }
                .buttonStyle(
                    IconActionButtonStyle(
                        tint: model.isListening
                            ? DesignTokens.Color.destructive
                            : DesignTokens.Color.voice,
                        fill: model.isListening
                            ? DesignTokens.Color.destructiveSurface
                            : DesignTokens.Color.voiceSurface
                    )
                )
                .disabled(model.isBusy)
                .accessibilityLabel(
                    model.isListening
                        ? UIStrings.stopListening
                        : UIStrings.startListening
                )
                .help(
                    model.isListening
                        ? UIStrings.stopListening
                        : UIStrings.startListening
                )

                TextField(
                    UIStrings.searchPlaceholder,
                    text: $model.queryText,
                    axis: .vertical
                )
                .focused($queryIsFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.vertical, DesignTokens.Spacing.small)
                .onSubmit { Task { await model.submit() } }

                Button {
                    Task { await model.submit() }
                } label: {
                    Image(systemName: SystemImages.send)
                }
                .buttonStyle(
                    IconActionButtonStyle(
                        tint: .white,
                        fill: DesignTokens.Color.primaryAction
                    )
                )
                .disabled(
                    model.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.isBusy
                )
                .accessibilityLabel(UIStrings.answerWithEvidence)
                .help(UIStrings.answerWithEvidence)
            }
            .padding(DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                    .fill(DesignTokens.Color.assistantSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                    .stroke(
                        queryIsFocused
                            ? DesignTokens.Color.focusRing
                            : DesignTokens.Color.hairline,
                        lineWidth: queryIsFocused ? 1.5 : 1
                    )
            )
            .shadow(
                color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
                radius: DesignTokens.Shadow.floatingRadius,
                y: DesignTokens.Shadow.floatingY
            )

            Text(UIStrings.composerHint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, DesignTokens.Spacing.small)
        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.top, DesignTokens.Spacing.medium)
        .padding(.bottom, DesignTokens.Spacing.large)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Color.hairline)
                .frame(height: 1)
        }
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

/// Purposeful empty state that demonstrates both conversation and file retrieval.
private struct AssistantWelcomeView: View {
    @Environment(AppModel.self) private var model

    /// Builds the welcome identity, privacy promise, and editable example requests.
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Color.primaryAccent.opacity(0.16),
                                DesignTokens.Color.voice.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: SystemImages.assistant)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.primaryAccent)
            }
            .frame(width: 72, height: 72)

            VStack(spacing: DesignTokens.Spacing.small) {
                Text(UIStrings.welcomeTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(UIStrings.welcomeDetail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            StatusPill(
                title: UIStrings.privateOnThisMac,
                systemImage: SystemImages.localVerified,
                tint: DesignTokens.Color.verifiedLocal
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Text(UIStrings.welcomePromptTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                promptButton(UIStrings.welcomePromptOne)
                promptButton(UIStrings.welcomePromptTwo)
                promptButton(UIStrings.welcomePromptThree)
            }
            .frame(maxWidth: 470)
        }
        .padding(DesignTokens.Spacing.xxLarge)
    }

    /// Builds one example request that is inserted for review instead of sent blindly.
    /// - Parameter prompt: Example request copied into the composer.
    /// - Returns: A full-width supporting action for the empty state.
    private func promptButton(_ prompt: String) -> some View {
        Button {
            model.queryText = prompt
            model.requestInputFocus()
        } label: {
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: SystemImages.prompt)
                    .foregroundStyle(DesignTokens.Color.primaryAccent)
                Text(prompt)
                    .lineLimit(1)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SecondaryActionButtonStyle())
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
        isUser ? Color.white.opacity(0.78) : DesignTokens.Color.primaryAccent
    }

    /// Builds a readable message anchored to the correct side of the conversation.
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            if isUser == false {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Color.primaryAccent.opacity(0.15),
                                    DesignTokens.Color.voice.opacity(0.13)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: SystemImages.assistant)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Color.primaryAccent)
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

                    StyledMessageText(text: message.text, isUser: isUser)
                }
                .padding(.horizontal, DesignTokens.Spacing.large)
                .padding(.vertical, DesignTokens.Spacing.medium)
                .background(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.large,
                        style: .continuous
                    )
                    .fill(
                        isUser
                            ? DesignTokens.Color.userSurface
                            : DesignTokens.Color.assistantSurface
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.large,
                        style: .continuous
                    )
                    .stroke(
                        isUser
                            ? Color.white.opacity(0.10)
                            : DesignTokens.Color.hairline
                    )
                )
                .shadow(
                    color: .black.opacity(isUser ? 0.08 : 0.045),
                    radius: isUser ? 8 : 5,
                    y: 2
                )
                .frame(
                    maxWidth: DesignTokens.Message.maximumWidth,
                    alignment: isUser ? .trailing : .leading
                )
                .fixedSize(horizontal: false, vertical: true)

                Text(UIStrings.messageTimestamp(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xSmall)
            }
            .frame(
                maxWidth: DesignTokens.Message.maximumWidth,
                alignment: isUser ? .trailing : .leading
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: isUser ? .trailing : .leading
        )
        .accessibilityElement(children: .combine)
    }
}

/// Selectable local rich text for user and assistant conversation content.
private struct StyledMessageText: View {
    let text: String
    let isUser: Bool

    private var foregroundColor: Color {
        isUser ? .white : DesignTokens.Color.graphite
    }

    private var messageFont: Font {
        isUser ? .body.weight(.medium) : .body
    }

    private var renderedText: AttributedString {
        let normalizedText = Self.normalizedListMarkers(in: text)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        var attributedText =
            (try? AttributedString(markdown: normalizedText, options: options))
            ?? AttributedString(normalizedText)
        let linkedRanges = attributedText.runs.compactMap { run in
            run.link == nil ? nil : run.range
        }
        for linkedRange in linkedRanges {
            attributedText[linkedRange].link = nil
        }
        return attributedText
    }

    /// Builds semantic message typography without a web-rendering surface.
    var body: some View {
        Text(renderedText)
            .font(messageFont)
            .foregroundStyle(foregroundColor)
            .lineSpacing(DesignTokens.Message.lineSpacing)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Replaces common Markdown bullet prefixes with stable visible bullets.
    /// - Parameter text: Raw user or assistant message text.
    /// - Returns: Message text with simple unordered-list markers normalized.
    private static func normalizedListMarkers(in text: String) -> String {
        text.split(separator: AppConstants.Text.newline, omittingEmptySubsequences: false)
            .map { line in
                let fullLine = String(line)
                let leadingWhitespace = fullLine.prefix {
                    $0 == AppConstants.Text.spaceCharacter
                        || $0 == AppConstants.Text.tabCharacter
                }
                let content = fullLine.dropFirst(leadingWhitespace.count)
                if content.hasPrefix(AppConstants.Text.markdownDashListPrefix)
                    || content.hasPrefix(AppConstants.Text.markdownAsteriskListPrefix) {
                    return String(leadingWhitespace)
                        + AppConstants.Text.visibleBulletPrefix
                        + content.dropFirst(AppConstants.Text.markdownListPrefixLength)
                }
                return fullLine
            }
            .joined(separator: AppConstants.Text.newline)
    }
}

/// Stable scroll destination placed after the newest conversation content.
private enum ChatScrollTarget: Hashable {
    case bottom
}
