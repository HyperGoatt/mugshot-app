import { drainAppleRevocations } from "./provider-worker.ts";
import { encryptProviderToken } from "./provider-crypto.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const secret = btoa("s".repeat(32));
const request = "10000000-0000-4000-8000-000000000001";
const config = {
  clientID: "com.example.synthetic",
  clientSecret: "synthetic-secret",
};
async function row() {
  return {
    request_id: request,
    client_id: config.clientID,
    ciphertext: await encryptProviderToken(
      "synthetic-refresh",
      secret,
      request,
      config.clientID,
    ),
    lease_token: "20000000-0000-4000-8000-000000000001",
  };
}
Deno.test("provider worker decrypts only the bound credential and acknowledges the lease", async () => {
  const credential = await row();
  let calls = 0;
  const result = await drainAppleRevocations(
    async (name, args) => {
      calls += 1;
      if (name === "claim_account_apple_revocations_v1") {
        assert(args.p_limit === 1, "bounded batch");
        return { data: [credential], error: null };
      }
      assert(
        name === "finish_account_apple_revocation_v1" &&
          args.p_request_id === request &&
          args.p_lease === credential.lease_token && args.p_revoked === true,
        "fenced success",
      );
      return { data: true, error: null };
    },
    config,
    secret,
    async (token, app) => {
      assert(
        token === "synthetic-refresh" && app.clientID === config.clientID,
        "bound token",
      );
    },
  );
  assert(
    calls === 2 && result.revoked === 1 && result.pending === 0,
    "acknowledged completion",
  );
  assert(
    !JSON.stringify(result).includes("synthetic"),
    "no credentials in result",
  );
});
Deno.test("provider worker preserves retries on provider failures and stale completion", async () => {
  for (
    const mode of ["provider_failure", "stale", "finish_failure", "wrong_app"]
  ) {
    const credential = await row();
    if (mode === "wrong_app") credential.client_id = "other-app";
    let providerCalls = 0;
    const result = await drainAppleRevocations(
      async (name, args) => {
        if (name === "claim_account_apple_revocations_v1") {
          return { data: [credential], error: null };
        }
        assert(
          args.p_revoked === (mode === "stale" || mode === "finish_failure"),
          "accurate outcome",
        );
        if (mode === "finish_failure") {
          throw new Error("private backend error");
        }
        return { data: mode !== "stale", error: null };
      },
      config,
      secret,
      async () => {
        providerCalls += 1;
        if (mode === "provider_failure") {
          throw new Error("private Apple response");
        }
      },
    );
    assert(
      result.revoked === 0 && result.pending === 1,
      "no premature completion",
    );
    assert(
      providerCalls === (mode === "wrong_app" ? 0 : 1),
      "wrong app never sent",
    );
  }
});
Deno.test("missing configuration still expires credentials without consuming retries", async () => {
  let calls = 0;
  const result = await drainAppleRevocations(
    async (name, args) => {
      calls += 1;
      assert(
        name === "claim_account_apple_revocations_v1" && args.p_limit === 0,
        "housekeeping only",
      );
      return { data: [], error: null };
    },
    config,
    "",
    async () => {
      throw new Error("must not send");
    },
  );
  assert(
    calls === 1 && !result.available && result.claimed === 0,
    "configuration unavailable",
  );
});
Deno.test("provider queue outage returns a sanitized status without failing data cleanup", async () => {
  for (const throws of [true, false]) {
    const result = await drainAppleRevocations(
      async () => {
        if (throws) throw new Error("sensitive backend body");
        return { data: null, error: "sensitive backend body" };
      },
      config,
      secret,
    );
    assert(!result.available && result.claimed === 0, "isolated queue failure");
    assert(!JSON.stringify(result).includes("sensitive"), "sanitized result");
  }
});
