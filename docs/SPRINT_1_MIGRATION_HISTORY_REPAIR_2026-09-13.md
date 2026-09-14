---
document_type: historical
status: checkpoint
last_verified: 2026-09-13
---

# Sprint 1 migration-history repair — September 13, 2026

Current release state: [Sprint 1 tracker](SPRINT_1_TRACKER.md) and
[Supabase release workflow](SUPABASE_RELEASE_WORKFLOW.md).

## Finding and correction

The first hosted QA checkpoint counted 85 migration records sharing one SQL
statement hash. Exact repository comparison showed that 84 were incorrect;
`20260711135027_optimize_feed_queries.sql` legitimately owns that statement.
This corrects the earlier description of all 85 records as damaged. The valid
record was not changed.

Replaced only the `statements` arrays of those 84 production migration records
with their exact repository sources. Existing versions, names (including blank
historical names), author metadata, idempotency keys, and rollback fields were
preserved. No migration SQL was executed by the repair. No Sprint 1 migration,
Edge Function, credential, or processing schedule was deployed.

## Safety and verification

The original 127-record snapshot and deduplicated statement sources are retained
locally outside Git, with restricted permissions. A guarded reverse transaction
is retained alongside the forward transaction. Both exact transactions passed
in disposable QA against a reproduction of production's migration-table shape
and original metadata. The rehearsal restored the original bad metadata with
the reverse transaction, then rolled back the outer transaction and verified
that QA's canonical history was intact.

The forward transaction checks all 127 before-images under an exclusive metadata
table lock, refuses unexpected triggers or drift, changes exactly 84 statement
arrays, verifies each replacement hash, and compares application/Auth/Storage
row fingerprints and schema catalog fingerprints before committing. The first
QA proof covered 119 tables. Production ran the same invariant checks in a
repeatable-read transaction and returned `metadata_repair_verified`.

Forward transaction SHA-256:
`14e6be93d6bfa13cc12079e6bc2f93b2767adaa8cc6924c04dcffb6a30aeae6a`.

Read-only production verification afterward found 127 records, unchanged head
`20260826143102`, and only the legitimate `20260711135027` record with the formerly
duplicated statement hash. A fresh data-less branch automatically replayed
113 migrations through `20260809144548`, past all repaired records. Its next
migration requires the operational scheduler Vault secret. The branch reported
`MIGRATIONS_FAILED`; this is proof that the damaged-history failure was removed,
not a complete automatic replay pass. The check branch was deleted and absence
verified. Full application QA and production feature activation are not implied
by this metadata repair.

## Application QA and cleanup

The second data-less QA branch replayed 152 repository migrations. The full
remote suite reported 32 passes, 24 failures, and 56 total contracts. The cafe
least-privilege grant, screening queue, and corrected owner-edit rollback
contracts pass. Former cafe-grant errors now progress to unavailable
friend/profile assertions; those are still failures requiring fixture and
behavior review. Scheduler tests still expect active jobs, while this isolated
QA environment intentionally keeps them inactive. Media tests still contain
legacy public-bucket expectations. These observations do not waive failures.

Deleted the second QA branch after evidence capture and verified that only the
default branch remained. Its local database credential file was removed. The
separate fresh-branch replay check is tracked in the current sprint tracker.

## Exact replacement ledger

Hashes are MD5 of the stored statement text, used for exact before/after
comparison, not for cryptographic authentication. The complete transaction is
identified by SHA-256 above.

