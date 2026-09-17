export type ContactInput = { item_key: string; emails: string[] };

export function isExplicitlyEnabled(value: string | undefined): boolean {
  return value === "true";
}

export function normalizeEmail(value: string): string | null {
  const normalized = value.trim().toLocaleLowerCase("en-US");
  if (normalized.length < 3 || normalized.length > 254) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) return null;
  return normalized;
}

export function validateItems(value: unknown): ContactInput[] | null {
  if (!Array.isArray(value) || value.length < 1 || value.length > 50) {
    return null;
  }
  const seenKeys = new Set<string>();
  let addressCount = 0;
  const result: ContactInput[] = [];
  for (const raw of value) {
    if (!raw || typeof raw !== "object") return null;
    const itemKey = (raw as Record<string, unknown>).item_key;
    const emails = (raw as Record<string, unknown>).emails;
    if (
      typeof itemKey !== "string" || !/^[A-Za-z0-9_-]{8,80}$/.test(itemKey) ||
      seenKeys.has(itemKey) || !Array.isArray(emails)
    ) return null;
    seenKeys.add(itemKey);
    const normalized = [
      ...new Set(emails.flatMap((email) => {
        if (typeof email !== "string") return [];
        const result = normalizeEmail(email);
        return result ? [result] : [];
      })),
    ].slice(0, 10);
    addressCount += normalized.length;
    if (addressCount > 200) return null;
    result.push({ item_key: itemKey, emails: normalized });
  }
  return result;
}

function hex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export async function keyedDigest(
  value: string,
  secret: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return hex(await crypto.subtle.sign("HMAC", key, encoder.encode(value)));
}

export const privateHeaders = {
  "Cache-Control": "private, no-store",
  "Content-Type": "application/json; charset=utf-8",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
};
