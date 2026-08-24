import { createClient } from "npm:@supabase/supabase-js@2.110.3";
import {
  accountDeletionSubjectMatches,
  cleanupWorkerContract,
  exactStorageRemovalPlan,
  identityReconciliationAction,
  isRecoverySecret,
  shouldRestoreStorageOwnership,
  stepUpAuthenticationEvidence,
  type StorageManifestItem,
} from "./state.ts";

const protocolName = "mugshot-account-deletion";
const protocolVersion = 3;
const deletionAction = "delete_v3";
const recoveryAction = "resume_delete_v3";
const acknowledgementAction = "acknowledge_delete_v3";
const beginStepUpAction = "begin_delete_step_up_v3";
const authorizeStepUpAction = "authorize_delete_step_up_v3";
const cleanupAction = cleanupWorkerContract.action;
const buckets = [
  "visit-photos",
  "visit-photos-private",
  "profile-media",
  "home-coffee-bag-photos",
] as const;

const corsHeaders = {
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Content-Type": "application/json",
};

type AdminClient = ReturnType<typeof createClient<any>>;

interface DeletionJob {
  job_id: string;
  request_id: string;
  subject_id?: string | null;
  status: string;
  storage_manifest: StorageManifestItem[];
  identity_exists?: boolean;
  database_identity_exists?: boolean;
  storage_ownership_detached_at?: string | null;
  identity_deleted_at?: string | null;
  collaboration_finalized_at?: string | null;
  cleanup_completed_at?: string | null;
  redacted_at?: string | null;
  completion_proof_state?: "completed" | "expired_completed" | null;
  completion_receipt_fresh_until?: string | null;
}

interface ProcessResult {
  requestId: string;
  jobId: string;
  subjectId: string;
  identityDeleted: boolean;
  collaborationStatus: "not_started" | "pending" | "completed";
  cleanupStatus: "not_started" | "pending" | "completed";
  status:
    | "identity_deletion_pending"
    | "collaboration_pending"
    | "cleanup_pending"
    | "completed";
  completionProofState?: "completed" | "expired_completed";
}

