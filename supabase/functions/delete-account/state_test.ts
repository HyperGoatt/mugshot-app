import {
  accountDeletionSubjectMatches,
  cleanupWorkerContract,
  exactStorageRemovalPlan,
  identityReconciliationAction,
  isRecoverySecret,
  shouldRestoreStorageOwnership,
  stepUpAuthenticationEvidence,
} from "./state.ts";

function assertEquals<T>(actual: T, expected: T, message: string) {
  if (actual !== expected) {
    throw new Error(
      `${message}: expected ${String(expected)}, got ${String(actual)}`,
    );
  }
}

Deno.test("committed Auth delete wins over a timed-out confirmation response", () => {
  // This is the hard ambiguity: deleteUser committed, the confirmation RPC
  // timed out, and the subsequent authoritative read sees both identities gone.
  const authoritativeState = {
    identityExists: false,
    databaseIdentityExists: false,
  };

  assertEquals(
    identityReconciliationAction(authoritativeState),
    "confirmed",
    "authoritative absence must confirm deletion",
  );
  assertEquals(
    shouldRestoreStorageOwnership(authoritativeState),
    false,
    "Storage ownership must never be restored to a deleted identity",
  );
});

Deno.test("Auth absence retries only legacy database confirmation and never restores", () => {
  const authoritativeState = {
    identityExists: false,
    databaseIdentityExists: true,
  };

  assertEquals(
    identityReconciliationAction(authoritativeState),
    "retry_database_confirmation",
    "a lingering public profile needs database-only reconciliation",
  );
  assertEquals(
    shouldRestoreStorageOwnership(authoritativeState),
    false,
    "Auth absence is an irreversible no-restore boundary",
  );
});

Deno.test("a live Auth identity remains pending and can use reversible restore", () => {
  const authoritativeState = {
    identityExists: true,
    databaseIdentityExists: true,
  };

  assertEquals(
    identityReconciliationAction(authoritativeState),
    "pending",
    "a live identity is not a confirmed deletion",
  );
  assertEquals(
    shouldRestoreStorageOwnership(authoritativeState),
    true,
    "reversible restore is limited to a live identity",
  );
});

Deno.test("cleanup worker contract requires a scheduled service-role batch", () => {
  assertEquals(
    cleanupWorkerContract.action,
    "drain_deletions_v3",
    "worker action",
  );
  assertEquals(
    cleanupWorkerContract.authentication,
    "service_role_bearer",
    "worker authentication",
  );
  assertEquals(
    cleanupWorkerContract.invocation,
    "scheduled_service_role_batch",
    "worker invocation",
  );
});

Deno.test("deletion confirmation cannot follow a changed authenticated subject", () => {
  const confirmedSubject = "34F9F48F-8AC1-4BDC-86A7-3B3503400D24";
  const laterSession = "81b696d8-d9d7-4fa3-a822-8f1753e4b591";

  assertEquals(
    accountDeletionSubjectMatches(
      confirmedSubject.toLowerCase(),
      confirmedSubject,
    ),
    true,
    "UUID case differences must not break the same subject",
  );
  assertEquals(
    accountDeletionSubjectMatches(laterSession, confirmedSubject),
    false,
    "a later authenticated session must not inherit the deletion request",
  );
});

Deno.test("Storage cleanup uses only exact frozen manifest paths", () => {
  const subject = "34f9f48f-8ac1-4bdc-86a7-3b3503400d24";
  const plan = exactStorageRemovalPlan(subject, [{
    bucket: "visit-photos-private",
    path: `${subject}/4fb96fef-a25a-49ce-b37c-7caa918a4e7f/photo.jpg`,
    object_id: "aef8aa86-a69e-4848-aa41-f079b946136d",
  }]);
  assertEquals(
    plan.get("visit-photos-private")?.[0],
    `${subject}/4fb96fef-a25a-49ce-b37c-7caa918a4e7f/photo.jpg`,
    "exact path",
  );
});

