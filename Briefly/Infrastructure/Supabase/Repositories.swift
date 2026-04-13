import Foundation
import Storage
import Supabase

@MainActor
final class ProfileRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchProfile(userId: UUID) async throws -> UserProfileRow {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func upsertProfile(_ row: UserProfileRow) async throws {
        try await client
            .from("profiles")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func upsertBusinessProfile(userId: UUID, businessType: String?, operatingNotes: String?) async throws {
        let row = BusinessProfileUpsert(
            userId: userId,
            businessType: businessType,
            operatingNotes: operatingNotes
        )
        try await client
            .from("business_profiles")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    private struct BusinessProfileUpsert: Encodable {
        let userId: UUID
        let businessType: String?
        let operatingNotes: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case businessType = "business_type"
            case operatingNotes = "operating_notes"
        }
    }
}

@MainActor
final class DailyLogRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func createDraft(userId: UUID, logDate: String, transcript: String, audioPath: String?) async throws -> DailyLogRow {
        let insert = DailyLogInsert(
            userId: userId,
            logDate: logDate,
            rawTranscript: transcript,
            cleanedSummary: nil,
            structuredData: .empty,
            confidenceNotes: nil,
            sourceType: .voice,
            status: .draft,
            audioStoragePath: audioPath
        )
        return try await client
            .from("daily_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateLog(_ row: DailyLogRow) async throws {
        try await client
            .from("daily_logs")
            .update(row)
            .eq("id", value: row.id.uuidString)
            .execute()
    }

