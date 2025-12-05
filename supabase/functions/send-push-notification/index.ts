// Supabase Edge Function: send-push-notification
// Sends push notifications to iOS devices via APNs when a notification is created

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// APNs Configuration
// These should be set as Supabase Edge Function secrets:
// - APNS_KEY_ID: Your APNs Key ID (from Apple Developer account)
// - APNS_TEAM_ID: Your Apple Team ID
// - APNS_BUNDLE_ID: Your app's bundle ID (e.g., com.yourcompany.mugshot)
// - APNS_KEY_CONTENT: The content of your .p8 key file (base64 encoded or raw)
// - APNS_USE_SANDBOX: "true" for development, "false" for production

interface NotificationPayload {
  aps: {
    alert: {
      title: string;
      body: string;
    };
    sound: string;
    badge?: number;
  };
  type: string;
  actor_username?: string;
  actor_avatar_url?: string;
  visit_id?: string;
  friend_user_id?: string;
  cafe_name?: string;
  tap_action: string;
}

interface NotificationRecord {
  id: string;
  user_id: string;
  actor_user_id: string;
  type: string;
  visit_id?: string;
  comment_id?: string;
  created_at: string;
}

interface UserDevice {
  id: string;
  user_id: string;
  push_token: string;
  platform: string;
}

// Map notification types from database to iOS-friendly types
function mapNotificationType(dbType: string): string {
  const typeMap: Record<string, string> = {
    "like": "like",
    "comment": "comment",
    "reply": "reply",
    "mention": "mention",
    "follow": "follow",
    "friend_request": "friend_request",
    "friend_request_accepted": "friend_accept", // Map to iOS type
    "new_visit_from_friend": "new_visit_from_friend",
  };
  return typeMap[dbType] || "system";
}

// Determine tap action based on notification type
function determineTapAction(
  type: string,
  visitId?: string,
  friendUserId?: string
): string {
  switch (type) {
    case "like":
    case "comment":
    case "new_visit_from_friend":
      return visitId ? "visit_detail" : "friends_feed";
    case "friend_request":
    case "friend_accept":
      return friendUserId ? "friend_profile" : "notifications";
    default:
      return "friends_feed";
  }
}

// Generate JWT token for APNs authentication using jose library
async function generateAPNsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const keyContent = Deno.env.get("APNS_KEY_CONTENT");

  if (!keyId || !teamId || !keyContent) {
    throw new Error("Missing APNs configuration. Set APNS_KEY_ID, APNS_TEAM_ID, and APNS_KEY_CONTENT secrets.");
  }

  try {
    // Import jose library for JWT signing
    const { SignJWT, importPKCS8 } = await import("https://deno.land/x/jose@v4.14.4/index.ts");

    // Decode base64 key if needed, or use raw content
    let privateKeyPEM: string;
    try {
      // Try to decode as base64 first
      privateKeyPEM = atob(keyContent);
    } catch {
      // If not base64, use as-is
      privateKeyPEM = keyContent;
    }

    // Ensure the key is in PEM format
    if (!privateKeyPEM.includes("BEGIN PRIVATE KEY")) {
      privateKeyPEM = `-----BEGIN PRIVATE KEY-----\n${privateKeyPEM}\n-----END PRIVATE KEY-----`;
    }

    // Import the private key
    const privateKey = await importPKCS8(privateKeyPEM, "ES256");

    // Create and sign JWT
    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: keyId })
      .setIssuedAt()
      .setIssuer(teamId)
      .setExpirationTime("1h")
      .sign(privateKey);

    return jwt;
  } catch (error) {
    console.error(`Failed to generate APNs JWT: ${error.message}`);
    throw new Error(`JWT generation failed: ${error.message}`);
  }
}

