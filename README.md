# EmmaPrep English

EmmaPrep English is a personalised Flutter revision app for Emmaculate, covering ZIMSEC English Language Paper 1 and Paper 2. Lessons, quizzes, progress and accessibility features work offline. The optional AI coach and content synchronization use a separately operated backend.

Current version: **1.2.0+3**

## Core capabilities

- Beginner-friendly Paper 1 and Paper 2 lessons
- Worked examples followed by short practice tasks
- Mixed and paper-specific quizzes with explanations
- Offline mastery, bookmarks, accuracy and study streaks
- Dark theme, high contrast, larger text, simple explanations and reduced motion
- AI coach through a backend that keeps provider credentials off the device
- Remote lesson/question updates cached for offline use

## Development

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

For Chrome:

```powershell
flutter run -d chrome
```

## Production configuration

Copy `config.example.json` to the ignored `config.production.json` and set only the backend URL and an optional limited app token. Never place an AI-provider secret in an APK configuration.

Production Android signing uses the ignored `android/key.properties`, based on `android/key.properties.example`, and a keystore stored outside the repository. Local builds fall back to debug signing and must not be distributed as VI26 production releases.

## Smaller release APKs

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=config.production.json
```

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
