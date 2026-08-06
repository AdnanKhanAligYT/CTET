// Bridges Firebase Phone Auth (free, and Google handles India's mandatory
// DLT SMS registration for you) into a real Supabase session — Supabase's
// own phone provider needs a paid SMS vendor (Twilio etc.) plus that same
// DLT registration done yourself, which is a lot for an individual
// developer. See README "Set up Mobile OTP" for the full setup.
//
// Flow: the Flutter app completes Firebase phone verification client-side,
// then sends this function the resulting Firebase ID token. This function:
//   1. Verifies that ID token's signature against Google's public keys
//      (proves Firebase really did verify this phone number — a client
//      could otherwise just claim any number).
//   2. Creates a Supabase auth user for that phone number if one doesn't
//      exist yet, or resets its password if it does — either way with a
//      fresh, random, one-time password only this function and the caller
//      ever see.
//   3. Returns {phone, password} so the app can immediately call Supabase's
//      normal `signInWithPassword(phone, password)` — a real sign-in
//      through Supabase's own auth flow, with a real session that
//      refreshes normally. No custom token-minting involved.
//
// Deploy: `supabase functions deploy firebase-phone-bridge`
// Needs one secret set first: `supabase secrets set FIREBASE_PROJECT_ID=<your-firebase-project-id>`
import { createClient } from "jsr:@supabase/supabase-js@2";
import { decodeProtectedHeader, importX509, jwtVerify } from "npm:jose@5";

const FIREBASE_CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

async function verifyFirebaseIdToken(idToken: string, projectId: string) {
  const { kid } = decodeProtectedHeader(idToken);
  if (!kid) throw new Error("Firebase ID token has no key id");

  const certsRes = await fetch(FIREBASE_CERTS_URL);
  const certs = (await certsRes.json()) as Record<string, string>;
  const cert = certs[kid];
  if (!cert) throw new Error("Firebase ID token key id not recognised");

  const publicKey = await importX509(cert, "RS256");
  const { payload } = await jwtVerify(idToken, publicKey, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  return payload;
}

function randomPassword() {
  return crypto.randomUUID() + crypto.randomUUID();
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    const { idToken } = await req.json();
    if (!idToken) return json({ error: "Missing idToken" }, 400);

    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    if (!projectId) return json({ error: "Server not configured" }, 500);

    const payload = await verifyFirebaseIdToken(idToken, projectId);
    const phoneNumber = payload.phone_number as string | undefined;
    if (!phoneNumber) {
      return json({ error: "Token has no verified phone number" }, 400);
    }
    // Supabase stores phone numbers without the leading "+".
    const phone = phoneNumber.replace(/^\+/, "");
    const password = randomPassword();

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: created, error: createError } = await supabaseAdmin.auth
      .admin.createUser({ phone, password, phone_confirm: true });

    if (created?.user) {
      return json({ phone, password });
    }

    // createUser fails if this phone is already registered — find that
    // existing user instead and reset their password to this one-time value.
    let existingId: string | null = null;
    for (let page = 1; page <= 50 && !existingId; page++) {
      const { data: list, error: listError } = await supabaseAdmin.auth.admin
        .listUsers({ page, perPage: 200 });
      if (listError || !list || list.users.length === 0) break;
      const match = list.users.find((u) => u.phone === phone);
      if (match) existingId = match.id;
      if (list.users.length < 200) break;
    }

    if (!existingId) {
      return json({ error: createError?.message ?? "Could not verify this number" }, 500);
    }

    const { error: updateError } = await supabaseAdmin.auth.admin
      .updateUserById(existingId, { password });
    if (updateError) return json({ error: updateError.message }, 500);

    return json({ phone, password });
  } catch (err) {
    return json({ error: String(err) }, 400);
  }
});