function capability() {
  const automaticCleanupScheduled =
    Deno.env.get("ACCOUNT_DELETION_WORKER_SCHEDULED") === "true";
  const liveSessionGateConfigured =
    Deno.env.get("ACCOUNT_DELETION_LIVE_SESSION_GATE") === "true";
  const stepUpClientConfigured =
    Deno.env.get("ACCOUNT_DELETION_STEP_UP_CLIENT_READY") === "true";
  return {
    protocol: protocolName,
    protocolVersion,
    destructiveAction: deletionAction,
    requiresExplicitAction: true,
    expectedSubjectRequired: true,
    recentSessionRequired: true,
    recentSessionMaximumAgeSeconds: 900,
    stepUpRequired: true,
    stepUpProtocol: "fresh_amr_new_session_challenge_v3",
    beginStepUpAction,
    authorizeStepUpAction,
    stepUpChallengeLifetimeSeconds: 300,
    stepUpAuthorizationLifetimeSeconds: 120,
    stepUpSingleUse: true,
    stepUpClientConfigured,
    recoveryAction,
    localCleanupAcknowledgementAction: acknowledgementAction,
    recoveryAuthentication: "sha256_capability",
    recoveryPersistsAfterAuthDeletion: true,
    completionReceiptFreshDays: 400,
    completionTombstoneRetention: "until_local_cleanup_ack_plus_30_days",
    completionTombstoneFinalRetentionDays: 30,
    recoveryCapabilityExpires: false,
    recoveryCapabilityExpiresAfterLocalAcknowledgement: true,
    exactOwnerValidatedStorageManifest: true,
    statusRpc: "read_account_deletion_job_by_recovery_v3",
    cleanupWorkerAction: cleanupAction,
    cleanupWorkerAuthentication: cleanupWorkerContract.authentication,
    cleanupWorkerInvocation: cleanupWorkerContract.invocation,
    cleanupDelivery: cleanupWorkerContract.delivery,
    automaticCleanupScheduled,
    // Older clients include this field in their destructive capability gate.
    // Keep deletion fail-closed until a client that performs the step-up
    // challenge has been deployed and the operational session hook is active.
    liveSessionGateConfigured: liveSessionGateConfigured &&
      stepUpClientConfigured,
    identityBeforeStorage: true,
    buckets: [...buckets],
  };
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function responseFor(result: ProcessResult): Response {
  return json({
    protocol: protocolName,
    protocolVersion,
    ...result,
    cleanupDelivery: result.cleanupStatus === "completed"
      ? "none_required"
      : cleanupWorkerContract.delivery,
  }, result.status === "completed" ? 200 : 202);
}

function pendingResultFor(
  job: DeletionJob,
  responseSubjectID: string,
): ProcessResult {
  const identityDeleted = job.identity_deleted_at != null;
  const collaborationCompleted = job.collaboration_finalized_at != null;
  const cleanupCompleted = job.cleanup_completed_at != null ||
    job.status === "completed";
  return {
    requestId: job.request_id,
    jobId: job.job_id,
    subjectId: responseSubjectID,
    identityDeleted,
    collaborationStatus: collaborationCompleted
      ? "completed"
      : identityDeleted
      ? "pending"
      : "not_started",
    cleanupStatus: cleanupCompleted
      ? "completed"
      : collaborationCompleted
      ? "pending"
      : "not_started",
    status: cleanupCompleted
      ? "completed"
      : collaborationCompleted
      ? "cleanup_pending"
      : identityDeleted
      ? "collaboration_pending"
      : "identity_deletion_pending",
    completionProofState: cleanupCompleted
      ? job.completion_proof_state ?? "completed"
      : undefined,
  };
}

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return null;
  const token = authorization.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

function constantTimeEqual(lhs: string, rhs: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(lhs);
  const right = encoder.encode(rhs);
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }
  return difference === 0;
}

