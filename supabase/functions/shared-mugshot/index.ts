import { createClient } from "npm:@supabase/supabase-js@2";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";

type PublicMugshot = {
  visit_id: string;
  slug: string;
  author_name: string;
  author_username: string | null;
  drink_name: string;
  context_name: string;
  rating: number;
  caption: string | null;
  cover_photo_url: string | null;
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
  "Cache-Control": "public, max-age=60, stale-while-revalidate=120",
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

function neutralPage(downloadURL: string): Response {
  return new Response(
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
}

function page(input: {
  title: string;
  description: string;
  body: string;
  image?: string | null;
  canonical?: string;
}): string {
  const imageMeta = input.image
    ? `<meta property="og:image" content="${escapeHTML(input.image)}">
  <meta name="twitter:image" content="${escapeHTML(input.image)}">`
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
    main { position:relative; width:min(94vw,680px); margin:0 auto; padding:40px 20px 64px; }
    .mark { color:var(--sage); font-size:12px; font-weight:900; letter-spacing:.24em; margin-bottom:18px; }
    .card { overflow:hidden; border:1px solid var(--line); border-radius:28px; background:var(--foam); box-shadow:0 18px 44px rgba(51,35,29,.12); }
    .cover { display:block; width:100%; aspect-ratio:4/5; object-fit:cover; background:#dfd2bd; }
    .content { padding:28px; }
    .route { display:flex; align-items:center; gap:9px; color:var(--sage); font-size:12px; font-weight:800; text-transform:uppercase; letter-spacing:.1em; }
    .route::before { content:""; width:9px; height:9px; border-radius:50%; background:var(--sage); box-shadow:18px 0 0 -3px var(--sage); margin-right:16px; }
    h1 { margin:14px 0 8px; font-family:Georgia,serif; font-size:clamp(36px,8vw,62px); line-height:1; letter-spacing:-.035em; }
    .meta { color:#715f54; font-weight:650; }
    .score { margin:24px 0 0; display:flex; align-items:baseline; gap:8px; font-family:Georgia,serif; font-size:54px; font-weight:700; }
    .score span { font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; color:var(--sage); font-size:11px; letter-spacing:.12em; }
    blockquote { margin:22px 0 0; padding-left:16px; border-left:3px solid var(--mint); color:#5a4941; font-family:Georgia,serif; font-size:20px; line-height:1.45; }
    .byline { margin:24px 0 0; color:#76675e; font-size:13px; }
  .button { display:inline-flex; min-height:48px; margin-top:24px; padding:0 22px; align-items:center; justify-content:center; border-radius:14px; background:#143d31; color:white; text-decoration:none; font-weight:800; }
    .neutral { min-height:80vh; display:flex; flex-direction:column; justify-content:center; align-items:flex-start; }
    .neutral h1 { max-width:560px; }
    .neutral p { color:#715f54; font-size:18px; }
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
  const downloadURL = Deno.env.get("MUGSHOT_DOWNLOAD_URL") ??
    `${marketingURL}/download?placement=share`;
  if (!validSlug(slug)) return neutralPage(downloadURL);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  if (!supabaseURL || !publicKey) return neutralPage(downloadURL);

  const client = createClient(supabaseURL, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.rpc("get_public_mugshot_share_v1", {
    p_slug: slug,
  });
  const mugshot = !error && Array.isArray(data)
    ? (data[0] as PublicMugshot | undefined)
    : undefined;
  if (!mugshot) return neutralPage(downloadURL);
  await client.rpc("record_public_mugshot_share_event_v1", {
    p_slug: slug,
    p_event_name: "landing_visit",
  });

  const title = `${mugshot.drink_name} at ${mugshot.context_name}`;
  const description = `${mugshot.author_name} remembered this on Mugshot.`;
  const caption = mugshot.caption
    ? `<blockquote>${escapeHTML(mugshot.caption)}</blockquote>`
    : "";
  const cover = mugshot.cover_photo_url
    ? `<img class="cover" src="${
      escapeHTML(
        mugshot.cover_photo_url,
      )
    }" alt="Photo of ${escapeHTML(mugshot.drink_name)}">`
    : "";
  const date = new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(new Date(mugshot.created_at));
  const body = `
    <main>
      <div class="mark">MUGSHOT</div>
      <article class="card">
        ${cover}
        <div class="content">
          <div class="route">${escapeHTML(mugshot.context_name)} · ${
    escapeHTML(
      date,
    )
  }</div>
          <h1>${escapeHTML(mugshot.drink_name)}</h1>
          <div class="meta">${escapeHTML(mugshot.context_name)}</div>
          <div class="score">${
    Number(mugshot.rating).toFixed(
      1,
    )
  } <span>OUT OF 5</span></div>
          ${caption}
          <p class="byline">Remembered by ${escapeHTML(mugshot.author_name)}</p>
          ${
    downloadURL
      ? `<a class="button" href="${
        escapeHTML(
          downloadURL,
        )
      }">Get Mugshot</a>`
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
      image: mugshot.cover_photo_url,
      canonical: `${marketingURL}/m/${encodeURIComponent(slug)}`,
    }),
    { status: 200, headers: successHeaders },
  );
  return request.method === "HEAD"
    ? new Response(null, { status: response.status, headers: response.headers })
    : response;
});
