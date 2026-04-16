import SwiftUI

struct RambleCaptureView: View {
    @EnvironmentObject private var state: BrieflyAppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = RambleCaptureEngine()
    @State private var isWorking = false
    @State private var navigateToReview: DailyLogRow?

    var body: some View {
        VStack(spacing: 24) {
            Text("What happened today?")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 120)
                HStack(spacing: 10) {
                    ForEach(0..<24, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.25 + Double(i % 5) * 0.05))
                            .frame(width: 4, height: CGFloat(30 + (i % 7) * 8) * (0.2 + CGFloat(engine.waveformLevel)))
                    }
                }
                .opacity(engine.isRecording ? 1 : 0.25)
            }

            ScrollView {
                Text(engine.liveTranscript.isEmpty ? "Live transcript appears as you speak…" : engine.liveTranscript)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
            .frame(maxHeight: 220)

            hints

            if engine.isRecording {
                Button(role: .destructive) {
                    Task { await stopAndSubmit() }
                } label: {
                    Label("Stop & process", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    Task { await start() }
                } label: {
                    Label("Start recording", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
            }

            if isWorking {
                ProgressView("Processing with your business context…")
            }
            if let err = engine.errorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
            if let err = state.errorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $navigateToReview) { log in
            ReviewConfirmView(log: log)
        }
        .onAppear { state.errorMessage = nil }
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Try mentioning:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach([
                "What sold today?",
                "How busy was it?",
                "Inventory or supply issues?",
                "Anything you changed or tried?",
            ], id: \.self) { line in
                Text("• \(line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func start() async {
        let ok = await engine.requestPermissions()
        guard ok else {
            engine.errorMessage = "Microphone or speech permission is required."
            return
        }
        do {
            AnalyticsService.log("first_ramble_started", parameters: ["stage": "record"])
            try engine.startSession()
        } catch {
            engine.errorMessage = error.localizedDescription
        }
    }

    private func stopAndSubmit() async {
        guard engine.isRecording else { return }
        engine.stopSession()
        isWorking = true
        defer { isWorking = false }
        do {
            let log = try await state.processCapturedSession(engine: engine)
            navigateToReview = log
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
