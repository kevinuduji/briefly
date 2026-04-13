import SwiftUI

struct ActionsListView: View {
    @EnvironmentObject private var state: BrieflyAppState

    var body: some View {
        NavigationStack {
            List {
                if state.pendingActions.isEmpty {
                    ContentUnavailableView("No pending actions", systemImage: "checkmark.circle")
                } else {
                    ForEach(state.pendingActions) { action in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(action.title).font(.headline)
                            if let r = action.reason {
                                Text(r).font(.subheadline).foregroundStyle(.secondary)
                            }
                            HStack {
                                Button("Done") {
                                    Task { await state.markAction(action, status: .done, feedback: nil) }
                                }
                                .buttonStyle(.borderedProminent)
                                Button("Skip") {
                                    Task { await state.markAction(action, status: .skipped, feedback: nil) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Actions")
            .refreshable {
                if let uid = state.userId {
                    await state.refreshHome(userId: uid)
                }
            }
            .onAppear {
                AnalyticsService.log("dashboard_viewed", parameters: ["surface": "actions_tab"])
            }
        }
    }
}
