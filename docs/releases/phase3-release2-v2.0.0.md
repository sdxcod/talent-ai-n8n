# TalentAI Phase 3 — Release 2 v2.0.0

## Release baseline

Release 2 closes Phase 3 on top of operational baseline `f4ee5b6`. It includes
evidence-based scoring, deterministic decisions, idempotent retries and replay,
controlled failure routing, stale-execution recovery, observability, calibration
fixtures and the frozen Phase 3 handoff contract `1.0.0`.

## Final verification

```bash
./scripts/verify-phase1.sh
node scripts/test-phase3-calibration.mjs
node scripts/test-phase3-handoff.mjs
git diff --check
```

## Clean-install test

Use a disposable Compose project and fresh volumes. Do not point this test at
the development database. Clone the tagged source, create its local `.env`,
choose unused host ports, run `scripts/bootstrap-local.sh`, import the final
package with credentials set to `must-preexist`, and run the smoke matrix below.
Delete only the explicitly named disposable Compose project after evidence is
captured.

## Smoke matrix

1. Happy path: new request completes with attempt `1`.
2. Completed replay: same request returns identical IDs and no duplicate rows.
3. Intake rejection: malformed request is rejected and not persisted.
4. Provider failure: invalid model produces a retryable recorded failure.
5. Recovery: corrected provider retries the same request and completes with
   attempt `2`.
6. Evidence-scoring failure: stage is recorded as `EVIDENCE_SCORING` and retains
   the extraction ID.
7. Final replay: completed attempt `2` is replayed without new extraction or
   assessment rows.
8. Observability: `scripts/show-assessment-executions.sh` reports duration and
   stale status without private payloads.

## Demo scenario

Use only a synthetic resume. Submit it for `JAVA_BACKEND` / `SENIOR`, show the
seven Evidence-linked dimension results, explain that the LLM proposes scores
while the deterministic engine owns the decision, then replay the same request
to demonstrate idempotency. Finally show the observability command and the
versioned handoff contract used by Phases 4 and 5.

## Release artifacts

- `TalentAI-phase3-release2-v2.0.0.n8np` (private build output, never commit);
- SHA-256 printed by `scripts/build-phase3-release2.sh`;
- `docs/contracts/phase3-assessment-handoff-v1.md`;
- `docs/contracts/phase3-assessment-handoff-v1.schema.json`;
- synthetic calibration fixtures under `demo/phase3`.

## Exit criteria

Phase 3 is closed only after repository verification, clean install, smoke
matrix, package hash, clean Git status, commit, push and annotated tag all pass.
Question generation and answer evaluation are explicitly owned by Phases 4 and
5 and must not be added to this release.
