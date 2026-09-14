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

/** Resolve historical public Storage URLs through the same short-lived signing
 * path as private references. Callers must first obtain an authorized projection. */
export function legacyCapabilityStorageReference(
  value: unknown,
  supabaseURL: string,
): { bucket: string; path: string } | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value), base = new URL(supabaseURL);
    if (
      url.origin !== base.origin || url.protocol !== "https:" ||
      url.username || url.password || url.search || url.hash
    ) return null;
    const prefix = "/storage/v1/object/public/";
    if (!url.pathname.startsWith(prefix)) return null;
    const parts = decodeURIComponent(url.pathname.slice(prefix.length)).split(
      "/",
    );
    const bucket = parts.shift();
    if (
      !bucket ||
      !["profile-media", "visit-photos", "visit-photos-private"].includes(
        bucket,
      ) ||
      parts.length < (bucket === "visit-photos-private" ? 3 : 2) ||
      parts.some((part) => !part || part === "." || part === "..")
    ) return null;
    return { bucket, path: parts.join("/") };
  } catch {
    return null;
  }
}

/** IDs must come from the authorized database projection, never request fields
 * or the image path itself. A visit scope cannot authorize profile objects. */
export type CapabilityMediaScope = {
  kind: "profile" | "visit";
  ownerID: unknown;
  visitID?: unknown;
};

export function mediaBelongsToScope(
  reference: { bucket: string; path: string },
  scope: CapabilityMediaScope,
): boolean {
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (typeof scope.ownerID !== "string" || !uuid.test(scope.ownerID)) {
    return false;
  }
  const parts = reference.path.split("/");
  if (parts[0]?.toLowerCase() !== scope.ownerID.toLowerCase()) return false;
  if (scope.kind === "profile") return reference.bucket === "profile-media";
  // Historical projections contain owner/file and owner/visits/file objects.
  // The caller must obtain the exact reference from an authorized projection.
  if (reference.bucket === "visit-photos" && parts.length === 2) return true;
  if (
    reference.bucket === "profile-media" && parts[1] === "visits" &&
    parts.length >= 3
  ) return true;
  return ["visit-photos", "visit-photos-private"].includes(reference.bucket) &&
    typeof scope.visitID === "string" && uuid.test(scope.visitID) &&
    parts[1]?.toLowerCase() === scope.visitID.toLowerCase();
}

/** Use only a publishable-key anonymous client. Public cafe-list images must
 * pass Storage RLS; this function must never receive a privileged client. */
export async function resolvedPublicAudienceMediaURL(
  value: unknown,
  anonymousClient: MediaSigningClient,
  supabaseURL: string,
): Promise<string | null> {
  const reference = privateStorageReference(value) ??
    legacyCapabilityStorageReference(value, supabaseURL);
  if (reference) {
    return await signStorageMediaURL(reference, anonymousClient, supabaseURL);
  }
  const url = safeHTTPSURL(value);
  if (!url) return null;
  try {
    return new URL(url).origin === new URL(supabaseURL).origin ? null : url;
  } catch {
    return null;
  }
}

async function signStorageMediaURL(
  reference: { bucket: string; path: string },
  client: MediaSigningClient,
  supabaseURL: string,
): Promise<string | null> {
  const { data, error } = await client.storage.from(reference.bucket)
    .createSignedUrl(reference.path, 60);
  if (error) return null;
  const signed = safeHTTPSURL(data?.signedUrl);
  if (!signed) return null;
  try {
    return new URL(signed).origin === new URL(supabaseURL).origin
      ? signed
      : null;
  } catch {
    return null;
  }
}

export async function resolvedCapabilityMediaURL(
  value: unknown,
  adminClient: MediaSigningClient | null,
  supabaseURL: string,
  scope: CapabilityMediaScope,
): Promise<string | null> {
  const reference = privateStorageReference(value) ??
    legacyCapabilityStorageReference(value, supabaseURL);
  if (!reference) {
    // Foreign HTTPS images retain the existing projection behavior, but never
    // gain a service-role signature. Invalid own-Storage URLs fail closed.
    const publicURL = safeHTTPSURL(value);
    if (!publicURL) return null;
    try {
      return new URL(publicURL).origin === new URL(supabaseURL).origin
        ? null
        : publicURL;
    } catch {
      return null;
    }
  }
  if (!adminClient || !mediaBelongsToScope(reference, scope)) return null;
  return await signStorageMediaURL(reference, adminClient, supabaseURL);
}
