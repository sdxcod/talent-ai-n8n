# TalentAI Phase 3 Assessment Handoff Contract

## Contract identity

| Item | Value |
|---|---|
| Contract | `talentai.phase3.assessment-handoff` |
| Version | `1.0.0` |
| Status | `FROZEN_FOR_PARALLEL_DEVELOPMENT` |
| Producer | TalentAI Phase 3 assessment pipeline |
| Consumers | Phase 4 question generation; Phase 5 assessment orchestration |
| Source baseline | Git commit `f4ee5b6` |
| Schema | `phase3-assessment-handoff-v1.schema.json` |
| Example | `phase3-assessment-handoff-v1.example.json` |

This contract is the stable boundary between the completed Phase 3 pipeline and
the independently developed Phase 4 and Phase 5 workflows. Consumers must not
depend on n8n node names, workflow layout, internal SQL queries, or database
table structure.

## Producer implementation status

This is the frozen **Release 2 integration boundary**. The Phase 3 database and
workflow at baseline `f4ee5b6` contain all source values, but their internal
runtime object is not itself this public contract: it uses internal fields such
as `schemaVersion` and `metadata.status`. The Release 2 producer projection must
map that object to this exact envelope, add `contract` and `contractVersion`,
rename internal status to `metadata.assessmentStatus`, and validate the result
against the companion schema before delivery.

Hamed may develop and test against the schema and example now. Consumers must
not parse the current n8n terminal text or bind directly to the current internal
workflow object while the projection is being finalized.

## Compatibility and revision policy

- Version `1.x` is backward compatible.
- Optional fields may be added in a minor revision.
- Required fields, field meaning, enum values, or numeric interpretation cannot
  change without a new major version.
- A consumer must reject an unsupported `contractVersion` explicitly.
- Existing versioned contracts remain immutable. Corrections are published as a
  new revision and include migration notes.
- The initial frozen revision is `1.0.0`.

## Delivery semantics

- One payload represents one completed Phase 3 assessment.
- `requestId` is the end-to-end idempotency and correlation identifier.
- `assessmentId` identifies the persisted scoring result.
- `extractionId` identifies the persisted structured resume extraction.
- The producer may return the same payload again for a completed replay.
- Consumers must be idempotent on the tuple:

```text
(contractVersion, requestId, assessmentId)
```

- A payload is consumable only when:

```text
execution.status = COMPLETED
assessmentStatus = COMPLETED
```

- `RUNNING`, `FAILED`, rejected claims, and unrecorded failures are not Phase 3
  handoff payloads.

## Canonical payload

```json
{
  "contract": "talentai.phase3.assessment-handoff",
  "contractVersion": "1.0.0",
  "requestId": "00d42c64-5a1d-4e96-8b42-c43ece7c6ae9",
  "assessmentId": "7d879827-0b75-4741-bd5f-44827fd77dd3",
  "extractionId": "17af847d-0a73-4c43-9775-4c752c0e005e",
  "candidate": {
    "fullName": "Synthetic Candidate"
  },
  "assessmentContext": {
    "positionCode": "JAVA_BACKEND",
    "targetGradeCode": "SENIOR",
    "jobDescription": "Senior Java Backend Developer with Java, Spring Boot, PostgreSQL, messaging, testing, observability and architecture experience."
  },
  "gradeGuide": {
    "id": "11111111-1111-4111-8111-111111111111",
    "version": "1.0.0"
  },
  "score": {
    "overall": 75,
    "minimumRequired": 70,
    "thresholdMet": true,
    "mandatoryDimensionsMet": true
  },
  "decision": "MEETS_TARGET",
  "dimensionAssessments": [
    {
      "code": "JAVA_CORE",
      "title": "Core Java and JVM",
      "weight": 25,
      "mandatory": true,
      "modelScore": 3,
      "effectiveScore": 3,
      "confidence": "HIGH",
      "confidenceAccepted": true,
      "weightedScore": 18.75,
      "minimumRequired": 3,
      "minimumMet": true,
      "evidence": [
        {
          "quote": "Developed backend services with Java 17 and Java 21",
          "source": "WORK_EXPERIENCE"
        }
      ],
      "rationale": "The resume contains direct and recent Java evidence."
    }
  ],
  "reviewReasons": [],
  "modelWarnings": [],
  "assessmentSummary": "The candidate meets the target based on traceable resume evidence.",
  "execution": {
    "attemptCount": 2,
    "status": "COMPLETED",
    "replayed": false,
    "startedAt": "2026-09-01T06:03:08.278914Z",
    "completedAt": "2026-09-01T06:11:42.524005Z"
  },
  "metadata": {
    "scoringModel": "gpt-5.6-sol",
    "promptVersion": "1.0",
    "engineVersion": "1.0",
    "assessmentStatus": "COMPLETED",
    "createdAt": "2026-09-01T06:11:42.507Z"
  }
}
```

