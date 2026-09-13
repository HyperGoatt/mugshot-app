import {
  AppleRevocationError,
  exchangeAppleDeletionCode,
  revokeAppleDeletionToken,
} from "./apple.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const config = {
  clientID: "com.example.synthetic",
  clientSecret: "synthetic-client-secret",
};
const pair = await crypto.subtle.generateKey(
  {
    name: "RSASSA-PKCS1-v1_5",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256",
  },
  true,
  ["sign", "verify"],
);
const jwk = {
  ...await crypto.subtle.exportKey("jwk", pair.publicKey),
  kid: "synthetic-key",
};
const base64 = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-")
    .replace(/\//g, "_");
const encode = (value: unknown) =>
  base64(new TextEncoder().encode(JSON.stringify(value)));
async function token(overrides: Record<string, unknown> = {}) {
  const message = encode({ alg: "RS256", kid: jwk.kid }) + "." +
    encode({
      iss: "https://appleid.apple.com",
      aud: config.clientID,
      sub: "synthetic-owner",
      iat: 1000,
      exp: 2000,
      ...overrides,
    });
  return message + "." +
    base64(
      new Uint8Array(
        await crypto.subtle.sign(
          "RSASSA-PKCS1-v1_5",
          pair.privateKey,
          new TextEncoder().encode(message),
        ),
      ),
    );
}
function fake(identity: string) {
  const calls: string[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const url = String(input);
    calls.push(url);
    assert(
      init?.redirect === "error",
      "redirects cannot move credentials to another host",
    );
    if (url.endsWith("/keys")) return Response.json({ keys: [jwk] });
    assert(
      url === "https://appleid.apple.com/auth/token",
      "only the fixed Apple token endpoint",
    );
    const body = new URLSearchParams(String(init?.body));
    assert(
      body.get("code") === "synthetic-code" &&
        body.get("client_id") === config.clientID &&
        body.get("grant_type") === "authorization_code",
      "bounded code exchange",
    );
    return Response.json({
      id_token: identity,
      refresh_token: "synthetic-refresh",
    });
  };
  return { fetcher, calls };
}
Deno.test("Apple exchange verifies signature, audience and subject before returning a revocation token", async () => {
  const f = fake(await token());
  assert(
    await exchangeAppleDeletionCode(
      "synthetic-code",
      "synthetic-owner",
      config,
      f.fetcher,
      1500,
    ) === "synthetic-refresh",
    "verified refresh token",
  );
  assert(
    f.calls.length === 2 && f.calls[0].endsWith("/keys"),
    "keys fetched before consuming the code",
  );
});
Deno.test("Apple exchange rejects another identity, audience, issuer, expired or forged tokens", async () => {
  const invalid = [
    await token({ sub: "other-owner" }),
    await token({ aud: "other-app" }),
    await token({ iss: "https://foreign.invalid" }),
    await token({ exp: 1400 }),
    (await token()).slice(0, -10) + "AAAAAAAAAA",
  ];
  for (const identity of invalid) {
    try {
      await exchangeAppleDeletionCode(
        "synthetic-code",
        "synthetic-owner",
        config,
        fake(identity).fetcher,
        1500,
      );
      throw new Error("accepted invalid token");
    } catch (error) {
      assert(
        error instanceof AppleRevocationError &&
          error.code === "identity_mismatch",
        "reject wrong identity without exposing credentials",
      );
    }
  }
});
Deno.test("Apple key failure leaves the one-use authorization code unconsumed", async () => {
  const urls: string[] = [];
  const fetcher: typeof fetch = async (input) => {
    urls.push(String(input));
    return new Response("synthetic private body", { status: 503 });
  };
  try {
    await exchangeAppleDeletionCode(
      "synthetic-code",
      "synthetic-owner",
      config,
      fetcher,
      1500,
    );
    throw new Error("unexpected success");
  } catch (error) {
    assert(
      error instanceof AppleRevocationError && error.code === "unavailable",
      "retryable sanitized error",
    );
  }
  assert(
    urls.length === 1 && urls[0].endsWith("/keys"),
    "no exchange after key failure",
  );
});
Deno.test("Apple revocation is bounded to the token endpoint and errors never expose bodies", async () => {
  let count = 0;
  const fetcher: typeof fetch = async (input, init) => {
    count++;
    assert(
      String(input) === "https://appleid.apple.com/auth/revoke" &&
        init?.redirect === "error",
      "fixed revocation destination",
    );
    const body = new URLSearchParams(String(init.body));
    assert(
      body.get("token") === "synthetic-refresh" &&
        body.get("token_type_hint") === "refresh_token",
      "refresh-token revocation",
    );
    return new Response(null, { status: 200 });
  };
  await revokeAppleDeletionToken("synthetic-refresh", config, fetcher);
  await revokeAppleDeletionToken("synthetic-refresh", config, fetcher);
  assert(count === 2, "durable callers may repeat the same revocation request");
  try {
    await revokeAppleDeletionToken(
      "synthetic-refresh",
      config,
      async () => new Response("SECRET RESPONSE", { status: 503 }),
    );
    throw new Error("unexpected success");
  } catch (error) {
    assert(
      error instanceof AppleRevocationError &&
        error.message === "apple_unavailable",
      "upstream body omitted",
    );
  }
});

Deno.test("Apple distinguishes client configuration from a spent authorization code", async () => {
  for (
    const [upstream, expected] of [["invalid_client", "configuration"], [
      "invalid_grant",
      "reauthentication_required",
    ]]
  ) {
    const fetcher: typeof fetch = async (input) =>
      String(input).endsWith("/keys")
        ? Response.json({ keys: [jwk] })
        : Response.json({ error: upstream }, { status: 400 });
    try {
      await exchangeAppleDeletionCode(
        "synthetic-code",
        "synthetic-owner",
        config,
        fetcher,
      );
      throw new Error("unexpected success");
    } catch (error) {
      assert(
        error instanceof AppleRevocationError && error.code === expected,
        "actionable sanitized error",
      );
    }
  }
});
