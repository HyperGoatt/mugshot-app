import { getSecretSupabaseKey } from "../_shared/secret-key.ts";

type EnvironmentReader = (name: string) => string | undefined;

export function getMugsyAdminKey(
  readEnvironment: EnvironmentReader = (name) => Deno.env.get(name),
): string | null {
  const modern = readEnvironment("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const keys = JSON.parse(modern) as Record<string, unknown>;
      const preferred = keys["activity-delivery"];
      if (typeof preferred === "string" && preferred.length > 0) {
        return preferred;
      }
    } catch {
      // Share the hosted named/default/legacy fallback during key migrations.
    }
  }
  return getSecretSupabaseKey(readEnvironment);
}
