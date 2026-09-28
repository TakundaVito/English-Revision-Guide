import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, {
      status: 405,
      headers: cors,
    });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const authorization = request.headers.get("authorization") ?? "";
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) {
    return Response.json({ error: "Authentication required", requestId }, {
      status: 401,
      headers: cors,
    });
  }
  const { data: profile } = await userClient.from("admin_profiles").select(
    "user_id",
  ).eq("user_id", user.id).maybeSingle();
  if (!profile) {
    return Response.json(
      { error: "Administrator access required", requestId },
      { status: 403, headers: cors },
    );
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: profiles, error: profileError } = await admin
    .from("student_profiles")
    .select("user_id,display_name,created_at")
    .order("created_at", { ascending: false });
  if (profileError) {
    return Response.json({ error: profileError.message, requestId }, {
      status: 400,
      headers: cors,
    });
  }
  return Response.json({ students: profiles ?? [], requestId }, {
    headers: cors,
  });
});
