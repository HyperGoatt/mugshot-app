// Only provider identifiers leave Mugshot. Never send journal text or images.
export type Provider = "apple" | "google";
type ProviderOperation =
  | "configuration"
  | "apple_token"
  | "apple_place"
  | "google_place";
export class ProviderFailure extends Error {
  constructor(
    readonly reason:
      | "configuration"
      | "provider_http"
      | "provider_unavailable"
      | "provider_payload",
    readonly operation: ProviderOperation,
    readonly status?: number,
  ) {
    super("Cafe provider verification failed");
  }
}
export type Place = {
  name: string;
  address: string | null;
  city: string | null;
  country: string | null;
  latitude: number;
  longitude: number;
};
const text = (v: unknown, max: number): string | null =>
  typeof v === "string" && v.trim().length > 0 && v.length <= max &&
    !/[\u0000-\u001f]/.test(v)
    ? v.trim()
    : null;
export function placeID(v: unknown): v is string {
  return typeof v === "string" && /^[A-Za-z0-9_-]{1,256}$/.test(v);
}
export function parsePlace(
  provider: Provider,
  id: string,
  value: unknown,
): Place {
  const p = value as Record<string, any>;
  const ids = provider === "apple"
    ? [p?.id, ...(Array.isArray(p?.alternateIds) ? p.alternateIds : [])]
    : [p?.place_id];
  if (!ids.includes(id)) throw Error("invalid_place");
  const name = text(p.name, 300);
  const latitude = provider === "apple"
    ? p.coordinate?.latitude
    : p.geometry?.location?.lat;
  const longitude = provider === "apple"
    ? p.coordinate?.longitude
    : p.geometry?.location?.lng;
  if (
    !name || !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    Math.abs(latitude) > 90 || Math.abs(longitude) > 180
  ) throw Error("invalid_place");
  let city: string | null = null,
    country: string | null = null,
    address: string | null = null;
  if (provider === "apple") {
    if (
      !Array.isArray(p.formattedAddressLines) ||
      !p.formattedAddressLines.every((s: unknown) =>
        typeof s === "string" && s.length <= 500 && s.trim().length > 0 &&
        !/[\u0000-\u0009\u000b\u000c\u000e-\u001f]/.test(s)
      )
    ) throw Error("invalid_place");
    // Apple can return a whole postal address inside one array entry. Preserve
    // its line boundaries as separators; retain rejection of other controls.
    const lines: string[] = p.formattedAddressLines.flatMap((s: string) =>
      s.split(/\r\n?|\n/).map((line) => line.trim()).filter(Boolean)
    );
    if (!lines.every((line) => text(line, 500))) throw Error("invalid_place");
    address = text(lines.join(", "), 2000);
    city = text(p.structuredAddress?.locality, 300);
    country = text(p.country, 300);
  } else {
    address = text(p.formatted_address, 2000);
    if (!Array.isArray(p.address_components)) throw Error("invalid_place");
    for (const component of p.address_components) {
      if (component.types?.includes("locality")) {
        city = text(component.long_name, 300);
      }
      if (component.types?.includes("country")) {
        country = text(component.long_name, 300);
      }
    }
  }
  if (!address) throw Error("invalid_place");
  return { name, address, city, country, latitude, longitude };
}
const base64url = (data: Uint8Array) =>
  btoa(String.fromCharCode(...data)).replaceAll("+", "-").replaceAll("/", "_")
    .replaceAll("=", "");
export async function appleAuthorization(
  pem: string,
  keyID: string,
  teamID: string,
  now = Date.now(),
): Promise<string> {
  if (!/^[A-Z0-9]{10}$/.test(keyID) || !/^[A-Z0-9]{10}$/.test(teamID)) {
    throw Error("configuration");
  }
  const raw = pem.replace(/-----[A-Z ]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(raw), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const encode = (v: unknown) =>
    base64url(new TextEncoder().encode(JSON.stringify(v)));
  const issued = Math.floor(now / 1000);
  const body = encode({ alg: "ES256", kid: keyID, typ: "JWT" }) + "." +
    encode({
      iss: teamID,
      iat: issued,
      exp: issued + 300,
      scope: "server_api",
    });
  const signed = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(body),
  );
  return body + "." + base64url(new Uint8Array(signed));
}
export async function fetchPlace(provider: Provider, id: string, credentials: {
  appleKey?: string;
  appleKeyID?: string;
  appleTeamID?: string;
  googleKey?: string;
}, request: typeof fetch = fetch): Promise<Place> {
  if (!placeID(id)) throw Error("invalid_place");
  // Fixed hosts and encoded identifiers: no client-controlled URL or redirects.
  const get = async (
    url: string,
    operation: ProviderOperation,
    authorization?: string,
  ) => {
    let response: Response;
    try {
      response = await request(url, {
        headers: authorization
          ? { Authorization: "Bearer " + authorization }
          : {},
        redirect: "error",
        signal: AbortSignal.timeout(10000),
      });
    } catch {
      throw new ProviderFailure("provider_unavailable", operation);
    }
    if (!response.ok) {
      throw new ProviderFailure("provider_http", operation, response.status);
    }
    try {
      return await response.json();
    } catch {
      throw new ProviderFailure("provider_payload", operation);
    }
  };
  if (provider === "apple") {
    if (
      !credentials.appleKey || !credentials.appleKeyID ||
      !credentials.appleTeamID
    ) throw new ProviderFailure("configuration", "configuration");
    let jwt: string;
    try {
      jwt = await appleAuthorization(
        credentials.appleKey,
        credentials.appleKeyID,
        credentials.appleTeamID,
      );
    } catch {
      throw new ProviderFailure("configuration", "configuration");
    }
    const token = await get(
      "https://maps-api.apple.com/v1/token",
      "apple_token",
      jwt,
    );
    if (typeof token.accessToken !== "string" || !token.accessToken) {
      throw new ProviderFailure("provider_payload", "apple_token");
    }
    return parsePlace(
      provider,
      id,
      await get(
        "https://maps-api.apple.com/v1/place/" + encodeURIComponent(id),
        "apple_place",
        token.accessToken,
      ),
    );
  }
  if (!credentials.googleKey) {
    throw new ProviderFailure("configuration", "configuration");
  }
  const query = new URLSearchParams({
    place_id: id,
    fields: "place_id,name,formatted_address,address_components,geometry",
    key: credentials.googleKey,
  });
  const result = await get(
    "https://maps.googleapis.com/maps/api/place/details/json?" + query,
    "google_place",
  );
  if (result.status !== "OK") throw Error("provider_unavailable");
  return parsePlace(provider, id, result.result);
}
