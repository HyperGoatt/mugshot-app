import { createClient } from "npm:@supabase/supabase-js@2.110.8";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";
import { handle } from "./handler.ts";
import { fetchPlace } from "./provider.ts";
Deno.serve((request) => {
  const base = Deno.env.get("SUPABASE_URL") ?? "",
    publicKey = getPublicSupabaseKey() ?? "",
    secret = getSecretSupabaseKey() ?? "";
  const options = {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: (input: RequestInfo | URL, init?: RequestInit) =>
        fetch(input, { ...init, signal: AbortSignal.timeout(15000) }),
    },
  };
  return handle(request, {
    authenticate: async (authorization) => {
      if (!base || !publicKey || !secret) return null;
      const viewer = createClient(base, publicKey, {
        ...options,
        global: {
          ...options.global,
          headers: { Authorization: authorization },
        },
      });
      const user = await viewer.auth.getUser(authorization.slice(7));
      if (user.error || !user.data.user) return null;
      const live = await viewer.rpc("is_live_account", {
        p_subject_id: user.data.user.id,
      });
      return !live.error && live.data === true ? user.data.user.id : null;
    },
    reserve: async (actor) => {
      const result = await createClient(base, secret, options).rpc(
        "reserve_cafe_verification_v1",
        { p_actor: actor },
      );
      if (result.error) throw Error("reservation_unavailable");
      return result.data === true;
    },
    verify: (provider, id) =>
      fetchPlace(provider, id, {
        appleKey: Deno.env.get("APPLE_MAPS_PRIVATE_KEY"),
        appleKeyID: Deno.env.get("APPLE_MAPS_KEY_ID"),
        appleTeamID: Deno.env.get("APPLE_MAPS_TEAM_ID"),
        googleKey: Deno.env.get("GOOGLE_PLACES_API_KEY"),
      }),
    save: async (actor, provider, id, place) => {
      const result = await createClient(base, secret, options).rpc(
        "accept_verified_cafe_v1",
        {
          p_actor: actor,
          p_provider: provider,
          p_place_id: id,
          p_place: place,
        },
      );
      if (result.error || !result.data) throw Error("save_unavailable");
      return result.data;
    },
  });
});
