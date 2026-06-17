// Supabase Edge Function: force-verify-user
// Admin-only: set a user's email as confirmed (email_confirmed_at) so they can sign in without OTP.
// Uses JWKS to verify JWT, checks profiles.role = admin, then uses service role to call Auth Admin API.

import * as jose from "jsr:@panva/jose@6";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_JWT_ISSUER =
  Deno.env.get("SB_JWT_ISSUER") ?? Deno.env.get("SUPABASE_URL") + "/auth/v1";
const JWKS_URL = Deno.env.get("SUPABASE_URL")! + "/auth/v1/.well-known/jwks.json";

function getAuthToken(req: Request): string {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing or invalid Authorization header");
  }
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) throw new Error("Empty token");
  return token;
}

async function verifyJwtAndGetSub(token: string): Promise<string> {
  const jwks = jose.createRemoteJWKSet(new URL(JWKS_URL));
  const { payload } = await jose.jwtVerify(token, jwks, { issuer: SUPABASE_JWT_ISSUER });
  const sub = payload.sub;
  if (typeof sub !== "string" || !sub) throw new Error("JWT missing sub");
  return sub;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const token = getAuthToken(req);
    const callerUserId = await verifyJwtAndGetSub(token);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Ensure caller is admin
    const { data: profile } = await adminClient
      .from("profiles")
      .select("role")
      .eq("id", callerUserId)
      .single();
    if (profile?.role !== "admin") {
      return new Response(
        JSON.stringify({ message: "Forbidden: admin only" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse body: { target_user_id: string }
    const contentType = req.headers.get("content-type") || "";
    if (!contentType.includes("application/json")) {
      return new Response(
        JSON.stringify({ message: "Content-Type must be application/json" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const body = (await req.json()) as { target_user_id?: string };
    const targetUserId = body?.target_user_id;
    if (typeof targetUserId !== "string" || !targetUserId.trim()) {
      return new Response(
        JSON.stringify({ message: "Missing or invalid target_user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error } = await adminClient.auth.admin.updateUserById(targetUserId.trim(), {
      email_confirm: true,
    });
    if (error) {
      return new Response(
        JSON.stringify({ message: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Internal server error";
    const status =
      msg.includes("Authorization") || msg.includes("JWT") || msg.includes("token") ? 401 : 500;
    return new Response(
      JSON.stringify({ message: msg }),
      { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
