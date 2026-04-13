import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var state: BrieflyAppState

    var body: some View {
        NavigationStack {
            List {
                ForEach(state.recentLogs) { log in
                    NavigationLink {
                        DashboardView(log: log)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.logDate).font(.caption).foregroundStyle(.secondary)
                            Text(log.cleanedSummary ?? "Update")
                                .font(.body)
                        }
                    }
                }
            }
            .navigationTitle("Memory")
            .refreshable {
                if let uid = state.userId {
                    await state.refreshHome(userId: uid)
                }
            }
            .onAppear {
                AnalyticsService.log("timeline_viewed", parameters: nil)
            }
        }
    }
}
