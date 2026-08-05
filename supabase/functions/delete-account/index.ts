// Deletes the calling student's own account entirely (auth user + every
// row that references it via `on delete cascade` — see
// supabase/schema.sql). Play Store policy requires an in-app account
// deletion path; this can't be done from the Flutter app directly because
// only the service_role key can call the admin delete-user API, and that
// key must never ship inside the app.
//
// Deploy once with the Supabase CLI (no billing needed, generous free
// tier): `supabase functions deploy delete-account`
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
    });
  }

  // Verifies the caller's own JWT (anon key + their token) to find out who
  // they are, without ever trusting a client-supplied user id.
  const callerClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
    });
  }

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    user.id,
  );
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
    });
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 });
});
