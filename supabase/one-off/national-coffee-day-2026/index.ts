import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { constantTimeEqual } from "../../functions/deliver-activity/worker.ts";
import {
  body,
  campaignID,
  expiresAt,
  isCampaignOpen,
  isEligible,
  payload,
  type RegisteredDevice,
  title,
} from "./campaign.ts";

const projectURL = "https://quskamnfwglctqewwfln.supabase.co";
const topic = "co.mugshot.app";
const responseHeaders = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

function json(value: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: responseHeaders,
  });
}

function adminKey(): string | null {
  const campaignKey = Deno.env.get("NATIONAL_COFFEE_DAY_2026_ADMIN_KEY");
  if (campaignKey) return campaignKey;
  const keys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (keys) {
    try {
      const parsed = JSON.parse(keys) as Record<string, string>;
      return parsed["activity-delivery"] ?? parsed.default ??
        Object.values(parsed).find((value) => value.length > 0) ?? null;
    } catch {
      return null;
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

function authorized(request: Request): boolean {
  const supplied = request.headers.get("x-operator-secret") ?? "";
  const expected = Deno.env.get("NATIONAL_COFFEE_DAY_2026_OPERATOR_SECRET");
  return expected !== undefined && constantTimeEqual(supplied, expected);
}

function base64URL(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_")
    .replace(/=+$/u, "");
}

function decodePEM(value: string): ArrayBuffer {
  const binary = atob(value.replace(/-----[^-]+-----|\s/gu, ""));
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function providerToken(): Promise<string> {
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const productionTopic = Deno.env.get("APNS_PRODUCTION_TOPIC");
  if (!keyID || !teamID || !privateKey || productionTopic !== topic) {
    throw new Error("apns_configuration_unavailable");
  }
  const encode = (value: unknown) =>
    base64URL(new TextEncoder().encode(JSON.stringify(value)));
  const input = `${encode({ alg: "ES256", kid: keyID })}.${
    encode({ iss: teamID, iat: Math.floor(Date.now() / 1000) })
  }`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    decodePEM(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64URL(new Uint8Array(signature))}`;
}

async function send(
  token: string,
  notificationID: string,
): Promise<Record<string, unknown>> {
  const authorization = await providerToken();
  const response = await fetch(
    `https://api.push.apple.com/3/device/${encodeURIComponent(token)}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${authorization}`,
        "apns-topic": topic,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-id": notificationID,
        "apns-collapse-id": campaignID,
        "apns-expiration": String(Math.floor(expiresAt / 1000)),
        "content-type": "application/json",
      },
      body: JSON.stringify(payload()),
      signal: AbortSignal.timeout(10_000),
    },
  );
  let reason: string | null = null;
  if (!response.ok) {
    try {
      const parsed = await response.json() as { reason?: unknown };
      if (typeof parsed.reason === "string") reason = parsed.reason;
    } catch {
      reason = "apns_response_unreadable";
    }
  }
  return {
    accepted: response.ok,
    apns_status: response.status,
    apns_reason: reason,
    apns_id: response.headers.get("apns-id") ?? notificationID,
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const key = adminKey();
  if (!key) return json({ error: "admin_key_unavailable" }, 503);
  if (!authorized(request)) {
    return json({ error: "unauthorized" }, 401);
  }
  const runtimeProjectURL = Deno.env.get("SUPABASE_URL");
  if (runtimeProjectURL && runtimeProjectURL !== projectURL) {
    return json({ error: "wrong_project" }, 503);
  }
  let input: { action?: unknown; campaign_id?: unknown; device_id?: unknown };
  try {
    input = await request.json();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
  if (input.campaign_id !== campaignID) {
    return json({ error: "campaign_mismatch" }, 400);
  }
  const client = createClient(projectURL, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  if (input.action === "dry_run") {
    const [devices, preferences] = await Promise.all([
      client.from("user_devices").select(
        "id,user_id,push_token,platform,environment,disabled_at",
      ).limit(1000),
      client.from("notification_preferences").select("user_id,push_enabled")
        .limit(1000),
    ]);
    if (
      devices.error || preferences.error || !devices.data ||
      !preferences.data || devices.data.length >= 1000 ||
      preferences.data.length >= 1000
    ) {
      return json({ error: "audience_unavailable" }, 503);
    }
    const enabled = new Map(
      preferences.data.map((preference) => [
        preference.user_id,
        preference.push_enabled,
      ]),
    );
    const eligible = (devices.data as RegisteredDevice[]).filter((device) =>
      isEligible(device, enabled.get(device.user_id))
    );
    return json({
      campaign_id: campaignID,
      eligible_devices: eligible.length,
      title,
      body,
    });
  }
  if (!isCampaignOpen()) return json({ error: "campaign_closed" }, 410);
  if (input.action === "probe") {
    try {
      return json({
        campaign_id: campaignID,
        ...await send("0".repeat(64), crypto.randomUUID()),
      });
    } catch {
      return json({ error: "apns_probe_failed" }, 503);
    }
  }
  if (
    input.action !== "send" || typeof input.device_id !== "string" ||
    !/^[0-9a-f-]{36}$/iu.test(input.device_id)
  ) {
    return json({ error: "invalid_action_or_device" }, 400);
  }
  const device = await client.from("user_devices").select(
    "id,user_id,push_token,platform,environment,disabled_at",
  ).eq("id", input.device_id).maybeSingle();
  if (device.error || !device.data) {
    return json({ error: "device_unavailable" }, 404);
  }
  const preference = await client.from("notification_preferences")
    .select("push_enabled").eq("user_id", device.data.user_id).maybeSingle();
  if (
    preference.error || !isEligible(
      device.data as RegisteredDevice,
      preference.data?.push_enabled,
    )
  ) {
    return json({ error: "device_ineligible" }, 409);
  }
  try {
    return json({
      campaign_id: campaignID,
      device_id: input.device_id,
      ...await send(device.data.push_token, input.device_id),
    });
  } catch {
    return json({ error: "apns_send_uncertain" }, 503);
  }
});
