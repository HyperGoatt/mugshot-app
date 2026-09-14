import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  type AdminClient,
  type APNSConfiguration,
  constantTimeEqual,
  type PushDelivery,
  sendAPNS,
} from "../deliver-activity/worker.ts";

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

function configuration(): APNSConfiguration | null {
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

interface ReflectionDeliveryRow {
  delivery_id: string;
  occurrence_id: string;
  recipient_id: string;
  device_record_id: string;
  push_token: string;
  environment: "sandbox" | "production";
  title: string;
  body: string;
  deep_link: string;
  reminder_kind: "on_this_day" | "weekly_reflection";
  attempt_count: number;
  claim_token: string;
  lease_version: number;
  collapse_id: string;
  expires_at: string;
}

async function complete(
  admin: AdminClient,
  delivery: ReflectionDeliveryRow,
  outcome: "succeeded" | "retryable" | "terminal" | "unregistered",
  errorCode?: string,
  retryAfterSeconds?: number,
): Promise<boolean> {
  const { data, error } = await admin.rpc(
    "complete_reflection_reminder_delivery_v1",
    {
      p_delivery_id: delivery.delivery_id,
      p_claim_token: delivery.claim_token,
      p_lease_version: delivery.lease_version,
      p_outcome: outcome,
      p_error_code: errorCode ?? null,
      p_retry_after_seconds: retryAfterSeconds ?? null,
    },
  );
  return !error && data === true;
}

Deno.serve(async (request) => {
  if (request.method === "GET") {
    const configured = configuration() !== null;
    return json({
      protocol: "mugshot-reflection-delivery",
      protocolVersion: 1,
      databaseSwitchRequired: true,
      pushDelivery: configured ? "configured" : "configuration_required",
    });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const adminKey = resolveAdminKey();
  const requestKey = Deno.env.get("ACTIVITY_DELIVERY_WORKER_SECRET") ??
    adminKey;
  const apns = configuration();
  if (!url || !adminKey || !requestKey || !apns) {
    return json({ error: "service_unavailable" }, 503);
  }
  const suppliedKey = request.headers.get("apikey");
  if (!suppliedKey || !constantTimeEqual(suppliedKey, requestKey)) {
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
  const limit = Math.min(
    Math.max(typeof body.limit === "number" ? Math.trunc(body.limit) : 25, 1),
    50,
  );
  const admin = createClient(url, adminKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  }) as unknown as AdminClient;

  const enqueued = await admin.rpc("enqueue_reflection_reminders_v1", {});
  if (enqueued.error) return json({ error: "enqueue_unavailable" }, 503);
  const claim = await admin.rpc("claim_reflection_reminder_batch_v1", {
    p_limit: limit,
  });
  if (claim.error) return json({ error: "claim_unavailable" }, 503);
  const rows = Array.isArray(claim.data)
    ? claim.data as ReflectionDeliveryRow[]
    : [];

  let sent = 0;
  let pendingOrFailed = 0;
  let cancelled = 0;
  let receiptFailures = 0;
  for (let index = 0; index < rows.length; index += 5) {
    const outcomes = await Promise.all(
      rows.slice(index, index + 5).map(async (delivery) => {
        const revalidation = await admin.rpc(
          "revalidate_reflection_reminder_delivery_v1",
          {
            p_delivery_id: delivery.delivery_id,
            p_claim_token: delivery.claim_token,
            p_lease_version: delivery.lease_version,
          },
        );
        const eligibility = revalidation.data as { eligible?: unknown } | null;
        if (revalidation.error || eligibility?.eligible !== true) {
          return {
            cancelled: true,
            sent: false,
            receiptFailed: Boolean(revalidation.error),
          };
        }
        const push: PushDelivery = {
          delivery_id: delivery.delivery_id,
          activity_event_id: delivery.occurrence_id,
          recipient_id: delivery.recipient_id,
          device_record_id: delivery.device_record_id,
          push_token: delivery.push_token,
          environment: delivery.environment,
          title: delivery.title,
          body: delivery.body,
          deep_link: delivery.deep_link,
          attempt_count: delivery.attempt_count,
          claim_token: delivery.claim_token,
          lease_version: delivery.lease_version,
          payload_kind: "reflection",
          reminder_kind: delivery.reminder_kind,
          collapse_id: delivery.collapse_id,
          expires_at: delivery.expires_at,
        };
        const result = await sendAPNS(push, apns);
        const receipt = await complete(
          admin,
          delivery,
          result.outcome,
          result.errorCode,
          result.retryAfterSeconds,
        );
        return {
          cancelled: false,
          sent: result.outcome === "succeeded" && receipt,
          receiptFailed: !receipt,
        };
      }),
    );
    for (const outcome of outcomes) {
      if (outcome.cancelled) cancelled += 1;
      else if (outcome.sent) sent += 1;
      else pendingOrFailed += 1;
      if (outcome.receiptFailed) receiptFailures += 1;
    }
  }
  return json({
    protocol: "mugshot-reflection-delivery",
    protocolVersion: 1,
    enqueued: enqueued.data ?? 0,
    claimed: rows.length,
    sent,
    pendingOrFailed,
    cancelled,
    receiptFailures,
  }, receiptFailures > 0 ? 202 : 200);
});
