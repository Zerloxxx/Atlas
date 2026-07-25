import SwiftUI

/// Список прошлых запросов к ИИ — тап на запись открывает те же карточки,
/// что были показаны тогда, без повторного обращения к ИИ.
struct HistoryView: View {
    @ObservedObject private var history = RecommendationHistoryStore.shared

    var body: some View {
        ScrollView {
            if history.entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: AppTheme.Layout.spacing) {
                    ForEach(history.entries) { entry in
                        NavigationLink {
                            HistoryDetailView(entry: entry)
                        } label: {
                            entryRow(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Layout.padding)
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("История запросов")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entryRow(_ entry: RecommendationHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.scenarioLabel)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if !entry.queryDescription.isEmpty {
                        Text(entry.queryDescription)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(entry.date.ruShort)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(entry.items.prefix(5), id: \.movieId) { item in
                    PosterImageView(movieId: item.movieId)
                        .frame(width: 40, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Layout.padding)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Пока пусто")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Здесь появятся прошлые запросы к ИИ и что он посоветовал")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}
