import { createClient } from "npm:@supabase/supabase-js@2";
import { getPublicSupabaseKey } from "../_shared/public-key.ts";

type PublicCafeListItem = {
  cafe_name: string;
  cafe_address: string | null;
  cafe_city: string | null;
  caption: string | null;
  photo_url: string | null;
};

type PublicCafeList = {
  title: string;
  description: string | null;
  creator?: { display_name?: string | null; username?: string | null } | null;
  cafe_count: number;
  items: PublicCafeListItem[];
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

function page(
  title: string,
  description: string,
  body: string,
  image?: string | null,
  canonical?: string,
): string {
  const imageMeta = image
    ? `<meta property="og:image" content="${
      escapeHTML(image)
    }"><meta name="twitter:image" content="${escapeHTML(image)}">`
    : "";
  const canonicalMeta = canonical
    ? `<link rel="canonical" href="${
      escapeHTML(canonical)
    }"><meta property="og:url" content="${escapeHTML(canonical)}">`
    : "";
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${escapeHTML(title)}</title><meta name="description" content="${
    escapeHTML(
      description,
    )
  }">
  <meta name="robots" content="noindex,nofollow,noarchive">${canonicalMeta}
  <meta property="og:type" content="website"><meta property="og:title" content="${
    escapeHTML(
      title,
    )
  }">
  <meta property="og:description" content="${
    escapeHTML(
      description,
    )
  }"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${
    escapeHTML(title)
  }"><meta name="twitter:description" content="${
    escapeHTML(description)
  }">${imageMeta}
  <style>
  :root{color-scheme:light;--cream:#f6f0e4;--foam:#fffdf8;--espresso:#33231d;--sage:#607763;--line:#d9d0c1}
  *{box-sizing:border-box}body{margin:0;background:var(--cream);color:var(--espresso);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
  main{width:min(94vw,720px);margin:auto;padding:40px 18px 64px}.mark{color:var(--sage);font-size:12px;font-weight:900;letter-spacing:.24em}
  h1{font:700 clamp(38px,8vw,64px)/1 Georgia,serif;letter-spacing:-.035em;margin:16px 0 10px}.lede{color:#715f54;font-size:17px;line-height:1.5}
  .card{background:var(--foam);border:1px solid var(--line);border-radius:22px;padding:14px;margin-top:12px;display:flex;gap:14px;align-items:center}
  .photo{width:76px;height:76px;object-fit:cover;border-radius:15px;background:#dfd2bd}.number{color:var(--sage);font-weight:900}.name{font-weight:800;margin-bottom:4px}.place,.caption{color:#715f54;font-size:13px}.caption{margin-top:5px;font-family:Georgia,serif}
  .button{display:inline-flex;min-height:48px;margin-top:24px;padding:0 22px;align-items:center;border-radius:14px;background:#143d31;color:white;text-decoration:none;font-weight:800}
  </style></head><body>${body}</body></html>`;
}

function unavailable(destination: string): Response {
  const body =
    `<main><div class="mark">MUGSHOT</div><h1>This cafe list is not available.</h1>
  <p class="lede">It may have been removed or made private.</p>${
      destination
        ? `<a class="button" href="${escapeHTML(destination)}">Open Mugshot</a>`
        : ""
    }</main>`;
  return new Response(
    page(
      "Cafe list unavailable",
      "This public cafe list is not available.",
      body,
    ),
    { status: 404, headers: unavailableHeaders },
  );
}

Deno.serve(async (request) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { ...unavailableHeaders, Allow: "GET, HEAD" },
    });
  }
  const url = new URL(request.url);
  const slug = url.searchParams.get("slug") ??
    url.pathname.split("/").filter(Boolean).at(-1) ??
    "";
  const marketingURL = Deno.env.get("MUGSHOT_MARKETING_URL") ??
    "https://mugshotapp.co";
  const destination = Deno.env.get("MUGSHOT_DOWNLOAD_URL") ??
    `${marketingURL}/download?placement=share`;
  if (!/^[a-f0-9]{24}$/.test(slug)) return unavailable(destination);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publicKey = getPublicSupabaseKey();
  if (!supabaseURL || !publicKey) return unavailable(destination);
  const client = createClient(supabaseURL, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.rpc("get_public_cafe_list_v1", {
    p_slug: slug,
  });
  const list = !error && data && !Array.isArray(data)
    ? (data as PublicCafeList)
    : null;
  if (!list) return unavailable(destination);

  const creator = list.creator?.display_name ?? list.creator?.username ??
    "a Mugshot creator";
  const description = list.description ??
    `${list.cafe_count} cafes selected by ${creator}.`;
  const items = (list.items ?? [])
    .map((item, index) => {
      const location = item.cafe_address ?? item.cafe_city ?? "";
      const photo = item.photo_url
        ? `<img class="photo" src="${escapeHTML(item.photo_url)}" alt="${
          escapeHTML(
            item.cafe_name,
          )
        }">`
        : "";
      const caption = item.caption
        ? `<div class="caption">${escapeHTML(item.caption)}</div>`
        : "";
      return `<article class="card"><div class="number">${
        index + 1
      }</div>${photo}<div><div class="name">${
        escapeHTML(
          item.cafe_name,
        )
      }</div><div class="place">${
        escapeHTML(
          location,
        )
      }</div>${caption}</div></article>`;
    })
    .join("");
  const body = `<main><div class="mark">MUGSHOT</div><h1>${
    escapeHTML(
      list.title,
    )
  }</h1>
  <p class="lede">${escapeHTML(description)}<br>Curated by ${
    escapeHTML(
      creator,
    )
  }.</p>${items}
  <a class="button" href="${
    escapeHTML(
      destination,
    )
  }">Open in Mugshot</a></main>`;
  const response = new Response(
    page(
      list.title,
      description,
      body,
      list.items?.find((item) => item.photo_url)?.photo_url,
      `${marketingURL}/l/${encodeURIComponent(slug)}`,
    ),
    { status: 200, headers: successHeaders },
  );
  return request.method === "HEAD"
    ? new Response(null, { status: 200, headers: successHeaders })
    : response;
});
