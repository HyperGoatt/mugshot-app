import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type MediaSigningClient,
  resolvedCapabilityMediaURL,
  safeHTTPSURL,
} from "../_shared/capability-media.ts";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";
import { getSecretSupabaseKey } from "../_shared/secret-key.ts";
import {
  mugshotOGAlt,
  mugshotOGDescription,
  mugshotOGHeight,
  mugshotOGImageResponse,
  mugshotOGTitle,
  mugshotOGWidth,
} from "./og.tsx";

type PublicMugshot = {
  visit_id: string;
  slug: string;
  author_name: string;
  author_username: string | null;
  author_avatar_url: string | null;
  drink_name: string;
  context_name: string;
  rating: number;
  ratings: Record<string, unknown>;
  caption: string | null;
  cover_photo_url: string | null;
  photo_urls: string[];
  created_at: string;
};

const privateHeaders = {
  "Cache-Control": "private, no-store",
  "X-Content-Type-Options": "nosniff",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "Referrer-Policy": "no-referrer",
};

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function validSlug(value: string): boolean {
  return /^[A-Za-z0-9_-]{24,128}$/.test(value);
}

function isLinkPreviewAgent(userAgent: string): boolean {
  return /bot|crawler|spider|facebookexternalhit|twitterbot|linkedinbot|slackbot|discordbot|whatsapp|telegrambot|applebot/i
    .test(userAgent);
}

async function resolveMugshotMedia(
  mugshot: PublicMugshot,
  adminClient: MediaSigningClient | null,
): Promise<PublicMugshot> {
  const rawCandidates = [
    mugshot.cover_photo_url,
    ...(Array.isArray(mugshot.photo_urls) ? mugshot.photo_urls : []),
  ].filter((value): value is string =>
    typeof value === "string" && value.length > 0
  ).filter((value, index, values) => values.indexOf(value) === index)
    .slice(0, 10);
  const resolved = await Promise.all(
    rawCandidates.map((value) =>
      resolvedCapabilityMediaURL(value, adminClient)
    ),
  );
  const mediaByReference = new Map(
    rawCandidates.map((value, index) => [value, resolved[index]]),
  );
  const photoURLs = rawCandidates
    .map((value) => mediaByReference.get(value))
    .filter((value): value is string => Boolean(value));
  const coverPhotoURL = typeof mugshot.cover_photo_url === "string"
    ? mediaByReference.get(mugshot.cover_photo_url) ?? null
    : null;
  return {
    ...mugshot,
    author_avatar_url: safeHTTPSURL(mugshot.author_avatar_url),
    cover_photo_url: coverPhotoURL ?? photoURLs[0] ?? null,
    photo_urls: photoURLs,
  };
}

function redirectResponse(destination: string, head: boolean): Response {
  const headers = new Headers(privateHeaders);
  headers.set("Location", destination);
  return new Response(head ? null : "Opening Mugshot…", {
    status: 302,
    headers,
  });
}

function unavailableMetadata(canonicalURL: string, head: boolean): Response {
  const html = metadataPage({
    title: "This Mugshot is not available",
    description: "It may have been removed or its audience may have changed.",
    canonicalURL,
  });
  return new Response(head ? null : html, {
    status: 404,
    headers: {
      ...privateHeaders,
      "Content-Type": "text/html; charset=utf-8",
    },
  });
}

