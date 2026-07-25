import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    init(initialText: String = "") {
        _viewModel = StateObject(wrappedValue: ChatViewModel(initialText: initialText))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(AppTheme.Layout.padding)
                }
                .onChange(of: viewModel.messages) { _, messages in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if viewModel.inputText.isEmpty {
                moodChips
            }

            inputBar
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: isShowingResults) {
            RecommendationResultsView(profile: viewModel.pendingProfile ?? UserPreferenceProfile(source: .chat))
        }
    }

    private var isShowingResults: Binding<Bool> {
        Binding(
            get: { viewModel.pendingProfile != nil },
            set: { newValue in if !newValue { viewModel.pendingProfile = nil } }
        )
    }

    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(AppTheme.Layout.padding)
                .background(message.role == .user ? AppTheme.Colors.accent.opacity(0.25) : AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    /// Готовые подсказки настроения — снимают "паралич перед пустым полем".
    /// Тап просто подставляет фразу в поле, отправка остаётся ручной.
    private var moodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.moodSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.inputText = suggestion
                        isInputFocused = true
                    } label: {
                        Text(suggestion)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.surface)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, AppTheme.Layout.padding)
        }
        .padding(.bottom, 4)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Напишите сообщение…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusSmall))
                .focused($isInputFocused)
                .lineLimit(1...4)

            Button {
                viewModel.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppTheme.Layout.padding)
        .background(AppTheme.Colors.background)
    }
}
