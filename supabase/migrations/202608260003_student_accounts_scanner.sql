create table public.student_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Student' check (char_length(display_name) between 2 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.student_profiles enable row level security;
create policy student_profile_self_read on public.student_profiles
for select to authenticated using (user_id = auth.uid());
create policy student_profile_self_update on public.student_profiles
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy admin_student_profiles_read on public.student_profiles
for select to authenticated using (public.is_emmaprep_admin());

create or replace function public.create_student_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.student_profiles(user_id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Student'))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger auth_user_student_profile
after insert on auth.users
for each row execute function public.create_student_profile();

insert into public.student_profiles(user_id, display_name)
select users.id, coalesce(nullif(users.raw_user_meta_data ->> 'display_name', ''), 'Student')
from auth.users as users
where not exists (select 1 from public.admin_profiles where user_id = users.id)
on conflict (user_id) do nothing;

insert into public.app_config(key, value) values
  ('registration_enabled', 'false'::jsonb),
  ('question_scanner_enabled', 'true'::jsonb)
on conflict (key) do nothing;

create policy public_feature_flags_read on public.app_config
for select to anon using (key in ('registration_enabled', 'question_scanner_enabled'));

insert into public.audit_log(actor_id, action, entity_type, entity_id, details)
values (auth.uid(), 'install', 'migration', '202608260003_student_accounts_scanner', '{}');
