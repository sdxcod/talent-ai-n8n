# TalentAI Phase 4/5 MVP — v3.0.0

## Release scope

This release extends the Phase 3 assessment baseline with an auditable
technical interview workflow. It generates evidence-based questions, collects
first-round and follow-up answers, evaluates answers against rubrics, compares
interview performance with resume evidence and assigns the highest grade whose
deterministic rules pass.

The release contains four inactive workflows:

1. TAI-01 Resume Intake & Extraction v2;
2. TAI-02 Grade Guide Resolver v1;
3. TAI-03 Evidence Scoring & Deterministic Grade Engine v1;
4. TAI-04 Candidate Interview & Final Grade v1.

TAI-04 consumes the frozen `talentai.phase3.assessment-handoff` contract version
`1.0.0`. It is started independently with a completed Phase 3 `extractionId`;
TAI-01 is not directly coupled to an asynchronous human interview.

## Persistence and recovery

Migrations V009 and V010 add versioned storage for interview sessions,
question sets, answers, results and checkpoint recovery. Runtime queries Q013
through Q020 implement claim, persistence, replay, failure recording and resume
semantics. Q021 is the release correlation gate from Phase 3 execution through
the final Phase 5 result.

Retryable executions preserve validated checkpoints. Completed executions are
replayed without creating duplicate question sets, answers or results. Stable
failure metadata omits resume text, prompts, raw answers and provider payloads.

## Quality gates

```bash
bash -n database/bootstrap/*.sh scripts/*.sh
node scripts/test-phase3-calibration.mjs
node scripts/test-phase3-handoff.mjs
node scripts/test-phase45-workflow.mjs
./scripts/test-technical-interview-persistence.sh
./scripts/verify-phase1.sh
git diff --check
```

After a complete synthetic runtime smoke test:

```bash
./scripts/verify-phase45-correlation.sh '<phase3-extraction-uuid>'
```

The detailed operator procedure and privacy rules are in
`docs/runbooks/phase45-end-to-end.md`.

## Smoke matrix

1. Phase 3 happy path completes once and returns its three correlation IDs.
2. Phase 3 replay returns the same extraction and assessment without duplicates.
3. TAI-04 rejects an invalid or incomplete Phase 3 handoff.
4. First-round and follow-up forms persist two versioned question sets.
5. Thirty answers are persisted and evaluated exactly once.
6. Grade checks cover Junior, Mid and Senior and deterministic assignment agrees
   with the highest passing grade.
7. Provider/persistence failure routing records sanitized failure metadata.
8. A retry resumes from its last valid checkpoint.
9. A completed TAI-04 replay returns the immutable result without duplicates.
10. Q021 verifies the full persisted correlation from Phase 3 through Phase 5.

## Build and artifact

Build only from the final clean `main` commit:

```bash
./scripts/build-phase45-mvp-package.sh 3.0.0
shasum -a 256 exports/private/TalentAI-phase45-mvp-v3.0.0.n8np
```

Attach `TalentAI-phase45-mvp-v3.0.0.n8np` to the annotated `v3.0.0` GitHub
Release and publish its SHA-256. Files under `exports/private` must never be
committed.

## Known boundary

The MVP uses n8n test/production forms for the human interview. A dedicated
candidate portal, scheduling, authentication, notification delivery and
multi-position Grade Guide catalog are outside this release. The two-step
assessment/interview launch is an intentional asynchronous boundary, not a
missing data integration.

## Exit criteria

The release is complete only after CI, repository verification, a clean-install
import, the full synthetic smoke matrix, correlation verification, replay,
package hash, clean Git status, merge to `main`, annotated tag and GitHub
Release all succeed.
