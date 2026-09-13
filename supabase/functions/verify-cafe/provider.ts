// Only provider identifiers leave Mugshot. Never send journal text or images.
export type Provider = "apple" | "google";
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
      !p.formattedAddressLines.every((s: unknown) => text(s, 500))
    ) throw Error("invalid_place");
    address = text(p.formattedAddressLines.join(", "), 2000);
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
  const get = async (url: string, authorization?: string) => {
    const response = await request(url, {
      headers: authorization
        ? { Authorization: "Bearer " + authorization }
        : {},
      redirect: "error",
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw Error("provider_unavailable");
    return await response.json();
  };
  if (provider === "apple") {
    if (
      !credentials.appleKey || !credentials.appleKeyID ||
      !credentials.appleTeamID
    ) throw Error("configuration");
    const jwt = await appleAuthorization(
      credentials.appleKey,
      credentials.appleKeyID,
      credentials.appleTeamID,
    );
    const token = await get("https://maps-api.apple.com/v1/token", jwt);
    if (typeof token.accessToken !== "string" || !token.accessToken) {
      throw Error("provider_unavailable");
    }
    return parsePlace(
      provider,
      id,
      await get(
        "https://maps-api.apple.com/v1/place/" + encodeURIComponent(id),
        token.accessToken,
      ),
    );
  }
  if (!credentials.googleKey) throw Error("configuration");
  const query = new URLSearchParams({
    place_id: id,
    fields: "place_id,name,formatted_address,address_components,geometry",
    key: credentials.googleKey,
  });
  const result = await get(
    "https://maps.googleapis.com/maps/api/place/details/json?" + query,
  );
  if (result.status !== "OK") throw Error("provider_unavailable");
  return parsePlace(provider, id, result.result);
}
