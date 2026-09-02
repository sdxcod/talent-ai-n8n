# TalentAI Phase 3 Release 2 checkpoint

- Operational baseline: `f4ee5b6`
- Grade Guide: `JAVA_BACKEND` `1.0.0`
- Handoff contract: `talentai.phase3.assessment-handoff` `1.0.0`
- Release version: `2.0.0`
- Phase 3 ownership ends at the immutable completed assessment handoff.
- Phase 4 owns evidence-based technical question generation.
- Phase 5 owns answers and post-interview evaluation.
- Downstream work must preserve `requestId`, `assessmentId`, `extractionId` and
  be idempotent on `(contractVersion, requestId, assessmentId)`.
- Downstream workflows must not write Phase 3-owned tables.

If the contract changes compatibly, publish a new `1.x` revision. Required
field removal, semantic changes or enum changes require a new major contract.
