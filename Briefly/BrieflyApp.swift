import SwiftUI

@main
struct BrieflyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var deps = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deps.state)
                .environmentObject(deps.auth)
        }
    }
}
