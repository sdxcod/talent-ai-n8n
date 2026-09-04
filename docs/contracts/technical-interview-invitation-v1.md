# TalentAI Secure Technical Interview Invitation v1

## Purpose

This contract connects a completed Phase 3 assessment to the Phase 4/5
technical interview without exposing TalentAI correlation identifiers in the
candidate-facing URL.

The invitation is an authorization boundary. It is not a copy of the Phase 3
handoff and it must never contain resume text, job-description text, evidence,
prompts, provider responses, credentials, or internal failure details.

## Eligibility

An invitation can be issued only when all of the following rows agree on
`requestId`, `assessmentId`, and `extractionId`:

- `assessment_execution.status = COMPLETED`
- `assessment_execution.current_stage = COMPLETED`
- `assessment_execution.completed_at IS NOT NULL`
- `grade_assessment.status = COMPLETED`

The frozen upstream contract remains:

- name: `talentai.phase3.assessment-handoff`
- version: `1.0.0`
- idempotency key: `(contractVersion, requestId, assessmentId)`

Invitation persistence does not create foreign keys into Phase 3-owned tables
and never mutates those tables.

## Token

- The deliverable token contains 32 random bytes encoded as 64 lowercase
  hexadecimal characters.
- Only `SHA-256(token)` is stored in PostgreSQL.
- The raw token is returned exactly when a new or replacement invitation is
  issued. It is never recoverable from the database.
- A second issue request cannot reveal an already active token.
- The candidate-facing URL contains only the opaque token. It must not contain
  `requestId`, `assessmentId`, `extractionId`, candidate data, or assessment
  data.
- Production delivery requires HTTPS.

## Lifetime and states

The accepted TTL range is 15 minutes through 7 days. The workflow default is
48 hours.

| State | Meaning | Allowed transition |
|---|---|---|
| `ISSUED` | Active and not yet used | `CLAIMED`, `REVOKED`, `EXPIRED` |
| `CLAIMED` | Bound to one TAI-04 workflow execution | Terminal, except controlled failure recovery |
| `REVOKED` | Disabled by an authorized operator | Replacement issue |
| `EXPIRED` | Lifetime elapsed | Replacement issue |

Only one row exists for a Phase 3 handoff. Reissuing an expired or revoked
invitation rotates the token hash and increments `issue_count`.

A claimed invitation can be revoked for recovery only when its correlated
technical interview session is `FAILED` and retryable, or when no interview
session was created and the claim is older than ten minutes. Invitations tied
to `RUNNING` or `COMPLETED` interviews cannot be revoked. Recovery revocation
clears the previous claim binding before a replacement token is issued.

## Claim semantics

Claiming is an atomic database update.

- The first valid, unexpired claim returns `CLAIMED_NEW` and the three Phase 3
  correlation identifiers.
- A replay from the same n8n workflow execution returns `CLAIMED_CURRENT` and
  can continue. This makes the claim step retry-safe inside one execution.
- Any other execution receives `INVITATION_ALREADY_CLAIMED` and no correlation
  identifiers.
- Invalid, unknown, expired, or revoked tokens never receive correlation data.

TAI-04 must use the returned correlation identifiers to resolve and validate
the existing Phase 3 handoff before it creates or resumes an interview session.

## Persistence and logging rules

- The raw token must not be written to PostgreSQL, console output, failure
  messages, application logs, or final result text.
- TAI-05 must disable successful and failed execution-data retention.
- TAI-04 must discard the raw token immediately after the claim step and must
  not include it in downstream items.
- Operational output may contain `invitationId`, status, expiry, and issue
  count. Candidate-facing failures use generic messages.

## Database operations

| Query | Responsibility |
|---|---|
| `Q022` | Validate Phase 3 eligibility and issue or replace a token |
| `Q023` | Atomically claim a token and disclose correlation only to its owner |
| `Q024` | Revoke an unclaimed invitation |
| `Q025` | Mark stale issued invitations as expired |

Contract and behavior are verified by `T005`, `T006`, and
`scripts/test-technical-interview-invitations.sh`.
