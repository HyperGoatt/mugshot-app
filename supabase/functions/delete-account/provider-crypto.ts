export type EncryptedProviderToken = {
  version: 1;
  nonce: string;
  data: string;
};
const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
function decode(value: string): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}
function context(requestID: string, clientID: string) {
  if (
    !/^[a-f0-9-]{36}$/i.test(requestID) || !clientID || clientID.length > 256
  ) throw new Error("provider_credential_context_invalid");
  return new TextEncoder().encode(
    `mugshot-apple-revocation:v1:${requestID.toLowerCase()}:${clientID}`,
  );
}
async function key(secret: string) {
  try {
    const raw = decode(secret);
    if (raw.length !== 32) throw new Error();
    return await crypto.subtle.importKey("raw", raw, "AES-GCM", false, [
      "encrypt",
      "decrypt",
    ]);
  } catch {
    throw new Error("provider_credential_key_unavailable");
  }
}
export async function encryptProviderToken(
  token: string,
  secret: string,
  requestID: string,
  clientID: string,
): Promise<EncryptedProviderToken> {
  const bytes = new TextEncoder().encode(token);
  if (!bytes.length || bytes.length > 8192) {
    throw new Error("provider_credential_invalid");
  }
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv: nonce,
      additionalData: context(requestID, clientID),
    },
    await key(secret),
    bytes,
  );
  return {
    version: 1,
    nonce: encode(nonce),
    data: encode(new Uint8Array(encrypted)),
  };
}
export async function decryptProviderToken(
  value: EncryptedProviderToken,
  secret: string,
  requestID: string,
  clientID: string,
): Promise<string> {
  try {
    if (
      value.version !== 1 || value.data.length > 12000 ||
      value.nonce.length > 32
    ) throw new Error();
    const nonce = decode(value.nonce);
    if (nonce.length !== 12) throw new Error();
    const plaintext = await crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: nonce,
        additionalData: context(requestID, clientID),
      },
      await key(secret),
      decode(value.data),
    );
    const token = new TextDecoder("utf-8", { fatal: true }).decode(plaintext);
    if (!token || plaintext.byteLength > 8192) throw new Error();
    return token;
  } catch {
    throw new Error("provider_credential_unavailable");
  }
}
