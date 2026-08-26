# EmmaPrep Supabase setup

Project: `hobzfmqnnztjyrtjspol`

The publishable project URL/key are supplied through ignored local configuration. Never add the database password, secret key, service-role key or AI-provider key to the Flutter source or an APK.

## 1. Install the database

Open the Supabase dashboard **SQL Editor**, create a query, paste the complete contents of:

`supabase/migrations/202608260001_initial_admin.sql`

Run it once. It creates the draft tables, immutable release snapshots, audit records, publishing function and Row Level Security policies.

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
```

The content function is public but returns only the latest published snapshot. The chat function is rate-limited and keeps the OpenAI credential on the server.

Set the chat secrets in the Supabase dashboard or CLI. Do not paste them into Git:

```powershell
supabase secrets set OPENAI_API_KEY=YOUR_OPENAI_KEY
supabase secrets set OPENAI_MODEL=gpt-5.4-mini
supabase secrets set RATE_LIMIT_SALT=A_LONG_RANDOM_VALUE
```

## 4. Run the administrator dashboard

The ignored `admin/config.local.json` is already configured for this project.

```powershell
cd admin
flutter run -d chrome --dart-define-from-file=config.local.json
```

Sign in with the administrator created in step 2. Create lessons and questions as drafts, enable the records that passed review, then publish a version such as `2026.08.1`.

## 5. Run or build the learning app

The ignored root `config.production.json` points to the Supabase Edge Functions API.

```powershell
flutter run -d chrome --dart-define-from-file=config.production.json
flutter build apk --release --split-per-abi --dart-define-from-file=config.production.json
```

The app requests `/v1/content` at launch, validates `emmaprep-content-v1` and `zimsec-4005`, then caches the snapshot for offline use.

## Publishing safety

- Draft edits do not reach the student app.
- Publishing archives the previous active release and creates an atomic snapshot.
- Only authenticated users listed in `admin_profiles` can edit or publish.
- Do not copy past-paper passages. Create original questions that practise the same typical skills and structures.
