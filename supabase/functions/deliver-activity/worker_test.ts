import {
  type AdminClient,
  type APNSConfiguration,
  classifyAPNSFailure,
  fetchResponseWithTimeout,
  parseRetryAfter,
  processDeliveries,
  type PushDelivery,
  resolveAPNSTarget,
} from "./worker.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("APNs responses separate disable, terminal, and retryable outcomes", () => {
  assert(
    classifyAPNSFailure(410, "Unregistered").outcome === "unregistered",
    "Unregistered must disable",
  );
  assert(
    classifyAPNSFailure(413, "PayloadTooLarge").outcome === "terminal",
    "payload must be terminal",
  );
  assert(
    classifyAPNSFailure(403, "InvalidProviderToken").outcome === "terminal",
    "configuration must be terminal",
  );
  assert(
    classifyAPNSFailure(400, "BadDeviceToken").outcome === "terminal",
    "bad token must not be retried or disabled",
  );
  assert(
    (classifyAPNSFailure(429, "TooManyRequests").retryAfterSeconds ?? 0) >= 60,
    "429 needs delay",
  );
  assert(
    (classifyAPNSFailure(503, "ServiceUnavailable").retryAfterSeconds ?? 0) >=
      900,
    "5xx needs durable delay",
  );
});

Deno.test("Retry-After accepts seconds and bounded HTTP dates", () => {
  assert(parseRetryAfter("12") === 12, "seconds were not parsed");
  const now = Date.UTC(2026, 6, 22, 12, 0, 0);
  assert(
    parseRetryAfter(new Date(now + 30_000).toUTCString(), now) === 30,
    "date was not parsed",
  );
  assert(parseRetryAfter("999999") === 86_400, "retry delay was not capped");
});

Deno.test("sandbox Debug and production Release use their own APNs topic", () => {
  const configuration: APNSConfiguration = {
    keyID: "key",
    teamID: "team",
    topics: {
      sandbox: "co.mugshot.app.dev",
      production: "co.mugshot.app",
    },
    privateKeyPEM: "unused",
  };
  const sandbox = resolveAPNSTarget(
    { environment: "sandbox" },
    configuration,
  );
  const production = resolveAPNSTarget(
    { environment: "production" },
    configuration,
  );
  assert(
    sandbox.host === "https://api.sandbox.push.apple.com" &&
      sandbox.topic === "co.mugshot.app.dev",
    "physical Debug did not use the sandbox App ID",
  );
  assert(
    production.host === "https://api.push.apple.com" &&
      production.topic === "co.mugshot.app",
    "Release did not use the production App ID",
  );
});

Deno.test("APNs transport is aborted at the configured bound", async () => {
  const fetcher = (
    _input: string | URL | Request,
    init?: RequestInit,
  ): Promise<Response> =>
    new Promise((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () =>
        reject(new DOMException("aborted", "AbortError")));
    });
  let timedOut = false;
  try {
    await fetchResponseWithTimeout(fetcher, "https://example.invalid", {}, 5);
  } catch (error) {
    timedOut = error instanceof DOMException && error.name === "AbortError";
  }
  assert(timedOut, "transport did not abort");
});

Deno.test("a false fenced completion is counted as a receipt failure", async () => {
  const delivery: PushDelivery = {
    delivery_id: "10000000-0000-4000-8000-000000000001",
    activity_event_id: "20000000-0000-4000-8000-000000000001",
    recipient_id: "25000000-0000-4000-8000-000000000001",
    device_record_id: "30000000-0000-4000-8000-000000000001",
    push_token: "a".repeat(64),
    environment: "sandbox",
    title: "Title",
    body: "Body",
    deep_link: "mugshot://activity",
    attempt_count: 1,
    claim_token: "40000000-0000-4000-8000-000000000001",
    lease_version: 7,
  };
  let completionParams: Record<string, unknown> | undefined;
  const admin: AdminClient = {
    rpc(name, params) {
      if (name === "revalidate_activity_push_delivery_v2") {
        return Promise.resolve({ data: true, error: null });
      }
      completionParams = params;
      return Promise.resolve({ data: false, error: null });
    },
  };
  const configuration: APNSConfiguration = {
    keyID: "key",
    teamID: "team",
    topics: {
      sandbox: "co.mugshot.app.dev",
      production: "co.mugshot.app",
    },
    privateKeyPEM: "unused",
  };
  const result = await processDeliveries(
    admin,
    [delivery],
    configuration,
    async () => ({ outcome: "succeeded" }),
  );
  assert(
    result.sent === 0 && result.pendingOrFailed === 1,
    "false receipt was reported sent",
  );
  assert(result.receiptFailures === 1, "false receipt was not counted");
  assert(
    completionParams?.p_claim_token === delivery.claim_token,
    "claim token was omitted",
  );
  assert(completionParams?.p_lease_version === 7, "lease version was omitted");
});

Deno.test("recipient eligibility is revalidated immediately before APNs", async () => {
  const delivery: PushDelivery = {
    delivery_id: "10000000-0000-4000-8000-000000000002",
    activity_event_id: "20000000-0000-4000-8000-000000000002",
    recipient_id: "25000000-0000-4000-8000-000000000002",
    device_record_id: "30000000-0000-4000-8000-000000000002",
    push_token: "b".repeat(64),
    environment: "sandbox",
    title: "Title",
    body: "Body",
    deep_link: "mugshot://activity",
    attempt_count: 1,
    claim_token: "40000000-0000-4000-8000-000000000002",
    lease_version: 1,
  };
  const rpcNames: string[] = [];
  const admin: AdminClient = {
    rpc(name) {
      rpcNames.push(name);
      return Promise.resolve({ data: false, error: null });
    },
  };
  const configuration: APNSConfiguration = {
    keyID: "key",
    teamID: "team",
    topics: {
      sandbox: "co.mugshot.app.dev",
      production: "co.mugshot.app",
    },
    privateKeyPEM: "unused",
  };
  let sendCount = 0;
  const result = await processDeliveries(
    admin,
    [delivery],
    configuration,
    async () => {
      sendCount += 1;
      return { outcome: "succeeded" };
    },
  );
  assert(sendCount === 0, "APNs began after eligibility was revoked");
  assert(
    rpcNames.length === 1 &&
      rpcNames[0] === "revalidate_activity_push_delivery_v2",
    "the worker did not stop at the final eligibility check",
  );
  assert(result.cancelledBeforeSend === 1, "cancellation was not reported");
  assert(result.receiptFailures === 0, "a clean cancellation became an error");
});
