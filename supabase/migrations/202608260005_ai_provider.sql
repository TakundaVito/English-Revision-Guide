insert into public.app_config (key, value) values
  ('ai_provider', '"openai"'::jsonb),
  ('groq_model', '"openai/gpt-oss-20b"'::jsonb),
  ('groq_vision_model', '"qwen/qwen3.6-27b"'::jsonb)
on conflict (key) do nothing;
