import { screenContent, stripImageMetadata } from "./provider.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const keys = [
  "sexual",
  "sexual/minors",
  "harassment",
  "harassment/threatening",
  "hate",
  "hate/threatening",
  "illicit",
  "illicit/violent",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions",
  "violence",
  "violence/graphic",
];
const configuration = {
  apiKey: "synthetic-test-key",
  noTrainingControlsVerified: true,
};
const shared = {
  audience: "shared" as const,
  text: "A synthetic cup of coffee",
  images: [],
};
const cleanResult = () => ({
  model: "omni-moderation-latest",
  results: [{
    flagged: false,
    categories: Object.fromEntries(keys.map((key) => [key, false])),
    category_scores: Object.fromEntries(keys.map((key) => [key, 0.001])),
  }],
});
const respond = (body: unknown, status = 200): typeof fetch => () =>
  Promise.resolve(new Response(JSON.stringify(body), { status }));

Deno.test("Private and disabled no-training configuration never transmit", async () => {
  const forbidden: typeof fetch = () => {
    throw new Error("unexpected provider call");
  };
  assert(
    (await screenContent(
      { ...shared, audience: "private" },
      configuration,
      forbidden,
    )).state === "excluded",
    "Private excluded",
  );
  assert(
    (await screenContent(shared, {
      ...configuration,
      noTrainingControlsVerified: false,
    }, forbidden)).state === "needs_review",
    "disabled configuration holds",
  );
});

Deno.test("provider request uses only standalone moderation and explicit shared inputs", async () => {
  let calls = 0;
  const inspect: typeof fetch = (url, options) => {
    calls++;
    assert(
      url === "https://api.openai.com/v1/moderations",
      "standalone fixed endpoint",
    );
    const body = JSON.parse(String(options?.body));
    assert(
      JSON.stringify(Object.keys(body).sort()) ===
        JSON.stringify(["input", "model"]),
      "no identity, feedback, training or stored row fields",
    );
    assert(
      body.model === "omni-moderation-latest" &&
        body.input[0].text === shared.text,
      "explicit input",
    );
    assert(options?.redirect === "error", "credentials cannot follow redirect");
    return Promise.resolve(new Response(JSON.stringify(cleanResult())));
  };
  const result = await screenContent(
    { ...shared, private_notes: "must not leave Mugshot" } as typeof shared,
    configuration,
    inspect,
  );
  assert(
    result.state === "approved" && calls === 1,
    "valid result approves exactly one request",
  );
});

Deno.test("flags and contradictory or incomplete responses never approve", async () => {
  const flagged = cleanResult();
  flagged.results[0].categories.violence = true;
  const result = await screenContent(shared, configuration, respond(flagged));
  assert(
    result.state === "needs_review" && result.reason === "provider_flag",
    "category flag holds even with flagged false",
  );
  for (
    const payload of [{}, { results: [] }, {
      model: "x",
      results: [{ flagged: false, categories: {}, category_scores: {} }],
    }, {
      ...cleanResult(),
      results: [...cleanResult().results, ...cleanResult().results],
    }]
  ) {
    assert(
      (await screenContent(shared, configuration, respond(payload))).state ===
        "needs_review",
      "malformed result must hold",
    );
  }
});

Deno.test("rate limits, provider outages and network failures retry without exposing bodies", async () => {
  for (const status of [429, 500, 503]) {
    const result = await screenContent(
      shared,
      configuration,
      respond({ error: "synthetic-sensitive-body" }, status),
    );
    assert(
      result.state === "retry" && result.retryAfterSeconds >= 60,
      "outage must retry",
    );
    assert(
      !JSON.stringify(result).includes("synthetic-sensitive-body"),
      "no raw provider error retention",
    );
  }
  const network: typeof fetch = () =>
    Promise.reject(new Error("synthetic-sensitive-request"));
  assert(
    (await screenContent(shared, configuration, network)).state === "retry",
    "network failure holds",
  );
  assert(
    (await screenContent(shared, configuration, respond({}, 401))).state ===
      "needs_review",
    "configuration error needs operator",
  );
});

Deno.test("spam signals and invalid images stop before provider", async () => {
  let calls = 0;
  const inspect: typeof fetch = () => {
    calls++;
    return Promise.resolve(new Response());
  };
  for (
    const input of [
      { ...shared, text: "https://a https://b https://c https://d" },
      { ...shared, text: "x".repeat(30) },
      {
        ...shared,
        images: [{
          mime: "image/jpeg" as const,
          bytes: new Uint8Array([1, 2, 3]),
        }],
      },
    ]
  ) {
    assert(
      (await screenContent(input, configuration, inspect)).state ===
        "needs_review",
      "unsupported input holds",
    );
  }
  assert(calls === 0, "nothing transmitted");
});

Deno.test("JPEG metadata including inter-scan segments and trailing bytes is removed", () => {
  const data = new Uint8Array([
    255,
    216,
    255,
    225,
    0,
    6,
    71,
    80,
    83,
    33,
    255,
    218,
    0,
    2,
    1,
    2,
    255,
    0,
    3,
    255,
    225,
    0,
    6,
    88,
    77,
    80,
    33,
    255,
    218,
    0,
    2,
    4,
    5,
    255,
    217,
    71,
    80,
    83,
  ]);
  const stripped = stripImageMetadata(data, "image/jpeg");
  assert(
    JSON.stringify([...stripped]) ===
      JSON.stringify([
        255,
        216,
        255,
        218,
        0,
        2,
        1,
        2,
        255,
        0,
        3,
        255,
        218,
        0,
        2,
        4,
        5,
        255,
        217,
      ]),
    "metadata and trailing bytes removed, scans preserved",
  );
});

Deno.test("PNG metadata is removed while image structure is retained", () => {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  const chunk = (
    type: string,
    data: number[],
  ) => [
    0,
    0,
    0,
    data.length,
    ...[...type].map((char) => char.charCodeAt(0)),
    ...data,
    0,
    0,
    0,
    0,
  ];
  const required = [
    ...chunk("IHDR", Array(13).fill(0)),
    ...chunk("IDAT", [1, 2, 3]),
    ...chunk("IEND", []),
  ];
  const bytes = new Uint8Array([
    ...signature,
    ...chunk("IHDR", Array(13).fill(0)),
    ...chunk("eXIf", [71, 80, 83]),
    ...chunk("tEXt", [88, 77, 80]),
    ...chunk("IDAT", [1, 2, 3]),
    ...chunk("IEND", []),
    9,
    9,
  ]);
  assert(
    JSON.stringify([...stripImageMetadata(bytes, "image/png")]) ===
      JSON.stringify([...signature, ...required]),
    "ancillary metadata and suffix stripped",
  );
});
