import { getMugsyAdminKey } from "./config.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error("Unexpected admin-key selection");
  }
}

function environment(values: Record<string, string | undefined>) {
  return (name: string) => values[name];
}

Deno.test("Mugsy accepts a named hosted secret without a default label", () => {
  assertEquals(
    getMugsyAdminKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({ hostedWorker: "synthetic-named" }),
    })),
    "synthetic-named",
  );
});

Deno.test("Mugsy prefers its activity-delivery label over default and named keys", () => {
  assertEquals(
    getMugsyAdminKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({
        named: "synthetic-named",
        default: "synthetic-default",
        "activity-delivery": "synthetic-activity",
      }),
    })),
    "synthetic-activity",
  );
});

Deno.test("Mugsy uses the shared default before other named keys", () => {
  assertEquals(
    getMugsyAdminKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({
        named: "synthetic-named",
        default: "synthetic-default",
      }),
    })),
    "synthetic-default",
  );
});

Deno.test("Mugsy ignores an empty preferred label and keeps a usable default", () => {
  assertEquals(
    getMugsyAdminKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({
        "activity-delivery": "",
        default: "synthetic-default",
      }),
    })),
    "synthetic-default",
  );
});

Deno.test("Mugsy keeps hosted legacy fallback during a malformed modern-key rollout", () => {
  assertEquals(
    getMugsyAdminKey(environment({
      SUPABASE_SECRET_KEYS: "not-json",
      SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role",
    })),
    "synthetic-service-role",
  );
  assertEquals(
    getMugsyAdminKey(environment({ SUPABASE_SECRET_KEY: "synthetic-secret" })),
    "synthetic-secret",
  );
});

Deno.test("Mugsy fails closed when no usable key is configured", () => {
  assertEquals(getMugsyAdminKey(environment({})), null);
  assertEquals(
    getMugsyAdminKey(environment({
      SUPABASE_SECRET_KEYS: JSON.stringify({ default: 7, other: false }),
    })),
    null,
  );
});
