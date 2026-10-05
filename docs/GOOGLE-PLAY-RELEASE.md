# Google Play release runbook

This runbook separates repository work from steps that must be completed by the
legal owner of the Google Play developer account.

## Release identity

- App name: `EmmaPrep English`
- Android application ID: `com.emmaprep.emma_prep_english`
- Current version: read `version` from `pubspec.yaml`
- Category: Education
- Android target: API 36

The application ID becomes permanent after the first Play Console upload. Check
that the legal owner wants this exact identifier before creating the app.

## 1. Create and verify the developer account

Use the legal owner's Google account. Choose an organization account only when
an incorporated organization can complete Google's organization verification;
otherwise use a personal account. Complete identity, contact, payment and device
verification in Play Console.

New personal accounts may need a closed test with at least 12 testers opted in
continuously for 14 days before production access is available. Play Console is
the source of truth for the requirements shown for the account.

## 2. Complete the policy prerequisites

Before uploading a production release, publish and review:

- a public, non-PDF privacy-policy URL that names EmmaPrep English and the
  developer shown on the store listing;
- a public account-deletion request URL;
- an in-app path to the privacy policy and account-deletion process;
- a support email address and preferably a support website;
- guardian-consent and child-data procedures for learners under 18.

Because EmmaPrep can create learner accounts, uses a camera for question scans,
and can send prompts or images to configured AI providers, the Data safety form
must be completed from the real production configuration. Do not claim that no
data is collected merely because some processing is transient.

Give Google reviewers working learner credentials and precise instructions for
all content hidden behind sign-in.

## 3. Create the upload key

Use Google Play App Signing. Google should protect the app-signing key; the
developer retains a separate upload key.

From a secure PowerShell terminal, choose a path outside the repository and run:

```powershell
keytool -genkeypair -v -keystore C:\secure\emmaprep-upload.jks -alias emmaprep-upload -keyalg RSA -keysize 2048 -validity 10000
```

Do not paste the passwords into issues, chat, CI logs or Git. Back up the
keystore and passwords in two controlled locations.

Copy `android/key.properties.example` to the ignored
`android/key.properties`, then replace every placeholder and point `storeFile`
at the upload keystore.

Record the certificate fingerprint:

```powershell
keytool -list -v -keystore C:\secure\emmaprep-upload.jks -alias emmaprep-upload
```

## 4. Build and verify the bundle

Supply the real production Dart defines. Never put service-role or AI-provider
secrets in the app bundle.

```powershell
flutter clean
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
flutter build appbundle --release --dart-define-from-file=config.production.json
```

The upload artifact is:

`build/app/outputs/bundle/release/app-release.aab`

Inspect the signed bundle before upload:

```powershell
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

## 5. Create the Play Console listing

Complete all required sections rather than guessing:

- app access and reviewer credentials;
- ads declaration;
- target audience and Families-policy questions;
- content-rating questionnaire;
- Data safety and data-deletion declarations;
- camera permission purpose;
- privacy-policy URL;
- support contact;
- Education category, store description, icon, screenshots and feature graphic.

Use an internal test first. Then create the required closed test, resolve the
pre-launch report, and only then apply for production access or submit the
production release.

## Release evidence

Retain the Git commit, version code, signed bundle checksum, upload certificate
fingerprint, Play Console declarations, tester list and dates, pre-launch report,
privacy approval and final release approval. Never store passwords or private
keys in this evidence folder.
