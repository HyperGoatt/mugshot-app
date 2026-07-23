export type DeliveryOutcome =
  | "succeeded"
  | "retryable"
  | "terminal"
  | "unregistered";

export interface PushDelivery {
  delivery_id: string;
  activity_event_id: string;
  recipient_id: string;
  device_record_id: string;
  push_token: string;
  environment: "sandbox" | "production";
  title: string;
  body: string;
  deep_link: string;
  attempt_count: number;
  claim_token: string;
  lease_version: number;
}

export interface APNSConfiguration {
  keyID: string;
  teamID: string;
  topics: {
    sandbox: string;
    production: string;
  };
  privateKeyPEM: string;
}

export interface APNSTarget {
  host: string;
  topic: string;
}

export interface APNSResult {
  outcome: DeliveryOutcome;
  errorCode?: string;
  retryAfterSeconds?: number;
}

interface AdminRPCResult {
  data: unknown;
  error: unknown;
}

export interface AdminClient {
  rpc(
    functionName: string,
    params?: Record<string, unknown>,
  ): PromiseLike<AdminRPCResult>;
}

export type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

let cachedProviderToken: { value: string; expiresAt: number } | null = null;

export function constantTimeEqual(lhs: string, rhs: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(lhs);
  const right = encoder.encode(rhs);
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }
  return difference === 0;
}

function base64URL(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

function base64URLText(value: string): string {
  return base64URL(new TextEncoder().encode(value));
}

function decodePEM(value: string): ArrayBuffer {
  const payload = value
    .replace(/-----BEGIN PRIVATE KEY-----/gu, "")
    .replace(/-----END PRIVATE KEY-----/gu, "")
    .replace(/\s/gu, "");
  const binary = atob(payload);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function providerToken(
  configuration: APNSConfiguration,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedProviderToken && cachedProviderToken.expiresAt > now + 60) {
    return cachedProviderToken.value;
  }

  const header = base64URLText(JSON.stringify({
    alg: "ES256",
    kid: configuration.keyID,
  }));
  const payload = base64URLText(JSON.stringify({
    iss: configuration.teamID,
    iat: now,
  }));
  const signingInput = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    decodePEM(configuration.privateKeyPEM),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const value = `${signingInput}.${base64URL(new Uint8Array(signature))}`;
  cachedProviderToken = { value, expiresAt: now + 50 * 60 };
  return value;
}

function stableErrorCode(value: unknown, fallback: string): string {
  const candidate = typeof value === "string"
    ? value
    : value instanceof Error
    ? value.name
    : fallback;
  const normalized = candidate
    .toLowerCase()
    .replace(/[^a-z0-9_-]/gu, "_")
    .slice(0, 80);
  return normalized.length > 0 ? normalized : fallback;
}

export function parseRetryAfter(
  value: string | null,
  nowMilliseconds = Date.now(),
): number | undefined {
  if (!value) return undefined;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.min(Math.ceil(seconds), 86_400);
  }
  const date = Date.parse(value);
  if (Number.isNaN(date)) return undefined;
  return Math.min(
    Math.max(Math.ceil((date - nowMilliseconds) / 1000), 0),
    86_400,
  );
}

export function classifyAPNSFailure(
  status: number,
  reason: string,
  retryAfterHeader: string | null = null,
): APNSResult {
  const errorCode = stableErrorCode(reason, `apns_${status}`);
  if (status === 410 || reason === "Unregistered") {
    return { outcome: "unregistered", errorCode };
  }

  const suppliedDelay = parseRetryAfter(retryAfterHeader) ?? 0;
  if (
    status === 429 ||
    ["TooManyRequests", "TooManyProviderTokenUpdates"].includes(reason)
  ) {
    return {
      outcome: "retryable",
      errorCode,
      retryAfterSeconds: Math.max(suppliedDelay, 60),
    };
  }
  if (status >= 500 && status <= 599) {
    return {
      outcome: "retryable",
      errorCode,
      retryAfterSeconds: Math.max(suppliedDelay, 15 * 60),
    };
  }

  // Payload, provider configuration, malformed-token, and other 4xx failures
  // are terminal for this delivery. Only Unregistered disables the device;
  // configuration mistakes must not destroy an otherwise valid binding.
  return { outcome: "terminal", errorCode };
}

/// APNs environment and app topic are separate routing dimensions. Mugshot's
/// physical Debug build uses the sandbox host with the `.dev` App ID, while a
/// distributed build uses the production host with the release App ID.
export function resolveAPNSTarget(
  delivery: Pick<PushDelivery, "environment">,
  configuration: APNSConfiguration,
): APNSTarget {
  return delivery.environment === "sandbox"
    ? {
      host: "https://api.sandbox.push.apple.com",
      topic: configuration.topics.sandbox,
    }
    : {
      host: "https://api.push.apple.com",
      topic: configuration.topics.production,
    };
}

