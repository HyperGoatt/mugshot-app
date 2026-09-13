// PostHog account erasure transport. Queue integration must persist the verified
// target before submitting, so retries can still verify an already-deleted person.
export type AnalyticsErasureConfiguration = {
  region: "us" | "eu";
  projectID: number;
  personalAPIKey: string;
};
export type AnalyticsErasureTarget = {
  ownerID: string;
  personID: string;
  otherAccountCandidates?: string[];
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function validateTarget(target: AnalyticsErasureTarget) {
  if (!uuid.test(target.ownerID) || !uuid.test(target.personID)) {
    throw new Error("Invalid analytics erasure target");
  }
}

async function request(
  configuration: AnalyticsErasureConfiguration,
  path: string,
  fetcher: typeof fetch,
  body?: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  try {
    return await performRequest(configuration, path, fetcher, body);
  } catch {
    throw new Error("Analytics erasure request unavailable");
  }
}

async function performRequest(
  configuration: AnalyticsErasureConfiguration,
  path: string,
  fetcher: typeof fetch,
  body?: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (
    !["us", "eu"].includes(configuration.region) ||
    !Number.isSafeInteger(configuration.projectID) ||
    configuration.projectID <= 0 ||
    configuration.personalAPIKey.trim().length < 20
  ) throw new Error("Analytics erasure is not configured");
  const url =
    `https://${configuration.region}.posthog.com/api/projects/${configuration.projectID}/persons/${path}`;
  const response = await fetcher(url, {
    method: body ? "POST" : "GET",
    headers: {
      Authorization: `Bearer ${configuration.personalAPIKey}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
    redirect: "error",
    signal: AbortSignal.timeout(15_000),
  });
  if (response.status !== (body ? 202 : 200)) {
    throw new Error("Analytics erasure provider request failed");
  }
  const reader = response.body?.getReader();
  if (!reader) throw new Error("Analytics erasure response missing");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      size += part.value.byteLength;
      if (size > 65_536) {
        await reader.cancel();
        throw new Error("Analytics erasure response exceeded limit");
      }
      chunks.push(part.value);
    }
  } finally {
    reader.releaseLock();
  }
  const data = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    data.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let result: unknown;
  try {
    result = JSON.parse(new TextDecoder().decode(data));
  } catch {
    throw new Error("Analytics erasure response invalid");
  }
  if (!result || typeof result !== "object" || Array.isArray(result)) {
    throw new Error("Analytics erasure response invalid");
  }
  return result as Record<string, unknown>;
}

export async function lookupAnalyticsErasureTarget(
  configuration: AnalyticsErasureConfiguration,
  ownerID: string,
  fetcher: typeof fetch = fetch,
): Promise<AnalyticsErasureTarget | null> {
  if (!uuid.test(ownerID)) throw new Error("Invalid analytics owner");
  const result = await request(
    configuration,
    `?distinct_id=${encodeURIComponent(ownerID.toLowerCase())}&limit=2`,
    fetcher,
  );
  if (!Array.isArray(result.results) || result.next) {
    throw new Error("Ambiguous analytics owner lookup");
  }
  if (result.results.length === 0) return null; // Absence is not historical erasure proof.
  if (result.results.length !== 1) {
    throw new Error("Ambiguous analytics owner lookup");
  }
  const person = result.results[0];
  if (
    !person || typeof person !== "object" || typeof person.uuid !== "string" ||
    !uuid.test(person.uuid) || !Array.isArray(person.distinct_ids) ||
    !person.distinct_ids.includes(ownerID.toLowerCase())
  ) throw new Error("Analytics owner lookup mismatch");
  return {
    ownerID: ownerID.toLowerCase(),
    personID: person.uuid.toLowerCase(),
    otherAccountCandidates: person.distinct_ids.filter((
      id: unknown,
    ): id is string =>
      typeof id === "string" && uuid.test(id) &&
      id.toLowerCase() !== ownerID.toLowerCase()
    ).map((id: string) => id.toLowerCase()),
  };
}

export async function submitAnalyticsErasure(
  configuration: AnalyticsErasureConfiguration,
  target: AnalyticsErasureTarget,
  fetcher: typeof fetch = fetch,
): Promise<"submitted"> {
  validateTarget(target);
  const result = await request(configuration, "bulk_delete/", fetcher, {
    ids: [target.personID],
    delete_events: true,
    delete_recordings: true,
    keep_person: false,
  });
  if (
    !Array.isArray(result.deletion_errors) ||
    result.deletion_errors.length !== 0 ||
    result.events_queued_for_deletion !== true ||
    result.recordings_queued_for_deletion !== true
  ) {
    throw new Error("Analytics erasure was not fully queued");
  }
  return "submitted";
}

export async function analyticsErasureStatus(
  configuration: AnalyticsErasureConfiguration,
  target: AnalyticsErasureTarget,
  submittedAt: string,
  fetcher: typeof fetch = fetch,
): Promise<"pending" | "verified"> {
  validateTarget(target);
  const submitted = Date.parse(submittedAt);
  if (!Number.isFinite(submitted)) {
    throw new Error("Invalid analytics submission time");
  }
  const result = await request(
    configuration,
    `deletion_status/?person_uuid=${
      encodeURIComponent(target.personID)
    }&status=all&limit=100`,
    fetcher,
  );
  if (
    !Array.isArray(result.results) || result.next || result.results.length === 0
  ) return "pending";
  const current = result.results.filter((row) =>
    row && row.person_uuid === target.personID &&
    typeof row.created_at === "string" &&
    Date.parse(row.created_at) >= submitted
  );
  return current.length > 0 &&
      current.every((row) =>
        row.status === "completed" &&
        typeof row.delete_verified_at === "string" &&
        Date.parse(row.delete_verified_at) >= Date.parse(row.created_at)
      )
    ? "verified"
    : "pending";
}
