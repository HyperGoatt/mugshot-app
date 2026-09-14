import { type Place, placeID, type Provider } from "./provider.ts";
export type Dependencies = {
  authenticate(authorization: string): Promise<string | null>;
  reserve(actor: string): Promise<boolean>;
  verify(provider: Provider, id: string): Promise<Place>;
  save(
    actor: string,
    provider: Provider,
    id: string,
    place: Place,
  ): Promise<unknown>;
};
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (value: unknown, status: number) =>
  new Response(JSON.stringify(value), {
    status,
    headers: {
      ...cors,
      "Content-Type": "application/json",
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
export async function handle(
  request: Request,
  deps: Dependencies,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const authorization = request.headers.get("Authorization") ?? "";
  if (!/^Bearer .{1,8192}$/.test(authorization)) {
    return json({ error: "authentication_required" }, 401);
  }
  try {
    const actor = await deps.authenticate(authorization);
    if (!actor) return json({ error: "authentication_required" }, 401);
    const reader = request.body?.getReader();
    if (!reader) return json({ error: "invalid_request" }, 400);
    let raw = "", size = 0;
    const decoder = new TextDecoder();
    try {
      while (true) {
        const part = await reader.read();
        if (part.done) break;
        size += part.value.length;
        if (size > 1024) {
          await reader.cancel();
          return json({ error: "invalid_request" }, 400);
        }
        raw += decoder.decode(part.value, { stream: true });
      }
      raw += decoder.decode();
    } finally {
      reader.releaseLock();
    }
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      return json({ error: "invalid_request" }, 400);
    }
    if (
      !input || !["apple", "google"].includes(input.provider) ||
      !placeID(input.place_id) ||
      Object.keys(input).some((k) => !["provider", "place_id"].includes(k))
    ) return json({ error: "invalid_request" }, 400);
    if (!await deps.reserve(actor)) {
      return json({ error: "try_again_later" }, 429);
    }
    const place = await deps.verify(input.provider, input.place_id);
    return json(
      await deps.save(actor, input.provider, input.place_id, place),
      200,
    );
  } catch {
    // Never return provider URLs, keys, submitted identifiers or raw exceptions.
    return json({
      error: "Cafe verification is temporarily unavailable. Please try again.",
    }, 503);
  }
}
