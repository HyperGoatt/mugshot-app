import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type MediaSigningClient,
  resolvedCapabilityMediaURL,
} from "../_shared/capability-media.ts";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";

type ProfileProjection = {
  profile?: {
    display_name?: string;
    username?: string;
    bio?: string | null;
    avatar_url?: string | null;
    banner_url?: string | null;
  };
};

const headers = {
  "Cache-Control": "private, no-store",
  "X-Content-Type-Options": "nosniff",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "Referrer-Policy": "no-referrer",
};

function escapeHTML(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function validSlug(value: string): boolean {
  return /^[A-Za-z0-9_-]{24,128}$/.test(value);
}

function isPreviewAgent(userAgent: string): boolean {
  return /bot|crawler|spider|facebookexternalhit|twitterbot|linkedinbot|slackbot|discordbot|whatsapp|telegrambot|applebot/i
    .test(userAgent);
}

function metadataPage(input: {
  title: string;
  description: string;
  canonicalURL: string;
  imageURL?: string | null;
}): string {
  const image = input.imageURL
    ? `<meta property="og:image" content="${escapeHTML(input.imageURL)}">
  <meta name="twitter:image" content="${escapeHTML(input.imageURL)}">`
    : "";
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
  <title>${escapeHTML(input.title)}</title>
  <meta name="description" content="${escapeHTML(input.description)}">
  <meta name="robots" content="noindex,nofollow,noarchive">
  <link rel="canonical" href="${escapeHTML(input.canonicalURL)}">
  <meta property="og:type" content="profile">
  <meta property="og:url" content="${escapeHTML(input.canonicalURL)}">
  <meta property="og:title" content="${escapeHTML(input.title)}">
  <meta property="og:description" content="${escapeHTML(input.description)}">
  <meta name="twitter:card" content="summary_large_image">
  ${image}</head><body></body></html>`;
}

function unavailable(canonicalURL: string, head: boolean): Response {
  const body = metadataPage({
    title: "This Mugshot profile is not available",
    description: "Its sharing link may have been revoked.",
    canonicalURL,
  });
  return new Response(head ? null : body, {
    status: 404,
    headers: { ...headers, "Content-Type": "text/html; charset=utf-8" },
  });
}

async function resolveImage(
  profile: NonNullable<ProfileProjection["profile"]>,
  adminClient: MediaSigningClient | null,
): Promise<string | null> {
  for (const candidate of [profile.banner_url, profile.avatar_url]) {
    if (!candidate) continue;
    const resolved = await resolvedCapabilityMediaURL(candidate, adminClient);
    if (resolved) return resolved;
  }
  return null;
}

Deno.serve(async (request) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { ...headers, Allow: "GET, HEAD" },
    });
  }

  const requestURL = new URL(request.url);
  const slug = requestURL.searchParams.get("slug") ??
    requestURL.pathname.split("/").filter(Boolean).at(-1) ?? "";
  const marketingURL = Deno.env.get("MUGSHOT_MARKETING_URL") ??
    "https://mugshotapp.co";
  const webAppURL = Deno.env.get("MUGSHOT_WEB_APP_URL") ??
    "https://app.mugshotapp.co";
  const canonicalURL = `${marketingURL}/p/${encodeURIComponent(slug)}`;
  const pwaURL = `${webAppURL}/p/${encodeURIComponent(slug)}`;
  const isHead = request.method === "HEAD";
  const wantsMetadata = isHead || isPreviewAgent(
    request.headers.get("user-agent") ?? "",
  );

  if (!wantsMetadata) {
    return new Response("Opening Mugshot…", {
      status: 302,
      headers: { ...headers, Location: pwaURL },
    });
  }
  if (!validSlug(slug)) return unavailable(canonicalURL, isHead);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  if (!supabaseURL || !publicKey) return unavailable(canonicalURL, isHead);

  const client = createClient(supabaseURL, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.rpc("get_profile_share_v1", {
    p_slug: slug,
  });
  const projection = !error && data && typeof data === "object"
    ? data as ProfileProjection
    : null;
  if (!projection?.profile?.display_name || !projection.profile.username) {
    return unavailable(canonicalURL, isHead);
  }

  const secretKey = getSecretSupabaseKey();
  const adminClient = secretKey
    ? createClient(supabaseURL, secretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    : null;
  const imageURL = await resolveImage(projection.profile, adminClient);
  const title =
    `${projection.profile.display_name} (@${projection.profile.username}) on Mugshot`;
  const description = projection.profile.bio?.trim() ||
    `Explore ${projection.profile.display_name}'s public Mugshot profile.`;
  const body = metadataPage({ title, description, canonicalURL, imageURL });
  return new Response(isHead ? null : body, {
    status: 200,
    headers: { ...headers, "Content-Type": "text/html; charset=utf-8" },
  });
});
