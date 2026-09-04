# Secure Interview Invitation Runbook

## Operational boundary

`TAI-05 Secure Interview Invitation v1` is an authenticated HR/operator
workflow. It issues or revokes an invitation only after the completed Phase 3
handoff is resolved and validated.

`TAI-04 Candidate Interview & Final Grade v1` is the public candidate workflow.
Its first form contains one hidden `invitationToken` field. The workflow claims
that token before it loads Phase 3 data or calls an AI provider.

Publish TAI-04 before TAI-05. Both workflows must be published for production
Form URLs to work.

## Build and import a release candidate

```bash
./scripts/verify-phase1.sh

./scripts/build-phase45-mvp-package.sh 3.1.0-rc.1
```

Import the resulting five-workflow package with the existing PostgreSQL and
OpenAI-compatible credentials:

```bash
n8n-cli package import \
  --file=exports/private/TalentAI-phase45-mvp-v3.1.0-rc.1.n8np \
  --project-id='<talentai-project-id>' \
  --workflow-conflict-policy=new-version \
  --workflow-id-policy=source \
  --workflow-publishing-policy=preserve-published-state \
  --credential-matching-mode=id-only \
  --credential-missing-mode=must-preexist \
  --missing-node-type-mode=fail \
  --format=json
```

Expected result:

- TAI-01 through TAI-04 are updated;
- TAI-05 is created on its first import and updated on later imports;
- both existing credentials are matched;
- no credential is stubbed.

## Issue an invitation

1. Sign in to n8n with a user who can execute TAI-05 in the TalentAI project.
2. Open `/form/talentai-secure-interview-invitation`.
3. Select `ISSUE`.
4. Enter the `extractionId` from a completed Phase 3 assessment.
5. Keep the default lifetime `2880` minutes, or select another allowed value.
6. Submit the form.
7. Copy the candidate link from the completion page. Do not copy it into logs,
   tickets, source control, screenshots, or shared chat channels.

The link contains only an opaque 64-character token. Right-clicking the link
and selecting **Copy Link Address** produces the full URL on the current n8n
host.

## Candidate flow

1. Open the invitation link over HTTPS.
2. Select **شروع مصاحبه**.
3. TAI-04 atomically claims the token.
4. A valid first claim continues to question generation.
5. Reopening the same link in another execution shows a generic failure page
   and does not disclose any TalentAI identifier.

Do not test one-time behavior with automated link preview tools. TAI-04 enables
the Form Trigger bot guard, but invitation links should still be treated as
bearer credentials.

## Revoke or recover

Use TAI-05 with action `REVOKE` and the displayed `invitationId`.

- An unclaimed invitation is revoked immediately.
- A claimed invitation for a `RUNNING` or `COMPLETED` interview is not revoked.
- A claimed invitation can be revoked when its correlated interview failed and
  is retryable.
- If the token was claimed before an interview session could be created, it can
  be revoked after a ten-minute recovery grace period.

After a successful recovery revocation, run `ISSUE` again with the same
`extractionId`. The previous token becomes invalid and a new token is returned.

## Database verification

Use identifiers, never the raw invitation token:

```sql
SELECT
    id,
    request_id,
    assessment_id,
    extraction_id,
    status,
    issue_count,
    LENGTH(token_hash) = 64 AS token_hash_valid,
    issued_at,
    expires_at,
    claimed_at,
    revoked_at
FROM talentai.technical_interview_invitation
WHERE extraction_id = '<phase3-extraction-uuid>'::UUID;
```

Expected lifecycle for a normal run:

```text
ISSUED -> CLAIMED
```

Expected lifecycle for manual cancellation:

```text
ISSUED -> REVOKED
```

Expected lifecycle for controlled recovery:

```text
CLAIMED -> REVOKED -> ISSUED -> CLAIMED
```

## Privacy checks

- PostgreSQL stores only `token_hash`, never the raw token.
- Candidate URLs do not contain `requestId`, `assessmentId`, or `extractionId`.
- TAI-04 and TAI-05 disable success, error, manual, and progress execution-data
  retention and enable full workflow redaction.
- Candidate-facing failure text is fixed and contains no internal identifiers
  or failure detail.
- Reverse proxies must not log query strings for the `/form/` route.
