import Foundation
import Supabase

@MainActor
final class BrieflyAppState: ObservableObject {
    @Published private(set) var profile: UserProfileRow?
    @Published private(set) var todayLog: DailyLogRow?
    @Published private(set) var pendingActions: [ActionRecommendationRow] = []
    @Published private(set) var recentLogs: [DailyLogRow] = []
    @Published private(set) var generatedReports: [GeneratedReportRow] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published var onboardingCompleted: Bool {
        didSet { UserDefaults.standard.set(onboardingCompleted, forKey: Keys.onboarding) }
    }

    let client: SupabaseClient
    let auth: AuthService
    let profileRepo: ProfileRepository
    let dailyLogRepo: DailyLogRepository
    let metricRepo: MetricRepository
    let actionRepo: ActionRepository
    let reportRepo: ReportRepository
    let storage: StorageService
    let edge: EdgeFunctionsService
    let notifications: NotificationManager
    let audioBriefPlayer: AudioBriefPlayer

    private enum Keys {
        static let onboarding = "briefly.onboarding.completed"
    }

    init(
        client: SupabaseClient,
        auth: AuthService,
        profileRepo: ProfileRepository,
        dailyLogRepo: DailyLogRepository,
        metricRepo: MetricRepository,
        actionRepo: ActionRepository,
        reportRepo: ReportRepository,
        storage: StorageService,
        edge: EdgeFunctionsService,
        notifications: NotificationManager,
        audioBriefPlayer: AudioBriefPlayer
    ) {
        self.client = client
        self.auth = auth
        self.profileRepo = profileRepo
        self.dailyLogRepo = dailyLogRepo
        self.metricRepo = metricRepo
        self.actionRepo = actionRepo
        self.reportRepo = reportRepo
        self.storage = storage
        self.edge = edge
        self.notifications = notifications
        self.audioBriefPlayer = audioBriefPlayer
        onboardingCompleted = UserDefaults.standard.bool(forKey: Keys.onboarding)
    }

    var userId: UUID? {
        auth.session?.user.id
    }

    func bootstrap() async {
        await auth.restoreSession()
        guard let uid = userId else {
            profile = nil
            return
        }
        await refreshProfile(userId: uid)
        await refreshHome(userId: uid)
    }

