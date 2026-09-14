import {
  screenContent,
  type ScreeningInput,
  type ScreeningResult,
} from "./provider.ts";

export type ScreeningJob = {
  subject_kind: string;
  subject_id: string;
  owner_id: string;
  revision: string;
  lease_token: string;
};
export type ScreeningClient = {
  rpc(
    name: string,
    parameters?: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: unknown }>;
  storage: {
    from(
      bucket: string,
    ): {
      download(path: string): Promise<{ data: Blob | null; error: unknown }>;
    };
  };
};

// Resolve only owner-scoped objects in Mugshot Storage. Never fetch arbitrary
// user-controlled hosts or turn another owner's private object into AI input.
export function screeningMediaLocation(
  value: unknown,
  job: Pick<ScreeningJob, "subject_kind" | "subject_id" | "owner_id">,
  baseURL: string,
): { bucket: string; path: string } | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value), base = new URL(baseURL);
    if (url.username || url.password || url.search || url.hash) return null;
    let bucket: string, path: string;
    if (
      url.protocol === "mugshot-storage:" &&
      url.hostname === "visit-photos-private"
    ) {
      bucket = url.hostname;
      path = decodeURIComponent(url.pathname.slice(1));
    } else {
      if (url.protocol !== "https:" || url.origin !== base.origin) return null;
      const match = url.pathname.match(
        /^\/storage\/v1\/object\/public\/(profile-media|visit-photos)\/(.+)$/,
      );
      if (!match) return null;
      bucket = match[1];
      path = decodeURIComponent(match[2]);
    }
    const segments = path.split("/");
    if (
      segments.some((part) =>
        !part || part === "." || part === ".." || /[\\\u0000-\u001f]/.test(part)
      ) || segments[0].toLowerCase() !== job.owner_id.toLowerCase()
    ) return null;
    // Historical uploads used owner/file.jpg and owner/folder/file.jpg.
    // The caller accepts references only from a freshly leased server payload.
    if (job.subject_kind === "user") {
      if (bucket !== "profile-media") return null;
    } else if (job.subject_kind === "visit") {
      if (
        bucket === "visit-photos-private" &&
        (segments.length < 3 ||
          segments[1].toLowerCase() !== job.subject_id.toLowerCase())
      ) return null;
    } else return null;
    return { bucket, path };
  } catch {
    return null;
  }
}

export async function processScreeningJob(
  client: ScreeningClient,
  job: ScreeningJob,
  configuration: {
    apiKey: string;
    noTrainingControlsVerified: boolean;
    supabaseURL: string;
  },
  request: typeof fetch = fetch,
): Promise<"applied" | "stale" | "deferred"> {
  const identity = {
    p_kind: job.subject_kind,
    p_id: job.subject_id,
    p_revision: job.revision,
    p_lease: job.lease_token,
  };
  try {
    const current = await client.rpc("read_screening_lease_v1", identity);
    if (current.error) return "deferred";
    if (!current.data) return "stale";
    const payload = current.data as { text?: unknown; images?: unknown };
    let outcome: ScreeningResult = {
      state: "retry",
      reason: "invalid_input",
      retryAfterSeconds: 60,
      diagnostics: { stage: "payload" },
    };
    if (
      typeof payload.text === "string" && Array.isArray(payload.images) &&
      payload.images.length <= 12
    ) {
      const refs = payload.images.length ? payload.images : [null];
      let aggregate: Extract<ScreeningResult, { state: "approved" }> | null =
        null;
      for (const ref of refs) {
        const images: ScreeningInput["images"] = [];
        if (ref !== null) {
          const location = screeningMediaLocation(
            ref,
            job,
            configuration.supabaseURL,
          );
          if (!location) {
            outcome = {
              state: "retry",
              reason: "invalid_input",
              retryAfterSeconds: 60,
              diagnostics: { stage: "media_reference" },
            };
            break;
          }
          const media = await client.storage.from(location.bucket).download(
            location.path,
          );
          if (media.error || !media.data) {
            const storageError = media.error && typeof media.error === "object"
              ? media.error as Record<string, unknown>
              : {};
            const status = Number(
              storageError.statusCode ?? storageError.status,
            );
            const missing = status === 404 ||
              storageError.error === "not_found";
            outcome = {
              state: "retry",
              reason: missing ? "invalid_input" : "provider_unavailable",
              retryAfterSeconds: 60,
              diagnostics: {
                stage: "media_download",
                ...(Number.isInteger(status) && status >= 100 && status <= 599
                  ? { http_status: status }
                  : {}),
                ...(missing ? { error_code: "storage_object_missing" } : {}),
              },
            };
            break;
          }
          if (media.data.size > 20 * 1024 * 1024) {
            outcome = {
              state: "retry",
              reason: "invalid_input",
              retryAfterSeconds: 60,
              diagnostics: { stage: "media_size" },
            };
            break;
          }
          const bytes = new Uint8Array(await media.data.arrayBuffer());
          const mime = bytes[0] === 255 && bytes[1] === 216
            ? "image/jpeg"
            : bytes[0] === 137 && bytes[1] === 80
            ? "image/png"
            : null;
          if (!mime) {
            outcome = {
              state: "retry",
              reason: "invalid_input",
              retryAfterSeconds: 60,
              diagnostics: { stage: "media_format" },
            };
            break;
          }
          images.push({ mime, bytes });
        }
        // Check deletion, audience and revision before EACH external request.
        const fresh = await client.rpc("read_screening_lease_v1", identity);
        if (fresh.error) return "deferred";
        if (!fresh.data) return "stale";
        outcome = await screenContent(
          { audience: "shared", text: payload.text, images },
          configuration,
          request,
        );
        if (outcome.state !== "approved") break;
        if (!aggregate) aggregate = outcome;
        else {for (const key of Object.keys(outcome.scores)) {
            aggregate.scores[key] = Math.max(
              aggregate.scores[key],
              outcome.scores[key],
            );
          }}
      }
      if (outcome.state === "approved" && aggregate) outcome = aggregate;
    }
    if (outcome.state === "excluded") return "stale";
    const { state, ...details } = outcome;
    const evidence = { ...details } as Record<string, unknown>;
    const retrySeconds = evidence.retryAfterSeconds;
    delete evidence.retryAfterSeconds;
    const finished = await client.rpc("finish_screening_job_v1", {
      ...identity,
      p_state: state,
      p_evidence: evidence,
      p_retry_seconds: typeof retrySeconds === "number" ? retrySeconds : 60,
    });
    return finished.error
      ? "deferred"
      : finished.data === true
      ? "applied"
      : "stale";
  } catch {
    return "deferred";
  }
}
