// Explicit, paid, synthetic-only acceptance probe. Never called by CI or app.
// Run with Deno --env-file=.env.local and allow only api.openai.com networking.
import {
  type Input,
  validateSuggestion,
} from "../supabase/functions/coffee-assistance/handler.ts";
import { generate } from "../supabase/functions/coffee-assistance/provider.ts";

const key = Deno.env.get("OPENAI_API_KEY") ?? "";
const model = Deno.env.get("MUGSHOT_AI_MODEL") ?? "";
if (!key || model !== "gpt-6-luna") {
  throw Error("Approved Luna configuration required");
}
const examples = [
  {
    task: "bag_scan",
    query: "Read the supplied bag text",
    evidence: [{
      id: "bag-1",
      title: "Fictional test bag",
      detail:
        "Roaster: Example Roasters\nCoffee: Dawn\nOrigin: Colombia\nProcess: Washed\nTasting notes: Cocoa, cherry",
    }],
  },
  {
    task: "recipe_import",
    query: "Extract only the printed source; I created this fictional recipe",
    evidence: [{
      id: "recipe-1",
      title: "Fictional recipe",
      detail:
        "Name: Vanilla iced latte\nIngredient: 10 g vanilla syrup\nIngredient: 150 ml milk\nStep: Stir the syrup into the coffee.\nCreator: Fixture Author",
    }],
  },
  {
    task: "memory_search",
    query: "Find my oat latte",
    evidence: [{
      id: "sip-1",
      title: "Iced oat latte",
      detail: "Date: 2026-11-01\nPlace: Example Cafe\nRating: 4.5 / 5",
    }],
  },
  {
    task: "taste_insight",
    query: "Describe one cautious observation",
    evidence: [{
      id: "sip-1",
      title: "Latte",
      detail: "Rating: 4.5 / 5\nCaption: Chocolatey and balanced",
    }, {
      id: "sip-2",
      title: "Cortado",
      detail: "Rating: 4 / 5\nCaption: Cocoa sweetness",
    }, {
      id: "sip-3",
      title: "Iced latte",
      detail: "Rating: 3 / 5\nCaption: Too sweet",
    }],
  },
  {
    task: "brew_experiment",
    query: "Suggest one optional experiment",
    evidence: [{
      id: "home-1",
      title: "Home vanilla latte",
      detail:
        "Recorded syrup: 15 g\nRecorded milk: 150 ml\nNext-time note: Less sweetness\nUnknown actuals stay unknown",
    }],
  },
  {
    task: "weekly_reflection",
    query: "Write a brief reflection using verified facts only",
    evidence: [{
      id: "period-facts",
      title: "This week",
      detail:
        "Verified completed sips: 3\nDistinct cafes: 2\nPrivate Home sips included: 1\nNo drafts included",
    }],
  },
] as const;

let passed = 0;
for (const example of examples) {
  const input: Input = {
    owner_id: "11111111-1111-4111-8111-111111111111",
    request_id: crypto.randomUUID(),
    consent_version: "selected-details-v1",
    task: example.task,
    query: example.query,
    evidence: example.evidence.map((x) => ({ ...x })),
    image: null,
  };
  const result = await generate(
    input,
    { key, model },
    new AbortController().signal,
  );
  if (!validateSuggestion(result, input)) {
    throw Error(`Validation failed for synthetic ${input.task}`);
  }
  console.log(
    `PASS synthetic ${input.task}: bounded schema and supplied references`,
  );
  passed++;
}
console.log(
  `Synthetic provider acceptance: ${passed}/${examples.length}; model=${model}. No production journal or database accessed.`,
);
