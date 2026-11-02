import { deepStrictEqual as equal, rejects } from "node:assert/strict";
import { type Input, validateSuggestion } from "./handler.ts";
import { generate } from "./provider.ts";

const input: Input = {
  owner_id: "11111111-1111-4111-8111-111111111111",
  request_id: "22222222-2222-4222-8222-222222222222",
  consent_version: "selected-details-v1",
  task: "memory_search",
  query: "Find a latte",
  evidence: [{ id: "sip-1", title: "Latte", detail: "A recorded memory" }],
  image: null,
};
const suggestion = {
  text: "A possible match",
  evidence_ids: ["sip-1"],
  fields: [],
  search_terms: ["latte"],
};
const completed = (text: string) =>
  Response.json({
    status: "completed",
    output: [{ type: "message", content: [{ type: "output_text", text }] }],
  });

Deno.test("provider request fixes model, bounded output, no storage and no tools; excludes owner and operation IDs", async () => {
  let calls = 0;
  const fetcher: typeof fetch = async (url, init) => {
    calls++;
    equal(String(url), "https://api.openai.com/v1/responses");
    equal(init?.redirect, "error");
    const body = JSON.parse(String(init?.body));
    equal(body.model, "gpt-6-luna");
    equal(body.store, false);
    equal(body.max_output_tokens, 1000);
    equal(body.reasoning, { effort: "none" });
    equal(body.tools, undefined);
    equal(body.text.format.strict, true);
    equal(String(init?.body).includes(input.owner_id), false);
    equal(String(init?.body).includes(input.request_id), false);
    return completed(JSON.stringify(suggestion));
  };
  equal(
    await generate(
      input,
      { key: "fixture-only", model: "gpt-6-luna" },
      new AbortController().signal,
      fetcher,
    ),
    suggestion,
  );
  equal(calls, 1);
  await rejects(() =>
    generate(
      input,
      { key: "fixture-only", model: "expensive-model" },
      new AbortController().signal,
      fetcher,
    )
  );
  equal(calls, 1);
  await rejects(() =>
    generate(
      input,
      { key: "fixture-only", model: "gpt-6.1-luna" },
      new AbortController().signal,
      fetcher,
    )
  );
  equal(calls, 1, "an unapproved Luna version must not reach the provider");
});

Deno.test("provider errors, refusals, partial results and malformed JSON fail without leaking bodies", async () => {
  for (
    const response of [
      Response.json({ error: "fixture-private-detail" }, { status: 429 }),
      Response.json({ status: "incomplete", output: [] }),
      Response.json({
        status: "completed",
        output: [{
          type: "message",
          content: [{ type: "refusal", refusal: "No" }],
        }],
      }),
      completed("not-json"),
    ]
  ) {
    await rejects(() =>
      generate(
        input,
        { key: "fixture-only", model: "gpt-6-luna" },
        new AbortController().signal,
        async () => response,
      )
    );
  }
});

Deno.test("capture validation rejects invented quotes, duplicate citations, blank text and oversized fields", () => {
  const bag: Input = { ...input, task: "bag_scan" };
  for (
    const candidate of [
      { ...suggestion, text: "" },
      { ...suggestion, evidence_ids: ["sip-1", "sip-1"] },
      {
        ...suggestion,
        fields: [{
          key: "origin",
          value: "Kenya",
          source_quote: "Not in source",
        }],
      },
      {
        ...suggestion,
        fields: [{
          key: "origin",
          value: "x".repeat(401),
          source_quote: "A recorded memory",
        }],
      },
    ]
  ) equal(validateSuggestion(candidate, bag), null);
});
