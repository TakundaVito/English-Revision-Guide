import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID()
  console.info(JSON.stringify({ event: 'admin_create_student_start', requestId }))
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: cors })
  const authorization = request.headers.get('authorization') ?? ''
  const url = Deno.env.get('SUPABASE_URL')!
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
  const { data: { user } } = await userClient.auth.getUser()
  if (!user) { console.warn(JSON.stringify({ event: 'admin_create_student_denied', requestId, reason: 'unauthenticated' })); return Response.json({ error: 'Authentication required', requestId }, { status: 401, headers: cors }) }
  const { data: profile } = await userClient.from('admin_profiles').select('user_id').eq('user_id', user.id).maybeSingle()
  if (!profile) { console.warn(JSON.stringify({ event: 'admin_create_student_denied', requestId, reason: 'not_admin' })); return Response.json({ error: 'Administrator access required', requestId }, { status: 403, headers: cors }) }

  const body = await request.json()
  const email = String(body.email ?? '').trim().toLowerCase()
  const password = String(body.password ?? '')
  const displayName = String(body.displayName ?? 'Student').trim().slice(0, 80)
  const personalEdition = body.personalEdition === true
  if (!email.includes('@') || password.length < 8 || displayName.length < 2) {
    return Response.json({ error: 'Valid name, email and an 8-character password are required' }, { status: 400, headers: cors })
  }
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: displayName },
    app_metadata: { personal_edition: personalEdition },
  })
  if (error) { console.error(JSON.stringify({ event: 'admin_create_student_failed', requestId, code: error.code ?? 'auth_error' })); return Response.json({ error: error.message, requestId }, { status: 400, headers: cors }) }
  await admin.from('audit_log').insert({ actor_id: user.id, action: 'create', entity_type: 'student_account', entity_id: data.user.id, details: { displayName, personalEdition } })
  console.info(JSON.stringify({ event: 'admin_create_student_success', requestId, userId: data.user.id }))
  return Response.json({ ok: true, userId: data.user.id, email, displayName, requestId }, { headers: cors })
})
