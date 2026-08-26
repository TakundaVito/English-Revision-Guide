import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'apikey, authorization, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })

  const apiKey = Deno.env.get('OPENAI_API_KEY')
  if (!apiKey) return Response.json({ error: 'AI coach is not configured' }, { status: 503, headers: corsHeaders })

  const clientAddress = request.headers.get('x-forwarded-for')?.split(',')[0] ?? 'unknown'
  const salt = Deno.env.get('RATE_LIMIT_SALT') ?? 'configure-rate-limit-salt'
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${salt}:${clientAddress}`))
  const clientHash = Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const since = new Date(Date.now() - 60_000).toISOString()
  const { count } = await admin.from('chat_rate_limits').select('*', { count: 'exact', head: true }).eq('client_hash', clientHash).gte('created_at', since)
  if ((count ?? 0) >= 12) return Response.json({ error: 'Please wait before sending another message' }, { status: 429, headers: corsHeaders })
  await admin.from('chat_rate_limits').insert({ client_hash: clientHash })

  const body = await request.json()
  const message = String(body.message ?? '').trim().slice(0, 4000)
  const history = Array.isArray(body.history) ? body.history.slice(-8) : []
  if (!message) return Response.json({ error: 'Message is required' }, { status: 400, headers: corsHeaders })

  const modelResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: Deno.env.get('OPENAI_MODEL') ?? 'gpt-5.4-mini',
      instructions: 'You are EmmaPrep, a warm and patient tutor for Emmaculate. Teach only ZIMSEC O-Level English Language 4005 Paper 1 and Paper 2 skills. Use simple Zimbabwe-relevant examples, active recall, and one short practice question at a time. Never claim invented rules are official. Give helpful feedback before a model answer.',
      input: [...history, { role: 'user', content: message }],
      max_output_tokens: 700,
      store: false,
      safety_identifier: 'emmaprep-student',
    }),
  })
  if (!modelResponse.ok) return Response.json({ error: 'AI provider request failed' }, { status: 502, headers: corsHeaders })
  const result = await modelResponse.json()
  const reply = result.output_text ?? result.output?.flatMap((item: any) => item.content ?? []).find((item: any) => item.type === 'output_text')?.text
  return Response.json({ reply: reply ?? 'Please try that question again.' }, { headers: corsHeaders })
})
