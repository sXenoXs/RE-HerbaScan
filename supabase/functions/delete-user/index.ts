// Supabase Edge Function: delete-user
// (1) Self-delete: authenticated user deletes their own account (no body).
// (2) Admin delete: body { "user_id": "<uuid>" }; caller must be admin. Client must delete storage first.
// Uses JWKS to verify JWT (supports Supabase's asymmetric ES256 signing). Then uses service role to delete.

import * as jose from "jsr:@panva/jose@6";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Allowed origins: Vercel admin portal + localhost for local dev.
// Set ALLOWED_ORIGIN env variable in Supabase to override (e.g. custom domain).
const ALLOWED_ORIGIN =
  Deno.env.get("ALLOWED_ORIGIN") ??
  "https://herbascan-admin.vercel.app";

function buildCorsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  const allowedOrigins = [ALLOWED_ORIGIN, "http://localhost:8080", "http://localhost:3000"];
  const responseOrigin = allowedOrigins.includes(origin) ? origin : ALLOWED_ORIGIN;
  return {
    "Access-Control-Allow-Origin": responseOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

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
  const corsHeaders = buildCorsHeaders(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const token = getAuthToken(req);
    const callerUserId = await verifyJwtAndGetSub(token);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    let targetUserId: string;

    const contentType = req.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      try {
        const body = (await req.json()) as { user_id?: string };
        if (body?.user_id && typeof body.user_id === "string") {
          // Admin delete: verify caller is admin
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
          targetUserId = body.user_id;
        } else {
          targetUserId = callerUserId;
        }
      } catch {
        targetUserId = callerUserId;
      }
    } else {
      targetUserId = callerUserId;
    }

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(targetUserId);
    if (deleteError) {
      return new Response(
        JSON.stringify({ message: deleteError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    const corsHeaders = buildCorsHeaders(req);
    const msg = e instanceof Error ? e.message : "Internal server error";
    const status = msg.includes("Authorization") || msg.includes("JWT") || msg.includes("token") ? 401 : 500;
    return new Response(
      JSON.stringify({ message: msg }),
      { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
