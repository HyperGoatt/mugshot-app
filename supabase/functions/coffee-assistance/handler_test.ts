import { deepStrictEqual as equal } from "node:assert/strict";
import { type Dependencies, handle } from "./handler.ts";

const actor = "11111111-1111-4111-8111-111111111111";
const input = () => ({
  owner_id: actor,
  request_id: crypto.randomUUID(),
  consent_version: "selected-details-v1",
  task: "memory_search",
  query: "Find my oat latte",
  evidence: [{ id: "sip-1", title: "Oat latte", detail: "Rated 4 / 5" }],
  image: null,
});
const output = () => ({
  text: "This saved sip may be the one you remember.",
  evidence_ids: ["sip-1"],
  fields: [],
  search_terms: ["oat latte"],
});
const request = (body: unknown, token = "Bearer fixture") =>
  new Request("https://fixture.test", {
    method: "POST",
    headers: { Authorization: token },
    body: JSON.stringify(body),
  });
function dependencies(overrides: Partial<Dependencies> = {}): Dependencies {
  return {
    enabled: true,
    authenticate: async () => actor,
    reserve: async () => true,
    generate: async () => output(),
    ...overrides,
  };
}

Deno.test("disabled, unauthenticated, wrong owner and missing consent never call AI", async () => {
  let calls = 0;
  const deps = dependencies({
    generate: async () => {
      calls++;
      return output();
    },
  });
  equal(
    (await handle(request(input()), { ...deps, enabled: false })).status,
    503,
  );
  equal((await handle(request(input(), ""), deps)).status, 401);
  equal(
    (await handle(request(input()), {
      ...deps,
      authenticate: async () => null,
    })).status,
    401,
  );
  equal(
    (await handle(request({ ...input(), owner_id: crypto.randomUUID() }), deps))
      .status,
    403,
  );
  equal(
    (await handle(request({ ...input(), consent_version: "" }), deps)).status,
    400,
  );
  equal(calls, 0);
});

Deno.test("bounded strict inputs reject extra fields, unsupported tasks, images and duplicate evidence", async () => {
  let reservations = 0;
  const deps = dependencies({
    reserve: async () => {
      reservations++;
      return true;
    },
  });
  for (
    const body of [
      { ...input(), model: "expensive-model" },
      { ...input(), task: "publish" },
      { ...input(), query: "x".repeat(401) },
      { ...input(), evidence: Array(41).fill(input().evidence[0]) },
      { ...input(), evidence: [input().evidence[0], input().evidence[0]] },
      { ...input(), image: "https://private-server.test/image" },
      { ...input(), image: "data:image/jpeg;base64,YWJj" },
      {
        ...input(),
        evidence: [{ id: "sip-1", title: "x", detail: "x".repeat(801) }],
      },
    ]
  ) equal((await handle(request(body), deps)).status, 400);
  equal(reservations, 0);
});

Deno.test("quota or duplicate reservation denies before provider; provider failure stays generic", async () => {
  let calls = 0;
  equal(
    (await handle(
      request(input()),
      dependencies({
        reserve: async () => false,
        generate: async () => {
          calls++;
          return output();
        },
      }),
    )).status,
    429,
  );
  equal(calls, 0);
  const response = await handle(
    request(input()),
    dependencies({
      generate: async () => {
        throw Error("private text and secret token");
      },
    }),
  );
  equal(response.status, 503);
  equal((await response.text()).includes("secret"), false);
});

Deno.test("invented references and inappropriate extracted fields are rejected", async () => {
  for (
    const result of [
      { ...output(), evidence_ids: ["another-owner-sip"] },
      {
        ...output(),
        fields: [{ key: "audience", value: "everyone", source_quote: "" }],
      },
      { ...output(), text: "x".repeat(1601) },
      { ...output(), evidence_ids: [] },
      { ...output(), search_terms: ["x".repeat(81)] },
    ]
  ) {
    equal(
      (await handle(
        request(input()),
        dependencies({ generate: async () => result }),
      )).status,
      503,
    );
  }
});

Deno.test("all six bounded tasks return reviewed suggestions with private no-store responses", async () => {
  for (
    const task of [
      "bag_scan",
      "recipe_import",
      "memory_search",
      "taste_insight",
      "brew_experiment",
      "weekly_reflection",
    ]
  ) {
    const response = await handle(
      request({ ...input(), task }),
      dependencies(),
    );
    equal(response.status, 200);
    equal(response.headers.get("Cache-Control"), "private, no-store");
    equal(await response.json(), { result: output() });
  }
});

Deno.test("bag fields require bounded source quotes and no unrelated write controls", async () => {
  const result = {
    ...output(),
    fields: [{
      key: "origin",
      value: "Colombia",
      source_quote: "Origin: Colombia",
    }],
  };
  equal(
    (await handle(
      request({
        ...input(),
        task: "bag_scan",
        evidence: [{ id: "sip-1", title: "Bag", detail: "Origin: Colombia" }],
      }),
      dependencies({ generate: async () => result }),
    )).status,
    200,
  );
  equal(
    (await handle(
      request(input()),
      dependencies({ generate: async () => result }),
    )).status,
    503,
  );
});

Deno.test("aborted requests and oversized bodies are rejected before spending", async () => {
  const controller = new AbortController();
  controller.abort();
  const aborted = new Request("https://fixture.test", {
    method: "POST",
    body: JSON.stringify(input()),
    signal: controller.signal,
    headers: { Authorization: "Bearer fixture" },
  });
  equal((await handle(aborted, dependencies())).status, 499);
  equal(
    (await handle(
      request({ ...input(), padding: "x".repeat(500001) }),
      dependencies(),
    )).status,
    413,
  );
});
