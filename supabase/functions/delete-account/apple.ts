/** Apple credentials stay on the server; callers must persist the returned
 * refresh token securely before revocation so interrupted cleanup can resume. */
export type AppleConfig = { clientID: string; clientSecret: string };
export class AppleRevocationError extends Error {
  constructor(
    readonly code:
      | "configuration"
      | "reauthentication_required"
      | "unavailable"
      | "identity_mismatch",
  ) {
    super(`apple_${code}`);
  }
}
const tokenURL = "https://appleid.apple.com/auth/token";
const revokeURL = "https://appleid.apple.com/auth/revoke";
const keysURL = "https://appleid.apple.com/auth/keys";
function configured(config: AppleConfig) {
  if (
    !config.clientID || config.clientID.length > 256 || !config.clientSecret ||
    config.clientSecret.length > 8192
  ) {
    throw new AppleRevocationError("configuration");
  }
}
async function boundedJSON(
  response: Response,
): Promise<Record<string, unknown>> {
  const reader = response.body?.getReader();
  if (!reader) throw new AppleRevocationError("unavailable");
  let size = 0, text = "";
  const decoder = new TextDecoder();
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 65536) {
        await reader.cancel();
        throw new AppleRevocationError("unavailable");
      }
      text += decoder.decode(value, { stream: true });
    }
    const parsed = JSON.parse(text + decoder.decode());
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error();
    }
    return parsed;
  } catch {
    throw new AppleRevocationError("unavailable");
  } finally {
    reader.releaseLock();
  }
}
async function send(
  fetcher: typeof fetch,
  url: string,
  options: RequestInit,
): Promise<Response> {
  try {
    return await fetcher(url, {
      ...options,
      redirect: "error",
      signal: AbortSignal.timeout(15000),
    });
  } catch {
    throw new AppleRevocationError("unavailable");
  }
}
function bytes(value: string): Uint8Array<ArrayBuffer> {
  const raw = atob(value.replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from(raw, (ch) => ch.charCodeAt(0));
}
async function verifyIdentity(
  token: string,
  keys: unknown[],
  expectedSubject: string,
  clientID: string,
  now: number,
) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) throw new Error();
    const header = JSON.parse(new TextDecoder().decode(bytes(parts[0])));
    const claims = JSON.parse(new TextDecoder().decode(bytes(parts[1])));
    if (header.alg !== "RS256" || typeof header.kid !== "string") {
      throw new Error();
    }
    const jwk = keys.find((value): value is JsonWebKey & { kid: string } =>
      !!value && typeof value === "object" &&
      "kid" in value && value.kid === header.kid && "kty" in value &&
      value.kty === "RSA"
    );
    if (!jwk) throw new Error();
    const key = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      bytes(parts[2]),
      new TextEncoder().encode(parts[0] + "." + parts[1]),
    );
    if (
      !valid || claims.iss !== "https://appleid.apple.com" ||
      claims.aud !== clientID || claims.sub !== expectedSubject ||
      typeof claims.exp !== "number" || claims.exp <= now ||
      typeof claims.iat !== "number" || claims.iat > now + 60
    ) throw new Error();
  } catch {
    throw new AppleRevocationError("identity_mismatch");
  }
}
export async function exchangeAppleDeletionCode(
  code: string,
  expectedSubject: string,
  config: AppleConfig,
  fetcher: typeof fetch = fetch,
  now = Math.floor(Date.now() / 1000),
): Promise<string> {
  configured(config);
  if (
    !code || code.length > 4096 || !expectedSubject ||
    expectedSubject.length > 256
  ) throw new AppleRevocationError("reauthentication_required");
  // Fetch verification keys before consuming the short-lived, single-use code.
  const keysResponse = await send(fetcher, keysURL, { method: "GET" });
  if (!keysResponse.ok) throw new AppleRevocationError("unavailable");
  const keys = (await boundedJSON(keysResponse)).keys;
  if (!Array.isArray(keys) || keys.length === 0 || keys.length > 20) {
    throw new AppleRevocationError("unavailable");
  }
  const response = await send(fetcher, tokenURL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: config.clientID,
      client_secret: config.clientSecret,
      code,
      grant_type: "authorization_code",
    }),
  });
  if (!response.ok) {
    const error = await boundedJSON(response).catch(
      () => ({} as Record<string, unknown>),
    );
    throw new AppleRevocationError(
      error.error === "invalid_client"
        ? "configuration"
        : error.error === "invalid_grant"
        ? "reauthentication_required"
        : "unavailable",
    );
  }
  const result = await boundedJSON(response);
  if (
    typeof result.id_token !== "string" || result.id_token.length > 16384 ||
    typeof result.refresh_token !== "string" || !result.refresh_token ||
    result.refresh_token.length > 8192
  ) throw new AppleRevocationError("unavailable");
  await verifyIdentity(
    result.id_token,
    keys,
    expectedSubject,
    config.clientID,
    now,
  );
  return result.refresh_token;
}
export async function revokeAppleDeletionToken(
  token: string,
  config: AppleConfig,
  fetcher: typeof fetch = fetch,
): Promise<void> {
  configured(config);
  if (!token || token.length > 8192) {
    throw new AppleRevocationError("reauthentication_required");
  }
  const response = await send(fetcher, revokeURL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: config.clientID,
      client_secret: config.clientSecret,
      token,
      token_type_hint: "refresh_token",
    }),
  });
  if (!response.ok) throw new AppleRevocationError("unavailable");
}
