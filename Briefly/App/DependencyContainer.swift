import Foundation
import Supabase

@MainActor
final class DependencyContainer: ObservableObject {
    let client: SupabaseClient
    let auth: AuthService
    let state: BrieflyAppState

    init() {
        let client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        let auth = AuthService(client: client)
        let profileRepo = ProfileRepository(client: client)
        let dailyLogRepo = DailyLogRepository(client: client)
        let metricRepo = MetricRepository(client: client)
        let actionRepo = ActionRepository(client: client)
        let reportRepo = ReportRepository(client: client)
        let storage = StorageService(client: client)
        let edge = EdgeFunctionsService(client: client)
        let notifications = NotificationManager()
        let audioBriefPlayer = AudioBriefPlayer()

        state = BrieflyAppState(
            client: client,
            auth: auth,
            profileRepo: profileRepo,
            dailyLogRepo: dailyLogRepo,
            metricRepo: metricRepo,
            actionRepo: actionRepo,
            reportRepo: reportRepo,
            storage: storage,
            edge: edge,
            notifications: notifications,
            audioBriefPlayer: audioBriefPlayer
        )

        self.client = client
        self.auth = auth

        Task { await state.bootstrap() }
    }
}
