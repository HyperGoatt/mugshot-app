import {
  type AdminClient,
  type APNSConfiguration,
  buildAPNSPayload,
  buildAPNSRequestHeaders,
  type PushDelivery,
} from "../deliver-activity/worker.ts";
import {
  chooseMugsyCopy,
  type MugsyDeliveryRow,
  runMugsyBatch,
} from "./worker.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const row: MugsyDeliveryRow = {
  delivery_id: "10000000-0000-4000-8000-000000000001",
  recipient_id: "20000000-0000-4000-8000-000000000001",
  device_record_id: "30000000-0000-4000-8000-000000000001",
  push_token: "a".repeat(64),
  environment: "sandbox",
  kind: "second_memory",
  deep_link: "mugshot://mugsy/log",
  expires_at: "2026-11-25T14:00:00Z",
  route_expires_at: "2027-02-23T14:00:00Z",
  claim_token: "40000000-0000-4000-8000-000000000001",
  lease_version: 1,
  attempt_count: 1,
  used_template_ids: [],
};
const configuration: APNSConfiguration = {
  keyID: "key",
  teamID: "team",
  privateKeyPEM: "unused",
  topics: { sandbox: "co.mugshot.app.dev", production: "co.mugshot.app" },
};
function admin(revalidate: boolean, receipt = true) {
  const calls: { name: string; params?: Record<string, unknown> }[] = [];
  const client: AdminClient = {
    rpc(name, params) {
      calls.push({ name, params });
      return Promise.resolve({
        error: null,
        data: name === "claim_mugsy_batch_v1"
          ? [row]
          : name === "revalidate_mugsy_delivery_v1"
          ? { eligible: revalidate }
          : name === "complete_mugsy_delivery_v1"
          ? receipt
          : 1,
      });
    },
  };
  return { client, calls };
}
Deno.test("copy is reviewed, deterministic and skips exhausted 28-day pool", () => {
  const first = chooseMugsyCopy(row);
  assert(first?.family === "second_memory", "wrong family");
  assert(chooseMugsyCopy(row)?.id === first.id, "retry changed copy");
  assert(
    chooseMugsyCopy({
      ...row,
      used_template_ids: [
        "second_memory_1",
        "second_memory_2",
        "second_memory_3",
        "second_memory_4",
      ],
    }) === null,
    "exhausted family reused",
  );
  assert(
    chooseMugsyCopy({ ...row, kind: "unsupported" }) === null,
    "unknown family invented",
  );
});
Deno.test("optional APNs payload stays passive with distinct delivery and route expirations", () => {
  const delivery: PushDelivery = {
    ...row,
    activity_event_id: row.delivery_id,
    title: "A tiny memory",
    body: "A moment worth keeping.",
    payload_kind: "mugsy",
    passive: true,
    asset_id: "MugsyPoseJournal",
    template_id: "second_memory_1",
  };
  const payload = buildAPNSPayload(delivery);
  const aps = payload.aps as Record<string, unknown>;
  assert(
    aps.sound === undefined && aps.badge === undefined,
    "optional push manufactured sound/badge",
  );
  assert(
    aps["interruption-level"] === "passive" && aps["mutable-content"] === 1,
    "rich passive settings missing",
  );
  assert(
    (payload.mugshot_mugsy as Record<string, unknown>).expires_at ===
      row.route_expires_at,
    "late tap lost route",
  );
  const headers = buildAPNSRequestHeaders(delivery, {
    host: "https://api.sandbox.push.apple.com",
    topic: "co.mugshot.app.dev",
  }, "fixture");
  assert(
    headers["apns-priority"] === "5",
    "optional push used immediate priority",
  );
  assert(
    headers["apns-expiration"] === String(Date.parse(row.expires_at) / 1000),
    "delivery TTL replaced by route retention",
  );
});
Deno.test("final consent cancellation prevents APNs dispatch", async () => {
  const mock = admin(false);
  let sends = 0;
  const result = await runMugsyBatch(
    mock.client,
    configuration,
    25,
    async () => {
      sends++;
      return { outcome: "succeeded" };
    },
  );
  assert(
    sends === 0 && result.cancelled === 1,
    "cancelled opportunity crossed APNs",
  );
  assert(
    !mock.calls.some((c) => c.name === "complete_mugsy_delivery_v1"),
    "cancelled claim was acknowledged incorrectly",
  );
});
Deno.test("transport ambiguity consumes existing reservation without retry in worker", async () => {
  const mock = admin(true);
  let sends = 0;
  const result = await runMugsyBatch(mock.client, configuration, 25, () => {
    sends++;
    throw new Error("lost response");
  });
  assert(sends === 1 && result.unknown === 1, "ambiguous request retried");
  const receipt = mock.calls.find((c) =>
    c.name === "complete_mugsy_delivery_v1"
  );
  assert(
    receipt?.params?.p_outcome === "unknown",
    "uncertainty became retryable",
  );
  assert(
    receipt.params.p_claim_token === row.claim_token &&
      receipt.params.p_lease_version === row.lease_version,
    "receipt lost fencing",
  );
});
Deno.test("APNs acceptance and database receipt failure remain distinct", async () => {
  const mock = admin(true, false);
  const result = await runMugsyBatch(
    mock.client,
    configuration,
    25,
    async () => ({ outcome: "succeeded" }),
  );
  assert(
    result.providerAccepted === 1 && result.accepted === 0 &&
      result.receiptFailures === 1,
    "missing receipt reported as full success",
  );
});
Deno.test("no eligible copy quietly cancels before send", async () => {
  const calls: string[] = [];
  const client: AdminClient = {
    rpc(name) {
      calls.push(name);
      return Promise.resolve({
        error: null,
        data: name === "claim_mugsy_batch_v1"
          ? [{
            ...row,
            used_template_ids: [
              "second_memory_1",
              "second_memory_2",
              "second_memory_3",
              "second_memory_4",
            ],
          }]
          : { eligible: false },
      });
    },
  };
  let sent = false;
  const result = await runMugsyBatch(client, configuration, 25, async () => {
    sent = true;
    return { outcome: "succeeded" };
  });
  assert(
    !sent && result.cancelled === 1 &&
      calls.includes("revalidate_mugsy_delivery_v1"),
    "exhausted copy bypassed fenced cancellation",
  );
});

Deno.test("real APNs transport classifies optional timeout as unknown while retaining legacy retry contract", async () => {
  const keyPair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const keyData = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", keyPair.privateKey),
  );
  let keyText = "";
  for (const byte of keyData) keyText += String.fromCharCode(byte);
  const config = {
    ...configuration,
    privateKeyPEM: `-----BEGIN PRIVATE KEY-----\n${
      btoa(keyText)
    }\n-----END PRIVATE KEY-----`,
  };
  const { sendAPNS } = await import("../deliver-activity/worker.ts");
  const delivery: PushDelivery = {
    ...row,
    activity_event_id: row.delivery_id,
    title: "A memory",
    body: "Worth keeping.",
    payload_kind: "mugsy",
    passive: true,
  };
  const fakeTransport = () => {
    throw new DOMException("timeout", "AbortError");
  };
  const optional = await sendAPNS(delivery, config, fakeTransport);
  const legacy = await sendAPNS(
    { ...delivery, payload_kind: "activity" },
    config,
    fakeTransport,
  );
  assert(
    optional.outcome === "unknown" && optional.errorCode === "apns_timeout",
    "optional uncertainty became a retry",
  );
  assert(
    legacy.outcome === "retryable",
    "existing Activity transport contract changed",
  );
});
