import { drainAnalyticsErasures } from "./analytics-worker.ts";

const configuration = {
  region: "us" as const,
  projectID: 521217,
  personalAPIKey: "synthetic-key-only-for-tests",
};
const owner = "11111111-1111-4111-8111-111111111111";
const person = "22222222-2222-4222-8222-222222222222";
const timestamp = "2026-09-13T06:00:00Z";
function assert(value: unknown) {
  if (!value) throw new Error("Assertion failed");
}

Deno.test("analytics worker persists target before submission and keeps accepted deletion pending", async () => {
  const calls: string[] = [];
  let outcome: unknown;
  const result = await drainAnalyticsErasures(
    async (name, args) => {
      calls.push(name);
      if (name.startsWith("claim_")) {
        return {
          data: [{
            request_id: "request",
            owner_id: owner,
            person_id: null,
            submitted_at: null,
            lease_token: "lease",
          }],
          error: null,
        };
      }
      if (name.startsWith("prepare_")) return { data: timestamp, error: null };
      outcome = args.p_outcome;
      return { data: true, error: null };
    },
    configuration,
    true,
    {
      lookup: async () => ({ ownerID: owner, personID: person }),
      status: async () => "pending",
      submit: async () => {
        assert(calls.includes("prepare_account_analytics_erasure_v1"));
        return "submitted";
      },
    },
  );
  assert(
    result.verified === 0 && result.pending === 1 && outcome === "submitted",
  );
});

Deno.test("analytics retry checks saved target receipt without repeating a completed submission", async () => {
  let submitted = false;
  const result = await drainAnalyticsErasures(
    async (name, args) => {
      if (name.startsWith("claim_")) {
        return {
          data: [{
            request_id: "request",
            owner_id: owner,
            person_id: person,
            submitted_at: timestamp,
            lease_token: "lease",
          }],
          error: null,
        };
      }
      assert(args.p_outcome === "verified");
      return { data: true, error: null };
    },
    configuration,
    true,
    {
      lookup: async () => {
        throw new Error("Must use saved target");
      },
      status: async () => "verified",
      submit: async () => {
        submitted = true;
        return "submitted";
      },
    },
  );
  assert(result.verified === 1 && !submitted);
});

Deno.test("analytics worker does not consume attempts when disabled or pointed at another project", async () => {
  for (const projectID of [521217, 1]) {
    await drainAnalyticsErasures(
      async (_, args) => {
        assert(args.p_limit === 0);
        return { data: [], error: null };
      },
      { ...configuration, projectID },
      projectID !== 521217,
    );
  }
});

Deno.test("accepted erasure is polled without repeatedly enqueueing new provider deletions", async () => {
  let submitted = false;
  const result = await drainAnalyticsErasures(
    async (name, args) => {
      if (name.startsWith("claim_")) {
        return {
          data: [{
            request_id: "request",
            owner_id: owner,
            person_id: person,
            submitted_at: timestamp,
            provider_accepted: true,
            lease_token: "lease",
          }],
          error: null,
        };
      }
      assert(args.p_outcome === "pending");
      return { data: true, error: null };
    },
    configuration,
    true,
    {
      lookup: async () => {
        throw new Error("Use saved target");
      },
      status: async () => "pending",
      submit: async () => {
        submitted = true;
        return "submitted";
      },
    },
  );
  assert(result.pending === 1 && !submitted);
});
