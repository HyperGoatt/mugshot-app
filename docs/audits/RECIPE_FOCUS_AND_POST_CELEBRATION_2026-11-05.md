---
document_type: historical
status: red-reproduced-in-progress
---

# Recipe focus and full-screen post completion — November 5, 2026

Current sources: [Home recipes](../HOME_RECIPES_IMPLEMENTATION.md),
[AI assistance](../AI_ASSISTANCE.md), [sharing](../REPAIR_SHARING_STATUS.md).

## Scope and observed failure

Documentation impact: recipe-import behavior and draft ownership, native post
completion/sharing, Edge provider instructions, privacy and development delivery.
No database schema change or TestFlight action is planned. The owner chooses
the full-screen result for successful Home, cafe and Elsewhere posts. Private
saves retain private-save behavior; sharing never silently changes an audience.

A read-only owner snapshot confirms the screenshot-imported PSL component has
29 ingredient rows and two steps. The ingredient list contains page chrome,
preparation headings and step fragments. Luna has supplied cleaner fields, but
the client appends them to the fallback's incorrect OCR rows. The original text
also contains an obscured/cropped last instruction. Saved owner versions, linked
drinks and published posts remain untouched during diagnosis. Private source,
identifiers and backups are excluded from this report and repository.

## ECC RED checkpoints

- The original parser executes 12 focused source tests: ten pass, two fail with
  three assertions. Synthetic wrapped-line/preparation and footer fixtures
  reproduce ingredient pollution and recipe/footer mixing. Raw console evidence:
  `/tmp/mugshot-psl-parser-red-2026-11-05.log`. Xcode stalls while finalizing the
  failed run; the incomplete result bundle is not claimed as a finalized receipt.
- A separate build-for-testing intentionally fails at the missing
  `CoffeeAssistanceRecipeImport.Draft` API. Tests require replacement of untouched
  generated rows while preserving typed names, edited ingredients and deletions.
  `/tmp/mugshot-psl-intended-api-red-2026-11-05.log`, exit 65.
- A completion-policy boundary test requires confirmed publication for the active
  owner. Private results, stale owners and incomplete saves must not open the
  full-screen posted result.

Implementation, native captures and GREEN/phone acceptance are pending at this
checkpoint. Existing passing evidence is reused only for unchanged behavior.
