import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })

  const authorization = request.headers.get('authorization') ?? ''
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  })
  const { data: { user } } = await userClient.auth.getUser()
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401, headers: corsHeaders })
  const { data: profile } = await userClient.from('admin_profiles').select('user_id').eq('user_id', user.id).maybeSingle()
  if (!profile) return Response.json({ error: 'Administrator access required' }, { status: 403, headers: corsHeaders })

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const [{ data: release }, { data: settings }] = await Promise.all([
    admin.from('content_releases').select('version,published_at').eq('published', true).order('published_at', { ascending: false }).limit(1).maybeSingle(),
    admin.from('app_config').select('key,value'),
  ])
  const config = Object.fromEntries((settings ?? []).map((row) => [row.key, row.value]))
  const provider = config.ai_provider === 'groq' ? 'groq' : 'openai'
  const providerKey = Deno.env.get(provider === 'groq' ? 'GROQ_API_KEY' : 'OPENAI_API_KEY')
  let providerStatus: number | null = null
  if (providerKey) {
    try {
      const providerResponse = await fetch(provider === 'groq' ? 'https://api.groq.com/openai/v1/models' : 'https://api.openai.com/v1/models', {
        headers: { Authorization: `Bearer ${providerKey}` },
        signal: AbortSignal.timeout(8000),
      })
      providerStatus = providerResponse.status
    } catch (_) {
      providerStatus = 0
    }
  }
  return Response.json({
    ok: true,
    contentRelease: release,
    settingsCount: settings?.length ?? 0,
    openAiConfigured: Boolean(Deno.env.get('OPENAI_API_KEY')),
    groqConfigured: Boolean(Deno.env.get('GROQ_API_KEY')),
    selectedProvider: provider,
    selectedProviderReachable: providerStatus != null && providerStatus >= 200 && providerStatus < 300,
    selectedProviderStatus: providerStatus,
    rateLimitSaltConfigured: Boolean(Deno.env.get('RATE_LIMIT_SALT')),
  }, { headers: corsHeaders })
})
