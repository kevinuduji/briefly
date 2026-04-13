import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var state: BrieflyAppState

    @State private var businessName = ""
    @State private var businessType = ""
    @State private var businessDescription = ""
    @State private var primaryGoal: PrimaryGoal = .betterDecisions
    @State private var notificationsEnabled = true
    @State private var spreadsheetsNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Your business") {
                    TextField("Business name", text: $businessName)
                    TextField("Business type (e.g. salon, boutique)", text: $businessType)
                    TextField("Short description", text: $businessDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Primary goal") {
                    Picker("Goal", selection: $primaryGoal) {
                        ForEach(PrimaryGoal.allCases) { g in
                            Text(g.displayName).tag(g)
                        }
                    }
                }
                Section("Reminders") {
                    Toggle("Helpful notifications", isOn: $notificationsEnabled)
                }
                Section {
                    TextField("Optional: spreadsheets or documents you already use", text: $spreadsheetsNote, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Optional")
                }
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        Task {
                            await state.completeOnboarding(
                                businessName: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
                                businessType: businessType.trimmingCharacters(in: .whitespacesAndNewlines),
                                businessDescription: businessDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                primaryGoal: primaryGoal,
                                notificationsEnabled: notificationsEnabled,
                                spreadsheetsNote: spreadsheetsNote.isEmpty ? nil : spreadsheetsNote
                            )
                        }
                    }
                    .disabled(businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            AnalyticsService.log("onboarding_started", parameters: nil)
        }
    }
}
