insert into public.app_config(key, value) values
  ('ai_enabled', 'true'::jsonb),
  ('ai_model', '"gpt-5.4-mini"'::jsonb),
  ('content_cache_seconds', '300'::jsonb),
  ('maintenance_notice', '""'::jsonb),
  ('minimum_version', '"1.3.0"'::jsonb)
on conflict (key) do nothing;

create policy public_content_cache_read on public.app_config
for select to anon using (key = 'content_cache_seconds');

insert into public.audit_log(actor_id, action, entity_type, entity_id, details)
values (auth.uid(), 'install', 'migration', '202608260002_remote_settings', '{}');
