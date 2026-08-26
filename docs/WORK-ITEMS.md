# EmmaPrep VI26 engineering work items

Release target: `1.2.0+3`

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

States are evidence-based. “Implemented” does not mean “verified” until the listed evidence exists for the exact release commit.
