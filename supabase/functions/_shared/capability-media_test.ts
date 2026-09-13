import {
  legacyCapabilityStorageReference,
  mediaBelongsToScope,
  type MediaSigningClient,
  privateStorageReference,
  resolvedCapabilityMediaURL,
  resolvedPublicAudienceMediaURL,
  safeHTTPSURL,
} from "./capability-media.ts";

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test("accepts only credential-free HTTPS media URLs", () => {
  assert(
    safeHTTPSURL("https://images.example/coffee.jpg") ===
      "https://images.example/coffee.jpg",
    "valid HTTPS media was rejected",
  );
  for (
    const invalid of [
      "http://images.example/coffee.jpg",
      "data:image/png;base64,abc",
      "https://user:secret@images.example/coffee.jpg",
      "not-a-url",
    ]
  ) {
    assert(safeHTTPSURL(invalid) === null, `unsafe URL passed: ${invalid}`);
  }
});

Deno.test("parses only normalized private visit photo references", () => {
  const reference = privateStorageReference(
    "mugshot-storage://visit-photos-private/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo%201.jpg",
  );
  assert(reference?.bucket === "visit-photos-private", "bucket was lost");
  assert(
    reference?.path ===
      "11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo 1.jpg",
    "path was not decoded",
  );

  for (
    const invalid of [
      "mugshot-storage://another-bucket/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo.jpg",
      "mugshot-storage://visit-photos-private/user/../photo.jpg",
      "mugshot-storage://visit-photos-private/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo.jpg?token=x",
      "mugshot-storage://visit-photos-private/too-short",
    ]
  ) {
    assert(
      privateStorageReference(invalid) === null,
      `unsafe reference passed: ${invalid}`,
    );
  }
});

Deno.test("signs only the exact capability-authorized private object", async () => {
  let signedBucket = "";
  let signedPath = "";
  let signedLifetime = 0;
  const client: MediaSigningClient = {
    storage: {
      from(bucket) {
        signedBucket = bucket;
        return {
          async createSignedUrl(path, expiresIn) {
            signedPath = path;
            signedLifetime = expiresIn;
            return {
              data: {
                signedUrl:
                  "https://project.supabase.co/storage/v1/object/sign/visit-photos-private/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo.jpg?token=signed",
              },
              error: null,
            };
          },
        };
      },
    },
  };

  const url = await resolvedCapabilityMediaURL(
    "mugshot-storage://visit-photos-private/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo.jpg",
    client,
    "https://project.supabase.co",
    {
      kind: "visit",
      ownerID: "11111111-1111-1111-1111-111111111111",
      visitID: "22222222-2222-2222-2222-222222222222",
    },
  );

  assert(signedBucket === "visit-photos-private", "wrong bucket was signed");
  assert(
    signedPath ===
      "11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/photo.jpg",
    "wrong path was signed",
  );
  assert(signedLifetime === 60, "signed URL lifetime changed");
  assert(
    url?.startsWith("https://project.supabase.co/") === true,
    "signed URL was lost",
  );
});

Deno.test("legacy profile and visit Storage URLs use protected signing without accepting foreign paths", async () => {
  const base = "https://project.supabase.co";
  let calls = 0;
  const client: MediaSigningClient = {
    storage: {
      from(bucket) {
        return {
          async createSignedUrl(path, seconds) {
            calls++;
            assert(
              bucket === "profile-media" &&
                path === "11111111-1111-1111-1111-111111111111/avatar.jpg" &&
                seconds === 60,
              "exact admitted profile object",
            );
            return {
              data: {
                signedUrl:
                  `${base}/storage/v1/object/sign/${bucket}/${path}?token=synthetic`,
              },
              error: null,
            };
          },
        };
      },
    },
  };
  const value =
    `${base}/storage/v1/object/public/profile-media/11111111-1111-1111-1111-111111111111/avatar.jpg`;
  assert(
    (await resolvedCapabilityMediaURL(value, client, base, {
      kind: "profile",
      ownerID: "11111111-1111-1111-1111-111111111111",
    }))?.includes(
      "/object/sign/",
    ) === true,
    "legacy profile is signed",
  );
  assert(
    await resolvedCapabilityMediaURL(value, null, base, {
      kind: "profile",
      ownerID: "11111111-1111-1111-1111-111111111111",
    }) === null,
    "missing signer never returns original public URL",
  );
  for (
    const invalid of [
      value + "?token=x",
      value.replace(
        "11111111-1111-1111-1111-111111111111/avatar.jpg",
        "owner/%2e%2e%2favatar.jpg",
      ),
      value.replace("project.supabase.co", "foreign.invalid"),
    ]
  ) {
    assert(
      legacyCapabilityStorageReference(invalid, base) === null,
      "invalid or foreign path not admitted for signing",
    );
  }
  assert(calls === 1, "no unintended signing");
});

Deno.test("capability signing refuses copied owners, sibling visits and wrong media buckets", async () => {
  const ownerID = "11111111-1111-1111-1111-111111111111";
  const visitID = "22222222-2222-2222-2222-222222222222";
  const other = "33333333-3333-3333-3333-333333333333";
  const base = "https://project.supabase.co";
  let calls = 0;
  const client: MediaSigningClient = {
    storage: {
      from() {
        calls++;
        throw new Error("Unauthorized reference reached privileged signer");
      },
    },
  };
  for (
    const [value, scope] of [
      [`mugshot-storage://visit-photos-private/${other}/${visitID}/x.jpg`, {
        kind: "visit",
        ownerID,
        visitID,
      }],
      [`mugshot-storage://visit-photos-private/${ownerID}/${other}/x.jpg`, {
        kind: "visit",
        ownerID,
        visitID,
      }],
      [`${base}/storage/v1/object/public/profile-media/${other}/x.jpg`, {
        kind: "profile",
        ownerID,
      }],
      [`${base}/storage/v1/object/public/profile-media/${ownerID}/x.jpg`, {
        kind: "visit",
        ownerID,
        visitID,
      }],
      [`mugshot-storage://visit-photos-private/${ownerID}/${visitID}/x.jpg`, {
        kind: "profile",
        ownerID,
      }],
      [`mugshot-storage://visit-photos-private/${ownerID}/${visitID}/x.jpg`, {
        kind: "visit",
        ownerID: null,
        visitID,
      }],
    ] as const
  ) {
    assert(
      await resolvedCapabilityMediaURL(value, client, base, scope) === null,
      "unauthorized media must be omitted",
    );
  }
  assert(calls === 0, "denials happened before privileged Storage calls");
  assert(
    mediaBelongsToScope({
      bucket: "visit-photos",
      path: `${ownerID}/${visitID}/x.jpg`,
    }, { kind: "visit", ownerID, visitID }),
    "matching legacy visit media remains supported",
  );
});

Deno.test("public-list media respects anonymous Storage denials without public fallback", async () => {
  const base = "https://project.supabase.co";
  let calls = 0;
  const client: MediaSigningClient = {
    storage: {
      from() {
        return {
          async createSignedUrl() {
            calls++;
            return { data: null, error: { message: "denied by RLS" } };
          },
        };
      },
    },
  };
  for (
    const value of [
      `${base}/storage/v1/object/public/visit-photos/owner/visit/photo.jpg`,
      "mugshot-storage://visit-photos-private/owner/visit/photo.jpg",
    ]
  ) {
    assert(
      await resolvedPublicAudienceMediaURL(value, client, base) === null,
      "denied media has no permanent fallback",
    );
  }
  assert(
    calls === 2,
    "both legacy and private references require anonymous authorization",
  );
});