    func fetchRecent(userId: UUID, limit: Int = 10) async throws -> [DailyLogRow] {
        try await client
            .from("daily_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .or("status.eq.confirmed,status.eq.processed")
            .order("log_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchTodayLog(userId: UUID, logDate: String) async throws -> DailyLogRow? {
        let rows: [DailyLogRow] = try await client
            .from("daily_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("log_date", value: logDate)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchTodayProcessed(userId: UUID, logDate: String) async throws -> DailyLogRow? {
        let rows: [DailyLogRow] = try await client
            .from("daily_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("log_date", value: logDate)
            .eq("status", value: DailyLogStatus.processed.rawValue)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private struct DailyLogInsert: Encodable {
        let userId: UUID
        let logDate: String
        let rawTranscript: String?
        let cleanedSummary: String?
        let structuredData: StructuredBusinessData
        let confidenceNotes: String?
        let sourceType: DailyLogSourceType
        let status: DailyLogStatus
        let audioStoragePath: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case logDate = "log_date"
            case rawTranscript = "raw_transcript"
            case cleanedSummary = "cleaned_summary"
            case structuredData = "structured_data"
            case confidenceNotes = "confidence_notes"
            case sourceType = "source_type"
            case status
            case audioStoragePath = "audio_storage_path"
        }
    }
}

@MainActor
final class MetricRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func replaceForLog(logId: UUID, metrics: MetricsDTO) async throws {
        try await client
            .from("metric_snapshots")
            .delete()
            .eq("log_id", value: logId.uuidString)
            .execute()

        let insert = MetricInsert(
            logId: logId,
            traffic: metrics.traffic,
            salesCount: metrics.salesCount,
            conversionEstimate: metrics.conversionEstimate,
            inventoryStatus: metrics.inventoryStatus,
            inventoryRiskLevel: metrics.inventoryRiskLevel,
            trendNotes: metrics.trendNotes,
            metricConfidence: metrics.metricConfidence
        )
        try await client
            .from("metric_snapshots")
            .insert(insert)
            .execute()
    }

    private struct MetricInsert: Encodable {
        let logId: UUID
        let traffic: Int?
        let salesCount: Int?
        let conversionEstimate: Double?
        let inventoryStatus: String?
        let inventoryRiskLevel: String?
        let trendNotes: String?
        let metricConfidence: String?

        enum CodingKeys: String, CodingKey {
            case logId = "log_id"
            case traffic
            case salesCount = "sales_count"
            case conversionEstimate = "conversion_estimate"
            case inventoryStatus = "inventory_status"
            case inventoryRiskLevel = "inventory_risk_level"
            case trendNotes = "trend_notes"
            case metricConfidence = "metric_confidence"
        }
    }
}

@MainActor
final class ActionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func replaceForLog(userId: UUID, logId: UUID, actions: [ActionDTO]) async throws {
        try await client
            .from("action_recommendations")
            .delete()
            .eq("log_id", value: logId.uuidString)
            .execute()

        let rows = actions.map { a in
            ActionInsert(
                userId: userId,
                logId: logId,
                title: a.title,
                reason: a.reason,
                priority: a.priority,
                category: a.category,
                expectedImpact: a.expectedImpact,
                followUpDate: a.followUpDate,
                status: .pending
            )
        }
        if !rows.isEmpty {
            try await client
                .from("action_recommendations")
                .insert(rows)
                .execute()
        }
    }

    func fetchPending(userId: UUID) async throws -> [ActionRecommendationRow] {
        try await client
            .from("action_recommendations")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: ActionStatus.pending.rawValue)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    func fetchForLog(logId: UUID) async throws -> [ActionRecommendationRow] {
        try await client
            .from("action_recommendations")
            .select()
            .eq("log_id", value: logId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateStatus(actionId: UUID, status: ActionStatus) async throws {
        try await client
            .from("action_recommendations")
            .update(["status": status.rawValue])
            .eq("id", value: actionId.uuidString)
            .execute()
    }

    func insertOutcome(actionId: UUID, userId: UUID, userFeedback: String?, outcomeSummary: String?, perceivedEffect: String?) async throws {
        let row = ActionOutcomeInsert(
            id: UUID(),
            actionId: actionId,
            userId: userId,
            userFeedback: userFeedback,
            outcomeSummary: outcomeSummary,
            perceivedEffect: perceivedEffect
        )
        try await client
            .from("action_outcomes")
            .insert(row)
            .execute()
    }

    private struct ActionOutcomeInsert: Encodable {
        let id: UUID
        let actionId: UUID
        let userId: UUID
        let userFeedback: String?
        let outcomeSummary: String?
        let perceivedEffect: String?

        enum CodingKeys: String, CodingKey {
            case id
            case actionId = "action_id"
            case userId = "user_id"
            case userFeedback = "user_feedback"
            case outcomeSummary = "outcome_summary"
            case perceivedEffect = "perceived_effect"
        }
    }

    private struct ActionInsert: Encodable {
        let userId: UUID
        let logId: UUID
        let title: String
        let reason: String?
        let priority: String?
        let category: String?
        let expectedImpact: String?
        let followUpDate: String?
        let status: ActionStatus

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case logId = "log_id"
            case title
            case reason
            case priority
            case category
            case expectedImpact = "expected_impact"
            case followUpDate = "follow_up_date"
            case status
        }
    }
}

@MainActor
final class ReportRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func insertReport(_ row: GeneratedReportRow) async throws {
        try await client
            .from("generated_reports")
            .insert(row)
            .execute()
    }

    func fetchRecent(userId: UUID) async throws -> [GeneratedReportRow] {
        try await client
            .from("generated_reports")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value
    }
}

@MainActor
final class StorageService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadAudio(userId: UUID, logId: UUID, localFileURL: URL) async throws -> String {
        let path = "\(userId.uuidString)/\(logId.uuidString).m4a"
        let data = try Data(contentsOf: localFileURL)
        try await client.storage
            .from("briefly-audio")
            .upload(
                path,
                data: data,
                options: FileOptions(cacheControl: "3600", contentType: "audio/m4a", upsert: true)
            )
        return path
    }

    func uploadReportPDF(userId: UUID, reportId: UUID, data: Data) async throws -> String {
        let path = "\(userId.uuidString)/\(reportId.uuidString).pdf"
        try await client.storage
            .from("briefly-reports")
            .upload(
                path,
                data: data,
                options: FileOptions(cacheControl: "3600", contentType: "application/pdf", upsert: true)
            )
        return path
    }
}
