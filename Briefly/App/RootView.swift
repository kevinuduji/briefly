import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: BrieflyAppState
    @EnvironmentObject private var auth: AuthService
    @State private var tab: MainTab = .home

    var body: some View {
        Group {
            if auth.session == nil {
                SignInView()
            } else if !state.onboardingCompleted {
                OnboardingView()
            } else {
                TabView(selection: $tab) {
                    HomeView()
                        .tabItem { Label("Today", systemImage: "sun.max") }
                        .tag(MainTab.home)

                    ActionsListView()
                        .tabItem { Label("Actions", systemImage: "bolt") }
                        .tag(MainTab.actions)

                    TimelineView()
                        .tabItem { Label("Memory", systemImage: "clock") }
                        .tag(MainTab.timeline)

                    ReportsView()
                        .tabItem { Label("Reports", systemImage: "doc") }
                        .tag(MainTab.reports)
                }
            }
        }
    }
}
