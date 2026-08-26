update public.app_config
set value = '"openai/gpt-oss-20b"'::jsonb,
    updated_at = now()
where key = 'groq_model'
  and value in ('"llama-3.3-70b-versatile"'::jsonb, 'null'::jsonb);

insert into public.app_config (key, value)
values ('groq_model', '"openai/gpt-oss-20b"'::jsonb)
on conflict (key) do nothing;
