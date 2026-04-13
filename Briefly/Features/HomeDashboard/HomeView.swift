import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: BrieflyAppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    recordCTA
                    if let top = state.pendingActions.first {
                        topActionCard(top)
                    }
                    if let log = state.todayLog {
                        todaySummaryCard(log)
                    } else {
                        ContentUnavailableView(
                            "No check-in yet today",
                            systemImage: "waveform",
                            description: Text("Record a short update to build your dashboard.")
                        )
                        .frame(maxWidth: .infinity)
                    }
                    memoryHint
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        Task { await state.auth.signOut() }
                    }
                }
            }
            .refreshable {
                if let uid = state.userId {
                    await state.refreshHome(userId: uid)
                }
            }
            .onAppear {
                if let uid = state.userId {
                    Task { await state.refreshHome(userId: uid) }
                }
                AnalyticsService.log("dashboard_viewed", parameters: ["surface": "home"])
            }
        }
    }

    private var recordCTA: some View {
        NavigationLink {
            RambleCaptureView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Record Today’s Update")
                        .font(.title3.bold())
                    Text("One tap. Talk naturally. Briefly structures it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 40))
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }

    private func topActionCard(_ action: ActionRecommendationRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most important action")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(action.title)
                .font(.headline)
            if let reason = action.reason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(0.35)))
    }

    private func todaySummaryCard(_ log: DailyLogRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today’s snapshot")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    DashboardView(log: log)
                } label: {
                    Text("Open dashboard")
                }
                .font(.subheadline)
            }
            if let s = log.cleanedSummary {
                Text(s)
                    .font(.body)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var memoryHint: some View {
        HStack {
            Image(systemName: "brain.head.profile")
            Text(state.recentLogs.count >= 2 ? "Your business memory is growing." : "Each check-in makes the next recommendation smarter.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
