# EmmaPrep English

EmmaPrep English is a Flutter revision app covering ZIMSEC English Language Paper 1 and Paper 2. Lessons, quizzes, progress and accessibility features work offline. The optional AI coach and content synchronization use a separately operated backend.

Current version: **1.10.0+15**

## Core capabilities

- Beginner-friendly Paper 1 and Paper 2 lessons
- Worked examples followed by short practice tasks
- Mixed and paper-specific quizzes with explanations
- Offline mastery, bookmarks, accuracy and study streaks
- Dark theme, high contrast, larger text, simple explanations and reduced motion
- AI coach through a backend that keeps provider credentials off the device
- Remote lesson/question updates cached for offline use
- Separate Flutter Web administrator dashboard with authenticated draft and publish workflows

## Development

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

The automated suite is divided into curriculum-integrity, persistence,
student-widget, accessibility, and admin schemes. See
[`docs/TESTING.md`](docs/TESTING.md) for the test matrix, commands, and physical
device release checklist.

For a credential-free build that a school, publisher, or prospective buyer can
evaluate, use `config.company-demo.json`. See
[`docs/COMPANY-EVALUATION.md`](docs/COMPANY-EVALUATION.md) for packaging and
pilot instructions.

For acquisition or licensing review, see
[`docs/BUYER-DUE-DILIGENCE.md`](docs/BUYER-DUE-DILIGENCE.md). It distinguishes
verified engineering evidence from curriculum, legal, security, pilot, and
release evidence that must be supplied by the responsible human reviewer.

For Chrome:

```powershell
flutter run -d chrome
```

## Production configuration

Copy `config.example.json` to the ignored `config.production.json` and set only the backend URL and an optional limited app token. Never place an AI-provider secret in an APK configuration.

Production Android signing uses the ignored `android/key.properties`, based on `android/key.properties.example`, and an upload keystore stored outside the repository. CI may use debug-signed APKs for installation verification, but the Google Play bundle build refuses to run without the private upload key. Follow `docs/GOOGLE-PLAY-RELEASE.md` for the production process.

## Smaller release APKs

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=config.production.json
```

## Remote administration

Supabase schema, Row Level Security policies and Edge Functions live under `supabase/`. The Flutter Web dashboard lives under `admin/` and is branded as **englishTutor**. Follow `docs/SUPABASE-SETUP.md` to install the migrations, create the first administrator, deploy the API and run the dashboard.

The AI provider is selected remotely in englishTutor. API keys are never bundled into either Flutter app: store `OPENAI_API_KEY` or `GROQ_API_KEY` only in Supabase Edge Function Secrets. Apply migrations `202608260004_privacy_safe_events.sql` and `202608260005_ai_provider.sql`, then redeploy `admin-create-student`, `admin-students`, `chat`, `scan-questions`, `health`, and `content`.

Identify a connected phone architecture with:

```powershell
& "C:\Lair\AndroidSDK\platform-tools\adb.exe" shell getprop ro.product.cpu.abi
```

## VI26 verification

After committing the release changes, run the complete clean-tree gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

Before committing, audit code gates without rebuilding APKs:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1 -AllowDirty -SkipApk
```

Do not claim VI26 compliance until every mandatory gate and the physical-device acceptance checklist have recorded passing evidence for the exact release commit.

## Content authority

The app is a revision aid structured around English Language 4005/01 and 4005/02 skills. The current official ZIMSEC syllabus, examination instructions and teacher guidance remain the final authority.
