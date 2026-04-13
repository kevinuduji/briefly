import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var state: BrieflyAppState

    var body: some View {
        NavigationStack {
            List {
                if state.generatedReports.isEmpty {
                    ContentUnavailableView(
                        "No exports yet",
                        systemImage: "doc.richtext",
                        description: Text("Generate a PDF from a daily dashboard.")
                    )
                } else {
                    ForEach(state.generatedReports) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.title ?? r.reportType).font(.headline)
                            Text(r.storagePath).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .refreshable {
                if let uid = state.userId {
                    await state.refreshHome(userId: uid)
                }
            }
        }
    }
}