    func refreshProfile(userId: UUID) async {
        do {
            profile = try await profileRepo.fetchProfile(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshHome(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let today = DateOnly.todayString()
            todayLog = try await dailyLogRepo.fetchTodayProcessed(userId: userId, logDate: today)
            pendingActions = try await actionRepo.fetchPending(userId: userId)
            recentLogs = try await dailyLogRepo.fetchRecent(userId: userId, limit: 5)
            generatedReports = try await reportRepo.fetchRecent(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeOnboarding(
        businessName: String,
        businessType: String,
        businessDescription: String,
        primaryGoal: PrimaryGoal,
        notificationsEnabled: Bool,
        spreadsheetsNote: String?
    ) async {
        guard let uid = userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let row = UserProfileRow(
                id: uid,
                createdAt: nil,
                businessName: businessName,
                businessType: businessType,
                businessDescription: businessDescription,
                primaryGoal: primaryGoal.rawValue,
                notificationsEnabled: notificationsEnabled,
                spreadsheetsOrDocumentsNote: spreadsheetsNote
            )
            try await profileRepo.upsertProfile(row)
            try await profileRepo.upsertBusinessProfile(
                userId: uid,
                businessType: businessType,
                operatingNotes: businessDescription
            )
            if notificationsEnabled {
                _ = await notifications.requestAuthorization()
                await notifications.scheduleDailyCheckIn()
            }
            onboardingCompleted = true
            profile = row
            AnalyticsService.log("onboarding_completed", parameters: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// After local capture: create draft, upload audio, run Edge function, persist structured review payload.
    func processCapturedSession(engine: RambleCaptureEngine) async throws -> DailyLogRow {
        guard let uid = userId else { throw BrieflyError.notSignedIn }
        guard let audioURL = engine.outputFileURL else { throw BrieflyError.missingAudio }
        let p = try await profileRepo.fetchProfile(userId: uid)

        let logDate = DateOnly.todayString()
        var draft = try await dailyLogRepo.createDraft(
            userId: uid,
            logDate: logDate,
            transcript: engine.liveTranscript,
            audioPath: nil
        )

        let path = try await storage.uploadAudio(userId: uid, logId: draft.id, localFileURL: audioURL)
        draft.audioStoragePath = path

        let response = try await edge.processDailyLog(
            transcript: nil,
            audioStoragePath: path,
            profile: p
        )

        draft.rawTranscript = response.transcript
        draft.cleanedSummary = response.cleanedSummary
        draft.confidenceNotes = response.confidenceNotes
        draft.structuredData = response.structuredData
        draft.audioStoragePath = path
        draft.status = .draft

        try await dailyLogRepo.updateLog(draft)
        AnalyticsService.log("first_ramble_completed", parameters: ["log_id": draft.id.uuidString])
        return draft
    }

    /// User confirms structured review: regenerate metrics/actions with `structuredOverride`, then commit.
    func confirmLog(_ log: DailyLogRow, editedStructured: StructuredBusinessData, editedSummary: String, editedTranscript: String) async throws {
        guard let uid = userId else { throw BrieflyError.notSignedIn }
        let profile = try await profileRepo.fetchProfile(userId: uid)
        let response = try await edge.processDailyLog(
            transcript: editedTranscript,
            audioStoragePath: nil,
            structuredOverride: editedStructured,
            profile: profile
        )

        var updated = log
        updated.rawTranscript = editedTranscript
        let trimmedSummary = editedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.cleanedSummary = trimmedSummary.isEmpty ? response.cleanedSummary : trimmedSummary
        updated.structuredData = editedStructured
        updated.confidenceNotes = response.confidenceNotes
        updated.status = .processed

        try await dailyLogRepo.updateLog(updated)
        try await metricRepo.replaceForLog(logId: updated.id, metrics: response.metrics)
        try await actionRepo.replaceForLog(userId: uid, logId: updated.id, actions: response.actions)

        await refreshHome(userId: uid)
        AnalyticsService.log("action_generated", parameters: ["count": "\(response.actions.count)", "log_id": updated.id.uuidString])
        AnalyticsService.log("dashboard_viewed", parameters: ["log_id": updated.id.uuidString])
    }

    func markAction(_ action: ActionRecommendationRow, status: ActionStatus, feedback: String?) async {
        guard let uid = userId else { return }
        do {
            try await actionRepo.updateStatus(actionId: action.id, status: status)
            if status == .done || status == .skipped {
                try await actionRepo.insertOutcome(
                    actionId: action.id,
                    userId: uid,
                    userFeedback: feedback,
                    outcomeSummary: feedback,
                    perceivedEffect: nil
                )
            }
            await refreshHome(userId: uid)
            AnalyticsService.log(
                status == .done ? "action_marked_done" : "action_skipped",
                parameters: ["action_id": action.id.uuidString]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playBrief(for log: DailyLogRow) async {
        guard let summary = log.cleanedSummary else { return }
        let text = [summary, log.structuredData.keySignals.prefix(2).joined(separator: "; ")].joined(separator: "\n")
        do {
            let res = try await edge.generateAudioBrief(text: text)
            try audioBriefPlayer.playBase64MP3(res.audioBase64)
            AnalyticsService.log("audio_brief_played", parameters: ["log_id": log.id.uuidString])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadActionsForLog(logId: UUID) async throws -> [ActionRecommendationRow] {
        try await actionRepo.fetchForLog(logId: logId)
    }

    func exportDailyPDF(log: DailyLogRow) async {
        guard let uid = userId else { return }
        let title = "Daily recap — \(log.logDate)"
        let body = [
            log.cleanedSummary,
            "Signals: \(log.structuredData.keySignals.joined(separator: "; "))",
            "Watchouts: \(log.structuredData.risks.joined(separator: "; "))",
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")

        let data = PDFReportBuilder.buildDailyRecap(title: title, body: body)
        let reportId = UUID()
        do {
            let path = try await storage.uploadReportPDF(userId: uid, reportId: reportId, data: data)
            let row = GeneratedReportRow(
                id: reportId,
                userId: uid,
                createdAt: nil,
                reportType: "daily_recap",
                title: title,
                storagePath: path,
                relatedLogIds: [log.id]
            )
            try await reportRepo.insertReport(row)
            AnalyticsService.log("report_exported", parameters: ["report_id": reportId.uuidString])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    enum BrieflyError: Error {
        case notSignedIn
        case missingAudio
    }
}
