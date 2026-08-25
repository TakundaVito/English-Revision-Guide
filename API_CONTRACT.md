# EmmaPrep API contract

The Flutter app connects to a backend that you control. Do not put an OpenAI, Anthropic, Gemini or other provider secret directly in the app; keep it on this backend.

The API is not configurable from the app interface. It is compiled into a release with Dart defines. Copy `config.example.json` to the ignored `config.production.json`, replace the placeholders, and build with:

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=config.production.json
```

The app reads `EMMAPREP_API_URL` and `EMMAPREP_APP_TOKEN` at compile time. Do not place an OpenAI, Anthropic, Gemini or other provider secret in this file: compiled values can be recovered from an APK. The provider secret belongs only on your backend. The optional app token should be limited, revocable and rate-limited.

## AI study coach

`POST /v1/chat`

Headers:

```text
Content-Type: application/json
Authorization: Bearer OPTIONAL_APP_TOKEN
```

Request:

```json
{
  "message": "Quiz me on summary writing",
  "student": "Emmaculate",
  "course": "ZIMSEC English Language 4005/01 and 4005/02",
  "mode": "learning_and_practice",
  "history": [
    {"role": "user", "content": "Explain inference"},
    {"role": "assistant", "content": "Inference means..."}
  ]
}
```

Response:

```json
{"reply": "Let us start with a short passage..."}
```

The server should instruct the model to behave as a supportive ZIMSEC English tutor, avoid inventing official rules, give feedback before model answers, and favour active recall and one-question-at-a-time practice.

## Content updates

`GET /v1/content`

Response:

```json
{
  "version": "2026.08.1",
  "lessons": [
    {
      "id": "formal-letter-2",
      "paper": "Paper 1",
      "title": "Formal Letters: Complaints",
      "subtitle": "Evidence, tone and requested action",
      "introduction": "A concise lesson introduction.",
      "notes": ["First teaching point", "Second teaching point"],
      "checklist": ["Purpose is clear", "Evidence is specific"]
    }
  ],
  "questions": [
    {
      "paper": "Paper 2",
      "question": "What does the image suggest?",
      "answers": ["Answer A", "Answer B", "Answer C", "Answer D"],
      "correctIndex": 1,
      "explanation": "Why answer B is correct."
    }
  ]
}
```

Synced content is cached locally and remains available offline. A subsequent successful sync replaces the previous remote content while preserving bundled content and learning progress.

## Recommended server controls

- Authenticate app installations or users instead of exposing provider keys.
- Validate content JSON and restrict payload sizes.
- Use HTTPS only in production.
- Rate-limit chat requests.
- Log content version and update time, but avoid storing private student writing unless consented.
- Review syllabus updates before publishing them through `/v1/content`.

## Smaller Android releases

Use `--split-per-abi` to create separate APKs for each processor architecture without removing functionality. Flutter writes them under `build/app/outputs/flutter-apk/`.

To identify a connected phone's architecture:

```powershell
& "C:\Lair\AndroidSDK\platform-tools\adb.exe" shell getprop ro.product.cpu.abi
```

Typical output `arm64-v8a` uses `app-arm64-v8a-release.apk`. Keep the universal `flutter build apk --release` workflow only when one APK must support every architecture.
