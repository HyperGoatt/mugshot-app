import { createClient } from "npm:@supabase/supabase-js@2.110.8";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";
import { handleReview } from "./handler.ts";

Deno.serve((request) => {
  const base = Deno.env.get("SUPABASE_URL"),
    publicKey = getPublicSupabaseKey(),
    secret = getSecretSupabaseKey();
  if (!base || !publicKey || !secret) return handleReview(request, null);
  const boundedFetch: typeof fetch = (input, init) =>
    fetch(input, {
      ...init,
      signal: init?.signal
        ? AbortSignal.any([init.signal, AbortSignal.timeout(15000)])
        : AbortSignal.timeout(15000),
    });
  return handleReview(request, {
    baseURL: base,
    authenticate: async (authorization) => {
      const viewer = createClient(base, publicKey, {
        global: {
          headers: { Authorization: authorization },
          fetch: boundedFetch,
        },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const account = await viewer.auth.getUser(authorization.slice(7));
      if (account.error || !account.data.user) return null;
      return {
        read: (parameters) =>
          viewer.rpc("get_screening_review_item_v1", parameters),
      };
    },
    sign: async (bucket, path, expires) => {
      const admin = createClient(base, secret, {
        global: { fetch: boundedFetch },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const signed = await admin.storage.from(bucket).createSignedUrl(
        path,
        expires,
      );
      return signed.error ? null : signed.data.signedUrl;
    },
  });
});
