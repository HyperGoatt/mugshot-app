import registry from "../_shared/mugsy-copy-v1.json" with { type: "json" };
import {
  type AdminClient,
  type APNSConfiguration,
  type APNSResult,
  type PushDelivery,
  sendAPNS,
} from "../deliver-activity/worker.ts";

export interface MugsyDeliveryRow {
  delivery_id: string;
  recipient_id: string;
  device_record_id: string;
  push_token: string;
  environment: "sandbox" | "production";
  kind: string;
  deep_link: string;
  expires_at: string;
  route_expires_at: string;
  claim_token: string;
  lease_version: number;
  attempt_count: number;
  used_template_ids: string[];
}

export function chooseMugsyCopy(row: MugsyDeliveryRow) {
  if (row.kind === "social_digest") {
    return {
      id: "social_digest_1",
      family: "social_digest",
      title: "A little company for your journal",
      body: "There are new moments from your people in Activity.",
      asset: undefined,
    };
  }
  const pool = registry.templates.filter((template) =>
    template.family === row.kind && !row.used_template_ids.includes(template.id)
  );
  if (pool.length === 0) return null;
  // Stable per occurrence, including a known-rejected request retried later.
  let hash = 2166136261;
  for (const character of row.delivery_id) {
    hash = Math.imul(hash ^ character.charCodeAt(0), 16777619) >>> 0;
  }
  return pool[hash % pool.length];
}

export async function runMugsyBatch(
  admin: AdminClient,
  configuration: APNSConfiguration,
  limit = 25,
  sender: typeof sendAPNS = sendAPNS,
) {
  const queued = await admin.rpc("enqueue_mugsy_opportunities_v1", {});
  if (queued.error) throw new Error("enqueue_unavailable");
  const claim = await admin.rpc("claim_mugsy_batch_v1", {
    p_limit: Math.min(Math.max(Math.trunc(limit), 1), 50),
  });
  if (claim.error) throw new Error("claim_unavailable");
  const rows = Array.isArray(claim.data)
    ? claim.data as MugsyDeliveryRow[]
    : [];
  let providerAccepted = 0,
    accepted = 0,
    unknown = 0,
    failed = 0,
    cancelled = 0,
    receiptFailures = 0;
  // Serial dispatch makes the circuit breaker and last-moment policy checks
  // observable between sends; each account already has a reserved budget slot.
  for (const row of rows) {
    const copy = chooseMugsyCopy(row);
    const check = await admin.rpc("revalidate_mugsy_delivery_v1", {
      p_delivery_id: row.delivery_id,
      p_claim_token: row.claim_token,
      p_lease_version: row.lease_version,
      p_template_id: copy?.id ?? null,
    });
    if (
      check.error ||
      (check.data as { eligible?: unknown } | null)?.eligible !== true || !copy
    ) {
      cancelled++;
      if (check.error) receiptFailures++;
      continue;
    }
    const push: PushDelivery = {
      ...row,
      activity_event_id: row.delivery_id,
      title: copy.title,
      body: copy.body,
      payload_kind: "mugsy",
      passive: true,
      asset_id: copy.asset,
      template_id: copy.id,
      collapse_id: `mugsy:${row.delivery_id}`,
      route_expires_at: row.route_expires_at,
    };
    let outcome: APNSResult;
    try {
      outcome = await sender(push, configuration);
    } catch {
      outcome = { outcome: "unknown", errorCode: "sender_interrupted" };
    }
    if (outcome.outcome === "succeeded") providerAccepted++;
    const receipt = await admin.rpc("complete_mugsy_delivery_v1", {
      p_delivery_id: row.delivery_id,
      p_claim_token: row.claim_token,
      p_lease_version: row.lease_version,
      p_outcome: outcome.outcome,
      p_error_code: outcome.errorCode ?? null,
      p_retry_after_seconds: outcome.retryAfterSeconds ?? null,
    });
    if (receipt.error || receipt.data !== true) {
      receiptFailures++;
      continue;
    }
    if (outcome.outcome === "succeeded") accepted++;
    else if (outcome.outcome === "unknown") unknown++;
    else failed++;
  }
  return {
    enqueued: queued.data ?? 0,
    claimed: rows.length,
    providerAccepted,
    accepted,
    unknown,
    failed,
    cancelled,
    receiptFailures,
  };
}
