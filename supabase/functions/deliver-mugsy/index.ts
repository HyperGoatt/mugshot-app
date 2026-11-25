import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  type AdminClient,
  type APNSConfiguration,
  constantTimeEqual,
} from "../deliver-activity/worker.ts";
import { runMugsyBatch } from "./worker.ts";

const protocol = "mugshot-mugsy-delivery";
const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
function adminKey(): string | null {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const keys = JSON.parse(modern) as Record<string, unknown>;
      const key = keys["activity-delivery"] ?? keys.default;
      return typeof key === "string" && key.length > 0 ? key : null;
    } catch {
      return null;
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}
function apnsConfiguration(): APNSConfiguration | null {
  const keyID = Deno.env.get("APNS_KEY_ID"),
    teamID = Deno.env.get("APNS_TEAM_ID"),
    privateKeyPEM = Deno.env.get("APNS_PRIVATE_KEY");
  const sandbox = Deno.env.get("APNS_SANDBOX_TOPIC"),
    production = Deno.env.get("APNS_PRODUCTION_TOPIC");
  return keyID && teamID && privateKeyPEM && sandbox && production
    ? { keyID, teamID, privateKeyPEM, topics: { sandbox, production } }
    : null;
}
Deno.serve(async (request) => {
  if (request.method === "GET") {
    return json({
      protocol,
      protocolVersion: 1,
      databaseSwitchRequired: true,
      defaultMode: "off",
      shadowDaysRequired: 7,
    });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const url = Deno.env.get("SUPABASE_URL"), key = adminKey();
  const secret = Deno.env.get("ACTIVITY_DELIVERY_WORKER_SECRET") ?? key;
  if (!url || !key || !secret) {
    return json({ error: "service_unavailable" }, 503);
  }
  const supplied = request.headers.get("apikey");
  if (!supplied || !constantTimeEqual(supplied, secret)) {
    return json({ error: "unauthorized" }, 401);
  }
  let body: { action?: unknown; limit?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
  if (body.action !== "deliver_v1") {
    return json({ error: "unsupported_action" }, 400);
  }
  const admin = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  }) as unknown as AdminClient;
  const apns = apnsConfiguration();
  // Shadow evaluation does not need an APNs key. A separate claim still cannot
  // deliver unless its private database release gate is explicitly enabled.
  if (!apns) {
    const enqueue = await admin.rpc("enqueue_mugsy_opportunities_v1", {});
    const report = await admin.rpc("mugsy_operator_report_v1", {});
    const mode = (report.data as { mode?: string } | null)?.mode;
    if (enqueue.error || report.error || mode !== "shadow" && mode !== "off") {
      return json({ error: "configuration_required" }, 503);
    }
    const claims = await admin.rpc("claim_mugsy_batch_v1", { p_limit: 50 });
    if (claims.error) return json({ error: "shadow_unavailable" }, 503);
    return json({
      protocol,
      protocolVersion: 1,
      mode,
      enqueued: enqueue.data ?? 0,
      sent: 0,
    });
  }
  try {
    const result = await runMugsyBatch(
      admin,
      apns,
      typeof body.limit === "number" ? body.limit : 25,
    );
    return json(
      { protocol, protocolVersion: 1, ...result },
      result.receiptFailures > 0 ? 202 : 200,
    );
  } catch {
    return json({ error: "delivery_unavailable" }, 503);
  }
});
