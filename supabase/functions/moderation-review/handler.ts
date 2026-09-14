import { screeningMediaLocation } from "../screen-content/worker.ts";

type Parameters = { p_kind: string; p_id: string; p_revision: string };
type Item = Record<string, unknown> & {
  subject_kind: string;
  subject_id: string;
  owner_id: string;
  revision: string;
  payload: { text: string; images: string[] };
};
export type ReviewDependencies = {
  baseURL: string;
  authenticate(authorization: string): Promise<
    {
      read(
        parameters: Parameters,
      ): PromiseLike<{ data: unknown; error: unknown }>;
    } | null
  >;
  sign(bucket: string, path: string, expires: number): Promise<string | null>;
};
const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function itemFor(value: unknown, request: Parameters): Item | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Item;
  return item.subject_kind === request.p_kind &&
      item.subject_id === request.p_id &&
      item.revision === request.p_revision &&
      typeof item.owner_id === "string" &&
      uuid.test(item.owner_id) && typeof item.payload?.text === "string" &&
      Array.isArray(item.payload.images) && item.payload.images.length <= 12 &&
      item.payload.images.every((ref) => typeof ref === "string")
    ? item
    : null;
}
async function bodyParameters(request: Request): Promise<Parameters | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  let raw = "", size = 0;
  const decoder = new TextDecoder();
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 2048) {
        await reader.cancel();
        return null;
      }
      raw += decoder.decode(value, { stream: true });
    }
    const value = JSON.parse(raw + decoder.decode());
    if (
      !value || typeof value !== "object" ||
      !["p_kind", "p_id", "p_revision"].every((key) =>
        typeof value[key] === "string"
      ) ||
      !/^[a-z_]{1,40}$/.test(value.p_kind) || !uuid.test(value.p_id) ||
      !uuid.test(value.p_revision)
    ) return null;
    return {
      p_kind: value.p_kind,
      p_id: value.p_id.toLowerCase(),
      p_revision: value.p_revision.toLowerCase(),
    };
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}

export async function handleReview(
  request: Request,
  dependencies: ReviewDependencies | null,
): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const authorization = request.headers.get("Authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") || authorization.length <= 7 ||
    authorization.length > 8192
  ) {
    return json({ error: "authentication_required" }, 401);
  }
  if (!dependencies) return json({ error: "unavailable" }, 503);
  const parameters = await bodyParameters(request);
  if (!parameters) return json({ error: "invalid_request" }, 400);
  try {
    const viewer = await dependencies.authenticate(authorization);
    if (!viewer) return json({ error: "authentication_required" }, 401);
    const result = await viewer.read(parameters);
    if (result.error) return json({ error: "review_unavailable" }, 403);
    const item = itemFor(result.data, parameters);
    if (!item) return json({ error: "revision_unavailable" }, 409);
    const urls: (string | null)[] = [];
    for (const ref of item.payload.images) {
      const location = screeningMediaLocation(ref, item, dependencies.baseURL);
      if (!location) {
        urls.push(null);
        continue;
      }
      const signed = await dependencies.sign(
        location.bucket,
        location.path,
        60,
      );
      const url = signed ? new URL(signed) : null;
      urls.push(
        url?.origin === new URL(dependencies.baseURL).origin ? signed : null,
      );
    }
    // Recheck appointment and revision after signing. Withdrawal returns no preview.
    const latest = await viewer.read(parameters);
    const current = latest.error ? null : itemFor(latest.data, parameters);
    if (
      !current || current.owner_id !== item.owner_id ||
      JSON.stringify(current.payload) !== JSON.stringify(item.payload)
    ) {
      return json({ error: "revision_unavailable" }, 409);
    }
    return json({ ...current, media_urls: urls });
  } catch {
    return json({ error: "review_unavailable" }, 503);
  }
}
