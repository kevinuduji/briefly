import Foundation
import Supabase

@MainActor
final class EdgeFunctionsService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func processDailyLog(
        transcript: String?,
        audioStoragePath: String?,
        structuredOverride: StructuredBusinessData? = nil,
        profile: UserProfileRow
    ) async throws -> ProcessDailyLogResponse {
        struct Body: Encodable {
            let transcript: String?
            let audioStoragePath: String?
            let structuredOverride: StructuredBusinessData?
            let businessName: String?
            let businessType: String?
            let businessDescription: String?
            let primaryGoal: String?
        }

        let body = Body(
            transcript: transcript,
            audioStoragePath: audioStoragePath,
            structuredOverride: structuredOverride,
            businessName: profile.businessName,
            businessType: profile.businessType,
            businessDescription: profile.businessDescription,
            primaryGoal: profile.primaryGoal
        )

        return try await client.functions.invoke(
            "process-daily-log",
            options: FunctionInvokeOptions(body: body)
        )
    }

    func generateAudioBrief(text: String) async throws -> AudioBriefResponse {
        struct Body: Encodable {
            let text: String
        }
        return try await client.functions.invoke(
            "generate-audio-brief",
            options: FunctionInvokeOptions(body: Body(text: text))
        )
    }
}
