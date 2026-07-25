import SwiftUI

/// Экран личного профиля — визуальная копия структуры реального сервиса
/// для демо-достоверности (см. README.md, "Объём"): большая часть кнопок
/// здесь декоративна, реальна только "Поделиться".
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var placeholderMessage: String?
    @ObservedObject private var watchlist = WatchlistStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacing * 1.5) {
                topBar
                avatarSection
                nameBlock
                statsRow
                actionButtons

                Rectangle()
                    .fill(AppTheme.Colors.divider)
                    .frame(height: 1)

                kidsRow

                suggestedSection
            }
            .padding(AppTheme.Layout.padding)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert(
            "Демо-версия",
            isPresented: Binding(
                get: { placeholderMessage != nil },
                set: { if !$0 { placeholderMessage = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(placeholderMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            Spacer()
            Button {
                placeholderMessage = "Редактирование профиля доступно в реальном сервисе."
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
        }
        .padding(.top, 8)
    }

    private var avatarSection: some View {
        HStack(spacing: AppTheme.Layout.spacing) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.surfaceElevated)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
                Circle()
                    .stroke(AppTheme.Colors.accentGradient, lineWidth: 3)
                    .frame(width: 90, height: 90)
            }

            Spacer()

            pillButton("Изменить фон") {
                placeholderMessage = "Смена оформления профиля доступна в реальном сервисе."
            }
        }
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Максим")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Публичный профиль")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 28) {
            statColumn(value: "0", label: "подписки")
            statColumn(value: "0", label: "подписчики")
            statColumn(value: "\(watchlist.savedMovieIds.count)", label: "фильмы и сериалы")
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            pillButton("Добавить друзей", expand: true) {
                placeholderMessage = "Добавление друзей доступно в реальном сервисе."
            }
            ShareLink(item: "Мой профиль в КИНОТЕАТР") {
                Text("Поделиться")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.surfaceElevated)
                    .clipShape(Capsule())
            }
        }
    }

    private var kidsRow: some View {
        Button {
            placeholderMessage = "Детский профиль доступен в реальном сервисе."
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.Colors.surfaceElevated)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "face.smiling")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Дети")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("12+")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Вы можете знать")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Text("Ещё")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: AppTheme.Colors.posterGradient(for: index),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.85)))
                                .overlay(Circle().stroke(AppTheme.Colors.accentGradient, lineWidth: 2))

                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, AppTheme.Colors.surfaceElevated)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func pillButton(_ title: String, expand: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: expand ? .infinity : nil)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.surfaceElevated)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