Deno.test("Storage cleanup includes private Home coffee bag photos", () => {
  const subject = "33333333-3333-4333-8333-333333333333";
  const path = `${subject}/55555555-5555-4555-8555-555555555555.jpg`;
  const plan = exactStorageRemovalPlan(subject, [{
    bucket: "home-coffee-bag-photos",
    path,
    object_id: "44444444-4444-4444-8444-444444444444",
  }]);

  assertEquals(
    plan.get("home-coffee-bag-photos")?.[0],
    path,
    "includes the owner-private Home coffee bag photo",
  );
  assertEquals(
    plan.get("home-coffee-bag-photos")?.length,
    1,
    "includes each private Home coffee bag photo exactly once",
  );
});

Deno.test("Storage cleanup rejects prefix escapes, foreign prefixes, and duplicates", () => {
  const subject = "34f9f48f-8ac1-4bdc-86a7-3b3503400d24";
  const objectID = "aef8aa86-a69e-4848-aa41-f079b946136d";
  const rejected = [
    `${subject}/../foreign.jpg`,
    `${subject}//photo.jpg`,
    `81b696d8-d9d7-4fa3-a822-8f1753e4b591/photo.jpg`,
  ];
  for (const path of rejected) {
    let didReject = false;
    try {
      exactStorageRemovalPlan(subject, [{
        bucket: "visit-photos",
        path,
        object_id: objectID,
      }]);
    } catch {
      didReject = true;
    }
    assertEquals(didReject, true, `reject ${path}`);
  }

  let duplicateRejected = false;
  try {
    exactStorageRemovalPlan(subject, [
      {
        bucket: "profile-media",
        path: `${subject}/avatar.jpg`,
        object_id: objectID,
      },
      {
        bucket: "profile-media",
        path: `${subject}/avatar.jpg`,
        object_id: objectID,
      },
    ]);
  } catch {
    duplicateRejected = true;
  }
  assertEquals(duplicateRejected, true, "duplicate path");
});

Deno.test("recovery secrets are exactly 256-bit base64url capabilities", () => {
  assertEquals(
    isRecoverySecret("0123456789abcdefghijklmnopqrstuvwxyzABCDEFG"),
    true,
    "43 base64url characters",
  );
  assertEquals(isRecoverySecret("too-short"), false, "short capability");
  assertEquals(
    isRecoverySecret("0123456789abcdefghijklmnopqrstuvwxyzABCDE+"),
    false,
    "non-base64url capability",
  );
});

Deno.test("step-up evidence selects a real, freshest authentication event", () => {
  const evidence = stepUpAuthenticationEvidence({
    session_id: "34f9f48f-8ac1-4bdc-86a7-3b3503400d24",
    amr: [
      { method: "password", timestamp: 1_721_000_000 },
      { method: "token_refresh", timestamp: 1_721_000_500 },
      { method: "totp", timestamp: 1_721_000_300 },
    ],
  });
  assertEquals(evidence?.method, "totp", "eligible method");
  assertEquals(
    evidence?.authenticatedAt,
    1_721_000_300,
    "freshest eligible timestamp",
  );
});

Deno.test("step-up evidence rejects refresh, recovery, signup, and malformed claims", () => {
  const sessionID = "34f9f48f-8ac1-4bdc-86a7-3b3503400d24";
  for (
    const method of [
      "token_refresh",
      "recovery",
      "invite",
      "email/signup",
      "anonymous",
    ]
  ) {
    assertEquals(
      stepUpAuthenticationEvidence({
        session_id: sessionID,
        amr: [{ method, timestamp: 1_721_000_000 }],
      }),
      null,
      `reject ${method}`,
    );
  }
  assertEquals(
    stepUpAuthenticationEvidence({
      session_id: "not-a-session",
      amr: [{ method: "password", timestamp: 1_721_000_000 }],
    }),
    null,
    "invalid session",
  );
});
