import {
  type AnalyticsErasureConfiguration,
  analyticsErasureStatus,
  lookupAnalyticsErasureTarget,
  submitAnalyticsErasure,
} from "./analytics.ts";

type RPC = (
  name: string,
  args: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: unknown }>;
type Job = {
  request_id: string;
  owner_id: string;
  person_id: string | null;
  submitted_at: string | null;
  lease_token: string;
};
type Provider = {
  lookup: typeof lookupAnalyticsErasureTarget;
  submit: typeof submitAnalyticsErasure;
  status: typeof analyticsErasureStatus;
};
const provider: Provider = {
  lookup: lookupAnalyticsErasureTarget,
  submit: submitAnalyticsErasure,
  status: analyticsErasureStatus,
};

export async function drainAnalyticsErasures(
  rpc: RPC,
  configuration: AnalyticsErasureConfiguration,
  enabled: boolean,
  service: Provider = provider,
) {
  // Bound the deployment to the independently matched Mugshot project.
  const ready = enabled && configuration.region === "us" &&
    configuration.projectID === 521217 &&
    configuration.personalAPIKey.trim().length >= 20;
  let claim;
  try {
    claim = await rpc("claim_account_analytics_erasures_v1", {
      p_limit: ready ? 1 : 0,
    });
  } catch {
    return { available: false, claimed: 0, verified: 0, pending: 0 };
  }
  if (claim.error || !Array.isArray(claim.data)) {
    return { available: false, claimed: 0, verified: 0, pending: 0 };
  }
  let verified = 0;
  for (const row of claim.data as Job[]) {
    let outcome: "pending" | "verified" | "attention" = "pending";
    try {
      if (!ready) throw new Error();
      let personID = row.person_id;
      let submittedAt = row.submitted_at;
      if (!personID || !submittedAt) {
        const target = await service.lookup(configuration, row.owner_id);
        if (!target) throw new Error(); // Retry absence; never infer historic erasure.
        const prepared = await rpc("prepare_account_analytics_erasure_v1", {
          p_request_id: row.request_id,
          p_lease: row.lease_token,
          p_person_id: target.personID,
          p_other_account_candidates: target.otherAccountCandidates ?? [],
        });
        if (prepared.error) throw new Error();
        if (typeof prepared.data !== "string") {
          outcome = "attention";
          throw new Error();
        }
        personID = target.personID;
        submittedAt = prepared.data;
      }
      const target = { ownerID: row.owner_id, personID };
      // Check before retrying: a prior submission may have succeeded after a
      // timeout. Only this attempt's matching verified receipt can complete it.
      if (
        await service.status(configuration, target, submittedAt) === "verified"
      ) outcome = "verified";
      else await service.submit(configuration, target);
    } catch {
      /* Coarse status only; never log provider payloads or identifiers. */
    }
    try {
      const finished = await rpc("finish_account_analytics_erasure_v1", {
        p_request_id: row.request_id,
        p_lease: row.lease_token,
        p_outcome: outcome,
      });
      if (outcome === "verified" && !finished.error && finished.data === true) {
        verified++;
      }
    } catch {
      /* Reclaim an unacknowledged lease without claiming completion. */
    }
  }
  return {
    available: ready,
    claimed: claim.data.length,
    verified,
    pending: claim.data.length - verified,
  };
}
