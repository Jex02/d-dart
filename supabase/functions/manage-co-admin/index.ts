import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Server configuration missing." }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonResponse({ error: "Missing authorization token." }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Authenticate caller via Supabase Auth
  const {
    data: { user: caller },
    error: callerError,
  } = await adminClient.auth.getUser(token);

  if (callerError || !caller) {
    return jsonResponse({ error: "Invalid or expired session." }, 401);
  }

  // 2. Authorize caller as Administrator via public.profiles
  const { data: callerProfile, error: profileErr } = await adminClient
    .from("profiles")
    .select("role, account_type")
    .eq("id", caller.id)
    .maybeSingle();

  const isCallerAdmin =
    !profileErr &&
    callerProfile != null &&
    (callerProfile.account_type === "admin" || callerProfile.role === "admin");

  if (!isCallerAdmin) {
    return jsonResponse(
      { error: "Only administrators can manage co-admin accounts." },
      403,
    );
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "Invalid JSON payload." }, 400);
  }

  const action = typeof body.action === "string" ? body.action.trim() : "create";

  if (action === "create") {
    const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const password = typeof body.password === "string" ? body.password : "";
    const phoneNumber = typeof body.phone_number === "string" ? body.phone_number.trim() : "";

    if (fullName.length < 2) {
      return jsonResponse({ error: "Full name must be at least 2 characters." }, 400);
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return jsonResponse({ error: "Please enter a valid email address." }, 400);
    }
    if (password.length < 6) {
      return jsonResponse({ error: "Password must be at least 6 characters." }, 400);
    }

    const { data: created, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
          phone_number: phoneNumber,
          account_type: "admin",
        },
      });

    if (createError || !created.user) {
      const msg = createError?.message ?? "Failed to create co-admin account.";
      const status = msg.toLowerCase().includes("already") ? 409 : 400;
      return jsonResponse({ error: msg }, status);
    }

    const newUserId = created.user.id;
    const nowIso = new Date().toISOString();

    const { error: upsertError } = await adminClient.from("profiles").upsert(
      {
        id: newUserId,
        full_name: fullName,
        email,
        phone_number: phoneNumber,
        student_id: "",
        role: "admin",
        account_type: "admin",
        verification_status: "verified",
        cor_verified: false,
        updated_at: nowIso,
      },
      { onConflict: "id" },
    );

    if (upsertError) {
      // Clean up auth user so we don't leave a non-admin orphan account
      await adminClient.auth.admin.deleteUser(newUserId);
      return jsonResponse(
        { error: `Failed to initialize co-admin profile: ${upsertError.message}` },
        500,
      );
    }

    return jsonResponse(
      {
        id: newUserId,
        full_name: fullName,
        email,
        phone_number: phoneNumber,
        role: "admin",
        account_type: "admin",
        verification_status: "verified",
      },
      201,
    );
  }

  if (action === "delete") {
    const targetUserId = typeof body.user_id === "string" ? body.user_id.trim() : "";
    if (!targetUserId) {
      return jsonResponse({ error: "Missing user_id." }, 400);
    }
    if (targetUserId === caller.id) {
      return jsonResponse(
        { error: "You cannot delete your own administrator account." },
        400,
      );
    }

    const { data: targetProfile, error: targetErr } = await adminClient
      .from("profiles")
      .select("role, account_type")
      .eq("id", targetUserId)
      .maybeSingle();

    if (targetErr || !targetProfile) {
      return jsonResponse({ error: "Target account not found." }, 404);
    }

    const isTargetAdmin =
      targetProfile.account_type === "admin" || targetProfile.role === "admin";
    if (!isTargetAdmin) {
      return jsonResponse(
        { error: "Only co-administrator accounts can be removed from this endpoint." },
        400,
      );
    }

    const { error: deleteErr } =
      await adminClient.auth.admin.deleteUser(targetUserId);
    if (deleteErr) {
      return jsonResponse({ error: deleteErr.message }, 500);
    }

    return jsonResponse({ deleted: true, user_id: targetUserId }, 200);
  }

  return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
});
