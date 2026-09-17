import { createClient } from "@supabase/supabase-js";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";
import {
  isExplicitlyEnabled,
  keyedDigest,
  privateHeaders,
  validateItems,
} from "./handler.ts";

function response(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: privateHeaders,
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return response(405, { error: "method_not_allowed" });
  }
  const authorization = request.headers.get("Authorization");
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  const secretKey = getSecretSupabaseKey();
  const hmacSecret = Deno.env.get("PEOPLE_DISCOVERY_HMAC_KEY_V1");
  const isEnabled = isExplicitlyEnabled(
    Deno.env.get("PEOPLE_DISCOVERY_ENABLED"),
  );
  if (
    !authorization || !supabaseURL || !publicKey || !secretKey || !hmacSecret ||
    !isEnabled
  ) {
    return response(503, { error: "service_unavailable" });
  }

  const userClient = createClient(supabaseURL, publicKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return response(401, { error: "authentication_required" });
  }

  const declaredLength = Number(request.headers.get("Content-Length") ?? "0");
  if (declaredLength > 32_768) {
    return response(413, { error: "request_too_large" });
  }
  let payload: Record<string, unknown>;
  try {
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > 32_768) {
      return response(413, { error: "request_too_large" });
    }
    payload = JSON.parse(rawBody);
  } catch {
    return response(400, { error: "invalid_request" });
  }
  const action = payload.action;
  if (payload.consent_version !== 1) {
    return response(400, { error: "unsupported_consent_version" });
  }
  const admin = createClient(supabaseURL, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: capabilityEnabled, error: capabilityError } = await admin.rpc(
    "service_people_discovery_enabled_v1",
    { p_capability: "contact_matching" },
  );
  if (capabilityError || capabilityEnabled !== true) {
    return response(503, { error: "service_unavailable" });
  }

  if (action === "enroll_email") {
    const email = authData.user.email;
    if (!email || !authData.user.email_confirmed_at) {
      return response(409, { error: "verified_email_required" });
    }
    const digest = await keyedDigest(
      email.trim().toLocaleLowerCase("en-US"),
      hmacSecret,
    );
    const { error } = await admin.rpc("service_set_discovery_email_v1", {
      p_user_id: authData.user.id,
      p_digest: digest,
      p_key_version: 1,
      p_verified_at: authData.user.email_confirmed_at,
    });
    if (error) return response(409, { error: "enrollment_failed" });
    return response(200, { enrolled: true });
  }

  if (action !== "match") return response(400, { error: "invalid_action" });
  const items = validateItems(payload.items);
  if (!items) return response(400, { error: "invalid_contacts" });
  const addresses = [...new Set(items.flatMap((item) => item.emails))];
  if (addresses.length > 200) {
    return response(400, { error: "too_many_addresses" });
  }
  if (addresses.length === 0) {
    return response(200, { items: [], has_more: false });
  }
  const { data: allowed, error: budgetError } = await userClient.rpc(
    "consume_contact_match_budget_v1",
    { p_address_count: addresses.length },
  );
  if (budgetError || allowed !== true) {
    return new Response(JSON.stringify({ error: "rate_limited" }), {
      status: 429,
      headers: { ...privateHeaders, "Retry-After": "3600" },
    });
  }
  const digestEntries = await Promise.all(addresses.map(async (address) =>
    [
      address,
      await keyedDigest(address, hmacSecret),
    ] as const
  ));
  const digestByAddress = new Map(digestEntries);
  const { data: matches, error } = await admin.rpc(
    "service_match_discovery_digests_v1",
    {
      p_actor_id: authData.user.id,
      p_digests: digestEntries.map(([, digest]) => digest),
      p_key_version: 1,
    },
  );
  if (error) return response(503, { error: "match_unavailable" });
  const byDigest = new Map<string, unknown[]>();
  for (const match of matches ?? []) {
    const digest = String(match.digest);
    const existing = byDigest.get(digest) ?? [];
    existing.push({
      id: match.id,
      display_name: match.display_name,
      username: match.username,
      avatar_url: match.avatar_url,
      friendship_state: match.friendship_state,
      mutual_friend_count: match.mutual_friend_count,
    });
    byDigest.set(digest, existing);
  }
  return response(200, {
    items: items.map((item) => ({
      item_key: item.item_key,
      matches: [
        ...new Map(
          item.emails.flatMap((address) =>
            (byDigest.get(digestByAddress.get(address) ?? "") ?? []).map((
              match: any,
            ) => [match.id, match])
          ),
        ).values(),
      ],
    })),
    has_more: false,
  });
});
