// Supabase Edge Function: notify-friends-new-visit
// Sends SILENT push notifications to all friends when a user posts a new visit
// This triggers widget updates without showing a visible notification

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// APNs Configuration (same secrets as send-push-notification)
// - APNS_KEY_ID: Your APNs Key ID
// - APNS_TEAM_ID: Your Apple Team ID  
// - APNS_BUNDLE_ID: Your app's bundle ID
// - APNS_KEY_CONTENT: The content of your .p8 key file
// - APNS_USE_SANDBOX: "true" for development, "false" for production

interface VisitCreatedPayload {
  type: "INSERT";
  table: "visits";
  record: {
    id: string;
    user_id: string;
    cafe_id: string;
    visibility: string;
    created_at: string;
  };
  schema: string;
  old_record: null;
}

interface SilentPushPayload {
  aps: {
    "content-available": 1;
    sound?: string;
  };
  type: string;
  visit_id: string;
  author_id: string;
  action: string;
}

// Generate JWT token for APNs authentication
async function generateAPNsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const keyContent = Deno.env.get("APNS_KEY_CONTENT");

  if (!keyId || !teamId || !keyContent) {
    throw new Error("Missing APNs configuration");
  }

  try {
    const { SignJWT, importPKCS8 } = await import("https://deno.land/x/jose@v4.14.4/index.ts");

    let privateKeyPEM: string;
    try {
      privateKeyPEM = atob(keyContent);
    } catch {
      privateKeyPEM = keyContent;
    }

    if (!privateKeyPEM.includes("BEGIN PRIVATE KEY")) {
      privateKeyPEM = `-----BEGIN PRIVATE KEY-----\n${privateKeyPEM}\n-----END PRIVATE KEY-----`;
    }

    const privateKey = await importPKCS8(privateKeyPEM, "ES256");

    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: keyId })
      .setIssuedAt()
      .setIssuer(teamId)
      .setExpirationTime("1h")
      .sign(privateKey);

    return jwt;
  } catch (error) {
    console.error(`Failed to generate APNs JWT: ${error.message}`);
    throw error;
  }
}

// Send silent push notification via APNs
async function sendSilentPush(
  deviceToken: string,
  payload: SilentPushPayload
): Promise<boolean> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID");
  const useSandbox = Deno.env.get("APNS_USE_SANDBOX") === "true";

  if (!bundleId) {
    throw new Error("Missing APNS_BUNDLE_ID");
  }

  const apnsHost = useSandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

  const url = `https://${apnsHost}/3/device/${deviceToken}`;

  try {
    const jwt = await generateAPNsJWT();

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "background", // Silent push type
        "apns-priority": "5", // Low priority for background updates (required for silent)
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`APNs error for token ${deviceToken.substring(0, 8)}...: ${response.status} ${errorText}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`Failed to send silent push: ${error.message}`);
    return false;
  }
}

// Fetch all friends of a user
async function fetchUserFriends(
  supabase: any,
  userId: string
): Promise<string[]> {
  // Query the friends table for bidirectional friendships
  const { data, error } = await supabase
    .from("friends")
    .select("user_id, friend_id")
    .or(`user_id.eq.${userId},friend_id.eq.${userId}`);

  if (error) {
    console.error(`Failed to fetch friends: ${error.message}`);
    return [];
  }

  // Extract friend IDs (the other user in each friendship)
  const friendIds = data.map((row: { user_id: string; friend_id: string }) => 
    row.user_id === userId ? row.friend_id : row.user_id
  );

  return friendIds;
}

// Fetch device tokens for multiple users
async function fetchDeviceTokens(
  supabase: any,
  userIds: string[]
): Promise<{ userId: string; token: string }[]> {
  if (userIds.length === 0) return [];

  const { data, error } = await supabase
    .from("user_devices")
    .select("user_id, push_token")
    .in("user_id", userIds)
    .eq("platform", "ios");

  if (error) {
    console.error(`Failed to fetch device tokens: ${error.message}`);
    return [];
  }

  return data.map((row: { user_id: string; push_token: string }) => ({
    userId: row.user_id,
    token: row.push_token,
  }));
}

Deno.serve(async (req) => {
  try {
    // Parse the webhook payload (from database trigger or HTTP call)
    const body = await req.json();
    
    // Handle both direct API calls and database webhook payloads
    let visitAuthorId: string;
    let visitId: string;
    let visibility: string;

    if (body.record) {
      // Database webhook payload format
      const payload = body as VisitCreatedPayload;
      visitAuthorId = payload.record.user_id;
      visitId = payload.record.id;
      visibility = payload.record.visibility;
    } else if (body.author_id && body.visit_id) {
      // Direct API call format
      visitAuthorId = body.author_id;
      visitId = body.visit_id;
      visibility = body.visibility || "everyone";
    } else {
      console.error("[SilentPush] Invalid payload format");
      return new Response(
        JSON.stringify({ success: false, error: "Invalid payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[SilentPush] Processing new visit: ${visitId} by user ${visitAuthorId.substring(0, 8)}...`);

    // Only send notifications for visible visits (friends or everyone)
    if (visibility === "private") {
      console.log("[SilentPush] Visit is private, skipping notifications");
      return new Response(
        JSON.stringify({ success: true, message: "Private visit, no notifications sent" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Check APNs configuration
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID");
    const apnsKeyContent = Deno.env.get("APNS_KEY_CONTENT");

    const isAPNsConfigured =
      apnsKeyId && apnsKeyId.trim() !== "" &&
      apnsTeamId && apnsTeamId.trim() !== "" &&
      apnsBundleId && apnsBundleId.trim() !== "" &&
      apnsKeyContent && apnsKeyContent.trim() !== "";

    if (!isAPNsConfigured) {
      console.log("[SilentPush] APNs not configured - skipping push delivery");
      return new Response(
        JSON.stringify({
          success: true,
          message: "APNs not configured",
          apns_configured: false,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase configuration");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get all friends of the visit author
    const friendIds = await fetchUserFriends(supabase, visitAuthorId);
    
    if (friendIds.length === 0) {
      console.log("[SilentPush] User has no friends, no notifications to send");
      return new Response(
        JSON.stringify({ success: true, message: "No friends to notify", friends_count: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[SilentPush] Found ${friendIds.length} friends to notify`);

    // Get device tokens for all friends
    const deviceTokens = await fetchDeviceTokens(supabase, friendIds);

    if (deviceTokens.length === 0) {
      console.log("[SilentPush] No device tokens found for friends");
      return new Response(
        JSON.stringify({ success: true, message: "No devices to notify", friends_count: friendIds.length, devices_count: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[SilentPush] Sending to ${deviceTokens.length} devices`);

    // Build silent push payload
    const silentPayload: SilentPushPayload = {
      aps: {
        "content-available": 1,
        // No alert, sound, or badge - this is a silent/background notification
      },
      type: "widget_update",
      visit_id: visitId,
      author_id: visitAuthorId,
      action: "refresh_friend_visits",
    };

    // Send silent push to all devices
    const results = await Promise.allSettled(
      deviceTokens.map(({ token }) => sendSilentPush(token, silentPayload))
    );

    const successCount = results.filter((r) => r.status === "fulfilled" && r.value).length;
    const failureCount = results.length - successCount;

    console.log(`[SilentPush] Sent ${successCount}/${deviceTokens.length} silent pushes successfully`);

    return new Response(
      JSON.stringify({
        success: true,
        friends_count: friendIds.length,
        devices_count: deviceTokens.length,
        sent: successCount,
        failed: failureCount,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[SilentPush] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

