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
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const client = createClient(url, publishableKey, { auth: { persistSession: false } })
  const [{ data, error }, { data: settings }] = await Promise.all([
    client.from('content_releases').select('version,payload,published_at').eq('published', true).order('published_at', { ascending: false }).limit(1).maybeSingle(),
    client.from('app_config').select('key,value').in('key', ['minimum_version', 'maintenance_notice', 'content_cache_seconds']),
  ])

  if (error) return Response.json({ error: 'Content unavailable' }, { status: 500, headers: corsHeaders })
  if (!data) return Response.json({ error: 'No content has been published' }, { status: 404, headers: corsHeaders })

  const etag = `"${data.version}"`
  if (request.headers.get('if-none-match') === etag) {
    return new Response(null, { status: 304, headers: { ...corsHeaders, ETag: etag } })
  }
  const publicConfig = Object.fromEntries((settings ?? []).map((row) => [row.key, row.value]))
  const cacheSeconds = Math.min(3600, Math.max(60, Number(publicConfig.content_cache_seconds ?? 300)))
  return Response.json({ ...data.payload, appConfig: publicConfig }, {
    headers: { ...corsHeaders, ETag: etag, 'Cache-Control': `public, max-age=${cacheSeconds}` },
  })
})
