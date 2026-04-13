# Briefly

Voice-first business operating companion: speak your daily reality, confirm what was understood, and get a self-building snapshot with grounded next actions.

## Prerequisites

- **Xcode 16+** (the Xcode project uses `PBXFileSystemSynchronizedRootGroup`, which requires a recent Xcode)
- Swift 5.10+
- A [Supabase](https://supabase.com) project
- An OpenAI API key (used only on the server in Edge Functions)
- Apple Developer account (Sign in with Apple)

## 1. Supabase

1. Create a project and open **SQL Editor**.
2. Run the migration in `supabase/migrations/20260113000000_initial_schema.sql`.
3. Deploy Edge Functions (CLI):

```bash
cd supabase
supabase functions deploy process-daily-log
supabase functions deploy generate-audio-brief
```

Set secrets in Supabase (Dashboard → Edge Functions → Secrets):

- `OPENAI_API_KEY`
- `SUPABASE_URL` (project URL)
- `SUPABASE_SERVICE_ROLE_KEY` (required so Whisper can read private audio from Storage)

> `process-daily-log` uses the service role only to download audio for Whisper when `audioStoragePath` is provided.

4. **Auth → Providers → Apple**: configure Sign in with Apple (Services ID, key, etc.) per Supabase docs.

## 2. iOS app configuration

1. Open `Briefly.xcodeproj` in Xcode.
2. Set your **Team** and a unique **Bundle Identifier** (e.g. `com.yourname.briefly`).
3. In `Briefly/Resources/Info.plist`, set:
   - `SUPABASE_URL` — `https://YOUR_REF.supabase.co`
   - `SUPABASE_ANON_KEY` — Project **anon** key (Settings → API).
4. **Sign in with Apple** capability is enabled via `Briefly/Resources/Briefly.entitlements`; enable the capability in Xcode if needed.
5. Add **App Icon** (1024×1024) in `Assets.xcassets` → App Icon before App Store submission.
6. (Optional) Add `GoogleService-Info.plist` from Firebase for Analytics/Crashlytics. Without it, analytics calls no-op safely.

## 3. Architecture (high level)

- **iOS**: SwiftUI, live transcript (Speech), capture (AVAudioEngine), Supabase Auth + DB + Storage + Functions, PDFKit exports, local notifications, optional Firebase Analytics/Crashlytics.
- **Edge**: OpenAI Chat (structured extraction + actions), Whisper (final transcript from uploaded audio), OpenAI TTS (audio brief).

## License

Proprietary — your repository.
