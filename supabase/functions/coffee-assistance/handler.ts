export const tasks = [
  "bag_scan",
  "recipe_import",
  "memory_search",
  "taste_insight",
  "brew_experiment",
  "weekly_reflection",
] as const;
export type Task = typeof tasks[number];
export type Evidence = { id: string; title: string; detail: string };
export type Input = {
  owner_id: string;
  request_id: string;
  consent_version: "selected-details-v1";
  task: Task;
  query: string;
  evidence: Evidence[];
  image: string | null;
};
export type Suggestion = {
  text: string;
  evidence_ids: string[];
  fields: { key: string; value: string; source_quote: string }[];
  search_terms: string[];
};
export type Dependencies = {
  enabled: boolean;
  authenticate: (authorization: string) => Promise<string | null>;
  reserve: (actor: string, requestID: string, task: Task) => Promise<boolean>;
  generate: (input: Input, signal: AbortSignal) => Promise<unknown>;
};
const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "private, no-store",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const bagKeys = [
  "roaster",
  "name",
  "producer",
  "origin",
  "process",
  "variety",
  "roastLevel",
  "roastDate",
  "tastingNotes",
];
const recipeKeys = [
  "name",
  "ingredient",
  "step",
  "method",
  "notes",
  "creatorCredit",
  "sourceURL",
];
const object = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const exact = (value: Record<string, unknown>, keys: string[]) =>
  Object.keys(value).length === keys.length &&
  keys.every((key) => key in value);
const string = (value: unknown, max: number): value is string =>
  typeof value === "string" && value.length <= max &&
  !/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value);
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

// Only small inline JPEGs. Never fetch a model-supplied or client-supplied URL.
export function validImage(value: string): boolean {
  if (
    !/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(value) ||
    value.length > 400000
  ) return false;
  try {
    const bytes = Uint8Array.from(
      atob(value.slice(23)),
      (x) => x.charCodeAt(0),
    );
    if (bytes[0] !== 0xff || bytes[1] !== 0xd8) return false;
    let offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset++] !== 0xff) return false;
      while (bytes[offset] === 0xff) offset++;
      const marker = bytes[offset++];
      if (marker === 0xda || marker === 0xd9) return false;
      const length = (bytes[offset] << 8) | bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) return false;
      if ([0xc0, 0xc1, 0xc2].includes(marker)) {
        const height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        const width = (bytes[offset + 5] << 8) | bytes[offset + 6];
        return width > 0 && height > 0 && width <= 1280 && height <= 1280;
      }
      offset += length;
    }
  } catch { /* Malformed input is a normal validation failure. */ }
  return false;
}

export function parseInput(value: unknown): Input | null {
  if (
    !object(value) ||
    !exact(value, [
      "owner_id",
      "request_id",
      "consent_version",
      "task",
      "query",
      "evidence",
      "image",
    ])
  ) return null;
  if (
    !string(value.owner_id, 36) || !uuid.test(value.owner_id) ||
    !string(value.request_id, 36) || !uuid.test(value.request_id)
  ) return null;
  if (
    value.consent_version !== "selected-details-v1" ||
    !tasks.includes(value.task as Task) || !string(value.query, 400)
  ) return null;
  if (!Array.isArray(value.evidence) || value.evidence.length > 40) return null;
  const ids = new Set<string>();
  let characters = 0;
  for (const item of value.evidence) {
    if (
      !object(item) || !exact(item, ["id", "title", "detail"]) ||
      !string(item.id, 80) || !/^[a-z0-9_-]+$/i.test(item.id) ||
      ids.has(item.id) || !string(item.title, 120) || !string(item.detail, 800)
    ) return null;
    ids.add(item.id);
    characters += item.title.length + item.detail.length;
  }
  if (characters > 20000) return null;
  if (
    value.image !== null &&
    (!string(value.image, 400000) ||
      !["bag_scan", "recipe_import"].includes(value.task as string) ||
      !validImage(value.image))
  ) return null;
  if (!value.evidence.length && value.image === null) return null;
  return value as Input;
}

export function validateSuggestion(
  value: unknown,
  input: Input,
): Suggestion | null {
  if (
    !object(value) ||
    !exact(value, ["text", "evidence_ids", "fields", "search_terms"]) ||
    !string(value.text, 1600) || !value.text.trim()
  ) return null;
  if (!Array.isArray(value.evidence_ids) || value.evidence_ids.length > 40) {
    return null;
  }
  const ids = new Set(input.evidence.map((x) => x.id));
  if (
    value.evidence_ids.some((id) => typeof id !== "string" || !ids.has(id)) ||
    new Set(value.evidence_ids).size !== value.evidence_ids.length
  ) return null;
  if (input.evidence.length > 0 && !value.evidence_ids.length) return null;
  if (!Array.isArray(value.fields) || value.fields.length > 24) return null;
  const keys = input.task === "bag_scan"
    ? bagKeys
    : input.task === "recipe_import"
    ? recipeKeys
    : [];
  for (const field of value.fields) {
    if (
      !object(field) || !exact(field, ["key", "value", "source_quote"]) ||
      !keys.includes(field.key as string) || !string(field.value, 400) ||
      !field.value.trim() || !string(field.source_quote, 400) ||
      !field.source_quote.trim()
    ) return null;
    if (
      !input.image &&
      !input.evidence.some((x) =>
        x.detail.includes(field.source_quote as string) ||
        x.title.includes(field.source_quote as string)
      )
    ) return null;
  }
  if (
    !Array.isArray(value.search_terms) || value.search_terms.length > 8 ||
    value.search_terms.some((x) => !string(x, 80))
  ) return null;
  return value as Suggestion;
}

export async function handle(
  request: Request,
  deps: Dependencies,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  if (!deps.enabled) return json({ error: "assistance_unavailable" }, 503);
  if (request.signal.aborted) return json({ error: "cancelled" }, 499);
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const actor = await deps.authenticate(authorization);
    if (!actor) return json({ error: "unauthorized" }, 401);
    // Bound streaming input too; Content-Length alone is controlled by the caller.
    const reader = request.body?.getReader();
    if (!reader) return json({ error: "invalid_input" }, 400);
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      size += next.value.length;
      if (size > 500000) {
        await reader.cancel();
        return json({ error: "input_too_large" }, 413);
      }
      chunks.push(next.value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    let raw: unknown;
    try {
      raw = JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      return json({ error: "invalid_input" }, 400);
    }
    const input = parseInput(raw);
    if (!input) return json({ error: "invalid_input" }, 400);
    if (input.owner_id.toLowerCase() !== actor.toLowerCase()) {
      return json({ error: "owner_mismatch" }, 403);
    }
    if (request.signal.aborted) return json({ error: "cancelled" }, 499);
    if (!await deps.reserve(actor, input.request_id, input.task)) {
      return json({ error: "assistance_limit" }, 429);
    }
    const result = validateSuggestion(
      await deps.generate(input, request.signal),
      input,
    );
    if (!result) return json({ error: "assistance_unavailable" }, 503);
    return json({ result });
  } catch {
    // Never return provider bodies, credentials, prompts or private journal content.
    return json({ error: "assistance_unavailable" }, 503);
  }
}
