import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID()
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: cors })
  const authorization = request.headers.get('authorization') ?? ''
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
  const { data: { user } } = await userClient.auth.getUser()
  if (!user) return Response.json({ error: 'Please sign in again', requestId }, { status: 401, headers: cors })
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const { data: configRows } = await admin.from('app_config').select('key,value').in('key', ['question_scanner_enabled', 'ai_provider', 'ai_model', 'groq_vision_model'])
  const config = Object.fromEntries((configRows ?? []).map((row) => [row.key, row.value]))
  if (config.question_scanner_enabled === false) return Response.json({ error: 'Question scanner is temporarily disabled' }, { status: 503, headers: cors })
  const provider = config.ai_provider === 'groq' ? 'groq' : 'openai'
  const apiKey = Deno.env.get(provider === 'groq' ? 'GROQ_API_KEY' : 'OPENAI_API_KEY')
  if (!apiKey) return Response.json({ error: 'Question scanner is not configured' }, { status: 503, headers: cors })

  const address = request.headers.get('x-forwarded-for')?.split(',')[0] ?? 'unknown'
  const salt = Deno.env.get('RATE_LIMIT_SALT') ?? 'configure-rate-limit-salt'
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${salt}:scan:${address}`))
  const clientHash = Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
  const since = new Date(Date.now() - 60_000).toISOString()
  const { count } = await admin.from('chat_rate_limits').select('*', { count: 'exact', head: true }).eq('client_hash', clientHash).gte('created_at', since)
  if ((count ?? 0) >= 4) return Response.json({ error: 'Please wait before scanning again' }, { status: 429, headers: cors })
  await admin.from('chat_rate_limits').insert({ client_hash: clientHash })

  const body = await request.json()
  const images = Array.isArray(body.images) ? body.images.slice(0, 3).filter((value: unknown) => typeof value === 'string' && value.toString().startsWith('data:image/')) : []
  if (images.length === 0) return Response.json({ error: 'At least one image is required' }, { status: 400, headers: cors })
  if (images.some((image: string) => image.length > 6_000_000)) return Response.json({ error: 'An image is too large' }, { status: 413, headers: cors })

  const prompt = 'Read the images in page order. They may contain a passage, questions, or a passage followed by questions on later pages. Transcribe the relevant passage into the passage field once for each related question, preserving paragraph order across images. Extract every visible question relevant to ZIMSEC O-Level English Language 4005 Paper 1 or Paper 2 and answer it accurately. Turn non-multiple-choice questions into four-option practice questions while preserving the tested skill. If a question depends on the passage, use evidence from it in the explanation. If text is unclear, say so instead of guessing. Return JSON shaped exactly as {"questions":[{"paper":"Paper 1","passage":"passage text or empty string","question":"...","answers":["...","...","...","..."],"correctIndex":0,"explanation":"...","studyNote":"..."}]}.'
  const content = [
    { type: 'input_text', text: prompt },
    ...images.map((image: string) => ({ type: 'input_image', image_url: image, detail: 'high' })),
  ]
  const groqContent = [
    { type: 'text', text: `${prompt} Return only a valid JSON object with a questions array.` },
    ...images.map((image: string) => ({ type: 'image_url', image_url: { url: image } })),
  ]
  const response = await fetch(provider === 'groq' ? 'https://api.groq.com/openai/v1/chat/completions' : 'https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(provider === 'groq' ? {
      model: String(config.groq_vision_model ?? 'qwen/qwen3.6-27b'),
      messages: [{ role: 'user', content: groqContent }],
      response_format: { type: 'json_object' },
      max_completion_tokens: 2200,
    } : {
      model: String(config.ai_model ?? 'gpt-5.4-mini'),
      input: [{ role: 'user', content }],
      store: false,
      max_output_tokens: 3500,
      text: { format: { type: 'json_schema', name: 'zimsec_question_scan', strict: true, schema: {
        type: 'object', additionalProperties: false, required: ['questions'], properties: {
          questions: { type: 'array', maxItems: 20, items: { type: 'object', additionalProperties: false,
            required: ['paper', 'passage', 'question', 'answers', 'correctIndex', 'explanation', 'studyNote'], properties: {
              paper: { type: 'string', enum: ['Paper 1', 'Paper 2'] },
              passage: { type: 'string' }, question: { type: 'string' }, answers: { type: 'array', minItems: 4, maxItems: 4, items: { type: 'string' } },
              correctIndex: { type: 'integer', minimum: 0, maximum: 3 }, explanation: { type: 'string' }, studyNote: { type: 'string' },
            } },
          },
        },
      } } },
    }),
  })
  if (!response.ok) {
    console.error(JSON.stringify({ event: 'question_scan_provider_failed', requestId, provider, status: response.status, imageCount: images.length }))
    const reason = response.status === 401 || response.status === 403
      ? `${provider === 'groq' ? 'Groq' : 'OpenAI'} rejected its API key`
      : response.status === 404
      ? 'The selected picture model is unavailable'
      : response.status === 429
      ? 'The picture service rate limit was reached'
      : response.status === 400
      ? 'The picture service rejected the images or selected model'
      : 'Question recognition failed'
    return Response.json({ error: reason, requestId, providerStatus: response.status }, { status: 502, headers: cors })
  }
  const result = await response.json()
  try {
    const raw = provider === 'groq' ? result.choices?.[0]?.message?.content : result.output_text
    const parsed = JSON.parse(raw ?? '{}')
    console.info(JSON.stringify({ event: 'question_scan_success', requestId, imageCount: images.length, questionCount: parsed.questions?.length ?? 0 }))
    return Response.json({ ...parsed, requestId }, { headers: cors })
  } catch (_) {
    return Response.json({ error: 'Question recognition returned an invalid result' }, { status: 502, headers: cors })
  }
})
