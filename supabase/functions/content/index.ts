import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, if-none-match',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'GET') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })

  const url = Deno.env.get('SUPABASE_URL')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const client = createClient(url, serviceKey, { auth: { persistSession: false } })
  const now = new Date().toISOString()
  const [{ data, error }, { data: settings }, { data: announcements }] = await Promise.all([
    client.from('content_releases').select('version,payload,published_at').eq('published', true).order('published_at', { ascending: false }).limit(1).maybeSingle(),
    client.from('app_config').select('key,value').in('key', ['minimum_version', 'maintenance_notice', 'content_cache_seconds', 'ai_enabled', 'question_scanner_enabled']),
    client.from('announcements').select('id,title,message,starts_at,ends_at,created_at').eq('enabled', true).or(`starts_at.is.null,starts_at.lte.${now}`).or(`ends_at.is.null,ends_at.gte.${now}`).order('created_at', { ascending: false }).limit(5),
  ])

  if (error) return Response.json({ error: 'Content unavailable' }, { status: 500, headers: corsHeaders })
  if (!data) return Response.json({ error: 'No content has been published' }, { status: 404, headers: corsHeaders })

  const publicConfig = Object.fromEntries((settings ?? []).map((row) => [row.key, row.value]))
  const responsePayload = { ...data.payload, appConfig: publicConfig, announcements: announcements ?? [] }
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify({ version: data.version, config: publicConfig, announcements: responsePayload.announcements })))
  const etag = `"${Array.from(new Uint8Array(digest)).slice(0, 12).map((byte) => byte.toString(16).padStart(2, '0')).join('')}"`
  if (request.headers.get('if-none-match') === etag) {
    return new Response(null, { status: 304, headers: { ...corsHeaders, ETag: etag } })
  }
  const cacheSeconds = Math.min(3600, Math.max(60, Number(publicConfig.content_cache_seconds ?? 300)))
  return Response.json(responsePayload, {
    headers: { ...corsHeaders, ETag: etag, 'Cache-Control': `public, max-age=${cacheSeconds}` },
  })
})
