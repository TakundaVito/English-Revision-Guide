# Changelog

All notable changes to EmmaPrep English are recorded here. Versions follow `major.minor.patch+androidBuild`.

## 1.2.0+3 - 2026-08-25

### Added

- Automatic launch-time API content pipeline with ETag/304 support and offline caching.
- Strict remote-content validation for the `zimsec-4005` curriculum and exam style.
- Home settings gear and clearer ZIMSEC 4005 practice labelling.

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
