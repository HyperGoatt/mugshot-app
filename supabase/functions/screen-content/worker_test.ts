import {
  processScreeningJob,
  type ScreeningClient,
  type ScreeningJob,
  screeningMediaLocation,
} from "./worker.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const job: ScreeningJob = {
  subject_kind: "visit",
  subject_id: "20000000-0000-4000-8000-000000000001",
  owner_id: "10000000-0000-4000-8000-000000000001",
  revision: "revision-1",
  lease_token: "lease-1",
};
const config = {
  apiKey: "synthetic",
  noTrainingControlsVerified: true,
  supabaseURL: "https://example.supabase.co",
};
const ref =
  `mugshot-storage://visit-photos-private/${job.owner_id}/${job.subject_id}/photo.jpg`;
const syntheticJPEG = new Uint8Array([
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
  3,
  255,
  217,
]);
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
const response = () =>
  new Response(JSON.stringify({
    model: "synthetic",
    results: [{
      flagged: false,
      categories: Object.fromEntries(keys.map((key) => [key, false])),
      category_scores: Object.fromEntries(keys.map((key) => [key, 0])),
    }],
  }));

Deno.test("screening media rejects foreign hosts, owners, subjects and malformed references", () => {
  assert(
    screeningMediaLocation(ref, job, config.supabaseURL)?.bucket ===
      "visit-photos-private",
    "own private object accepted",
  );
  for (
    const value of [
      ref.replace(job.owner_id, "another-owner"),
      ref.replace(job.subject_id, "another-visit"),
      ref + "?token=x",
      "https://evil.invalid/image.jpg",
      `https://example.supabase.co.evil.invalid/storage/v1/object/public/visit-photos/${job.owner_id}/${job.subject_id}/photo.jpg`,
      ref.replace("photo.jpg", "%2e%2e%2fphoto.jpg"),
    ]
  ) {
    assert(
      screeningMediaLocation(value, job, config.supabaseURL) === null,
      "unsafe media must not be fetched",
    );
  }
});

Deno.test("withdrawal during media loading prevents OpenAI transmission", async () => {
  let reads = 0, calls = 0, finished = false;
  const client: ScreeningClient = {
    rpc: (name) => {
      if (name === "read_screening_lease_v1") {
        return Promise.resolve({
          data: ++reads === 1 ? { text: "Synthetic", images: [ref] } : null,
          error: null,
        });
      }
      finished = true;
      return Promise.resolve({ data: true, error: null });
    },
    storage: {
      from: () => ({
        download: () =>
          Promise.resolve({ data: new Blob([syntheticJPEG]), error: null }),
      }),
    },
  };
  const request: typeof fetch = () => {
    calls++;
    return Promise.resolve(response());
  };
  assert(
    await processScreeningJob(client, job, config, request) === "stale",
    "withdrawn lease stops job",
  );
  assert(calls === 0 && !finished, "no request or stale completion");
});

Deno.test("worker sends stripped bytes and commits only the claimed revision and lease", async () => {
  let committed: Record<string, unknown> | undefined;
  const client: ScreeningClient = {
    rpc: (name, parameters) => {
      if (name === "read_screening_lease_v1") {
        return Promise.resolve({
          data: { text: "Synthetic", images: [ref] },
          error: null,
        });
      }
      committed = parameters;
      return Promise.resolve({ data: true, error: null });
    },
    storage: {
      from: () => ({
        download: () =>
          Promise.resolve({ data: new Blob([syntheticJPEG]), error: null }),
      }),
    },
  };
  const request: typeof fetch = (_url, init) => {
    const body = JSON.parse(String(init?.body));
    const encoded = body.input[1].image_url.url.split(",")[1];
    assert(
      !atob(encoded).includes("GPS!"),
      "image metadata removed before API boundary",
    );
    assert(
      !JSON.stringify(body).includes(job.owner_id),
      "storage owner/path never transmitted",
    );
    return Promise.resolve(response());
  };
  assert(
    await processScreeningJob(client, job, config, request) === "applied",
    "valid result applied",
  );
  assert(
    committed?.p_revision === job.revision &&
      committed?.p_lease === job.lease_token &&
      committed?.p_state === "approved",
    "revision and lease fenced",
  );
});