The example is illustrative. IDs and candidate data are synthetic and must not
be treated as test assertions.

## Required enums

### Decision

```text
MEETS_TARGET
BELOW_TARGET
REVIEW_REQUIRED
```

`REVIEW_REQUIRED` is the exact implemented value. `REQUIRES_REVIEW` is not a
valid value.

### Confidence

```text
HIGH
MEDIUM
LOW
```

### Evidence source

```text
PROFILE_SKILL
WORK_EXPERIENCE
EDUCATION
WARNING
OTHER
```

### Phase 3 dimension codes for `JAVA_BACKEND` guide version `1.0.0`

```text
JAVA_CORE
SPRING_ECOSYSTEM
DATABASE
DISTRIBUTED_SYSTEMS
TESTING
SOFTWARE_ARCHITECTURE
OBSERVABILITY_DEVOPS
```

Consumers must use dimension `code` as identity. Titles are display text and may
be revised in a future compatible Grade Guide version.

## Scoring invariants

- `score.overall` and `score.minimumRequired` are in the inclusive range
  `0..100`.
- A dimension `modelScore` and `effectiveScore` are in the inclusive range
  `0..4`.
- `effectiveScore` is the score accepted by the deterministic engine after its
  evidence-confidence policy is applied.
- `weightedScore = effectiveScore / 4 * weight`, rounded to two decimals.
- `minimumRequired` is nullable when the target Grade has no minimum for that
  dimension.
- Every positive model score requires at least one evidence item.
- Evidence quotes have already been validated as traceable to the structured
  candidate profile.
- `MEETS_TARGET` requires both `thresholdMet` and
  `mandatoryDimensionsMet` to be true and no review reason.
- `REVIEW_REQUIRED` takes precedence when deterministic review reasons exist.
- The LLM scores evidence only. The deterministic engine owns the final
  decision.

## Consumer rules for Phase 4

Phase 4 may use the following inputs when generating technical questions:

- target position and Grade;
- dimension scores and minimum requirements;
- evidence quotes and sources;
- rationales;
- review reasons and model warnings;
- Grade Guide identity and version.

Phase 4 must:

- generate questions against dimension `code`, not title;
- retain `requestId`, `assessmentId`, and `extractionId` on every generated
  question set;
- distinguish verification questions from gap questions;
- treat resume evidence as a claim to verify, not established truth;
- never change Phase 3 scores or decision;
- never write to `talentai.resume_extraction`, `talentai.grade_assessment`, or
  `talentai.assessment_execution`.

## Consumer rules for Phase 5

Phase 5 may reference the Phase 3 identifiers and snapshot when presenting
questions and evaluating answers. It must not reinterpret or overwrite the
Phase 3 assessment. Any post-interview score belongs to a separate versioned
Phase 5 result.

## Ownership boundary

| Data | Owner | Consumer access |
|---|---|---|
| Resume extraction | Phase 1/3 pipeline | Read through the handoff contract |
| Grade Guide resolution | Phase 3 | Read version and assessment projection |
| Resume evidence score | Phase 3 | Immutable input |
| Final resume decision | Phase 3 deterministic engine | Immutable input |
| Generated questions | Phase 4 | Phase 4-owned persistence |
| Candidate/interviewer answers | Phase 5 | Phase 5-owned persistence |
| Post-answer evaluation | Phase 5 | Separate from Phase 3 result |

Direct cross-phase writes to another phase's owned tables are prohibited.

## Privacy and security

- Do not include the original resume binary, provider response, prompt,
  credential, API key, or internal error message in the handoff.
- Candidate data is personal data and must be minimized for the consumer use
  case.
- Logs should use `requestId`, `assessmentId`, and stable codes rather than
  resume text or evidence quotes.
- Evidence may be shown to an authorized interviewer but must not be copied to
  general operational logs.

## Acceptance checklist for a consumer

- Supports `contractVersion = 1.0.0`.
- Validates the payload against the companion JSON Schema.
- Rejects unknown decision, confidence, evidence source, or dimension values.
- Is idempotent on `(contractVersion, requestId, assessmentId)`.
- Preserves all three Phase 3 identifiers in downstream records.
- Does not mutate Phase 3-owned persistence.
- Does not log candidate evidence or job description by default.
- Has a test for completed replay delivering the same assessment.

## Known v1 boundary

Version `1.0.0` defines only the Phase 3 output boundary. Question, question-set,
answer, and post-interview evaluation contracts are owned and versioned by
Phase 4 and Phase 5. They should reference this contract but must not be added
to it retroactively.