function isUUID(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function jwtPayloadFromToken(token: string): Record<string, unknown> | null {
  try {
    const payload = token.split(".")[1];
    if (!payload) return null;
    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/") +
      "=".repeat((4 - payload.length % 4) % 4);
    const value = JSON.parse(atob(normalized));
    return typeof value === "object" && value !== null
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function sessionIDFromJWT(token: string): string | null {
  const value = jwtPayloadFromToken(token);
  return isUUID(value?.session_id) ? value.session_id : null;
}

function randomCapability(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function parseBody(
  request: Request,
): Promise<Record<string, unknown> | null> {
  try {
    const value = await request.json();
    return typeof value === "object" && value !== null
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function stableErrorCode(error: unknown, fallback: string): string {
  if (typeof error === "object" && error !== null && "code" in error) {
    const candidate = String((error as { code?: unknown }).code ?? "")
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, "_")
      .slice(0, 80);
    if (candidate.length > 0) return candidate;
  }
  return fallback;
}

function errorMessage(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as { message?: unknown }).message ?? "");
  }
  return String(error ?? "");
}

function isKnownStorageOwnershipBlocker(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const candidate = error as { code?: unknown; message?: unknown };
  const code = String(candidate.code ?? "").toLowerCase();
  const message = String(candidate.message ?? "").toLowerCase();
  return code === "storage_owner_conflict" || (
    message.includes("storage") &&
    (message.includes("owner") || message.includes("object")) &&
    (message.includes("delete") || message.includes("foreign key"))
  ) || (
    (code === "unexpected_failure" || code === "database_error") &&
    message.includes("database error deleting user")
  );
}

async function readJob(
  admin: AdminClient,
  jobID: string,
): Promise<DeletionJob> {
  const { data, error } = await admin.rpc("read_account_deletion_job_v3", {
    p_job_id: jobID,
  });
  if (error) throw error;
  if (!data || typeof data !== "object" || !isUUID(data.job_id)) {
    throw new Error("deletion_job_unavailable");
  }
  return data as DeletionJob;
}

async function readJobByRecovery(
  admin: AdminClient,
  requestID: string,
  subjectID: string,
  recoverySecret: string,
): Promise<DeletionJob | null> {
  const recoveryHash = await sha256Hex(recoverySecret);
  const subjectProofHash = await sha256Hex(
    `${subjectID.toLowerCase()}:${recoverySecret}`,
  );
  const { data, error } = await admin.rpc(
    "read_account_deletion_job_by_recovery_v3",
    {
      p_request_id: requestID,
      p_recovery_hash: recoveryHash,
      p_subject_proof_hash: subjectProofHash,
    },
  );
  if (error) throw error;
  if (!data || typeof data !== "object" || !isUUID(data.job_id)) return null;
  return data as DeletionJob;
}

async function claimJobLease(
  admin: AdminClient,
  jobID: string,
  leaseToken: string,
): Promise<boolean> {
  const { data, error } = await admin.rpc("claim_account_deletion_job_v3", {
    p_job_id: jobID,
    p_lease_token: leaseToken,
  });
  if (error) throw error;
  return data === true;
}

async function renewJobLease(
  admin: AdminClient,
  jobID: string,
  leaseToken: string,
): Promise<void> {
  const { data, error } = await admin.rpc(
    "renew_account_deletion_job_lease_v3",
    { p_job_id: jobID, p_lease_token: leaseToken },
  );
  if (error || data !== true) {
    throw error ?? new Error("stale_account_deletion_lease");
  }
}

async function markPending(
  admin: AdminClient,
  jobID: string,
  status: ProcessResult["status"],
  error: unknown,
  fallback: string,
  leaseToken: string,
): Promise<void> {
  const { data, error: receiptError } = await admin.rpc(
    "mark_account_deletion_pending_v3",
    {
      p_job_id: jobID,
      p_status: status,
      p_error_code: stableErrorCode(error, fallback),
      p_lease_token: leaseToken,
    },
  );
  if (receiptError) {
    console.error("delete-account pending receipt failed", receiptError);
  } else if (data !== true) {
    console.warn("delete-account pending receipt lost its lease", { jobID });
  }
}

async function confirmAuthoritativeIdentityState(
  admin: AdminClient,
  initialJob: DeletionJob,
  leaseToken: string,
): Promise<{ confirmed: boolean; job: DeletionJob; error: unknown }> {
  let job = await readJob(admin, initialJob.job_id);
  let confirmation = await admin.rpc("confirm_account_identity_deleted_v3", {
    p_job_id: job.job_id,
    p_lease_token: leaseToken,
  });
  job = await readJob(admin, job.job_id);
  let action = identityReconciliationAction({
    identityExists: job.identity_exists,
    databaseIdentityExists: job.database_identity_exists,
  });
  if (confirmation.data === true || action === "confirmed") {
    return { confirmed: true, job, error: null };
  }
  if (action === "retry_database_confirmation") {
    confirmation = await admin.rpc("confirm_account_identity_deleted_v3", {
      p_job_id: job.job_id,
      p_lease_token: leaseToken,
    });
    job = await readJob(admin, job.job_id);
    action = identityReconciliationAction({
      identityExists: job.identity_exists,
      databaseIdentityExists: job.database_identity_exists,
    });
    if (confirmation.data === true || action === "confirmed") {
      return { confirmed: true, job, error: null };
    }
  }
  return { confirmed: false, job, error: confirmation.error };
}

async function ensureIdentityDeleted(
  admin: AdminClient,
  initialJob: DeletionJob,
  leaseToken: string,
): Promise<{ deleted: boolean; job: DeletionJob }> {
  let job = await readJob(admin, initialJob.job_id);
  if (job.identity_deleted_at) return { deleted: true, job };
  if (!job.subject_id) throw new Error("missing_deletion_subject");
  await renewJobLease(admin, job.job_id, leaseToken);

  // Recheck the owner-authoritative frozen inventory immediately before any
  // session or identity is revoked. The database guard prevents later owned
  // writes, including an empty-manifest account, from reopening this boundary.
  const preflight = await admin.rpc(
    "seal_account_deletion_storage_preflight_v3",
    { p_job_id: job.job_id, p_lease_token: leaseToken },
  );
  if (preflight.error || preflight.data !== true) {
    await markPending(
      admin,
      job.job_id,
      "identity_deletion_pending",
      preflight.error ?? new Error("storage_inventory_requires_support"),
      "storage_inventory_requires_support",
      leaseToken,
    );
    return { deleted: false, job: await readJob(admin, job.job_id) };
  }

  const revoked = await admin.rpc("revoke_account_sessions_v3", {
    p_job_id: job.job_id,
    p_lease_token: leaseToken,
  });
  if (revoked.error) {
    await markPending(
      admin,
      job.job_id,
      "identity_deletion_pending",
      revoked.error,
      "session_revocation_pending",
      leaseToken,
    );
    return { deleted: false, job: await readJob(admin, job.job_id) };
  }

  let deleteError: unknown = null;
  if (job.identity_exists !== false) {
    await renewJobLease(admin, job.job_id, leaseToken);
    const result = await admin.auth.admin.deleteUser(job.subject_id);
    deleteError = result.error;
  }
  let confirmation = await confirmAuthoritativeIdentityState(
    admin,
    job,
    leaseToken,
  );

  if (!confirmation.confirmed) {
    job = confirmation.job;
    const mayUseDetachedRetry = job.storage_ownership_detached_at != null;
    const mayDetachForKnownBlocker =
      job.storage_ownership_detached_at == null &&
      isKnownStorageOwnershipBlocker(deleteError) &&
      (job.storage_manifest?.length ?? 0) > 0;

    if (
      job.identity_exists !== false &&
      (mayUseDetachedRetry || mayDetachForKnownBlocker)
    ) {
      if (mayDetachForKnownBlocker) {
        const detach = await admin.rpc(
          "detach_account_storage_ownership_v3",
          { p_job_id: job.job_id, p_lease_token: leaseToken },
        );
        if (detach.error) {
          await markPending(
            admin,
            job.job_id,
            "identity_deletion_pending",
            detach.error,
            "storage_ownership_detach_failed",
            leaseToken,
          );
          return { deleted: false, job: await readJob(admin, job.job_id) };
        }
      }

      await renewJobLease(admin, job.job_id, leaseToken);
      const retry = await admin.auth.admin.deleteUser(job.subject_id!);
      deleteError = retry.error;
      confirmation = await confirmAuthoritativeIdentityState(
        admin,
        job,
        leaseToken,
      );
      if (!confirmation.confirmed) {
        const restored = shouldRestoreStorageOwnership({
            identityExists: confirmation.job.identity_exists,
            databaseIdentityExists: confirmation.job.database_identity_exists,
          })
          ? await admin.rpc("restore_account_storage_ownership_v3", {
            p_job_id: job.job_id,
            p_lease_token: leaseToken,
          })
          : { error: null };
        await markPending(
          admin,
          job.job_id,
          "identity_deletion_pending",
          restored.error ?? confirmation.error ?? deleteError,
          restored.error
            ? "storage_ownership_restore_pending"
            : "identity_deletion_pending",
          leaseToken,
        );
        return { deleted: false, job: await readJob(admin, job.job_id) };
      }
    } else {
      await markPending(
        admin,
        job.job_id,
        "identity_deletion_pending",
        confirmation.error ?? deleteError,
        "identity_deletion_pending",
        leaseToken,
      );
      return { deleted: false, job: await readJob(admin, job.job_id) };
    }
  }

  const marked = await admin.rpc("mark_account_deletion_identity_deleted_v3", {
    p_job_id: job.job_id,
    p_lease_token: leaseToken,
  });
  if (marked.error) {
    job = await readJob(admin, job.job_id);
    if (!job.identity_deleted_at) {
      await markPending(
        admin,
        job.job_id,
        "identity_deletion_pending",
        marked.error,
        "identity_receipt_pending",
        leaseToken,
      );
      return { deleted: false, job: await readJob(admin, job.job_id) };
    }
  }
  return { deleted: true, job: await readJob(admin, job.job_id) };
}

async function ensureCollaborationFinalized(
  admin: AdminClient,
  initialJob: DeletionJob,
  leaseToken: string,
): Promise<{ finalized: boolean; job: DeletionJob }> {
  let job = await readJob(admin, initialJob.job_id);
  if (job.collaboration_finalized_at) return { finalized: true, job };
  await renewJobLease(admin, job.job_id, leaseToken);
  const { error } = await admin.rpc("finalize_account_collaboration_v3", {
    p_job_id: job.job_id,
    p_lease_token: leaseToken,
  });
  if (error) {
    await markPending(
      admin,
      job.job_id,
      "collaboration_pending",
      error,
      "collaboration_finalization_pending",
      leaseToken,
    );
    return { finalized: false, job: await readJob(admin, job.job_id) };
  }
  job = await readJob(admin, job.job_id);
  return { finalized: job.collaboration_finalized_at != null, job };
}

async function finishStorageCleanup(
  admin: AdminClient,
  job: DeletionJob,
  leaseToken: string,
): Promise<boolean> {
  if (job.cleanup_completed_at || job.status === "completed") return true;
  if (!job.identity_deleted_at || !job.collaboration_finalized_at) return false;
  try {
    await renewJobLease(admin, job.job_id, leaseToken);
    const verified = await admin.rpc("verify_account_storage_cleanup_v3", {
      p_job_id: job.job_id,
    });
    if (verified.error || verified.data !== true) {
      throw verified.error ?? new Error("storage_manifest_changed");
    }
    const plan = exactStorageRemovalPlan(
      job.subject_id ?? "",
      job.storage_manifest ?? [],
    );
    for (const [bucket, paths] of plan) {
      for (let index = 0; index < paths.length; index += 100) {
        await renewJobLease(admin, job.job_id, leaseToken);
        const { error } = await admin.storage.from(bucket).remove(
          paths.slice(index, index + 100),
        );
        if (error) throw error;
      }
    }
    const completed = await admin.rpc(
      "mark_account_deletion_cleanup_completed_v3",
      { p_job_id: job.job_id, p_lease_token: leaseToken },
    );
    if (completed.error) throw completed.error;
    return true;
  } catch (error) {
    await markPending(
      admin,
      job.job_id,
      "cleanup_pending",
      error,
      "storage_cleanup_pending",
      leaseToken,
    );
    return false;
  }
}

async function processJob(
  admin: AdminClient,
  initialJob: DeletionJob,
  responseSubjectID: string,
  leaseToken: string,
): Promise<ProcessResult> {
  if (initialJob.status === "completed") {
    return {
      requestId: initialJob.request_id,
      jobId: initialJob.job_id,
      subjectId: responseSubjectID,
      identityDeleted: true,
      collaborationStatus: "completed",
      cleanupStatus: "completed",
      status: "completed",
      completionProofState: initialJob.completion_proof_state ?? "completed",
    };
  }
  const identity = await ensureIdentityDeleted(admin, initialJob, leaseToken);
  if (!identity.deleted) {
    return {
      requestId: identity.job.request_id,
      jobId: identity.job.job_id,
      subjectId: responseSubjectID,
      identityDeleted: false,
      collaborationStatus: "not_started",
      cleanupStatus: "not_started",
      status: "identity_deletion_pending",
    };
  }
  const collaboration = await ensureCollaborationFinalized(
    admin,
    identity.job,
    leaseToken,
  );
  if (!collaboration.finalized) {
    return {
      requestId: collaboration.job.request_id,
      jobId: collaboration.job.job_id,
      subjectId: responseSubjectID,
      identityDeleted: true,
      collaborationStatus: "pending",
      cleanupStatus: "pending",
      status: "collaboration_pending",
    };
  }
  const cleanupCompleted = await finishStorageCleanup(
    admin,
    collaboration.job,
    leaseToken,
  );
  return {
    requestId: collaboration.job.request_id,
    jobId: collaboration.job.job_id,
    subjectId: responseSubjectID,
    identityDeleted: true,
    collaborationStatus: "completed",
    cleanupStatus: cleanupCompleted ? "completed" : "pending",
    status: cleanupCompleted ? "completed" : "cleanup_pending",
    completionProofState: cleanupCompleted ? "completed" : undefined,
  };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method === "GET") return json(capability());
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    return json({ error: "service_unavailable" }, 503);
  }
  const body = await parseBody(request);
  if (!body || body.protocolVersion !== protocolVersion) {
    return json({ error: "invalid_v3_request" }, 400);
  }
  const action = body.action;
  const token = bearerToken(request);
  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (action === cleanupAction) {
    if (!token || !constantTimeEqual(token, serviceRoleKey)) {
      return json({ error: "unauthorized" }, 401);
    }
    const purged = await admin.rpc(
      "purge_account_deletion_security_receipts_v3",
      {},
    );
    if (purged.error) {
      console.error("delete-account receipt purge failed", purged.error);
    }
    const leaseToken = crypto.randomUUID();
    const claimed = await admin.rpc("claim_account_deletion_jobs_v3", {
      p_lease_token: leaseToken,
      p_limit: 1,
    });
    if (claimed.error) return json({ error: "worker_claim_unavailable" }, 503);
    let completed = 0;
    let pending = 0;
    for (const row of claimed.data ?? []) {
      try {
        const job = await readJob(admin, row.job_id);
        if (!job.subject_id) continue;
        const result = await processJob(
          admin,
          job,
          job.subject_id,
          leaseToken,
        );
        result.status === "completed" ? completed += 1 : pending += 1;
      } catch (error) {
        pending += 1;
        console.error("delete-account scheduled worker failed", error);
      } finally {
        await admin.rpc("release_account_deletion_job_v3", {
          p_job_id: row.job_id,
          p_lease_token: leaseToken,
        });
      }
    }
    return json({ claimed: (claimed.data ?? []).length, completed, pending });
  }

  const requestID = body.requestId;
  const expectedSubjectID = body.expectedSubjectId;
  const recoverySecret = body.recoverySecret;
  if (
    !isUUID(requestID) || !isUUID(expectedSubjectID) ||
    !isRecoverySecret(recoverySecret)
  ) {
    return json({ error: "invalid_account_bound_request" }, 400);
  }

  if (action === beginStepUpAction) {
    if (!token) return json({ error: "unauthorized" }, 401);
    const { data: userData, error: userError } = await admin.auth.getUser(
      token,
    );
    const user = userData.user;
    if (userError || !user) return json({ error: "unauthorized" }, 401);
    if (!accountDeletionSubjectMatches(user.id, expectedSubjectID)) {
      return json({ error: "account_scope_mismatch" }, 409);
    }
    const sessionID = sessionIDFromJWT(token);
    if (!sessionID) return json({ error: "unauthorized" }, 401);
    try {
      const recoveryHash = await sha256Hex(recoverySecret);
      const subjectProofHash = await sha256Hex(
        `${user.id.toLowerCase()}:${recoverySecret}`,
      );
      const { data, error } = await admin.rpc(
        "begin_account_deletion_step_up_v3",
        {
          p_subject_id: user.id,
          p_session_id: sessionID,
          p_request_id: requestID,
          p_recovery_hash: recoveryHash,
          p_subject_proof_hash: subjectProofHash,
        },
      );
      if (error) throw error;
      if (!data || !isUUID(data.challenge_id)) {
        throw new Error("step_up_challenge_unavailable");
      }
      return json({
        protocol: protocolName,
        protocolVersion,
        action: beginStepUpAction,
        requestId: requestID,
        subjectId: user.id,
        challengeId: data.challenge_id,
        expiresAt: data.expires_at,
        reauthenticationRequired: true,
      }, 201);
    } catch (error) {
      console.error("delete-account step-up challenge failed", error);
      return json({ error: "step_up_challenge_unavailable" }, 503);
    }
  }

  if (action === authorizeStepUpAction) {
    const challengeID = body.challengeId;
    if (!token || !isUUID(challengeID)) {
      return json({ error: "invalid_step_up_authorization_request" }, 400);
    }
    const { data: userData, error: userError } = await admin.auth.getUser(
      token,
    );
    const user = userData.user;
    if (userError || !user) return json({ error: "unauthorized" }, 401);
    if (!accountDeletionSubjectMatches(user.id, expectedSubjectID)) {
      return json({ error: "account_scope_mismatch" }, 409);
    }
    const evidence = stepUpAuthenticationEvidence(jwtPayloadFromToken(token));
    if (!evidence) {
      return json({ error: "step_up_reauthentication_required" }, 403);
    }
    const authorizationSecret = randomCapability();
    try {
      const recoveryHash = await sha256Hex(recoverySecret);
      const authorizationHash = await sha256Hex(authorizationSecret);
      const { data, error } = await admin.rpc(
        "authorize_account_deletion_step_up_v3",
        {
          p_challenge_id: challengeID,
          p_subject_id: user.id,
          p_request_id: requestID,
          p_recovery_hash: recoveryHash,
          p_session_id: evidence.sessionID,
          p_amr_method: evidence.method,
          p_amr_authenticated_at: evidence.authenticatedAt,
          p_authorization_hash: authorizationHash,
        },
      );
      if (error) {
        if (
          errorMessage(error).includes("step_up_reauthentication_required") ||
          errorMessage(error).includes("step_up_challenge_expired")
        ) {
          return json({ error: "step_up_reauthentication_required" }, 403);
        }
        throw error;
      }
      if (!data || data.authorized !== true) {
        throw new Error("step_up_authorization_unavailable");
      }
      return json({
        protocol: protocolName,
        protocolVersion,
        action: authorizeStepUpAction,
        requestId: requestID,
        subjectId: user.id,
        challengeId: challengeID,
        authorizationSecret,
        expiresAt: data.expires_at,
        singleUse: true,
      });
    } catch (error) {
      console.error("delete-account step-up authorization failed", error);
      return json({ error: "step_up_authorization_unavailable" }, 503);
    }
  }

  if (action === recoveryAction) {
    try {
      const job = await readJobByRecovery(
        admin,
        requestID,
        expectedSubjectID,
        recoverySecret,
      );
      if (!job) {
        return json({
          protocol: protocolName,
          protocolVersion,
          requestId: requestID,
          subjectId: expectedSubjectID,
          found: false,
          status: "not_found",
        });
      }
      if (job.status === "completed") {
        return responseFor(pendingResultFor(job, expectedSubjectID));
      }
      const leaseToken = crypto.randomUUID();
      if (!await claimJobLease(admin, job.job_id, leaseToken)) {
        return responseFor(pendingResultFor(
          await readJob(admin, job.job_id),
          expectedSubjectID,
        ));
      }
      try {
        return responseFor(
          await processJob(
            admin,
            job,
            expectedSubjectID,
            leaseToken,
          ),
        );
      } finally {
        await admin.rpc("release_account_deletion_job_v3", {
          p_job_id: job.job_id,
          p_lease_token: leaseToken,
        });
      }
    } catch (error) {
      console.error("delete-account recovery failed", error);
      return json({ error: "recovery_unavailable" }, 503);
    }
  }

  if (action === acknowledgementAction) {
    try {
      const recoveryHash = await sha256Hex(recoverySecret);
      const subjectProofHash = await sha256Hex(
        `${expectedSubjectID.toLowerCase()}:${recoverySecret}`,
      );
      const { data, error } = await admin.rpc(
        "acknowledge_account_deletion_completion_v3",
        {
          p_request_id: requestID,
          p_recovery_hash: recoveryHash,
          p_subject_proof_hash: subjectProofHash,
        },
      );
      if (error) throw error;
      if (!data || typeof data !== "object") {
        throw new Error("deletion_acknowledgement_unavailable");
      }
      return json({
        protocol: protocolName,
        protocolVersion,
        action: acknowledgementAction,
        requestId: requestID,
        subjectId: expectedSubjectID,
        acknowledged: data.acknowledged === true,
        status: data.status === "acknowledged" ? "acknowledged" : "not_found",
        receiptExpiresAt: typeof data.receipt_expires_at === "string"
          ? data.receipt_expires_at
          : undefined,
        finalRetentionDays: 30,
      });
    } catch (error) {
      console.error("delete-account acknowledgement failed", error);
      return json({ error: "acknowledgement_unavailable" }, 503);
    }
  }

  if (action !== deletionAction || !token) {
    return json({ error: "unsupported_action" }, 400);
  }
  const challengeID = body.challengeId;
  const authorizationSecret = body.authorizationSecret;
  if (!isUUID(challengeID) || !isRecoverySecret(authorizationSecret)) {
    return json({ error: "step_up_authorization_required" }, 403);
  }
  const advertisedCapability = capability();
  if (
    advertisedCapability.automaticCleanupScheduled !== true ||
    advertisedCapability.liveSessionGateConfigured !== true
  ) {
    return json({ error: "deletion_service_not_ready" }, 503);
  }
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);
  if (!accountDeletionSubjectMatches(user.id, expectedSubjectID)) {
    return json({ error: "account_scope_mismatch" }, 409);
  }
  const sessionID = sessionIDFromJWT(token);
  if (!sessionID) {
    return json({ error: "step_up_reauthentication_required" }, 403);
  }

  try {
    const recoveryHash = await sha256Hex(recoverySecret);
    const authorizationHash = await sha256Hex(authorizationSecret);
    const subjectProofHash = await sha256Hex(
      `${user.id.toLowerCase()}:${recoverySecret}`,
    );
    const prepared = await admin.rpc("prepare_account_deletion_v3", {
      p_subject_id: user.id,
      p_session_id: sessionID,
      p_request_id: requestID,
      p_recovery_hash: recoveryHash,
      p_subject_proof_hash: subjectProofHash,
      p_step_up_challenge_id: challengeID,
      p_step_up_authorization_hash: authorizationHash,
    });
    if (prepared.error) {
      if (
        errorMessage(prepared.error).includes("step_up_") ||
        errorMessage(prepared.error).includes("recent_authentication_required")
      ) {
        return json({ error: "step_up_reauthentication_required" }, 403);
      }
      if (
        errorMessage(prepared.error).includes(
          "unsafe_account_storage_inventory",
        )
      ) {
        return json({ error: "storage_inventory_requires_support" }, 409);
      }
      throw prepared.error;
    }
    if (!prepared.data || !isUUID(prepared.data.job_id)) {
      throw new Error("deletion_job_unavailable");
    }

    const leaseToken = crypto.randomUUID();
    if (!await claimJobLease(admin, prepared.data.job_id, leaseToken)) {
      return responseFor(pendingResultFor(
        await readJob(admin, prepared.data.job_id),
        user.id,
      ));
    }

    try {
      // Supported Admin sign-out plus the database session purge in processJob
      // revoke refresh paths before Auth deletion. The configured Data API hook
      // rejects the otherwise-valid access token as soon as its session is gone.
      const signOut = await admin.auth.admin.signOut(token, "global");
      if (signOut.error) {
        console.warn("delete-account global sign-out needed SQL fallback");
      }
      return responseFor(
        await processJob(
          admin,
          prepared.data as DeletionJob,
          user.id,
          leaseToken,
        ),
      );
    } finally {
      await admin.rpc("release_account_deletion_job_v3", {
        p_job_id: prepared.data.job_id,
        p_lease_token: leaseToken,
      });
    }
  } catch (error) {
    console.error("delete-account v3 failed before confirmation", error);
    return json({ error: "deletion_unavailable" }, 503);
  }
});
