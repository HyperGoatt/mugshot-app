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

const sharedHeaders = {
  "Content-Type": "text/html; charset=utf-8",
  "X-Content-Type-Options": "nosniff",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "Referrer-Policy": "no-referrer",
  "Cross-Origin-Resource-Policy": "same-site",
  "Content-Security-Policy":
    "default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
};

const successHeaders = {
  ...sharedHeaders,
  "Cache-Control": "private, no-store",
};

const unavailableHeaders = {
  ...sharedHeaders,
  "Cache-Control": "private, no-store",
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

function ratingEntries(
  value: Record<string, unknown>,
): Array<[string, number]> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  return Object.entries(value)
    .filter((entry): entry is [string, number] =>
      typeof entry[1] === "number" &&
      Number.isFinite(entry[1]) &&
      entry[1] >= 0 &&
      entry[1] <= 5
    )
    .slice(0, 12);
}

function ratingLabel(value: string): string {
  return value
    .replaceAll("_", " ")
    .replace(/\b\w/g, (character) => character.toUpperCase())
    .slice(0, 60);
}

function neutralPage(downloadURL: string, head = false): Response {
  const response = new Response(
    page({
      title: "This Mugshot is not available",
      description: "It may have been removed or its audience may have changed.",
      body: `
      <main class="neutral">
        <div class="mark">MUGSHOT</div>
        <h1>This Mugshot is not available.</h1>
        <p>It may have been removed or its audience may have changed.</p>
        ${
        downloadURL
          ? `<a class="button" href="${
            escapeHTML(
              downloadURL,
            )
          }">Get Mugshot</a>`
          : ""
      }
      </main>
    `,
    }),
    { status: 404, headers: unavailableHeaders },
  );
  return head
    ? new Response(null, { status: response.status, headers: response.headers })
    : response;
}

function page(input: {
  title: string;
  description: string;
  body: string;
  image?: string | null;
  imageAlt?: string;
  canonical?: string;
}): string {
  const imageMeta = input.image
    ? `<meta property="og:image" content="${escapeHTML(input.image)}">
  <meta property="og:image:width" content="${mugshotOGWidth}">
  <meta property="og:image:height" content="${mugshotOGHeight}">
  <meta property="og:image:alt" content="${
      escapeHTML(input.imageAlt ?? mugshotOGTitle)
    }">
  <meta name="twitter:image" content="${escapeHTML(input.image)}">
  <meta name="twitter:image:alt" content="${
      escapeHTML(input.imageAlt ?? mugshotOGTitle)
    }">`
    : "";
  const canonicalMeta = input.canonical
    ? `<link rel="canonical" href="${escapeHTML(input.canonical)}">
  <meta property="og:url" content="${escapeHTML(input.canonical)}">`
    : "";
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${escapeHTML(input.title)}</title>
  <meta name="description" content="${escapeHTML(input.description)}">
  <meta name="robots" content="noindex,nofollow,noarchive">
  ${canonicalMeta}
  <meta property="og:type" content="article">
  <meta property="og:title" content="${escapeHTML(input.title)}">
  <meta property="og:description" content="${escapeHTML(input.description)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHTML(input.title)}">
  <meta name="twitter:description" content="${escapeHTML(input.description)}">
  ${imageMeta}
  <style>
    :root { color-scheme: light; --cream:#f6f0e4; --foam:#fffdf8; --espresso:#33231d; --sage:#607763; --mint:#cfe0cf; --line:#d9d0c1; }
    * { box-sizing:border-box; }
    body { margin:0; min-height:100vh; background:var(--cream); color:var(--espresso); font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
    body::before { content:""; position:fixed; inset:0; pointer-events:none; opacity:.22; background:radial-gradient(circle at 15% 12%,var(--mint),transparent 32%),radial-gradient(circle at 85% 88%,#e8d8bd,transparent 28%); }
    main { position:relative; width:min(94vw,760px); margin:0 auto; padding:32px 20px 64px; }
    .mark { color:var(--sage); font-size:12px; font-weight:900; letter-spacing:.24em; margin-bottom:18px; }
    .card { overflow:hidden; border:1px solid var(--line); border-radius:28px; background:var(--foam); box-shadow:0 18px 44px rgba(51,35,29,.12); }
    .gallery { display:grid; grid-auto-flow:column; grid-auto-columns:100%; overflow-x:auto; scroll-snap-type:x mandatory; scrollbar-width:none; background:#dfd2bd; }
    .gallery::-webkit-scrollbar { display:none; }
    .photo { position:relative; margin:0; scroll-snap-align:start; }
    .cover { display:block; width:100%; aspect-ratio:4/5; object-fit:cover; background:#dfd2bd; }
    .count { position:absolute; right:16px; top:16px; padding:7px 11px; border-radius:999px; color:white; background:rgba(24,18,14,.72); font-size:12px; font-weight:800; }
    .content { padding:28px; }
    .author { display:flex; align-items:center; gap:12px; margin-bottom:22px; }
    .avatar { width:44px; height:44px; border-radius:50%; object-fit:cover; background:var(--mint); }
    .author-name { font-weight:850; }
    .author-handle { margin-top:2px; color:#76675e; font-size:13px; }
    .route { display:flex; align-items:center; gap:9px; color:var(--sage); font-size:12px; font-weight:800; text-transform:uppercase; letter-spacing:.1em; }
    .route::before { content:""; width:9px; height:9px; border-radius:50%; background:var(--sage); box-shadow:18px 0 0 -3px var(--sage); margin-right:16px; }
    h1 { margin:14px 0 8px; font-family:Georgia,serif; font-size:clamp(36px,8vw,62px); line-height:1; letter-spacing:-.035em; }
    .meta { color:#715f54; font-weight:650; }
    .score { margin:24px 0 0; display:flex; align-items:baseline; gap:8px; font-family:Georgia,serif; font-size:54px; font-weight:700; }
    .score span { font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; color:var(--sage); font-size:11px; letter-spacing:.12em; }
    blockquote { margin:22px 0 0; padding-left:16px; border-left:3px solid var(--mint); color:#5a4941; font-family:Georgia,serif; font-size:20px; line-height:1.45; }
    .ratings { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:10px; margin-top:24px; }
    .rating { padding:13px 14px; border:1px solid var(--line); border-radius:14px; background:#fbf8f1; }
    .rating-name { color:#76675e; font-size:11px; font-weight:800; letter-spacing:.06em; text-transform:uppercase; }
    .rating-value { margin-top:5px; font-family:Georgia,serif; font-size:24px; }
    .actions { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:24px; }
    .button { display:inline-flex; min-height:50px; padding:0 18px; align-items:center; justify-content:center; border-radius:14px; background:#143d31; color:white; text-align:center; text-decoration:none; font-weight:800; }
    .button.secondary { border:1px solid var(--line); background:var(--foam); color:var(--espresso); }
    .signup { display:block; margin-top:14px; color:var(--sage); text-align:center; font-size:13px; font-weight:750; }
    .note { margin:22px 0 0; color:#76675e; font-size:13px; line-height:1.5; }
    .neutral { min-height:80vh; display:flex; flex-direction:column; justify-content:center; align-items:flex-start; }
    .neutral h1 { max-width:560px; }
    .neutral p { color:#715f54; font-size:18px; }
    @media (max-width:540px) { .content { padding:22px; } .ratings,.actions { grid-template-columns:1fr; } }
  </style>
</head>
<body>${input.body}</body>
</html>`;
}

Deno.serve(async (request) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { ...unavailableHeaders, Allow: "GET, HEAD" },
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
  const downloadURL = Deno.env.get("MUGSHOT_DOWNLOAD_URL") ??
    `${marketingURL}/download?placement=share`;
  if (!validSlug(slug)) {
    return neutralPage(downloadURL, request.method === "HEAD");
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  if (!supabaseURL || !publicKey) {
    return neutralPage(downloadURL, request.method === "HEAD");
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
  if (!mugshot) return neutralPage(downloadURL, request.method === "HEAD");
  const secretKey = getSecretSupabaseKey();
  const adminClient = secretKey
    ? createClient(supabaseURL, secretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    : null;
  const resolvedMugshot = await resolveMugshotMedia(mugshot, adminClient);

  if (requestURL.searchParams.get("format") === "json") {
    const response = new Response(JSON.stringify(resolvedMugshot), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "private, no-store",
        "X-Content-Type-Options": "nosniff",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
        "Referrer-Policy": "no-referrer",
      },
    });
    return request.method === "HEAD"
      ? new Response(null, {
        status: response.status,
        headers: response.headers,
      })
      : response;
  }

  const canonicalURL = `${marketingURL}/m/${encodeURIComponent(slug)}`;
  const ogInput = {
    authorName: resolvedMugshot.author_name,
    drinkName: resolvedMugshot.drink_name,
    contextName: resolvedMugshot.context_name,
    coverPhotoURL: resolvedMugshot.cover_photo_url,
    appIconURL: `${marketingURL}/icons/app-icon.png`,
  };
  if (requestURL.searchParams.get("format") === "og") {
    if (request.method === "HEAD") {
      return new Response(null, {
        status: 200,
        headers: {
          "Content-Type": "image/png",
          "Cache-Control": "private, no-store",
          "X-Content-Type-Options": "nosniff",
          "X-Robots-Tag": "noindex, nofollow, noarchive",
          "Referrer-Policy": "no-referrer",
        },
      });
    }
    return mugshotOGImageResponse(ogInput);
  }

  if (request.method === "GET") {
    await client.rpc("record_public_mugshot_share_event_v1", {
      p_slug: slug,
      p_event_name: "landing_visit",
    });
  }

  const title = mugshotOGTitle;
  const description = mugshotOGDescription(ogInput);
  const caption = resolvedMugshot.caption
    ? `<blockquote>${escapeHTML(resolvedMugshot.caption)}</blockquote>`
    : "";
  const gallery = resolvedMugshot.photo_urls.length > 0
    ? `<div class="gallery" aria-label="${resolvedMugshot.photo_urls.length} post photo${
      resolvedMugshot.photo_urls.length === 1 ? "" : "s"
    }">${
      resolvedMugshot.photo_urls.map((url, index) =>
        `<figure class="photo">
          <img class="cover" src="${escapeHTML(url)}" alt="${
          escapeHTML(resolvedMugshot.drink_name)
        }, photo ${index + 1} of ${resolvedMugshot.photo_urls.length}">
          ${
          resolvedMugshot.photo_urls.length > 1
            ? `<span class="count">${
              index + 1
            }/${resolvedMugshot.photo_urls.length}</span>`
            : ""
        }
        </figure>`
      ).join("")
    }</div>`
    : "";
  const avatar = resolvedMugshot.author_avatar_url
    ? `<img class="avatar" src="${
      escapeHTML(resolvedMugshot.author_avatar_url)
    }" alt="">`
    : `<span class="avatar" aria-hidden="true"></span>`;
  const handle = resolvedMugshot.author_username
    ? `@${resolvedMugshot.author_username}`
    : "Mugshot member";
  const ratings = ratingEntries(resolvedMugshot.ratings);
  const ratingGrid = ratings.length > 0
    ? `<div class="ratings" aria-label="Taste ratings">${
      ratings.map(([label, value]) =>
        `<div class="rating"><div class="rating-name">${
          escapeHTML(ratingLabel(label))
        }</div><div class="rating-value">${value.toFixed(1)}</div></div>`
      ).join("")
    }</div>`
    : "";
  const date = new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(new Date(resolvedMugshot.created_at));
  const appRoute = `mugshot://m/${encodeURIComponent(slug)}`;
  const browseURL =
    `${webAppURL}/feed?utm_source=shared_mugshot&utm_medium=capability_link`;
  const signupURL =
    `${webAppURL}/auth?utm_source=shared_mugshot&utm_medium=capability_link`;
  const body = `
    <main>
      <div class="mark">MUGSHOT</div>
      <article class="card">
        ${gallery}
        <div class="content">
          <div class="author">
            ${avatar}
            <div>
              <div class="author-name">${
    escapeHTML(resolvedMugshot.author_name)
  }</div>
              <div class="author-handle">${escapeHTML(handle)} · ${
    escapeHTML(date)
  }</div>
            </div>
          </div>
          <div class="route">${escapeHTML(resolvedMugshot.context_name)} · ${
    escapeHTML(
      date,
    )
  }</div>
          <h1>${escapeHTML(resolvedMugshot.drink_name)}</h1>
          <div class="meta">${escapeHTML(resolvedMugshot.context_name)}</div>
          <div class="score">${
    Number(resolvedMugshot.rating).toFixed(
      1,
    )
  } <span>OUT OF 5</span></div>
          ${caption}
          ${ratingGrid}
          <div class="actions">
            <a class="button" href="${escapeHTML(appRoute)}">Open in Mugshot</a>
            <a class="button secondary" href="${
    escapeHTML(browseURL)
  }">Browse the web app</a>
          </div>
          <a class="signup" href="${
    escapeHTML(signupURL)
  }">New here? Create a Mugshot account</a>
          ${
    downloadURL
      ? `<p class="note">For the complete Mugshot experience on iPhone, <a href="${
        escapeHTML(downloadURL)
      }">join Mugshot on iOS</a>.</p>`
      : ""
  }
        </div>
      </article>
    </main>
  `;
  const response = new Response(
    page({
      title,
      description,
      body,
      image: `${canonicalURL}?format=og`,
      imageAlt: mugshotOGAlt(ogInput),
      canonical: canonicalURL,
    }),
    { status: 200, headers: successHeaders },
  );
  return request.method === "HEAD"
    ? new Response(null, { status: response.status, headers: response.headers })
    : response;
});
