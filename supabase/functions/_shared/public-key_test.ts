import assert from "node:assert/strict";
import { getPublicSupabaseKey } from "./public-key.ts";

function from(values: Record<string, string | undefined>) {
  return (name: string) => values[name];
}

assert.equal(
  getPublicSupabaseKey(
    from({ SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_default"}' }),
  ),
  "sb_publishable_default",
);
assert.equal(
  getPublicSupabaseKey(
    from({ SUPABASE_PUBLISHABLE_KEYS: '{"web":"sb_publishable_web"}' }),
  ),
  "sb_publishable_web",
);
assert.equal(
  getPublicSupabaseKey(
    from({
      SUPABASE_PUBLISHABLE_KEYS: "invalid",
      SUPABASE_ANON_KEY: "legacy-anon",
    }),
  ),
  "legacy-anon",
);
assert.equal(
  getPublicSupabaseKey(
    from({ SUPABASE_PUBLISHABLE_KEY: "legacy-publishable" }),
  ),
  "legacy-publishable",
);
assert.equal(getPublicSupabaseKey(from({})), null);

console.log("Public Supabase key resolution passed.");
