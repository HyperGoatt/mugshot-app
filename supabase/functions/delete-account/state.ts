export type IdentityReconciliationAction =
  | "confirmed"
  | "retry_database_confirmation"
  | "pending";

export interface IdentityStateObservation {
  identityExists?: boolean;
  databaseIdentityExists?: boolean;
}

/// Classifies only authoritative reads. An Admin API timeout is deliberately
/// absent from this input because a transport result cannot prove whether the
/// server committed the deletion.
export function identityReconciliationAction(
  observation: IdentityStateObservation,
): IdentityReconciliationAction {
  if (
    observation.identityExists === false &&
    observation.databaseIdentityExists === false
  ) {
    return "confirmed";
  }
  if (observation.identityExists === false) {
    return "retry_database_confirmation";
  }
  return "pending";
}

/// Storage ownership may be restored only while Auth authoritatively confirms
/// the identity is still live. This prevents compensating a timed-out delete
/// by assigning objects back to a user that no longer exists.
export function shouldRestoreStorageOwnership(
  observation: IdentityStateObservation,
): boolean {
  return observation.identityExists === true;
}

/// The destructive request is bound to the account that was visible when the
/// person confirmed deletion. A later token for another session can never
/// redirect that request to its authenticated subject.
export function accountDeletionSubjectMatches(
  authenticatedUserID: string,
  expectedSubjectID: string,
): boolean {
  return authenticatedUserID.toLowerCase() === expectedSubjectID.toLowerCase();
}

export const cleanupWorkerContract = {
  action: "drain_deletions_v3",
  authentication: "service_role_bearer",
  invocation: "scheduled_service_role_batch",
  delivery: "durable_scheduled_retry",
} as const;

export interface StorageManifestItem {
  bucket: string;
  path: string;
  object_id: string;
}

export interface StepUpAuthenticationEvidence {
  sessionID: string;
  method: string;
  authenticatedAt: number;
}

const stepUpAuthenticationMethods = new Set([
  "password",
  "oauth",
  "otp",
  "totp",
  "magiclink",
  "sso/saml",
]);

/**
 * Extracts only an independent authentication event from an already-verified
 * Supabase JWT payload. Refresh, recovery, invite, signup, and anonymous AMR
 * entries are deliberately ineligible for destructive step-up authorization.
 * The database independently binds this evidence to a live, new session and
 * verifies that its server-issued timestamp is after the deletion challenge.
 */
export function stepUpAuthenticationEvidence(
  payload: unknown,
): StepUpAuthenticationEvidence | null {
  if (typeof payload !== "object" || payload === null) return null;
  const value = payload as { session_id?: unknown; amr?: unknown };
  if (
    typeof value.session_id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value.session_id) ||
    !Array.isArray(value.amr)
  ) {
    return null;
  }

  let selected: { method: string; timestamp: number } | null = null;
  for (const entry of value.amr) {
    if (typeof entry !== "object" || entry === null) continue;
    const candidate = entry as { method?: unknown; timestamp?: unknown };
    if (
      typeof candidate.method !== "string" ||
      !stepUpAuthenticationMethods.has(candidate.method) ||
      typeof candidate.timestamp !== "number" ||
      !Number.isSafeInteger(candidate.timestamp) ||
      candidate.timestamp <= 0
    ) {
      continue;
    }
    if (!selected || candidate.timestamp > selected.timestamp) {
      selected = {
        method: candidate.method,
        timestamp: candidate.timestamp,
      };
    }
  }
  return selected
    ? {
      sessionID: value.session_id,
      method: selected.method,
      authenticatedAt: selected.timestamp,
    }
    : null;
}

const allowedBuckets = new Set([
  "visit-photos",
  "visit-photos-private",
  "profile-media",
]);

/**
 * Returns the only paths the deletion worker may remove. The database freezes
 * and ownership-validates this manifest before Auth deletion; this second
 * boundary rejects malformed, duplicate, or prefix-escaping receipts before
 * they reach the Storage API.
 */
export function exactStorageRemovalPlan(
  subjectID: string,
  manifest: StorageManifestItem[],
): Map<string, string[]> {
  const subject = subjectID.toLowerCase();
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuid.test(subjectID)) throw new Error("unsafe_storage_subject");

  const plan = new Map<string, string[]>();
  const seen = new Set<string>();
  for (const item of manifest) {
    if (!allowedBuckets.has(item.bucket) || !uuid.test(item.object_id)) {
      throw new Error("unsafe_storage_manifest");
    }
    const segments = item.path.split("/");
    if (
      segments.length < 2 || segments[0].toLowerCase() !== subject ||
      segments.some((segment) =>
        segment.length === 0 || segment === "." || segment === ".." ||
        segment.includes("\\") || /[\u0000-\u001f\u007f]/.test(segment)
      )
    ) {
      throw new Error("unsafe_storage_manifest");
    }
    const key = `${item.bucket}\u0000${item.path}`;
    if (seen.has(key)) throw new Error("duplicate_storage_manifest_item");
    seen.add(key);
    const paths = plan.get(item.bucket) ?? [];
    paths.push(item.path);
    plan.set(item.bucket, paths);
  }
  return plan;
}

export function isRecoverySecret(value: unknown): value is string {
  // 32 random bytes encoded as unpadded base64url.
  return typeof value === "string" && /^[A-Za-z0-9_-]{43}$/.test(value);
}
