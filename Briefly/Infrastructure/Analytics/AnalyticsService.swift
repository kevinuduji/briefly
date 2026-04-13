import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum AnalyticsService {
    static func configureIfAvailable() {
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            #endif
        }
        #endif
    }

    static func log(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        if FirebaseApp.app() != nil {
            Analytics.logEvent(name, parameters: parameters)
        }
        #else
        _ = name
        _ = parameters
        #endif
    }
}
