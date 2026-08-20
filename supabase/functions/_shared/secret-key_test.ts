import { getSecretSupabaseKey } from "./secret-key.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, received ${String(actual)}`);
  }
}

function environment(values: Record<string, string | undefined>) {
  return (name: string) => values[name];
}

Deno.test("prefers the default modern secret key", () => {
  assertEquals(
    getSecretSupabaseKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({
        secondary: "sb_secret_2",
        default: "sb_secret_1",
      }),
      SUPABASE_SERVICE_ROLE_KEY: "legacy",
    })),
    "sb_secret_1",
  );
});

Deno.test("accepts a named modern secret key", () => {
  assertEquals(
    getSecretSupabaseKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({
        capabilityMedia: "sb_secret_media",
      }),
    })),
    "sb_secret_media",
  );
});

Deno.test("falls back to legacy hosted variables", () => {
  assertEquals(
    getSecretSupabaseKey(environment({
      SUPABASE_SECRET_KEYS: "not-json",
      SUPABASE_SERVICE_ROLE_KEY: "legacy-service-role",
    })),
    "legacy-service-role",
  );
});
