import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: BrieflyAppState
    let log: DailyLogRow

    var body: some View {
        List {
            Section("Today’s summary") {
                Text(log.cleanedSummary ?? "—")
            }
            Section("Key signals") {
                if log.structuredData.keySignals.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(log.structuredData.keySignals, id: \.self) { s in
                        Text("• \(s)")
                    }
                }
            }
            Section("Metrics (grounded)") {
                Text("Traffic, sales, and conversion appear only when your words support them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Risks / watchouts") {
                if log.structuredData.risks.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(log.structuredData.risks, id: \.self) { r in
                        Text("• \(r)")
                    }
                }
            }
            Section("Recommended actions") {
                ActionsForLogSection(logId: log.id)
            }
            Section("Audio brief") {
                Button("Play brief") {
                    Task { await state.playBrief(for: log) }
                }
                if state.audioBriefPlayer.isPlaying {
                    Text("Playing…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Export") {
                Button("Generate daily recap PDF") {
                    Task { await state.exportDailyPDF(log: log) }
                }
            }
        }
        .navigationTitle("Dashboard")
    }
}

private struct ActionsForLogSection: View {
    @EnvironmentObject private var state: BrieflyAppState
    let logId: UUID

    @State private var actions: [ActionRecommendationRow] = []

    var body: some View {
        Group {
            if actions.isEmpty {
                Text("No actions for this log yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(actions) { a in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.headline)
                        if let r = a.reason {
                            Text(r).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task {
            actions = (try? await state.loadActionsForLog(logId: logId)) ?? []
        }
    }
}
