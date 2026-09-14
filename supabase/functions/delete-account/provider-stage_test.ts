import { stageAppleDeletionCredential } from "./provider-stage.ts";
import { decryptProviderToken } from "./provider-crypto.ts";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const config = { clientID: "com.example.synthetic", clientSecret: "synthetic" };
const encryptionKey = btoa("s".repeat(32));
const requestID = "10000000-0000-4000-8000-000000000001";
const identities = [{
  provider: "apple",
  identity_data: { sub: "verified-apple-subject" },
}];
Deno.test("Apple staging binds verified identity and persists ciphertext before reporting queued", async () => {
  let persisted = false;
  const result = await stageAppleDeletionCredential({
    config,
    encryptionKey,
    requestID,
    identities,
    authorizationCode: "one-use-code",
    exchange: async (code, subject) => {
      assert(
        code === "one-use-code" && subject === "verified-apple-subject",
        "server verified identity",
      );
      return "synthetic-refresh";
    },
    stage: async (ciphertext) => {
      assert(
        ciphertext &&
          await decryptProviderToken(
              ciphertext,
              encryptionKey,
              requestID,
              config.clientID,
            ) === "synthetic-refresh",
        "encrypted persistence",
      );
      persisted = true;
      return true;
    },
  });
  assert(persisted && result === "queued", "persist before success");
});
Deno.test("missing or invalid Apple credentials never block Mugshot deletion", async () => {
  for (
    const mode of [
      "missing_code",
      "missing_key",
      "ambiguous_identity",
      "provider_failure",
      "persistence_failure",
    ]
  ) {
    let exchanged = false;
    const result = await stageAppleDeletionCredential({
      config,
      requestID,
      encryptionKey: mode === "missing_key" ? "" : encryptionKey,
      identities: mode === "ambiguous_identity"
        ? [...identities, ...identities]
        : identities,
      authorizationCode: mode === "missing_code" ? null : "one-use-code",
      exchange: async () => {
        exchanged = true;
        if (mode === "provider_failure") throw new Error("private Apple body");
        return "synthetic-refresh";
      },
      stage: async (ciphertext) => {
        if (mode === "persistence_failure") {
          throw new Error("private database body");
        }
        assert(ciphertext === null, "unavailable receipt without raw data");
        return true;
      },
    });
    assert(result === "unavailable", "safe unavailable status");
    assert(
      exchanged === ["provider_failure", "persistence_failure"].includes(mode),
      "validate before spending code",
    );
  }
});
Deno.test("accounts without Apple identity do not enter provider cleanup", async () => {
  const result = await stageAppleDeletionCredential({
    config,
    encryptionKey,
    requestID,
    identities: [],
    authorizationCode: "injected-code",
    exchange: async () => {
      throw new Error("must not exchange");
    },
    stage: async () => {
      throw new Error("must not stage");
    },
  });
  assert(result === "not_required", "no Apple identity");
});
