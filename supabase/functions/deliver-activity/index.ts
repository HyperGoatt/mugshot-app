import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  type AdminClient,
  type APNSConfiguration,
  constantTimeEqual,
  processDeliveries,
  type PushDelivery,
} from "./worker.ts";

const protocol = "mugshot-activity-delivery";
const protocolVersion = 3;
const deliveryAction = "deliver_v3";
const compatibleDeliveryActions = new Set(["deliver_v2", deliveryAction]);

const jsonHeaders = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function resolveAdminKey(): string | null {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const keys = JSON.parse(modern) as Record<string, string>;
      const preferred = keys["activity-delivery"] ?? keys.default;
      if (typeof preferred === "string" && preferred.length > 0) {
        return preferred;
      }
      const first = Object.values(keys).find((value) =>
        typeof value === "string" && value.length > 0
      );
      if (first) return first;
    } catch {
      return null;
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

function resolveRequestKey(adminKey: string | null): string | null {
  return Deno.env.get("ACTIVITY_DELIVERY_WORKER_SECRET") ?? adminKey;
}

function apnsConfiguration(): APNSConfiguration | null {
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const sandboxTopic = Deno.env.get("APNS_SANDBOX_TOPIC");
  const productionTopic = Deno.env.get("APNS_PRODUCTION_TOPIC");
  const privateKeyPEM = Deno.env.get("APNS_PRIVATE_KEY");
  if (
    !keyID || !teamID || !sandboxTopic || !productionTopic || !privateKeyPEM
  ) return null;
  return {
    keyID,
    teamID,
    topics: { sandbox: sandboxTopic, production: productionTopic },
    privateKeyPEM,
  };
}

Deno.serve(async (request) => {
  if (request.method === "GET") {
    const configured = apnsConfiguration() !== null;
    return json({
      protocol,
      protocolVersion,
      action: deliveryAction,
      inAppActivity: "available",
      pushDelivery: configured ? "configured" : "configuration_required",
      requiredSecrets: configured ? [] : [
        "APNS_KEY_ID",
        "APNS_TEAM_ID",
        "APNS_SANDBOX_TOPIC",
        "APNS_PRODUCTION_TOPIC",
        "APNS_PRIVATE_KEY",
      ],
    });
  }

  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const adminKey = resolveAdminKey();
  const requestKey = resolveRequestKey(adminKey);
  const suppliedKey = request.headers.get("apikey");
  const configuration = apnsConfiguration();
  if (!url || !adminKey || !requestKey) {
    return json({ error: "service_unavailable" }, 503);
  }
  if (!suppliedKey || !constantTimeEqual(suppliedKey, requestKey)) {
    return json({ error: "unauthorized" }, 401);
  }
  if (!configuration) {
    return json({
      error: "push_configuration_required",
      inAppActivity: "available",
    }, 503);
  }

  let body: { action?: unknown; limit?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
  if (
    typeof body.action !== "string" ||
    !compatibleDeliveryActions.has(body.action)
  ) {
    return json({ error: "unsupported_action" }, 400);
  }
  const requestedLimit =
    typeof body.limit === "number" && Number.isFinite(body.limit)
      ? Math.trunc(body.limit)
      : 25;
  const limit = Math.min(Math.max(requestedLimit, 1), 50);

  const admin = createClient(url, adminKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  }) as unknown as AdminClient;
  const { data, error } = await admin.rpc("claim_activity_push_batch_v2", {
    p_limit: limit,
  });
  if (error) {
    console.error("activity delivery claim failed");
    return json({ error: "delivery_unavailable" }, 503);
  }

  const deliveries = Array.isArray(data) ? data as PushDelivery[] : [];
  const result = await processDeliveries(admin, deliveries, configuration);
  return json({
    protocol,
    protocolVersion,
    claimed: deliveries.length,
    ...result,
    inAppActivity: "available",
  }, result.receiptFailures > 0 ? 202 : 200);
});
