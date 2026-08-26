create table public.app_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  source text not null check (source in ('student_app', 'admin_app', 'edge_function')),
  event_name text not null check (event_name ~ '^[a-z0-9_]{3,80}$'),
  level text not null default 'info' check (level in ('info', 'warning', 'error')),
  app_version text not null default '',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  constraint app_event_metadata_size check (octet_length(metadata::text) <= 4096)
);

create index app_events_created_at on public.app_events(created_at desc);
create index app_events_name_created on public.app_events(event_name, created_at desc);
alter table public.app_events enable row level security;

create policy signed_in_event_insert on public.app_events
for insert to authenticated with check (actor_id = auth.uid());
create policy admin_event_read on public.app_events
for select to authenticated using (public.is_emmaprep_admin());

comment on table public.app_events is 'Privacy-safe operational events only. Never store credentials, tokens, emails, question text, answers, images or chat content.';

insert into public.audit_log(actor_id, action, entity_type, entity_id, details)
values (auth.uid(), 'install', 'migration', '202608260004_privacy_safe_events', '{}');