Deno.test("unsupported references and Storage outages remain held without provider calls", async () => {
  for (const outage of [false, true]) {
    let state: unknown, calls = 0;
    const client: ScreeningClient = {
      rpc: (name, parameters) => {
        if (name === "read_screening_lease_v1") {
          return Promise.resolve({
            data: {
              text: "Synthetic",
              images: [outage ? ref : "https://foreign.invalid/photo.jpg"],
            },
            error: null,
          });
        }
        state = parameters?.p_state;
        return Promise.resolve({ data: true, error: null });
      },
      storage: {
        from: () => ({
          download: () =>
            Promise.resolve({
              data: null,
              error: { message: "sensitive storage body" },
            }),
        }),
      },
    };
    const request: typeof fetch = () => {
      calls++;
      return Promise.resolve(response());
    };
    assert(
      await processScreeningJob(client, job, config, request) === "applied",
      "held outcome recorded",
    );
    assert(
      state === "retry" && calls === 0,
      "outage retries, unsupported media needs review",
    );
  }
});

Deno.test("albums screen one image per request and never approve partial success", async () => {
  for (const failAt of [-1, 2]) {
    let calls = 0;
    let finished: Record<string, unknown> | undefined;
    const payload = {
      text: "Synthetic coffee album",
      images: [ref, ref, ref, ref],
    };
    const client: ScreeningClient = {
      rpc: (name, params) =>
        Promise.resolve(
          name === "read_screening_lease_v1"
            ? { data: payload, error: null }
            : (finished = params, { data: true, error: null }),
        ),
      storage: {
        from: () => ({
          download: () =>
            Promise.resolve({ data: new Blob([syntheticJPEG]), error: null }),
        }),
      },
    };
    await processScreeningJob(client, job, config, (_url, init) => {
      const body = JSON.parse(String(init?.body));
      assert(
        body.input.filter((p: { type: string }) => p.type === "image_url")
          .length === 1,
        "API permits one image only",
      );
      return Promise.resolve(
        calls++ === failAt
          ? new Response(
            JSON.stringify({
              error: { code: "invalid_image", message: "sensitive body" },
            }),
            { status: 400 },
          )
          : response(),
      );
    });
    assert(
      finished?.p_state === (failAt < 0 ? "approved" : "retry"),
      "partial result never approves",
    );
    assert(
      calls === (failAt < 0 ? 4 : 3),
      "each image processed until first failure",
    );
    assert(
      !JSON.stringify(finished).includes("sensitive body"),
      "no raw provider body",
    );
  }
});
Deno.test("legacy owner uploads resolve without accepting another owner's photo", () => {
  for (
    const path of [
      `visit-photos/${job.owner_id}/legacy.jpg`,
      `profile-media/${job.owner_id}/visits/legacy.jpg`,
    ]
  ) {
    assert(
      screeningMediaLocation(
        `${config.supabaseURL}/storage/v1/object/public/${path}`,
        job,
        config.supabaseURL,
      ),
      "legacy path from sealed payload accepted",
    );
    assert(
      !screeningMediaLocation(
        `${config.supabaseURL}/storage/v1/object/public/${
          path.replace(job.owner_id, "another-owner")
        }`,
        job,
        config.supabaseURL,
      ),
      "other owner rejected",
    );
  }
});

Deno.test("missing Storage objects carry sanitized diagnostics without becoming policy flags", async () => {
  for (const status of [404, 503]) {
    let finished: Record<string, unknown> | undefined;
    const client: ScreeningClient = {
      rpc: (name, params) =>
        Promise.resolve(
          name === "read_screening_lease_v1"
            ? { data: { text: "Synthetic", images: [ref] }, error: null }
            : (finished = params, { data: true, error: null }),
        ),
      storage: {
        from: () => ({
          download: () =>
            Promise.resolve({
              data: null,
              error: {
                statusCode: String(status),
                message: "sensitive path and content",
              },
            }),
        }),
      },
    };
    let calls = 0;
    await processScreeningJob(client, job, config, () => {
      calls++;
      throw Error("must not transmit");
    });
    const evidence = finished?.p_evidence as {
      reason: string;
      diagnostics: { http_status: number; error_code?: string };
    };
    assert(
      finished?.p_state === "retry" && calls === 0,
      "technical failures never become policy flags",
    );
    assert(
      evidence.reason ===
        (status === 404 ? "invalid_input" : "provider_unavailable"),
      "missing files differ from outages",
    );
    assert(
      evidence.diagnostics.http_status === status,
      "sanitized HTTP status retained",
    );
    assert(
      evidence.diagnostics.error_code ===
        (status === 404 ? "storage_object_missing" : undefined),
      "fixed missing-file diagnostic",
    );
    assert(
      !JSON.stringify(finished).includes("sensitive"),
      "raw error content excluded",
    );
  }
});