export async function fetchResponseWithTimeout(
  fetcher: Fetcher,
  input: string | URL | Request,
  init: RequestInit,
  timeoutMilliseconds: number,
): Promise<{ response: Response; bodyText: string }> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMilliseconds);
  try {
    const response = await fetcher(input, {
      ...init,
      signal: controller.signal,
    });
    const bodyText = await response.text();
    return { response, bodyText };
  } finally {
    clearTimeout(timeout);
  }
}

export async function sendAPNS(
  delivery: PushDelivery,
  configuration: APNSConfiguration,
  fetcher: Fetcher = fetch,
): Promise<APNSResult> {
  let token: string;
  try {
    token = await providerToken(configuration);
  } catch {
    return {
      outcome: "terminal",
      errorCode: "apns_configuration_failed",
    };
  }

  const target = resolveAPNSTarget(delivery, configuration);
  try {
    const { response, bodyText } = await fetchResponseWithTimeout(
      fetcher,
      `${target.host}/3/device/${encodeURIComponent(delivery.push_token)}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${token}`,
          "apns-topic": target.topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "apns-id": delivery.delivery_id,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          aps: {
            alert: { title: delivery.title, body: delivery.body },
            sound: "default",
          },
          mugshot: {
            activity_event_id: delivery.activity_event_id,
            recipient_id: delivery.recipient_id,
            deep_link: delivery.deep_link,
          },
        }),
      },
      10_000,
    );

    if (response.ok) return { outcome: "succeeded" };
    let reason = `apns_${response.status}`;
    try {
      const parsed = JSON.parse(bodyText) as { reason?: unknown };
      if (typeof parsed.reason === "string") reason = parsed.reason;
    } catch {
      // The HTTP status remains a safe classification if APNs omits JSON.
    }
    return classifyAPNSFailure(
      response.status,
      reason,
      response.headers.get("retry-after"),
    );
  } catch (error) {
    return {
      outcome: "retryable",
      errorCode: error instanceof DOMException && error.name === "AbortError"
        ? "apns_timeout"
        : stableErrorCode(error, "apns_transport_failed"),
    };
  }
}

async function complete(
  admin: AdminClient,
  delivery: PushDelivery,
  result: APNSResult,
): Promise<void> {
  const { data, error } = await admin.rpc(
    "complete_activity_push_delivery_v2",
    {
      p_delivery_id: delivery.delivery_id,
      p_claim_token: delivery.claim_token,
      p_lease_version: delivery.lease_version,
      p_outcome: result.outcome,
      p_error_code: result.errorCode ?? null,
      p_retry_after_seconds: result.retryAfterSeconds ?? null,
    },
  );
  if (error) throw error;
  if (data !== true) throw new Error("stale_or_missing_delivery_lease");
}

async function revalidateImmediatelyBeforeSend(
  admin: AdminClient,
  delivery: PushDelivery,
): Promise<"eligible" | "cancelled" | "unavailable"> {
  const { data, error } = await admin.rpc(
    "revalidate_activity_push_delivery_v2",
    {
      p_delivery_id: delivery.delivery_id,
      p_claim_token: delivery.claim_token,
      p_lease_version: delivery.lease_version,
    },
  );
  if (error) return "unavailable";
  return data === true ? "eligible" : "cancelled";
}

export async function processDeliveries(
  admin: AdminClient,
  deliveries: PushDelivery[],
  configuration: APNSConfiguration,
  sender: typeof sendAPNS = sendAPNS,
): Promise<{
  sent: number;
  pendingOrFailed: number;
  receiptFailures: number;
  cancelledBeforeSend: number;
}> {
  let sent = 0;
  let pendingOrFailed = 0;
  let receiptFailures = 0;
  let cancelledBeforeSend = 0;

  for (let index = 0; index < deliveries.length; index += 5) {
    const batch = deliveries.slice(index, index + 5);
    const results = await Promise.all(batch.map(async (delivery) => {
      const eligibility = await revalidateImmediatelyBeforeSend(
        admin,
        delivery,
      );
      if (eligibility !== "eligible") {
        return {
          result: { outcome: "terminal" as const },
          receiptFailed: eligibility === "unavailable",
          cancelledBeforeSend: eligibility === "cancelled",
        };
      }
      const result = await sender(delivery, configuration);
      try {
        await complete(admin, delivery, result);
        return { result, receiptFailed: false, cancelledBeforeSend: false };
      } catch {
        console.error("activity delivery receipt failed", {
          deliveryID: delivery.delivery_id,
        });
        return { result, receiptFailed: true, cancelledBeforeSend: false };
      }
    }));

    for (const settled of results) {
      if (settled.result.outcome === "succeeded" && !settled.receiptFailed) {
        sent += 1;
      } else {
        pendingOrFailed += 1;
      }
      if (settled.receiptFailed) receiptFailures += 1;
      if (settled.cancelledBeforeSend) cancelledBeforeSend += 1;
    }
  }
  return { sent, pendingOrFailed, receiptFailures, cancelledBeforeSend };
}