| Version | Old statement MD5 | New statement MD5 |
| --- | --- | --- |
| `20251118164645` | `0b5b606071b98372a670ef09598a251a` | `7c41be3a5254122ccda30c7dc321b4f1` |
| `20251118220830` | `0b5b606071b98372a670ef09598a251a` | `07e6b1248d6489e9a0b694bcfeaa2b4e` |
| `20251121172921` | `0b5b606071b98372a670ef09598a251a` | `1c39639f860e78d35eed4b71a286a612` |
| `20251121172925` | `0b5b606071b98372a670ef09598a251a` | `2d731b9ec7f09f7c8dd003f3bd6aecd1` |
| `20251124200920` | `0b5b606071b98372a670ef09598a251a` | `a62edffb17c5a2ac05010a8428e5e6aa` |
| `20251124200926` | `0b5b606071b98372a670ef09598a251a` | `6b317266cf2d15eea125a9f9157d3d04` |
| `20251124200929` | `0b5b606071b98372a670ef09598a251a` | `65cb5f025891b99c62e01fd10711eccf` |
| `20251124200934` | `0b5b606071b98372a670ef09598a251a` | `a1646c7d9791001503c24d9d38bbac4e` |
| `20251124200939` | `0b5b606071b98372a670ef09598a251a` | `94e659e8d833e08e98627236f5636064` |
| `20251124200958` | `0b5b606071b98372a670ef09598a251a` | `b33646094c55eb61215fae731c953a0f` |
| `20251124221953` | `0b5b606071b98372a670ef09598a251a` | `0d1aeb79321724bbe1859300194f2d4f` |
| `20251124223547` | `0b5b606071b98372a670ef09598a251a` | `72fa95eaa49d9e544dadb21ef369c893` |
| `20251124223554` | `0b5b606071b98372a670ef09598a251a` | `692258e6280cb8e928b02ec11d470b63` |
| `20251126131357` | `0b5b606071b98372a670ef09598a251a` | `f205432fd9175d677c844429eec737e4` |
| `20251128040818` | `0b5b606071b98372a670ef09598a251a` | `066d8534e2c8de01de01557059f14235` |
| `20251202051605` | `0b5b606071b98372a670ef09598a251a` | `8aa104f97291afb70288717c6a628fdf` |
| `20251202055958` | `0b5b606071b98372a670ef09598a251a` | `56dc89bd5038faaa6d18d822861e3731` |
| `20251202194527` | `0b5b606071b98372a670ef09598a251a` | `5a5c44e0d9de336ceea895139b1184ad` |
| `20251204230021` | `0b5b606071b98372a670ef09598a251a` | `47c418f0976b8c9387f5f09a4bc20fbe` |
| `20251204232959` | `0b5b606071b98372a670ef09598a251a` | `1b3fd49e68cf54c0908afc81a804c2fc` |
| `20251204234153` | `0b5b606071b98372a670ef09598a251a` | `bb108ff7f5dbc8e4ffbb11cb1703f345` |
| `20251204234156` | `0b5b606071b98372a670ef09598a251a` | `bc663b04012561d45ea97066d04047f5` |
| `20251206233223` | `0b5b606071b98372a670ef09598a251a` | `4f7791077573ae9f8274d4595fa95acd` |
| `20251216180359` | `0b5b606071b98372a670ef09598a251a` | `d850eeafb3915a8cfa605372cbcf080c` |
| `20251216182948` | `0b5b606071b98372a670ef09598a251a` | `935f6c3254ca9800976601240cc387b0` |
| `20251216183559` | `0b5b606071b98372a670ef09598a251a` | `87b5f5ecf0c8ff0fcbdfd7370797b385` |
| `20251216185407` | `0b5b606071b98372a670ef09598a251a` | `dfc88fbd683988e7a1e47e23cce859fd` |
| `20251216194727` | `0b5b606071b98372a670ef09598a251a` | `a0c239371f07d714a775f293461e6c64` |
| `20251217022628` | `0b5b606071b98372a670ef09598a251a` | `b1175dd8632a0bcabcd96dc55d66cd3f` |
| `20251217023832` | `0b5b606071b98372a670ef09598a251a` | `220676340615eb30f0c9581588a1ddeb` |
| `20251217041252` | `0b5b606071b98372a670ef09598a251a` | `0a61babedc6eff0d8a614bd83799d779` |
| `20251217041341` | `0b5b606071b98372a670ef09598a251a` | `15b258ca488eb0d86847f5c736b71bf2` |
| `20251223043837` | `0b5b606071b98372a670ef09598a251a` | `3427d14a5b3298c622eb6eb1ad57725a` |
| `20251224035705` | `0b5b606071b98372a670ef09598a251a` | `7e3fac6ece8185a3368a9e67a20ade66` |
| `20251224054949` | `0b5b606071b98372a670ef09598a251a` | `0d02d3d9c733a1b330dba12e6932f6aa` |
| `20251224173856` | `0b5b606071b98372a670ef09598a251a` | `acbb965926b86a67cd779b0ce8fd9261` |
| `20251231194709` | `0b5b606071b98372a670ef09598a251a` | `9abcb38a89adc180f99ba55f74153065` |
| `20251231200727` | `0b5b606071b98372a670ef09598a251a` | `0e2c145a0b248fd1aa27afcfcc84f7c0` |
| `20260709205250` | `0b5b606071b98372a670ef09598a251a` | `5994c1d85025bf15a762b645f0afb2c6` |
| `20260709211841` | `0b5b606071b98372a670ef09598a251a` | `f38ddb5b7fa6e5442e51480fbbd3de9b` |
| `20260712134347` | `0b5b606071b98372a670ef09598a251a` | `b469d03a2a838fcf672b4d79a03ed5ff` |
| `20260712135105` | `0b5b606071b98372a670ef09598a251a` | `c1c649c60365decfb1d13aa5e150e0fd` |
| `20260712163405` | `0b5b606071b98372a670ef09598a251a` | `5ecf963b20b5f931784df1c99f3bbae8` |
| `20260712205140` | `0b5b606071b98372a670ef09598a251a` | `6876ad5e1c8a0a4da23f0b10add9a2b6` |
| `20260712205347` | `0b5b606071b98372a670ef09598a251a` | `bae26fb9e677df9684651f24efaa8999` |
| `20260712211408` | `0b5b606071b98372a670ef09598a251a` | `92f457d3d3dd26a7985a190ea2caa4eb` |
| `20260712214406` | `0b5b606071b98372a670ef09598a251a` | `a1cfa4bdfed5bc1ea72bf11ea1d97cb6` |
| `20260712214646` | `0b5b606071b98372a670ef09598a251a` | `b779a75d261685f23e525faed358ac31` |
| `20260713035201` | `0b5b606071b98372a670ef09598a251a` | `faf9d038380142b8013ff2ed484ec332` |
| `20260713205511` | `0b5b606071b98372a670ef09598a251a` | `5c58c20c07c3e7b5bef3cac2617a67d4` |
| `20260713205518` | `0b5b606071b98372a670ef09598a251a` | `fcf47e8192785a3136583bd6aada443b` |
| `20260713205526` | `0b5b606071b98372a670ef09598a251a` | `e343153c782bd86728a196dd68a7cf50` |
| `20260713231635` | `0b5b606071b98372a670ef09598a251a` | `0249779dc859e2efd7e82f14e30b4842` |
| `20260714013618` | `0b5b606071b98372a670ef09598a251a` | `b0c4806f20fdb0a9b5b332d4345c1a72` |
| `20260714013836` | `0b5b606071b98372a670ef09598a251a` | `cd475ce43f9b5ad16fa15fdacaeb68e2` |
| `20260714025602` | `0b5b606071b98372a670ef09598a251a` | `d12eb3973cd4584d8bd3deca5162d294` |
| `20260714034718` | `0b5b606071b98372a670ef09598a251a` | `48178d82e1199061893a769a9fdf0b4e` |
| `20260714042024` | `0b5b606071b98372a670ef09598a251a` | `ab2675e3dc9d0ea1c86081c9f8b1de70` |
| `20260714043328` | `0b5b606071b98372a670ef09598a251a` | `b4c73df13f3a9fc465b7fa52a942e2d2` |
| `20260714044901` | `0b5b606071b98372a670ef09598a251a` | `49dace2586ffe1decd1586d5fc6ecc98` |
| `20260714045207` | `0b5b606071b98372a670ef09598a251a` | `927ec8cf53190bb7594988f8df95321c` |
| `20260714050516` | `0b5b606071b98372a670ef09598a251a` | `9bd5d068ace91885b8932ad4118e3781` |
| `20260714051041` | `0b5b606071b98372a670ef09598a251a` | `d3a6964a079b5f20918420b272656724` |
| `20260714051404` | `0b5b606071b98372a670ef09598a251a` | `09543ee5c77ef3799dac821a7c005a27` |
| `20260714051432` | `0b5b606071b98372a670ef09598a251a` | `52866e723d221296af982fbb9373469d` |
| `20260714051603` | `0b5b606071b98372a670ef09598a251a` | `c4f375e6eba433decda997021d3ef94c` |
| `20260714052754` | `0b5b606071b98372a670ef09598a251a` | `fe808c8276a5aa6d5b44cf94e5871194` |
| `20260714053353` | `0b5b606071b98372a670ef09598a251a` | `0b67f1ddc1961063ddd461a03881ba59` |
| `20260714055538` | `0b5b606071b98372a670ef09598a251a` | `cd34f661cdaafb3b25105bd31546f256` |
| `20260714061539` | `0b5b606071b98372a670ef09598a251a` | `23b9908dc503f7ca329f924e979af110` |
| `20260714151316` | `0b5b606071b98372a670ef09598a251a` | `12e74f9907b62592bb71e83689ebd323` |
| `20260714185446` | `0b5b606071b98372a670ef09598a251a` | `37e2f89416fa23e418bc4bd7e0e50453` |
| `20260714231557` | `0b5b606071b98372a670ef09598a251a` | `76017c46500ef87cf5668f38de6d9b60` |
| `20260714231708` | `0b5b606071b98372a670ef09598a251a` | `a2f3619a9fb54c30a6067b9a63e9af67` |
| `20260717114908` | `0b5b606071b98372a670ef09598a251a` | `b7f32e8a6d296622b46c7257d64df64b` |
| `20260717114953` | `0b5b606071b98372a670ef09598a251a` | `4552889b5f6bb7ef84459650c0f508bd` |
| `20260717115015` | `0b5b606071b98372a670ef09598a251a` | `b4f2e8fddb68514dc8322b93a90f689e` |
| `20260717115054` | `0b5b606071b98372a670ef09598a251a` | `0af8cb152e7bd8317a018b0ee23bcb36` |
| `20260717142724` | `0b5b606071b98372a670ef09598a251a` | `0e7846e13b233726719707de5032967f` |
| `20260717150000` | `0b5b606071b98372a670ef09598a251a` | `19b4bf6f13eea33febc91d7e976ca3f4` |
| `20260717185855` | `0b5b606071b98372a670ef09598a251a` | `1074907fa8430b2aa1112f175a153fbf` |
| `20260721121228` | `0b5b606071b98372a670ef09598a251a` | `2957f0995070b9247041f949506691b3` |
| `20260721124855` | `0b5b606071b98372a670ef09598a251a` | `7d491a3468f225524c1536a538ebf007` |
| `20260721130557` | `0b5b606071b98372a670ef09598a251a` | `7581d1d53bee56664c8daca2285a86d7` |
