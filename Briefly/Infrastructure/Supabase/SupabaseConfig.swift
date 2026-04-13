import Foundation

enum SupabaseConfig {
    static var url: URL {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            fatalError("Set SUPABASE_URL in Briefly/Resources/Info.plist (project Settings → Info).")
        }
        return url
    }

    static var anonKey: String {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fatalError("Set SUPABASE_ANON_KEY in Briefly/Resources/Info.plist (project Settings → Info).")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
