type EnvironmentReader = (name: string) => string | undefined;

export function getPublicSupabaseKey(
  readEnvironment: EnvironmentReader = (name) => Deno.env.get(name),
): string | null {
  const publishableKeys = readEnvironment("SUPABASE_PUBLISHABLE_KEYS");
  if (publishableKeys) {
    try {
      const parsed = JSON.parse(publishableKeys) as Record<string, unknown>;
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
      // Fall through to compatibility variables when the hosted map is unavailable or malformed.
    }
  }

  return (
    readEnvironment("SUPABASE_ANON_KEY") ??
      readEnvironment("SUPABASE_PUBLISHABLE_KEY") ??
      null
  );
}
