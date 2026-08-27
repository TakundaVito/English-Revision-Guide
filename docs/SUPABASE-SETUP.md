# EmmaPrep Supabase setup

Project: `hobzfmqnnztjyrtjspol`

The publishable project URL/key are supplied through ignored local configuration. Never add the database password, secret key, service-role key or AI-provider key to the Flutter source or an APK.

## 1. Install the database

Open the Supabase dashboard **SQL Editor**, create a query, paste the complete contents of:

`supabase/migrations/202608260001_initial_admin.sql`

Run it once. It creates the draft tables, immutable release snapshots, audit records, publishing function and Row Level Security policies.

If the initial migration is already installed, run `supabase/migrations/202608260002_remote_settings.sql` as a new SQL Editor query. Do not rerun or delete the first migration.

Then run `supabase/migrations/202608260003_student_accounts_scanner.sql` as another new query. It adds self-only student profiles and keeps public registration disabled.

Finally run `supabase/migrations/202608260004_privacy_safe_events.sql` as a new query. It adds the administrator Activity feed without storing learning content or credentials.

Then run `supabase/migrations/202608260005_ai_provider.sql`. It adds the non-secret OpenAI/Groq provider and model controls used by englishTutor.

## 2. Create the administrator

In **Authentication > Users**, create Takunda's email/password user. Copy that user's UUID. In the SQL Editor run this after replacing the placeholder:

```sql
insert into public.admin_profiles(user_id, display_name)
values ('YOUR_AUTH_USER_UUID', 'Takunda Vito');
```

This row, not possession of the public key, grants dashboard write access.

## 3. Deploy the API functions

Install the Supabase CLI, sign in, then run from the repository root:

```powershell
supabase login
supabase link --project-ref hobzfmqnnztjyrtjspol
supabase functions deploy content
supabase functions deploy chat
supabase functions deploy health
supabase functions deploy admin-create-student
supabase functions deploy admin-students
supabase functions deploy scan-questions
```

The content function is public but returns only the latest published snapshot. Chat and scanning are rate-limited and keep the selected provider credential on the server. The health function requires an authenticated administrator and returns readiness booleans without returning secret values.

Set the chat secrets in the Supabase dashboard or CLI. Do not paste them into Git:

```powershell
supabase secrets set OPENAI_API_KEY=YOUR_OPENAI_KEY
supabase secrets set OPENAI_MODEL=gpt-5.4-mini
supabase secrets set GROQ_API_KEY=YOUR_GROQ_KEY
supabase secrets set RATE_LIMIT_SALT=A_LONG_RANDOM_VALUE
```

Prefer entering `GROQ_API_KEY` through **Supabase Dashboard > Edge Functions > Secrets**, so the value is not left in PowerShell history. englishTutor only selects the provider and approved models; it never receives or displays the key.

## 4. Run the administrator dashboard

The ignored `admin/config.local.json` is already configured for this project.

```powershell
cd admin
flutter run -d chrome --dart-define-from-file=config.local.json
```

Sign in with the administrator created in step 2. Create lessons and questions as drafts, enable the records that passed review, then publish a version such as `2026.08.1`.

Open **Users** to create Emmaculate's confirmed credentials. Keep **Allow public account creation** off while the app is private; turn it on later when other students may register.

## 5. Run or build the learning app

The ignored root `config.production.json` points to the Supabase Edge Functions API.

```powershell
flutter run -d chrome --dart-define-from-file=config.production.json
flutter build apk --release --split-per-abi --dart-define-from-file=config.production.json
```

The app requests `/v1/content` at launch, validates `emmaprep-content-v1` and `zimsec-4005`, then caches the snapshot for offline use.

The signed-in student may send up to three compressed camera/gallery images to the scanner. Results are reviewed before they are saved into local Study and Practice; image bytes are not retained in study history.

For production diagnostics, open Supabase **Functions**, select a function, then inspect **Invocations** and **Logs**. The admin app's Activity section shows the separate privacy-safe application event stream.

## Publishing safety

- Draft edits do not reach the student app.
- Publishing archives the previous active release and creates an atomic snapshot.
- Only authenticated users listed in `admin_profiles` can edit or publish.
- Do not copy past-paper passages. Create original questions that practise the same typical skills and structures.
