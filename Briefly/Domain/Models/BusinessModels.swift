import Foundation

enum PrimaryGoal: String, CaseIterable, Codable, Identifiable {
    case increaseSales = "increase_sales"
    case improveOrganization = "improve_organization"
    case manageInventory = "manage_inventory"
    case betterDecisions = "better_decisions"
    case improveOperations = "improve_operations"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .increaseSales: return "Increase sales"
        case .improveOrganization: return "Improve organization"
        case .manageInventory: return "Manage inventory better"
        case .betterDecisions: return "Make better decisions"
        case .improveOperations: return "Improve operations"
        }
    }
}

struct UserProfileRow: Codable, Equatable {
    var id: UUID
    var createdAt: Date?
    var businessName: String?
    var businessType: String?
    var businessDescription: String?
    var primaryGoal: String?
    var notificationsEnabled: Bool?
    var spreadsheetsOrDocumentsNote: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case businessName = "business_name"
        case businessType = "business_type"
        case businessDescription = "business_description"
        case primaryGoal = "primary_goal"
        case notificationsEnabled = "notifications_enabled"
        case spreadsheetsOrDocumentsNote = "spreadsheets_or_documents_note"
    }
}

struct BusinessProfileRow: Codable, Equatable {
    var id: UUID
    var userId: UUID
    var businessType: String?
    var revenueModelSummary: String?
    var operatingNotes: String?
    var recurringThemes: [String]
    var preferences: [String: String]
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case businessType = "business_type"
        case revenueModelSummary = "revenue_model_summary"
        case operatingNotes = "operating_notes"
        case recurringThemes = "recurring_themes"
        case preferences
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        businessType = try c.decodeIfPresent(String.self, forKey: .businessType)
        revenueModelSummary = try c.decodeIfPresent(String.self, forKey: .revenueModelSummary)
        operatingNotes = try c.decodeIfPresent(String.self, forKey: .operatingNotes)
        if let arr = try? c.decode([String].self, forKey: .recurringThemes) {
            recurringThemes = arr
        } else {
            recurringThemes = []
        }
        if let dict = try? c.decode([String: String].self, forKey: .preferences) {
            preferences = dict
        } else {
            preferences = [:]
        }
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

enum DailyLogStatus: String, Codable {
    case draft, confirmed, processed
}

enum DailyLogSourceType: String, Codable {
    case voice
    case uploadedFile = "uploaded_file"
    case mixed
}

struct DailyLogRow: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var userId: UUID
    var createdAt: Date?
    var logDate: String
    var rawTranscript: String?
    var cleanedSummary: String?
    var structuredData: StructuredBusinessData
    var confidenceNotes: String?
    var sourceType: DailyLogSourceType
    var status: DailyLogStatus
    var audioStoragePath: String?
    var localDraftId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case logDate = "log_date"
        case rawTranscript = "raw_transcript"
        case cleanedSummary = "cleaned_summary"
        case structuredData = "structured_data"
        case confidenceNotes = "confidence_notes"
        case sourceType = "source_type"
        case status
        case audioStoragePath = "audio_storage_path"
        case localDraftId = "local_draft_id"
    }

}

struct StructuredBusinessData: Codable, Equatable, Hashable {
    var keySignals: [String]
    var risks: [String]
    var productSignals: [String]
    var inventoryNotes: [String]
    var customerFeedback: [String]
    var issues: [String]
    var decisionsMentioned: [String]
    var trends: [String]

    enum CodingKeys: String, CodingKey {
        case keySignals
        case risks
        case productSignals
        case inventoryNotes
        case customerFeedback
        case issues
        case decisionsMentioned
        case trends
    }

    init(
        keySignals: [String],
        risks: [String],
        productSignals: [String],
        inventoryNotes: [String],
        customerFeedback: [String],
        issues: [String],
        decisionsMentioned: [String],
        trends: [String]
    ) {
        self.keySignals = keySignals
        self.risks = risks
        self.productSignals = productSignals
        self.inventoryNotes = inventoryNotes
        self.customerFeedback = customerFeedback
        self.issues = issues
        self.decisionsMentioned = decisionsMentioned
        self.trends = trends
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keySignals = try c.decodeIfPresent([String].self, forKey: .keySignals) ?? []
        risks = try c.decodeIfPresent([String].self, forKey: .risks) ?? []
        productSignals = try c.decodeIfPresent([String].self, forKey: .productSignals) ?? []
        inventoryNotes = try c.decodeIfPresent([String].self, forKey: .inventoryNotes) ?? []
        customerFeedback = try c.decodeIfPresent([String].self, forKey: .customerFeedback) ?? []
        issues = try c.decodeIfPresent([String].self, forKey: .issues) ?? []
        decisionsMentioned = try c.decodeIfPresent([String].self, forKey: .decisionsMentioned) ?? []
        trends = try c.decodeIfPresent([String].self, forKey: .trends) ?? []
    }

    static let empty = StructuredBusinessData(
        keySignals: [],
        risks: [],
        productSignals: [],
        inventoryNotes: [],
        customerFeedback: [],
        issues: [],
        decisionsMentioned: [],
        trends: []
    )
}

struct MetricSnapshotRow: Codable, Equatable {
    var id: UUID
    var logId: UUID
    var traffic: Int?
    var salesCount: Int?
    var conversionEstimate: Double?
    var inventoryStatus: String?
    var inventoryRiskLevel: String?
    var trendNotes: String?
    var metricConfidence: String?

    enum CodingKeys: String, CodingKey {
        case id
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

enum ActionStatus: String, Codable {
    case pending, done, skipped, snoozed
}

struct ActionRecommendationRow: Codable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID
    var logId: UUID?
    var title: String
    var reason: String?
    var priority: String?
    var category: String?
    var expectedImpact: String?
    var followUpDate: String?
    var status: ActionStatus
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case logId = "log_id"
        case title
        case reason
        case priority
        case category
        case expectedImpact = "expected_impact"
        case followUpDate = "follow_up_date"
        case status
        case createdAt = "created_at"
    }
}

struct ActionOutcomeRow: Codable, Identifiable, Equatable {
    var id: UUID
    var actionId: UUID
    var userId: UUID
    var createdAt: Date?
    var userFeedback: String?
    var outcomeSummary: String?
    var perceivedEffect: String?
    var optionalMetricDelta: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case actionId = "action_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case userFeedback = "user_feedback"
        case outcomeSummary = "outcome_summary"
        case perceivedEffect = "perceived_effect"
        case optionalMetricDelta = "optional_metric_delta"
    }
}

struct GeneratedReportRow: Codable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID
    var createdAt: Date?
    var reportType: String
    var title: String?
    var storagePath: String
    var relatedLogIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case reportType = "report_type"
        case title
        case storagePath = "storage_path"
        case relatedLogIds = "related_log_ids"
    }
}

enum NotificationTaskStatus: String, Codable {
    case scheduled, sent, cancelled, failed
}

struct NotificationTaskRow: Codable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID
    var type: String
    var scheduledFor: Date
    var relatedActionId: UUID?
    var relatedLogId: UUID?
    var status: NotificationTaskStatus

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case scheduledFor = "scheduled_for"
        case relatedActionId = "related_action_id"
        case relatedLogId = "related_log_id"
        case status
    }
}
