import { type AppleConfig, revokeAppleDeletionToken } from "./apple.ts";
import {
  decryptProviderToken,
  type EncryptedProviderToken,
} from "./provider-crypto.ts";

type RPC = (name: string, args: Record<string, unknown>) => PromiseLike<{
  data: unknown;
  error: unknown;
}>;
type Credential = {
  request_id: string;
  client_id: string;
  ciphertext: EncryptedProviderToken;
  lease_token: string;
};

/** The provider queue is separate from Mugshot data deletion. Never return
 * credentials or provider error bodies to the caller or logs. */
export async function drainAppleRevocations(
  rpc: RPC,
  config: AppleConfig,
  encryptionKey: string,
  revoke: typeof revokeAppleDeletionToken = revokeAppleDeletionToken,
): Promise<
  { claimed: number; revoked: number; pending: number; available: boolean }
> {
  const ready = !!config.clientID && !!config.clientSecret && !!encryptionKey;
  // A zero-size claim still purges expired credentials when configuration is
  // missing, without spending delivery attempts on a known configuration gap.
  let claim;
  try {
    claim = await rpc("claim_account_apple_revocations_v1", {
      p_limit: ready ? 1 : 0,
    });
  } catch {
    return { claimed: 0, revoked: 0, pending: 0, available: false };
  }
  if (claim.error || !Array.isArray(claim.data)) {
    return { claimed: 0, revoked: 0, pending: 0, available: false };
  }
  let revoked = 0;
  for (const row of claim.data as Credential[]) {
    let success = false;
    try {
      if (!ready || row.client_id !== config.clientID) throw new Error();
      const token = await decryptProviderToken(
        row.ciphertext,
        encryptionKey,
        row.request_id,
        row.client_id,
      );
      await revoke(token, config);
      success = true;
    } catch {
      // Retry only within the queue's bounded lease/attempt/retention policy.
    }
    try {
      const finish = await rpc("finish_account_apple_revocation_v1", {
        p_request_id: row.request_id,
        p_lease: row.lease_token,
        p_revoked: success,
      });
      if (success && !finish.error && finish.data === true) revoked += 1;
    } catch {
      // An unacknowledged attempt can be reclaimed; Apple revocation is safe
      // to repeat. A stale lease never reports a committed completion.
    }
  }
  return {
    claimed: claim.data.length,
    revoked,
    pending: claim.data.length - revoked,
    available: ready,
  };
}
