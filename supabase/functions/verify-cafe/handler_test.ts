import {
  deepStrictEqual as assertEquals,
  rejects as assertRejects,
} from "node:assert/strict";
import { type Dependencies, handle } from "./handler.ts";
import { appleAuthorization, fetchPlace, parsePlace } from "./provider.ts";
const place = {
  name: "Synthetic cafe",
  address: "123 Test St",
  city: null,
  country: null,
  latitude: 10,
  longitude: 20,
};
const req = (body: unknown, authorization = "Bearer test") =>
  new Request("https://example.test", {
    method: "POST",
    headers: { Authorization: authorization },
    body: JSON.stringify(body),
  });
Deno.test("authentication, strict payload, rate limit and provider failure never write", async () => {
  let reads = 0, saves = 0;
  const deps: Dependencies = {
    authenticate: async () => "actor",
    reserve: async () => true,
    verify: async () => {
      reads++;
      return place;
    },
    save: async () => {
      saves++;
      return { id: "cafe" };
    },
  };
  assertEquals(
    (await handle(req({ provider: "apple", place_id: "I123" }, ""), deps))
      .status,
    401,
  );
  assertEquals(
    (await handle(
      req({ provider: "apple", place_id: "I123", name: "injected" }),
      deps,
    )).status,
    400,
  );
  assertEquals(
    (await handle(req({ provider: "apple", place_id: "../../evil" }), deps))
      .status,
    400,
  );
  assertEquals(
    (await handle(req({ provider: "apple", place_id: "I123" }), {
      ...deps,
      authenticate: async () => null,
    })).status,
    401,
  );
  assertEquals(
    (await handle(req({ provider: "apple", place_id: "I123" }), {
      ...deps,
      reserve: async () => false,
    })).status,
    429,
  );
  assertEquals(reads, 0);
  assertEquals(saves, 0);
  const response = await handle(req({ provider: "apple", place_id: "I123" }), {
    ...deps,
    verify: async () => {
      throw Error("secret key + private location");
    },
  });
  assertEquals(response.status, 503);
  assertEquals((await response.text()).includes("secret"), false);
  assertEquals(saves, 0);
});
Deno.test("only verified provider fields reach persistence", async () => {
  let captured: unknown;
  const response = await handle(
    req({ provider: "google", place_id: "ChIJtest" }),
    {
      authenticate: async () => "actor",
      reserve: async () => true,
      verify: async () => place,
      save: async (...args) => {
        captured = args;
        return { id: "cafe", ...place };
      },
    },
  );
  assertEquals(response.status, 200);
  assertEquals(captured, ["actor", "google", "ChIJtest", place]);
  assertEquals(response.headers.get("Cache-Control"), "private, no-store");
});
Deno.test("provider ID mismatch, invalid coordinates and hostile URLs fail closed", async () => {
  const apple = {
    id: "I123",
    name: "Synthetic cafe",
    formattedAddressLines: ["123 Test St"],
    coordinate: { latitude: 10, longitude: 20 },
  };
  assertEquals(parsePlace("apple", "I123", apple), place);
  await assertRejects(async () => parsePlace("apple", "I999", apple));
  await assertRejects(async () =>
    parsePlace("apple", "I123", {
      ...apple,
      coordinate: { latitude: 91, longitude: 20 },
    })
  );
  let calls = 0;
  await assertRejects(() =>
    fetchPlace("google", "https://evil.test", { googleKey: "secret" }, () => {
      calls++;
      throw Error();
    })
  );
  assertEquals(calls, 0);
  await assertRejects(() =>
    fetchPlace(
      "google",
      "ChIJtest",
      { googleKey: "secret" },
      async (url, options) => {
        assertEquals(new URL(String(url)).hostname, "maps.googleapis.com");
        assertEquals(options?.redirect, "error");
        return Response.json({ status: "OK", result: { place_id: "other" } });
      },
    )
  );
});
Deno.test("Maps JWT signature and scope are restricted to server API", async () => {
  const keys = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const raw = await crypto.subtle.exportKey("pkcs8", keys.privateKey);
  const pem = "-----BEGIN PRIVATE KEY-----\n" +
    btoa(String.fromCharCode(...new Uint8Array(raw))) +
    "\n-----END PRIVATE KEY-----";
  const token = await appleAuthorization(
    pem,
    "1234567890",
    "ABCDEFGHIJ",
    1000000,
  );
  const [header, payload, signature] = token.split(".");
  const decode = (s: string) =>
    Uint8Array.from(
      atob(s.replaceAll("-", "+").replaceAll("_", "/")),
      (c) => c.charCodeAt(0),
    );
  assertEquals(JSON.parse(new TextDecoder().decode(decode(payload))), {
    iss: "ABCDEFGHIJ",
    iat: 1000,
    exp: 1300,
    scope: "server_api",
  });
  assertEquals(
    await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      keys.publicKey,
      decode(signature),
      new TextEncoder().encode(header + "." + payload),
    ),
    true,
  );
});
