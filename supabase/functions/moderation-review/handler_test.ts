import { handleReview, type ReviewDependencies } from "./handler.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const id = "10000000-0000-4000-8000-000000000001";
const owner = "20000000-0000-4000-8000-000000000001";
const revision = "30000000-0000-4000-8000-000000000001";
const baseURL = "https://example.supabase.co";
const item = {
  subject_kind: "visit",
  subject_id: id,
  owner_id: owner,
  revision,
  payload: {
    text: "Synthetic coffee",
    images: [`mugshot-storage://visit-photos-private/${owner}/${id}/photo.jpg`],
  },
};
const parameters = { p_kind: "visit", p_id: id, p_revision: revision };
const request = (body: unknown = parameters, token = "synthetic") =>
  new Request("https://example.test/review", {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
function fixture(
  options: {
    authenticated?: boolean;
    denied?: boolean;
    changed?: boolean;
    revoked?: boolean;
    images?: string[];
  } = {},
) {
  let reads = 0, signs = 0, authentications = 0;
  const source = {
    ...item,
    payload: { ...item.payload, images: options.images ?? item.payload.images },
  };
  const dependencies: ReviewDependencies = {
    baseURL,
    authenticate: async (authorization) => {
      authentications++;
      assert(
        authorization === "Bearer synthetic",
        "caller authorization is preserved",
      );
      if (options.authenticated === false) return null;
      return {
        read: async (input) => {
          reads++;
          assert(
            JSON.stringify(input) === JSON.stringify(parameters),
            "revision-bound parameters",
          );
          if (options.denied || (reads > 1 && options.revoked)) {
            return {
              data: null,
              error: "synthetic private error",
            };
          }
          return {
            data: reads > 1 && options.changed ? null : source,
            error: null,
          };
        },
      };
    },
    sign: async (bucket, path, expires) => {
      signs++;
      assert(
        bucket === "visit-photos-private" &&
          path === `${owner}/${id}/photo.jpg` && expires === 60,
        "only owner-scoped short previews are signed",
      );
      return `${baseURL}/storage/v1/object/sign/${bucket}/${path}?token=synthetic`;
    },
  };
  return { dependencies, counts: () => ({ reads, signs, authentications }) };
}
Deno.test("review rejects invalid authentication and unauthorized operators before signing", async () => {
  for (const options of [{ authenticated: false }, { denied: true }]) {
    const f = fixture(options),
      response = await handleReview(request(), f.dependencies);
    assert(
      response.status === (options.authenticated === false ? 401 : 403),
      "authorization status",
    );
    assert(f.counts().signs === 0, "no signing before authorization");
    assert(
      !(await response.text()).includes("synthetic private error"),
      "provider errors remain private",
    );
  }
  const f = fixture();
  assert(
    (await handleReview(request(parameters, ""), f.dependencies)).status ===
      401,
    "missing bearer rejected",
  );
  assert(f.counts().authentications === 0, "missing bearer never reaches auth");
});
Deno.test("review validates bounded input before backend work", async () => {
  for (
    const body of [null, { ...parameters, p_id: "invalid" }, {
      ...parameters,
      padding: "x".repeat(2048),
    }]
  ) {
    const f = fixture();
    assert(
      (await handleReview(request(body), f.dependencies)).status === 400,
      "invalid input rejected",
    );
    assert(
      f.counts().authentications === 0,
      "no backend work on invalid input",
    );
  }
});
Deno.test("privacy withdrawal and role revocation during signing return no media", async () => {
  for (const options of [{ changed: true }, { revoked: true }]) {
    const f = fixture(options),
      response = await handleReview(request(), f.dependencies);
    assert(
      response.status === 409 && f.counts().reads === 2,
      "latest authorization and revision checked",
    );
    assert(
      !(await response.text()).includes("token="),
      "no URL escapes a withdrawn preview",
    );
  }
});
Deno.test("review signs only admitted media and returns no-store responses", async () => {
  const f = fixture({
    images: [
      ...item.payload.images,
      "https://foreign.test/image.jpg",
      `mugshot-storage://visit-photos-private/other/${id}/photo.jpg`,
    ],
  });
  const response = await handleReview(request(), f.dependencies);
  assert(response.status === 200, "valid preview");
  assert(
    response.headers.get("Cache-Control") === "private, no-store",
    "no cache",
  );
  const body = await response.json();
  assert(
    f.counts().signs === 1 && body.media_urls.length === 3 &&
      body.media_urls[1] === null && body.media_urls[2] === null,
    "foreign media is never signed",
  );
});
