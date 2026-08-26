import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID()
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })

  const authorization = request.headers.get('authorization') ?? ''
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
  const { data: { user } } = await userClient.auth.getUser()
  if (!user) return Response.json({ error: 'Please sign in again', requestId }, { status: 401, headers: corsHeaders })

  const clientAddress = request.headers.get('x-forwarded-for')?.split(',')[0] ?? 'unknown'
  const salt = Deno.env.get('RATE_LIMIT_SALT') ?? 'configure-rate-limit-salt'
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${salt}:${clientAddress}`))
  const clientHash = Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const { data: configRows } = await admin.from('app_config').select('key,value').in('key', ['ai_enabled', 'ai_provider', 'ai_model', 'groq_model', 'groq_vision_model'])
  const config = Object.fromEntries((configRows ?? []).map((row) => [row.key, row.value]))
  if (config.ai_enabled === false) return Response.json({ error: 'AI coach is temporarily disabled' }, { status: 503, headers: corsHeaders })
  const provider = config.ai_provider === 'groq' ? 'groq' : 'openai'
  const apiKey = Deno.env.get(provider === 'groq' ? 'GROQ_API_KEY' : 'OPENAI_API_KEY')
  if (!apiKey) return Response.json({ error: `${provider === 'groq' ? 'Groq' : 'OpenAI'} is not configured` }, { status: 503, headers: corsHeaders })
  const since = new Date(Date.now() - 60_000).toISOString()
  const { count } = await admin.from('chat_rate_limits').select('*', { count: 'exact', head: true }).eq('client_hash', clientHash).gte('created_at', since)
  if ((count ?? 0) >= 12) return Response.json({ error: 'Please wait before sending another message' }, { status: 429, headers: corsHeaders })
  await admin.from('chat_rate_limits').insert({ client_hash: clientHash })

  const body = await request.json()
  const message = String(body.message ?? '').trim().slice(0, 4000)
  const history = Array.isArray(body.history) ? body.history.slice(-8) : []
  const images = Array.isArray(body.images) ? body.images.slice(0, 3).filter((value: unknown) => typeof value === 'string' && value.toString().startsWith('data:image/')) : []
  if (!message) return Response.json({ error: 'Message is required' }, { status: 400, headers: corsHeaders })
  if (images.some((image: string) => image.length > 6_000_000)) return Response.json({ error: 'An attachment is too large', requestId }, { status: 413, headers: corsHeaders })

  const instructions = 'You are EmmaPrep, a warm and patient tutor for Emmaculate. Teach only ZIMSEC O-Level English Language 4005 Paper 1 and Paper 2 skills. Use simple Zimbabwe-relevant examples, active recall, and one short practice question at a time. Never claim invented rules are official. Give helpful feedback before a model answer.'
  const groqUserContent = images.length === 0 ? message : [
    { type: 'text', text: message },
    ...images.map((image: string) => ({ type: 'image_url', image_url: { url: image } })),
  ]
  const openAiUserContent = images.length === 0 ? message : [
    { type: 'input_text', text: message },
    ...images.map((image: string) => ({ type: 'input_image', image_url: image, detail: 'high' })),
  ]
  const modelResponse = await fetch(provider === 'groq' ? 'https://api.groq.com/openai/v1/chat/completions' : 'https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(provider === 'groq' ? {
      model: String(images.length > 0 ? config.groq_vision_model ?? 'qwen/qwen3.6-27b' : config.groq_model ?? 'openai/gpt-oss-20b'),
      messages: [
        { role: 'system', content: instructions },
        ...history.map((item: any) => ({ role: item.role === 'assistant' ? 'assistant' : 'user', content: String(item.content ?? '') })),
        { role: 'user', content: groqUserContent },
      ],
      max_completion_tokens: 700,
      user: 'emmaprep-student',
    } : {
      model: String(config.ai_model ?? Deno.env.get('OPENAI_MODEL') ?? 'gpt-5.4-mini'),
      instructions,
      input: [...history, { role: 'user', content: openAiUserContent }],
      max_output_tokens: 700,
      store: false,
      safety_identifier: 'emmaprep-student',
    }),
  })
  if (!modelResponse.ok) {
    console.error(JSON.stringify({ event: 'chat_provider_failed', requestId, provider, status: modelResponse.status }))
    const reason = modelResponse.status === 401 || modelResponse.status === 403
      ? `${provider === 'groq' ? 'Groq' : 'OpenAI'} rejected its API key`
      : modelResponse.status === 404
      ? 'The selected AI model is unavailable'
      : modelResponse.status === 429
      ? 'The AI provider rate limit was reached'
      : modelResponse.status === 400
      ? 'The AI provider rejected the request or selected model'
      : 'The tutor provider could not answer'
    return Response.json({ error: reason, requestId, providerStatus: modelResponse.status }, { status: 502, headers: corsHeaders })
  }
  const result = await modelResponse.json()
  const reply = provider === 'groq'
    ? result.choices?.[0]?.message?.content
    : result.output_text ?? result.output?.flatMap((item: any) => item.content ?? []).find((item: any) => item.type === 'output_text')?.text
  console.info(JSON.stringify({ event: 'chat_success', requestId, provider }))
  return Response.json({ reply: reply ?? 'Please try that question again.', requestId }, { headers: corsHeaders })
})
