import SwiftUI

struct ReviewConfirmView: View {
    @EnvironmentObject private var state: BrieflyAppState
    @Environment(\.dismiss) private var dismiss

    @State private var log: DailyLogRow

    @State private var transcript: String
    @State private var summary: String
    @State private var keySignals: [String]
    @State private var risks: [String]
    @State private var isSaving = false

    init(log: DailyLogRow) {
        _log = State(initialValue: log)
        _transcript = State(initialValue: log.rawTranscript ?? "")
        _summary = State(initialValue: log.cleanedSummary ?? "")
        _keySignals = State(initialValue: log.structuredData.keySignals.isEmpty ? [""] : log.structuredData.keySignals)
        _risks = State(initialValue: log.structuredData.risks.isEmpty ? [""] : log.structuredData.risks)
    }

    var body: some View {
        Form {
            Section("Transcript") {
                TextEditor(text: $transcript)
                    .frame(minHeight: 120)
            }
            Section("Summary") {
                TextEditor(text: $summary)
                    .frame(minHeight: 80)
            }
            Section("Key signals") {
                ForEach(keySignals.indices, id: \.self) { i in
                    TextField("Signal", text: binding($keySignals, index: i))
                }
                Button("Add signal") {
                    keySignals.append("")
                }
            }
            Section("Risks / watchouts") {
                ForEach(risks.indices, id: \.self) { i in
                    TextField("Risk", text: binding($risks, index: i))
                }
                Button("Add risk") {
                    risks.append("")
                }
            }
            if let notes = log.confidenceNotes, !notes.isEmpty {
                Section("Confidence") {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Review")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving {
                ProgressView()
            }
        }
    }

    private func binding(_ array: Binding<[String]>, index: Int) -> Binding<String> {
        Binding(
            get: { array.wrappedValue[index] },
            set: { array.wrappedValue[index] = $0 }
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let cleanedSignals = keySignals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let cleanedRisks = risks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        var structured = log.structuredData
        structured.keySignals = cleanedSignals
        structured.risks = cleanedRisks

        do {
            try await state.confirmLog(
                log,
                editedStructured: structured,
                editedSummary: summary,
                editedTranscript: transcript
            )
            if let uid = state.userId {
                await state.refreshHome(userId: uid)
            }
            dismiss()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
