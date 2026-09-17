import { createClient } from "@supabase/supabase-js";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";

const headers = {
  "Cache-Control": "private, no-store",
  "X-Content-Type-Options": "nosniff",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "Referrer-Policy": "no-referrer",
  "Content-Security-Policy":
    "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  "Permissions-Policy": "camera=(), geolocation=(), microphone=()",
};

function escapeHTML(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll(
      "'",
      "&#039;",
    );
}

Deno.serve(async (request) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405, headers });
  }
  const url = new URL(request.url);
  const secret = url.searchParams.get("token") ??
    url.pathname.split("/").filter(Boolean).at(-1) ?? "";
  const configuredBaseURL = Deno.env.get("MUGSHOT_MARKETING_URL") ?? "";
  let baseURL = "https://mugshotapp.co";
  try {
    const candidate = new URL(configuredBaseURL);
    if (
      candidate.protocol === "https:" && !candidate.username &&
      !candidate.password
    ) {
      baseURL = candidate.origin;
    }
  } catch {
    // The first-party fallback remains authoritative for malformed configuration.
  }
  const configuredStoreURL = Deno.env.get("MUGSHOT_APP_STORE_URL") ?? "";
  const storeURL = configuredStoreURL.startsWith("https://apps.apple.com/")
    ? configuredStoreURL
    : baseURL;
  const canonicalURL = `${baseURL}/invite/${encodeURIComponent(secret)}`;
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  if (!supabaseURL || !publicKey || !/^[A-Za-z0-9_-]{40,64}$/.test(secret)) {
    return new Response("This invitation is unavailable.", {
      status: 404,
      headers,
    });
  }
  const client = createClient(supabaseURL, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.rpc("get_friend_invite_landing_v1", {
    p_secret: secret,
  });
  const invite = !error && Array.isArray(data) ? data[0] : null;
  if (!invite) {
    return new Response("This invitation is unavailable.", {
      status: 404,
      headers,
    });
  }
  const name = escapeHTML(String(invite.display_name));
  const username = escapeHTML(String(invite.username));
  const appURL = `mugshot://invite/${encodeURIComponent(secret)}`;
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow,noarchive"><title>${name} invited you to Mugshot</title>
  <link rel="canonical" href="${escapeHTML(canonicalURL)}"></head><body>
  <main><h1>${name} invited you to connect on Mugshot</h1><p>@${username}</p>
  <p><a href="${appURL}">Open Mugshot</a> or <a href="${
    escapeHTML(storeURL)
  }">install Mugshot</a>.</p>
  <p>After installing, reopen this invitation or enter its code in Find your people.</p></main>
  </body></html>`;
  return new Response(request.method === "HEAD" ? null : html, {
    status: 200,
    headers: { ...headers, "Content-Type": "text/html; charset=utf-8" },
  });
});