// Send push notification via APNs
async function sendAPNsNotification(
  deviceToken: string,
  payload: NotificationPayload
): Promise<boolean> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID");
  const useSandbox = Deno.env.get("APNS_USE_SANDBOX") === "true";
  
  if (!bundleId) {
    throw new Error("Missing APNS_BUNDLE_ID secret");
  }

  const apnsHost = useSandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

  const url = `https://${apnsHost}/3/device/${deviceToken}`;

  try {
    // Generate JWT token for authentication
    const jwt = await generateAPNsJWT();

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`APNs error: ${response.status} ${errorText}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`Failed to send APNs notification: ${error.message}`);
    return false;
  }
}

// Fetch actor user info (username, avatar) for notification
async function fetchActorInfo(
  supabase: any,
  actorUserId: string
): Promise<{ username?: string; avatar_url?: string }> {
  const { data, error } = await supabase
    .from("users")
    .select("username, avatar_url")
    .eq("id", actorUserId)
    .single();

  if (error || !data) {
    console.error(`Failed to fetch actor info: ${error?.message}`);
    return {};
  }

  return {
    username: data.username,
    avatar_url: data.avatar_url,
  };
}

// Fetch visit info (cafe name) for visit-related notifications
async function fetchVisitInfo(
  supabase: any,
  visitId: string
): Promise<{ cafe_name?: string }> {
  const { data, error } = await supabase
    .from("visits")
    .select("cafe:cafes(name)")
    .eq("id", visitId)
    .single();

  if (error || !data) {
    console.error(`Failed to fetch visit info: ${error?.message}`);
    return {};
  }

  return {
    cafe_name: data.cafe?.name,
  };
}

// Build notification message based on type
function buildNotificationMessage(
  type: string,
  actorUsername?: string
): { title: string; body: string } {
  const actorLabel = actorUsername || "Someone";
  
  const messages: Record<string, { title: string; body: string }> = {
    like: {
      title: "New Like",
      body: `${actorLabel} liked your visit`,
    },
    comment: {
      title: "New Comment",
      body: `${actorLabel} commented on your visit`,
    },
    new_visit_from_friend: {
      title: "New Visit",
      body: `${actorLabel} posted a new visit`,
    },
    friend_request: {
      title: "Friend Request",
      body: `${actorLabel} sent you a friend request`,
    },
    friend_accept: {
      title: "Friend Request Accepted",
      body: `${actorLabel} accepted your friend request`,
    },
    friend_join: {
      title: "Friend Joined",
      body: `${actorLabel} joined Mugshot`,
    },
  };

  return messages[type] || {
    title: "New Notification",
    body: "You have a new notification",
  };
}

Deno.serve(async (req) => {
  try {
    // Parse the notification record from the trigger
    const notification: NotificationRecord = await req.json();

    console.log(`[Push] Processing notification: ${notification.id}, type: ${notification.type}, user_id: ${notification.user_id}`);

    // APNs Configuration Guard
    // Check if APNs is configured - if not, gracefully skip push delivery
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
      console.log(`[Push] APNs not configured – skipping push delivery but keeping notification row.`);
      console.log(`[Push] To enable push notifications, configure APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, and APNS_KEY_CONTENT secrets.`);
      
      return new Response(
        JSON.stringify({
          status: "ok",
          message: "APNs not configured; notification stored but no push sent.",
          apns_configured: false,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[Push] APNs configured; sending push notifications...`);

    // Initialize Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase configuration");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch user devices for the notification recipient
    const { data: devices, error: devicesError } = await supabase
      .from("user_devices")
      .select("push_token, platform")
      .eq("user_id", notification.user_id)
      .eq("platform", "ios");

    if (devicesError) {
      throw new Error(`Failed to fetch user devices: ${devicesError.message}`);
    }

    if (!devices || devices.length === 0) {
      console.log(`[Push] No iOS devices found for user ${notification.user_id}`);
      return new Response(
        JSON.stringify({ success: true, message: "No devices to notify" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch actor info
    const actorInfo = await fetchActorInfo(supabase, notification.actor_user_id);

    // Fetch visit info if applicable
    let visitInfo: { cafe_name?: string } = {};
    if (notification.visit_id) {
      visitInfo = await fetchVisitInfo(supabase, notification.visit_id);
    }

    // Map notification type
    const mappedType = mapNotificationType(notification.type);

    // Determine tap action
    const tapAction = determineTapAction(
      mappedType,
      notification.visit_id,
      notification.actor_user_id // For friend requests, actor is the friend
    );

    // Build notification message
    const message = buildNotificationMessage(mappedType, actorInfo.username);

    // Build APNs payload
    const payload: NotificationPayload = {
      aps: {
        alert: {
          title: message.title,
          body: message.body,
        },
        sound: "default",
        badge: 1, // You may want to fetch actual unread count
      },
      type: mappedType,
      actor_username: actorInfo.username,
      actor_avatar_url: actorInfo.avatar_url,
      visit_id: notification.visit_id,
      friend_user_id: mappedType.includes("friend") ? notification.actor_user_id : undefined,
      cafe_name: visitInfo.cafe_name,
      tap_action: tapAction,
    };

    // Send to all user's iOS devices
    const results = await Promise.allSettled(
      devices.map((device: UserDevice) =>
        sendAPNsNotification(device.push_token, payload)
      )
    );

    const successCount = results.filter((r) => r.status === "fulfilled" && r.value).length;
    const failureCount = results.length - successCount;

    console.log(
      `[Push] Sent ${successCount}/${devices.length} notifications successfully`
    );

    if (failureCount > 0) {
      console.warn(`[Push] ${failureCount} notifications failed to send`);
    }

    return new Response(
      JSON.stringify({
        status: "ok",
        success: true,
        sent: successCount,
        failed: failureCount,
        apns_configured: true,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[Push] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

