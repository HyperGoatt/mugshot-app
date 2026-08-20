import {
  type MediaSigningClient,
  privateStorageReference,
  resolvedCapabilityMediaURL,
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
    "mugshot-storage://visit-photos-private/user/visit/photo%201.jpg",
  );
  assert(reference?.bucket === "visit-photos-private", "bucket was lost");
  assert(reference?.path === "user/visit/photo 1.jpg", "path was not decoded");

  for (
    const invalid of [
      "mugshot-storage://another-bucket/user/visit/photo.jpg",
      "mugshot-storage://visit-photos-private/user/../photo.jpg",
      "mugshot-storage://visit-photos-private/user/visit/photo.jpg?token=x",
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
                  "https://project.supabase.co/storage/v1/object/sign/visit-photos-private/user/visit/photo.jpg?token=signed",
              },
              error: null,
            };
          },
        };
      },
    },
  };

  const url = await resolvedCapabilityMediaURL(
    "mugshot-storage://visit-photos-private/user/visit/photo.jpg",
    client,
  );

  assert(signedBucket === "visit-photos-private", "wrong bucket was signed");
  assert(signedPath === "user/visit/photo.jpg", "wrong path was signed");
  assert(signedLifetime === 300, "signed URL lifetime changed");
  assert(
    url?.startsWith("https://project.supabase.co/") === true,
    "signed URL was lost",
  );
});
