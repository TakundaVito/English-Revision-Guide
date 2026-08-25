# Verification evidence

`scripts/verify-release.ps1` writes `latest.json` here. For an accepted release, preserve a copy named `<version>-<shortCommit>.json` and record the matching APK/AAB checksums.

Generated evidence is trustworthy only when:

- the repository was clean before verification;
- the commit SHA matches the reviewed release commit;
- every mandatory command returned exit code zero;
- the physical-device checklist is completed separately;
- the delivered artifact hash matches the recorded hash.
