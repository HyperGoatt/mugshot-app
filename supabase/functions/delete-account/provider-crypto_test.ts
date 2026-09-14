import {
  decryptProviderToken,
  encryptProviderToken,
} from "./provider-crypto.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const secret = btoa(String.fromCharCode(...new Uint8Array(32).fill(19)));
const request = "10000000-0000-4000-8000-000000000001";
Deno.test("provider tokens are randomized ciphertext bound to the deletion request and app", async () => {
  const token = "synthetic-private-refresh";
  const first = await encryptProviderToken(
    token,
    secret,
    request,
    "com.example.synthetic",
  );
  const second = await encryptProviderToken(
    token,
    secret,
    request,
    "com.example.synthetic",
  );
  assert(
    first.data !== second.data && first.nonce !== second.nonce,
    "fresh nonce for each encryption",
  );
  assert(
    !JSON.stringify(first).includes(token),
    "plaintext absent from envelope",
  );
  assert(
    await decryptProviderToken(
      first,
      secret,
      request,
      "com.example.synthetic",
    ) === token,
    "correct context decrypts",
  );
  for (
    const [requestID, clientID, key] of [[request, "other-app", secret], [
      "20000000-0000-4000-8000-000000000001",
      "com.example.synthetic",
      secret,
    ], [request, "com.example.synthetic", btoa("0".repeat(32))]]
  ) {
    try {
      await decryptProviderToken(first, key, requestID, clientID);
      throw new Error("unexpected success");
    } catch (error) {
      assert(
        error instanceof Error &&
          error.message === "provider_credential_unavailable",
        "context/key mismatch fails without secret text",
      );
    }
  }
  const tampered = { ...first, data: first.data.slice(0, -8) + "AAAAAAAA" };
  try {
    await decryptProviderToken(
      tampered,
      secret,
      request,
      "com.example.synthetic",
    );
    throw new Error("unexpected success");
  } catch (error) {
    assert(
      error instanceof Error &&
        error.message === "provider_credential_unavailable",
      "tampering rejected",
    );
  }
});
