# Retired external screening endpoint

As of 2026-09-14 this endpoint returns HTTP 410 and performs no network calls.
Shared text is validated synchronously by `private.enqueue_screening_v1` using
sealed local rules; its legacy name preserves installed-client compatibility.
Photos use report-driven human moderation. The external scheduler and OpenAI
server credentials are retired. Human review media resolution lives in
`../_shared/review-media.ts` and never invokes an AI provider.

Current implementation and verification: [repair status](../../../docs/REPAIR_SHARING_STATUS.md).
