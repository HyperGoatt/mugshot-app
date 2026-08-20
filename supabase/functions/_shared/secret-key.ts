type EnvironmentReader = (name: string) => string | undefined;

export function getSecretSupabaseKey(
  readEnvironment: EnvironmentReader = (name) => Deno.env.get(name),
): string | null {
  const secretKeys = readEnvironment("SUPABASE_SECRET_KEYS");
  if (secretKeys) {
    try {
      const parsed = JSON.parse(secretKeys) as Record<string, unknown>;
      const defaultKey = parsed.default;
      if (typeof defaultKey === "string" && defaultKey.length > 0) {
        return defaultKey;
      }

      const firstNamedKey = Object.values(parsed).find(
        (value): value is string =>
          typeof value === "string" && value.length > 0,
      );
      if (firstNamedKey) return firstNamedKey;
    } catch {
      // Fall through to the hosted legacy variable during key migrations.
    }
  }

  return (
    readEnvironment("SUPABASE_SERVICE_ROLE_KEY") ??
      readEnvironment("SUPABASE_SECRET_KEY") ??
      null
  );
}
