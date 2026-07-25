import SwiftUI

struct RootTabView: View {
    enum Tab {
        case home
        case matches
        case assistant
        case myList
        case search
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        // "Моё" и "Поиск" — рабочие (WatchlistStore и поиск по каталогу).
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Главное", systemImage: "house.fill")
            }
            .tag(Tab.home)

            NavigationStack {
                SwipeMatchesView()
            }
            .tabItem {
                Label("Мэтчи", systemImage: "flame.fill")
            }
            .tag(Tab.matches)

            NavigationStack {
                AIAssistantHomeView()
            }
            .tabItem {
                Label("Атлас", systemImage: "sparkles")
            }
            .tag(Tab.assistant)

            NavigationStack {
                MyListView()
            }
            .tabItem {
                Label("Моё", systemImage: "bookmark.fill")
            }
            .tag(Tab.myList)

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)
        }
        .tint(AppTheme.Colors.accent)
        .preferredColorScheme(.dark)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .onAppear(perform: configureAppearance)
    }

    /// UIKit-компоненты (навбар/таббар) не всегда подхватывают тёмную тему
    /// автоматически — фиксируем цвета явно, чтобы не было светлых мельканий.
    private func configureAppearance() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(AppTheme.Colors.background)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Таб-бар в духе Кинопоиска: тёмная панель чуть светлее фона, без стеклянного
        // эффекта системы; активная вкладка оранжевая, неактивные — нейтрально-серые.
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.surfaceElevated)
        tabBarAppearance.backgroundEffect = nil
        tabBarAppearance.shadowColor = .clear

        let accent = UIColor(AppTheme.Colors.accent)
        let inactive = UIColor(AppTheme.Colors.textSecondary)
        for itemAppearance in [
            tabBarAppearance.stackedLayoutAppearance,
            tabBarAppearance.inlineLayoutAppearance,
            tabBarAppearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.selected.iconColor = accent
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: accent,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            itemAppearance.normal.iconColor = inactive
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: inactive,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
        }

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

#Preview {
    RootTabView()
}
