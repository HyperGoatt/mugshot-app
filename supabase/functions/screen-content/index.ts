import { createClient } from "npm:@supabase/supabase-js@2.110.8";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";
import {
  processScreeningJob,
  type ScreeningClient,
  type ScreeningJob,
} from "./worker.ts";

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
async function sameSecret(left: string, right: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const hashes = await Promise.all(
    [left, right].map((value) =>
      crypto.subtle.digest("SHA-256", encoder.encode(value))
    ),
  );
  const a = new Uint8Array(hashes[0]), b = new Uint8Array(hashes[1]);
  let difference = 0;
  for (let index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const workerSecret = Deno.env.get("SCREENING_WORKER_SECRET");
  const provided = request.headers.get("x-screening-secret") ?? "";
  if (
    !workerSecret || provided.length > 512 ||
    !await sameSecret(provided, workerSecret)
  ) return json({ error: "unauthorized" }, 401);
  const supabaseURL = Deno.env.get("SUPABASE_URL"),
    adminKey = getSecretSupabaseKey(),
    apiKey = Deno.env.get("OPENAI_API_KEY");
  const noTrainingControlsVerified =
    Deno.env.get("SCREENING_NO_TRAINING_VERIFIED") === "true";
  if (
    !supabaseURL || !adminKey || !apiKey || !noTrainingControlsVerified ||
    Deno.env.get("SCREENING_DISCLOSURE_VERSION") !== "1" ||
    Deno.env.get("SCREENING_ENABLED") !== "true"
  ) return json({ error: "configuration_required" }, 503);
  const client = createClient(supabaseURL, adminKey, {
    global: {
      fetch: (input, init) =>
        fetch(input, {
          ...init,
          signal: init?.signal
            ? AbortSignal.any([init.signal, AbortSignal.timeout(15000)])
            : AbortSignal.timeout(15000),
        }),
    },
    auth: { autoRefreshToken: false, persistSession: false },
  }) as unknown as ScreeningClient;
  const claimed = await client.rpc("claim_screening_jobs_v1", { p_limit: 1 });
  if (claimed.error || !Array.isArray(claimed.data)) {
    return json({ error: "queue_unavailable" }, 503);
  }
  let applied = 0, stale = 0, deferred = 0;
  for (const job of claimed.data as ScreeningJob[]) {
    const result = await processScreeningJob(client, job, {
      supabaseURL,
      apiKey,
      noTrainingControlsVerified,
    });
    if (result === "applied") applied++;
    else if (result === "stale") stale++;
    else deferred++;
  }
  return json(
    { processed: claimed.data.length, applied, stale, deferred },
    deferred ? 503 : 200,
  );
});
