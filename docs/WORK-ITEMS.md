# EmmaPrep VI26 engineering work items

Release target: `1.9.0+14`

| ID | Requirement | Acceptance criteria | Verification | State |
| --- | --- | --- | --- | --- |
| EMMA-VI26-001 | Preserve learning-first navigation | Home, Learn and Practice remain immediately accessible; Coach does not block offline study | Widget test and device matrix | Implemented / device evidence pending |
| EMMA-VI26-002 | Beginner-relevant content | Every bundled lesson has a worked example and “Your turn” task using simple or locally relevant contexts | Static content assertion and manual content review | Implemented / review sign-off pending |
| EMMA-VI26-003 | Accessible presentation | Dark theme, high contrast, 90–140% text, simple explanations and reduced motion persist after restart | Automated persistence tests and physical-device matrix | Implemented / device evidence pending |
| EMMA-VI26-004 | Protect AI credentials | No provider secret or user-editable API configuration exists in the app; ignored production config contains backend details only | Git secret scan, static assertion and backend review | Implemented / backend review pending |
| EMMA-VI26-005 | Offline resilience | Lessons, practice and progress work without network; coach failure is non-blocking | Flight-mode device test | Implemented / device evidence pending |
| EMMA-VI26-006 | Reproducible build | Lockfile, pinned Flutter/Dart constraints, clean-tree verifier and CI repeat analysis/tests/build | `scripts/verify-release.ps1` and CI artifact | Implemented / clean CI run pending |
| EMMA-VI26-007 | Version consistency | `VERSION`, `pubspec.yaml`, README and changelog agree | Verifier version gate | Implemented |
| EMMA-VI26-008 | Authentic history | Release maps to reviewed commit and annotated tag | Git log, clean tree and tag | Pending user commit/tag |
| EMMA-VI26-009 | Android acceptance | Install, launch, navigation, persistence, offline mode and upgrade pass on target phone | `docs/DEVICE-ACCEPTANCE.md` | Pending |
| EMMA-VI26-010 | Release integrity | Every APK/AAB has recorded SHA-256, version, commit and build command | Generated verification evidence | Pending full release build |
| EMMA-VI26-011 | Rollback readiness | Previous signed APK and user-data implications are documented and rollback is rehearsed | Release checklist | Pending |
| EMMA-VI26-012 | Production signing | Release uses a private external keystore and verifier rejects missing production signing material when required | `-RequireProductionSigning`, certificate inspection | Implemented / private keystore evidence pending |
| EMMA-VI26-013 | ZIMSEC-only question pipeline | Launch sync accepts only versioned `zimsec-4005` content, rejects generic/malformed questions and preserves offline content | Unit tests, API contract and integration test | Implemented / live backend test pending |
| EMMA-VI26-014 | Authenticated remote administration | Separate dashboard requires Supabase Auth plus `admin_profiles` membership for writes and publishing | RLS policy review, dashboard tests and live access test | Implemented / live access test pending |
| EMMA-VI26-015 | Safe remote API controls | Admin may change non-secret API behaviour, but cannot read or write provider secrets from browser code | Secret scan, health response review and RLS verification | Implemented / deployed health check pending |
| EMMA-VI26-016 | Controlled student identity | Admin creates the private student account; public registration is disabled by default and remotely switchable; profiles are self-only under RLS | Auth tests, RLS review and device sign-in test | Implemented / live device test pending |
| EMMA-VI26-017 | Question image ingestion | Authenticated student may submit up to three compressed images, review extracted answers, and explicitly save accepted ZIMSEC questions to local Study and Practice | Payload validation, scanner integration and manual answer review | Implemented / live vision test pending |
| EMMA-VI26-018 | Privacy-safe observability | Admin can inspect operational usage/errors without storing credentials, emails, tokens, images, question text, answers or chat content | RLS review, event schema constraint, secret scan and live function logs | Implemented / live event review pending |
| EMMA-VI26-019 | Provider-safe AI switching | englishTutor selects OpenAI or Groq and approved text/vision models without receiving either API key | Secret scan, health readiness response and live provider tests | Implemented / live provider tests pending |
| EMMA-VI26-020 | Passage-aware document ingestion | Ordered images may contain passages, questions or both; related context remains visible during review and saved study | Multi-page device scan, schema validation and human answer review | Implemented / live device scan pending |
| EMMA-VI26-021 | Coach document assistance | Signed-in student may attach camera/gallery pages or locally rendered PDF pages; attachment bytes are transient and excluded from activity logs | Payload limits, PDF render test, provider test and privacy review | Implemented / live device test pending |

States are evidence-based. “Implemented” does not mean “verified” until the listed evidence exists for the exact release commit.
