import {
  analyticsErasureStatus,
  lookupAnalyticsErasureTarget,
  submitAnalyticsErasure,
} from "./analytics.ts";
const ownerID = "11111111-1111-4111-8111-111111111111";
const personID = "22222222-2222-4222-8222-222222222222";
const config = {
  region: "us" as const,
  projectID: 123,
  personalAPIKey: "synthetic-personal-key-for-tests",
};
function assert(value: boolean, message: string) {
  if (!value) throw new Error(message);
}
function response(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status });
}
async function rejects(action: () => Promise<unknown>) {
  try {
    await action();
  } catch {
    return;
  }
  throw new Error("Expected request rejection");
}

Deno.test("analytics lookup binds the provider person to the exact account without returning profile data", async () => {
  const target = await lookupAnalyticsErasureTarget(
    config,
    ownerID,
    ((url: string, init: RequestInit) => {
      assert(
        url ===
          `https://us.posthog.com/api/projects/123/persons/?distinct_id=${ownerID}&limit=2`,
        "exact fixed-host account lookup",
      );
      assert(
        init.redirect === "error",
        "credentials must not follow redirects",
      );
      return Promise.resolve(
        response({
          next: null,
          results: [{
            uuid: personID,
            distinct_ids: [ownerID, "synthetic-anonymous-alias"],
            properties: { private: "discarded" },
          }],
        }),
      );
    }) as typeof fetch,
  );
  assert(
    JSON.stringify(target) ===
      JSON.stringify({ ownerID, personID, otherAccountCandidates: [] }),
    "minimal verified target only",
  );
  await rejects(() =>
    lookupAnalyticsErasureTarget(
      config,
      ownerID,
      (() =>
        Promise.resolve(
          response({
            results: [{ uuid: personID, distinct_ids: ["different-account"] }],
          }),
        )) as typeof fetch,
    )
  );
});

Deno.test("analytics deletion requests events and recordings but returns submitted, never completed", async () => {
  const status = await submitAnalyticsErasure(
    config,
    { ownerID, personID },
    ((url: string, init: RequestInit) => {
      assert(url.endsWith("/persons/bulk_delete/"), "fixed deletion endpoint");
      assert(init.method === "POST", "explicit erasure mutation");
      assert(
        init.body ===
          JSON.stringify({
            ids: [personID],
            delete_events: true,
            delete_recordings: true,
            keep_person: false,
          }),
        "one verified person with full cleanup flags",
      );
      return Promise.resolve(
        response({
          deletion_errors: [],
          events_queued_for_deletion: true,
          recordings_queued_for_deletion: true,
        }, 202),
      );
    }) as typeof fetch,
  );
  assert(status === "submitted", "acceptance is not completion");
  await rejects(() =>
    submitAnalyticsErasure(
      config,
      { ownerID, personID },
      (() =>
        Promise.resolve(
          response({
            deletion_errors: [],
            events_queued_for_deletion: false,
            recordings_queued_for_deletion: true,
          }, 202),
        )) as typeof fetch,
    )
  );
});

Deno.test("analytics verification requires a matching completed deletion with a verified timestamp", async () => {
  for (
    const results of [
      [{
        person_uuid: personID,
        created_at: "2026-09-12T00:00:00Z",
        status: "completed",
        delete_verified_at: "2026-09-12T00:01:00Z",
      }],
      [],
      [{ person_uuid: personID, status: "pending" }],
      [{
        person_uuid: ownerID,
        status: "completed",
        delete_verified_at: "2026-09-13T00:00:00Z",
      }],
      [{
        person_uuid: personID,
        status: "completed",
        delete_verified_at: null,
      }],
    ]
  ) {
    assert(
      await analyticsErasureStatus(
        config,
        { ownerID, personID },
        "2026-09-13T00:00:00Z",
        (() => Promise.resolve(response({ results }))) as typeof fetch,
      ) === "pending",
      "weak evidence must remain pending",
    );
  }
  assert(
    await analyticsErasureStatus(
      config,
      { ownerID, personID },
      "2026-09-13T00:00:00Z",
      (() =>
        Promise.resolve(
          response({
            results: [{
              person_uuid: personID,
              created_at: "2026-09-13T00:00:00Z",
              status: "completed",
              delete_verified_at: "2026-09-13T00:00:00Z",
            }],
          }),
        )) as typeof fetch,
    ) === "verified",
    "exact completed evidence accepted",
  );
});

Deno.test("analytics transport rejects malformed configuration and oversized responses", async () => {
  await rejects(() =>
    lookupAnalyticsErasureTarget(
      { ...config, projectID: -1 },
      ownerID,
      (() => {
        throw new Error("must not call");
      }) as typeof fetch,
    )
  );
  await rejects(() =>
    lookupAnalyticsErasureTarget(
      config,
      ownerID,
      (() =>
        Promise.resolve(
          response({ padding: "x".repeat(70000) }),
        )) as typeof fetch,
    )
  );
});
