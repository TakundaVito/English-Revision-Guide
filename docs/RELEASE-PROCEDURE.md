# EmmaPrep VI26 release procedure

## 1. Start and decompose the release

1. Start from a clean `main` branch and create `release/<version>`.
2. Update `VERSION`, `pubspec.yaml`, README and changelog together.
3. Add every requirement and acceptance criterion to `docs/WORK-ITEMS.md` before implementation.
4. Never commit `config.production.json`, `.env`, signing keys, personal writing, API responses or provider credentials.

## 2. Pre-commit audit

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1 -AllowDirty -SkipApk
```

Review `git diff`, confirm no unrelated files or secrets, then commit the release changes.

## 3. Clean release verification

From the committed, clean release branch:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

This checks version consistency, tracked-secret exclusions, formatting, analysis, widget tests, architecture-split release builds and artifact SHA-256 values. Preserve `docs/verification/latest.json` with the release evidence.

CI must repeat the same code gates for the commit. Production configuration is not required for offline build verification; a production backend build is produced only in the controlled release environment.

## 4. Device acceptance

Complete `docs/DEVICE-ACCEPTANCE.md` on the target Samsung device and at least one other supported Android version when available. Test installation, upgrade, offline learning, progress persistence, accessibility, keyboard behavior and coach failure handling.

## 5. Production signing and security

1. Keep the Android upload/release keystore outside Git and backed up securely.
2. Keep AI-provider secrets exclusively on the backend.
3. Build with the ignored production configuration and a restricted, revocable app token.
4. Confirm the release APK is signed with the expected certificate.
5. Record hashes for the exact artifacts delivered.

For the final production-signing gate, copy `android/key.properties.example` to the ignored `android/key.properties`, point it at the private keystore outside the repository, and run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1 -RequireProductionSigning -ConfigFile config.production.json
```

## 6. Rollback

1. Preserve the previously accepted signed APK/AAB and checksum.
2. Record whether the new version changes local preference keys or remote content schema.
3. Android normally blocks version-code downgrades without uninstalling; rehearse rollback before release and document whether user progress would be lost.
4. Prefer a forward-fix build with a higher version code when data preservation matters.

## 7. Release decision

Update `docs/VI26-COMPLIANCE.md` from recorded evidence. Merge only after review, then create an annotated tag:

```powershell
git tag -a v1.1.0 -m "EmmaPrep English 1.1.0"
```

Do not tag or claim VI26 compliance while any mandatory gate remains conditional or failed.
