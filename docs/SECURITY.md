# Security and privacy controls

## Trust boundary

The APK is an untrusted public client. A determined user can inspect compiled strings and network traffic. `EMMAPREP_API_URL` is not secret. `EMMAPREP_APP_TOKEN`, when used, must be restricted, revocable, rate-limited and replaceable without exposing an AI-provider credential.

The backend is responsible for:

- storing AI-provider secrets;
- authenticating and rate-limiting clients;
- validating chat and content payloads;
- enforcing request and response size limits;
- preventing prompt input from changing server authorization or content-publishing controls;
- reviewing remote syllabus content before publication;
- applying HTTPS, logging minimization and retention limits.

## Student data

Bundled learning progress is stored locally. Do not send personal information, private correspondence or identifiable student records to the coach unless a documented consent and retention policy is introduced. The server should avoid retaining chat content by default.

## Repository exclusions

Never commit:

- `config.production.json` or `.env*`;
- Android keystores, aliases or passwords;
- provider/API secrets;
- production chat logs or remotely collected student writing;
- APK signing material, sessions, caches or local preferences.

## Reporting

Security concerns should be reported through the developer website: `https://takunda.vito.co.zw`.
