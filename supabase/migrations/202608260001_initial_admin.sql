create extension if not exists pgcrypto;

create type public.emmaprep_paper as enum ('Paper 1', 'Paper 2');

create table public.admin_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'EmmaPrep Administrator',
  created_at timestamptz not null default now()
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  paper public.emmaprep_paper not null,
  title text not null check (char_length(title) between 3 and 120),
  subtitle text not null default '',
  introduction text not null default '',
  notes text[] not null default '{}',
  checklist text[] not null default '{}',
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  paper public.emmaprep_paper not null,
  exam_style text not null default 'zimsec-4005' check (exam_style = 'zimsec-4005'),
  question text not null check (char_length(question) between 10 and 1000),
  answers text[] not null check (cardinality(answers) between 2 and 6),
  correct_index integer not null check (correct_index >= 0),
  explanation text not null check (char_length(explanation) >= 5),
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint correct_answer_exists check (correct_index < cardinality(answers))
);

create table public.content_releases (
  id uuid primary key default gen_random_uuid(),
  version text not null unique,
  schema_name text not null default 'emmaprep-content-v1' check (schema_name = 'emmaprep-content-v1'),
  curriculum text not null default 'zimsec-4005' check (curriculum = 'zimsec-4005'),
  payload jsonb not null,
  published boolean not null default true,
  published_by uuid references auth.users(id),
  published_at timestamptz not null default now()
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  enabled boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.chat_rate_limits (
  id bigint generated always as identity primary key,
  client_hash text not null,
  created_at timestamptz not null default now()
);
create index chat_rate_limits_lookup on public.chat_rate_limits(client_hash, created_at desc);

create or replace function public.is_emmaprep_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_profiles where user_id = auth.uid()
  );
$$;

create or replace function public.touch_admin_record()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  new.updated_by = auth.uid();
  if tg_op = 'INSERT' then
    new.created_by = auth.uid();
  end if;
  return new;
end;
$$;

create trigger lessons_touch before insert or update on public.lessons
for each row execute function public.touch_admin_record();

create trigger questions_touch before insert or update on public.questions
for each row execute function public.touch_admin_record();

create or replace function public.publish_emmaprep_content(release_version text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  release_id uuid;
  release_payload jsonb;
begin
  if not public.is_emmaprep_admin() then
    raise exception 'Administrator access required';
  end if;
  if release_version !~ '^[0-9]{4}\.[0-9]{2}\.[0-9]+$' then
    raise exception 'Version must look like 2026.08.1';
  end if;

  select jsonb_build_object(
    'schema', 'emmaprep-content-v1',
    'curriculum', 'zimsec-4005',
    'version', release_version,
    'lessons', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', slug, 'paper', paper::text, 'title', title,
        'subtitle', subtitle, 'introduction', introduction,
        'notes', notes, 'checklist', checklist
      ) order by paper, sort_order, title)
      from public.lessons where enabled
    ), '[]'::jsonb),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'paper', paper::text, 'examStyle', exam_style,
        'question', question, 'answers', answers,
        'correctIndex', correct_index, 'explanation', explanation
      ) order by paper, sort_order, created_at)
      from public.questions where enabled
    ), '[]'::jsonb)
  ) into release_payload;

  update public.content_releases set published = false where published;
  insert into public.content_releases(version, payload, published_by)
  values (release_version, release_payload, auth.uid()) returning id into release_id;
  insert into public.audit_log(actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'publish', 'content_release', release_id::text,
    jsonb_build_object('version', release_version));
  return release_id;
end;
$$;

alter table public.admin_profiles enable row level security;
alter table public.lessons enable row level security;
alter table public.questions enable row level security;
alter table public.content_releases enable row level security;
alter table public.announcements enable row level security;
alter table public.app_config enable row level security;
alter table public.audit_log enable row level security;
alter table public.chat_rate_limits enable row level security;

create policy admin_profile_self_read on public.admin_profiles
for select to authenticated using (user_id = auth.uid());
create policy admin_lessons_all on public.lessons
for all to authenticated using (public.is_emmaprep_admin()) with check (public.is_emmaprep_admin());
create policy admin_questions_all on public.questions
for all to authenticated using (public.is_emmaprep_admin()) with check (public.is_emmaprep_admin());
create policy admin_releases_all on public.content_releases
for all to authenticated using (public.is_emmaprep_admin()) with check (public.is_emmaprep_admin());
create policy published_releases_read on public.content_releases
for select to anon using (published);
create policy admin_announcements_all on public.announcements
for all to authenticated using (public.is_emmaprep_admin()) with check (public.is_emmaprep_admin());
create policy active_announcements_read on public.announcements
for select to anon using (
  enabled and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at >= now())
);
create policy admin_config_all on public.app_config
for all to authenticated using (public.is_emmaprep_admin()) with check (public.is_emmaprep_admin());
create policy public_config_read on public.app_config
for select to anon using (key in ('minimum_version', 'maintenance_notice'));
create policy admin_audit_read on public.audit_log
for select to authenticated using (public.is_emmaprep_admin());

grant execute on function public.publish_emmaprep_content(text) to authenticated;
revoke all on function public.publish_emmaprep_content(text) from anon;
