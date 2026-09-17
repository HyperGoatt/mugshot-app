import {
  isExplicitlyEnabled,
  keyedDigest,
  normalizeEmail,
  validateItems,
} from "./handler.ts";

Deno.test("contact matching requires an explicit enabled value", () => {
  assertEquals(isExplicitlyEnabled("true"), true);
  assertEquals(isExplicitlyEnabled(undefined), false);
  assertEquals(isExplicitlyEnabled("false"), false);
  assertEquals(isExplicitlyEnabled("TRUE"), false);
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

function assertMatch(actual: string, pattern: RegExp): void {
  if (!pattern.test(actual)) {
    throw new Error(`Expected ${actual} to match ${pattern}`);
  }
}

Deno.test("normalizes only plausible email addresses", () => {
  assertEquals(
    normalizeEmail(" Person+Coffee@Example.COM "),
    "person+coffee@example.com",
  );
  assertEquals(normalizeEmail("not-an-email"), null);
});

Deno.test("bounds and deduplicates selected inputs", () => {
  assertEquals(
    validateItems([{
      item_key: "contact_123",
      emails: ["A@B.com", "a@b.com"],
    }]),
    [
      { item_key: "contact_123", emails: ["a@b.com"] },
    ],
  );
  assertEquals(validateItems([]), null);
});

Deno.test("creates deterministic keyed digests", async () => {
  const first = await keyedDigest("a@b.com", "test-secret");
  assertEquals(first, await keyedDigest("a@b.com", "test-secret"));
  assertMatch(first, /^[a-f0-9]{64}$/);
});
