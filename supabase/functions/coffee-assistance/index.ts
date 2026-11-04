import { createClient } from "npm:@supabase/supabase-js@2.110.8";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";
import { handle } from "./handler.ts";
import { generate } from "./provider.ts";

Deno.serve((request) => {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const publicKey = getPublicSupabaseKey() ?? "";
  const secret = getSecretSupabaseKey() ?? "";
  const key = Deno.env.get("OPENAI_API_KEY") ?? "";
  const model = Deno.env.get("MUGSHOT_AI_MODEL") ?? "";
  const options = {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: (input: RequestInfo | URL, init?: RequestInit) =>
        fetch(input, { ...init, signal: AbortSignal.timeout(10000) }),
    },
  };
  return handle(request, {
    enabled: Deno.env.get("MUGSHOT_AI_ENABLED") === "true" && !!url &&
      !!publicKey && !!secret && !!key && model === "gpt-6-luna",
    authenticate: async (authorization) => {
      const viewer = createClient(url, publicKey, {
        ...options,
        global: {
          ...options.global,
          headers: { Authorization: authorization },
        },
      });
      const result = await viewer.auth.getUser(authorization.slice(7));
      if (result.error || !result.data.user) return null;
      const live = await viewer.rpc("is_live_account", {
        p_subject_id: result.data.user.id,
      });
      return !live.error && live.data === true ? result.data.user.id : null;
    },
    reserve: async (actor, requestID, task) => {
      const result = await createClient(url, secret, options).rpc(
        "reserve_coffee_assistance_v1",
        { p_actor: actor, p_request: requestID, p_task: task },
      );
      if (result.error) throw Error("reservation_unavailable");
      return result.data === true;
    },
    generate: (input, signal) => generate(input, { key, model }, signal),
  });
});