function metadataPage(input: {
  title: string;
  description: string;
  canonicalURL: string;
  imageURL?: string | null;
  imageAlt?: string;
}): string {
  const image = input.imageURL
    ? `<meta property="og:image" content="${escapeHTML(input.imageURL)}">
  <meta property="og:image:width" content="${mugshotOGWidth}">
  <meta property="og:image:height" content="${mugshotOGHeight}">
  <meta property="og:image:alt" content="${
      escapeHTML(input.imageAlt ?? input.title)
    }">
  <meta name="twitter:image" content="${escapeHTML(input.imageURL)}">`
    : "";
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${escapeHTML(input.title)}</title>
  <meta name="description" content="${escapeHTML(input.description)}">
  <meta name="robots" content="noindex,nofollow,noarchive">
  <link rel="canonical" href="${escapeHTML(input.canonicalURL)}">
  <meta property="og:type" content="article">
  <meta property="og:url" content="${escapeHTML(input.canonicalURL)}">
  <meta property="og:title" content="${escapeHTML(input.title)}">
  <meta property="og:description" content="${escapeHTML(input.description)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHTML(input.title)}">
  <meta name="twitter:description" content="${escapeHTML(input.description)}">
  ${image}
</head>
<body></body>
</html>`;
}

Deno.serve(async (request) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { ...privateHeaders, Allow: "GET, HEAD" },
    });
  }

  const requestURL = new URL(request.url);
  const slug = requestURL.searchParams.get("slug") ??
    requestURL.pathname.split("/").filter(Boolean).at(-1) ??
    "";
  const marketingURL = Deno.env.get("MUGSHOT_MARKETING_URL") ??
    "https://mugshotapp.co";
  const webAppURL = Deno.env.get("MUGSHOT_WEB_APP_URL") ??
    "https://app.mugshotapp.co";
  const pwaURL = `${webAppURL}/m/${encodeURIComponent(slug)}`;
  const canonicalURL = `${marketingURL}/m/${encodeURIComponent(slug)}`;
  const isHead = request.method === "HEAD";
  const wantsMetadata = isHead || isLinkPreviewAgent(
    request.headers.get("user-agent") ?? "",
  );

  // Human browsers always continue to the PWA's canonical VisitDetail route.
  // Invalid or revoked slugs are handled there by the same unavailable state.
  if (
    !wantsMetadata && requestURL.searchParams.get("format") !== "og" &&
    requestURL.searchParams.get("format") !== "json"
  ) {
    return redirectResponse(pwaURL, isHead);
  }

  if (!validSlug(slug)) {
    return unavailableMetadata(canonicalURL, isHead);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  if (!supabaseURL || !publicKey) {
    return unavailableMetadata(canonicalURL, isHead);
  }

  const client = createClient(supabaseURL, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.rpc("get_public_mugshot_share_v1", {
    p_slug: slug,
  });
  const mugshot = !error && Array.isArray(data)
    ? (data[0] as PublicMugshot | undefined)
    : undefined;
  if (!mugshot) return unavailableMetadata(canonicalURL, isHead);

  const secretKey = getSecretSupabaseKey();
  const adminClient = secretKey
    ? createClient(supabaseURL, secretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    : null;
  const resolvedMugshot = await resolveMugshotMedia(mugshot, adminClient);

  if (requestURL.searchParams.get("format") === "json") {
    return new Response(isHead ? null : JSON.stringify(resolvedMugshot), {
      status: 200,
      headers: {
        ...privateHeaders,
        "Content-Type": "application/json; charset=utf-8",
      },
    });
  }

  const ogInput = {
    authorName: resolvedMugshot.author_name,
    drinkName: resolvedMugshot.drink_name,
    contextName: resolvedMugshot.context_name,
    coverPhotoURL: resolvedMugshot.cover_photo_url,
    appIconURL: `${marketingURL}/icons/app-icon.png`,
  };
  if (requestURL.searchParams.get("format") === "og") {
    if (isHead) {
      return new Response(null, {
        status: 200,
        headers: {
          ...privateHeaders,
          "Content-Type": "image/png",
        },
      });
    }
    return mugshotOGImageResponse(ogInput);
  }

  const title = mugshotOGTitle;
  const description = mugshotOGDescription(ogInput);
  return new Response(
    isHead ? null : metadataPage({
      title,
      description,
      canonicalURL,
      imageURL: `${canonicalURL}?format=og`,
      imageAlt: mugshotOGAlt(ogInput),
    }),
    {
      status: 200,
      headers: {
        ...privateHeaders,
        "Content-Type": "text/html; charset=utf-8",
      },
    },
  );
});
