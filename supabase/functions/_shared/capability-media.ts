export type MediaSigningClient = {
  storage: {
    from(bucket: string): {
      createSignedUrl(
        path: string,
        expiresIn: number,
      ): Promise<{
        data: { signedUrl: string } | null;
        error: unknown;
      }>;
    };
  };
};

export function safeHTTPSURL(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

export function privateStorageReference(
  value: unknown,
): { bucket: string; path: string } | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    if (
      url.protocol !== "mugshot-storage:" ||
      url.hostname !== "visit-photos-private" ||
      url.search ||
      url.hash
    ) return null;
    const path = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
    const segments = path.split("/");
    if (
      segments.length < 3 ||
      segments.some((segment) =>
        !segment || segment === "." || segment === ".."
      )
    ) return null;
    return { bucket: url.hostname, path };
  } catch {
    return null;
  }
}

export async function resolvedCapabilityMediaURL(
  value: unknown,
  adminClient: MediaSigningClient | null,
): Promise<string | null> {
  const publicURL = safeHTTPSURL(value);
  if (publicURL) return publicURL;

  const reference = privateStorageReference(value);
  if (!reference || !adminClient) return null;
  const { data, error } = await adminClient.storage
    .from(reference.bucket)
    .createSignedUrl(reference.path, 300);
  if (error) return null;
  return safeHTTPSURL(data?.signedUrl);
}
