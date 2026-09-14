import { type AppleConfig, exchangeAppleDeletionCode } from "./apple.ts";
import {
  type EncryptedProviderToken,
  encryptProviderToken,
} from "./provider-crypto.ts";

/** Called only after the server has authorized the fresh, account-bound
 * deletion challenge. Apple subject comes from auth.getUser, never the body. */
export async function stageAppleDeletionCredential(args: {
  identities: {
    provider: string;
    identity_data?: { [key: string]: unknown };
  }[];
  authorizationCode: unknown;
  config: AppleConfig;
  encryptionKey: string;
  requestID: string;
  stage: (ciphertext: EncryptedProviderToken | null) => Promise<boolean>;
  exchange?: typeof exchangeAppleDeletionCode;
}): Promise<"not_required" | "queued" | "unavailable"> {
  const identities = args.identities.filter((identity) =>
    identity.provider === "apple"
  );
  if (!identities.length) return "not_required";
  let ciphertext: EncryptedProviderToken | null = null;
  const subject = identities.length === 1
    ? identities[0].identity_data?.sub
    : null;
  try {
    if (
      typeof subject !== "string" || !subject ||
      typeof args.authorizationCode !== "string" || !args.authorizationCode ||
      args.authorizationCode.length > 4096 || !args.config.clientID ||
      !args.config.clientSecret
    ) throw new Error();
    // Validate encryption configuration before consuming a single-use code.
    await encryptProviderToken(
      "configuration-check",
      args.encryptionKey,
      args.requestID,
      args.config.clientID,
    );
    const token = await (args.exchange ?? exchangeAppleDeletionCode)(
      args.authorizationCode,
      subject,
      args.config,
    );
    ciphertext = await encryptProviderToken(
      token,
      args.encryptionKey,
      args.requestID,
      args.config.clientID,
    );
  } catch {
    // Apple explicitly requires account deletion to remain available when a
    // provider token cannot be recovered. No raw provider error is retained.
  }
  try {
    if (await args.stage(ciphertext)) {
      return ciphertext ? "queued" : "unavailable";
    }
  } catch {
    // Provider persistence cannot block deletion of the user's Mugshot data.
  }
  return "unavailable";
}
