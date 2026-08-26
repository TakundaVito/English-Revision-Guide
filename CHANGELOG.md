# Changelog

All notable changes to EmmaPrep English are recorded here. Versions follow `major.minor.patch+androidBuild`.

## 1.5.0+6 - 2026-08-26

### Fixed

- Browser Edge Function calls now allow Supabase's `x-client-info` CORS header, preventing the generic account-creation “Failed to fetch” preflight failure.
- Function errors return safe request identifiers for correlation with Supabase logs.

### Added

- Privacy-safe operational event table protected by Row Level Security.
- Admin Activity dashboard for recent usage, warnings and errors.
- Structured Edge Function console events for account creation and question scanning.
- Server-side Groq support for tutoring and multi-image question recognition.
- Remote AI provider and approved Groq model controls in the administrator settings.
- Rebranded `englishTutor` dashboard with an oloid mark and refreshed blue/pink visual system.
- Passage-aware multi-page scanning that preserves passage context with extracted ZIMSEC questions.
- New EnglishTutor launcher icon generated from the supplied blue/pink E-and-book artwork.
- EnglishTutor E branding on the native splash, student login and Coach header.
- Coach attachments for camera pictures, gallery pictures and the first three pages of a PDF.
- Administrator provider-key connectivity check and actionable upstream provider failures.
- Replaced Groq's retired Llama 3.3 tutor model with the production `openai/gpt-oss-20b` model.

### Security

- Observability explicitly excludes credentials, tokens, emails, images, question text, answers and chat content.
- Only authenticated users may submit their own events and only administrators may read the event stream.
- Groq and OpenAI secrets remain in Supabase Edge Function Secrets and are never exposed to Flutter Web.
- Tutor and scanner functions now require a valid signed-in student and return traceable request identifiers without logging learning content.

## 1.4.0+5 - 2026-08-26

### Added

- Administrator-created student credentials with private first-run sign-in.
- Remotely switchable public registration for a future multi-user release.
- Camera and multi-image gallery question scanning for authenticated students.
- Review flow that adds approved solved questions to local Study and Practice collections.
- Self-only student profiles and an administrator-only student-account creation function.

### Security

- Public registration is disabled by default.
- The image scanner requires a signed-in student, enforces image/count limits and is rate-limited.
- Captured image bytes are not stored in the student study history and OpenAI response storage is disabled.

### Changed

- VI26 work items now cover student identity, image ingestion and human review of generated answers.

## 1.3.0+4 - 2026-08-26

### Added

- Separate Flutter Web administration app for lessons, questions, publishing and remote settings.
- Authenticated API health endpoint reporting deployment readiness without disclosing secrets.
- Remote controls for AI availability, approved model, content caching, maintenance notices and minimum app version.
- Incremental Supabase migration for safely deploying remote settings after the initial schema.

### Changed

- Supabase publishable keys use the correct `apikey` request header.
- AI model selection is read remotely while the provider credential remains in Supabase Secrets.
- Public content responses include safe app configuration and remotely controlled cache duration.

### Security

- Administrator writes remain protected by Supabase Auth and Row Level Security.
- Provider secrets cannot be viewed, entered or returned by the browser dashboard.
- API status reports booleans only and requires an authenticated administrator session.

## 1.2.0+3 - 2026-08-25

### Added

- Automatic launch-time API content pipeline with ETag/304 support and offline caching.
- Strict remote-content validation for the `zimsec-4005` curriculum and exam style.
- Home settings gear and clearer ZIMSEC 4005 practice labelling.
- Explicit settings save confirmation and an About section with developer metadata.
- Supabase database migration, Row Level Security, content/chat Edge Functions and Flutter Web admin dashboard.

### Changed

- Users no longer need to trigger content synchronization manually.
- Remote updates are applied atomically so invalid questions cannot partially replace valid content.
- Practice navigation is restricted to Paper 1 and Paper 2 exam skills rather than general English trivia.

## 1.1.0+2 - 2026-08-25

### Added

- Expanded ZIMSEC Paper 1 and Paper 2 beginner lessons and practical exercises.
- Worked examples and “Your turn” activities across every bundled lesson.
- AI study-coach backend integration and remotely synchronized learning content.
- Blue-and-pink visual identity, Takunda Vito oloid branding and personal motivation page.
- Dark theme, high contrast, scalable text, simple explanations and reduced motion.
- Flutter/Android VI26 release controls, evidence templates, CI and verification tooling.

### Changed

- API configuration is compile-time only and no longer user-editable.
- Production builds support architecture-specific APKs for smaller downloads.
- Lesson examples use more recognisable Zimbabwean school and community contexts.

### Security

- Legacy locally saved API configuration is deleted during migration.
- Production configuration and environment files are excluded from Git.
- AI provider credentials are required to remain on the backend.

## 1.0.0+1 - 2026-08-25

- Initial personalised offline English revision application.
