import Foundation

struct ProcessDailyLogResponse: Decodable {
    let transcript: String
    let cleanedSummary: String
    let confidenceNotes: String?
    let structuredData: StructuredBusinessData
    let metrics: MetricsDTO
    let actions: [ActionDTO]
    let briefText: String?

    enum CodingKeys: String, CodingKey {
        case transcript
        case cleanedSummary = "cleanedSummary"
        case confidenceNotes
        case structuredData = "structuredData"
        case metrics
        case actions
        case briefText
    }
}

struct MetricsDTO: Decodable, Equatable {
    var traffic: Int?
    var salesCount: Int?
    var conversionEstimate: Double?
    var inventoryStatus: String?
    var inventoryRiskLevel: String?
    var trendNotes: String?
    var metricConfidence: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        traffic = try c.decodeIfPresent(Int.self, forKey: .traffic)
        salesCount = try c.decodeIfPresent(Int.self, forKey: .salesCount)
        conversionEstimate = try c.decodeIfPresent(Double.self, forKey: .conversionEstimate)
        inventoryStatus = try c.decodeIfPresent(String.self, forKey: .inventoryStatus)
        inventoryRiskLevel = try c.decodeIfPresent(String.self, forKey: .inventoryRiskLevel)
        trendNotes = try c.decodeIfPresent(String.self, forKey: .trendNotes)
        metricConfidence = try c.decodeIfPresent(String.self, forKey: .metricConfidence)
    }

    private enum CodingKeys: String, CodingKey {
        case traffic
        case salesCount
        case conversionEstimate
        case inventoryStatus
        case inventoryRiskLevel
        case trendNotes
        case metricConfidence
    }
}

struct ActionDTO: Decodable, Equatable {
    var title: String
    var reason: String?
    var priority: String?
    var category: String?
    var expectedImpact: String?
    var followUpDate: String?
}

struct AudioBriefResponse: Decodable {
    let audioBase64: String
    let mimeType: String
}
