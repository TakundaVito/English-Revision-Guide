# EmmaPrep testing strategy

EmmaPrep uses layered automated checks so failures identify the affected part of
the product instead of appearing as one large end-to-end failure.

## Test schemes

| Scheme | Location | Purpose |
| --- | --- | --- |
| Curriculum integrity | `test/content_integrity_test.dart` | Protects lesson IDs, required teaching content, question structure, explanations, paper coverage, and remote-content validation. |
| State and persistence | `test/store_test.dart` | Verifies progress, bookmarks, scores, streaks, accessibility preferences, legacy-secret cleanup, remote-content hydration, and safe API headers. |
| Student UI | `test/widget_test.dart`, `test/accessibility_widget_test.dart` | Covers public/private content separation, notices, narrow screens, large text, and key navigation. |
| Admin UI and utilities | `admin/test/widget_test.dart` | Covers safe unconfigured startup, multiline form parsing, field decoration, and sanitized error messages. |
| Edge Function helpers | `supabase/functions/_shared/validation_test.ts` | Covers rate-limit configuration, learner-name sanitization, message limits, and image data-URL validation. |
| Static and release gates | `scripts/verify-release.ps1` | Enforces formatting, analysis, all student/admin tests, admin web compilation, secret scanning, version consistency, and optional release APK builds. |

## Local commands

Run the fast student suite:

```powershell
flutter test --reporter expanded
```

Run the administrator suite:

```powershell
Push-Location admin
flutter test --reporter expanded
Pop-Location
```

Create a coverage report:

```powershell
flutter test --coverage
```

Run every code gate without building release APKs:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1 -AllowDirty -SkipApk
```

Run backend helper tests:

```powershell
deno test supabase/functions
```

CI enforces a 40% student-app line-coverage floor. Raise the threshold as
networking, authentication, scanning, and administrative workflows gain tests.

## Manual release scheme

Automation does not replace checks on a physical Android device. Before a
release, record the device model, Android version, APK hash, tester, date, and
result for each of these scenarios:

1. Fresh install, registration/sign-in, sign-out, and returning sign-in.
2. Complete a lesson, bookmark it, restart the app, and confirm persistence.
3. Complete Paper 1 and Paper 2 quizzes and confirm score/progress updates.
4. Use the app offline, including lessons and bundled quizzes.
5. Exercise 1.4x text, high contrast, dark mode, and reduced motion.
6. Verify AI coach and question scanning with valid, invalid, and unavailable backend responses.
7. Confirm the public account never displays private-edition content.
8. Confirm the admin can draft, publish, and retrieve an update without exposing provider secrets.

Release evidence should be tied to the exact Git commit tested.
