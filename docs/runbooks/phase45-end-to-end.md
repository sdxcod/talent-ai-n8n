# Phase 1–5 end-to-end runbook

This runbook verifies the MVP as one auditable flow while preserving the
asynchronous boundary between resume assessment and the technical interview.
Use synthetic data only.

## Architecture boundary

1. TAI-01 receives the resume and coordinates TAI-02 and TAI-03.
2. TAI-03 persists the completed Phase 3 assessment and its versioned handoff.
3. An operator or future application starts TAI-04 with the completed
   `extractionId`.
4. TAI-04 loads and validates the Phase 3 handoff, then persists its own
   interview session, versioned question sets, answers and final result.

TAI-01 does not call TAI-04 directly. This is intentional: the technical
interview is asynchronous, human-in-the-loop and can occur later than resume
assessment. The persisted identifiers and handoff contract are the integration
boundary.

## Preconditions

- The repository is on the release candidate commit with a clean worktree.
- Docker Compose, `jq`, `rg`, Node.js and `n8n-cli` are available.
- PostgreSQL and OpenAI credentials already exist in the target n8n project.
- The OpenAI credential uses a model available to the configured provider.
- No real resume, answer or provider payload is used for release evidence.

Apply the schema and run the repository gate:

```bash
chmod +x database/bootstrap/*.sh scripts/*.sh
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

The database must include migrations V001 through V010. Verification must end
with `TalentAI repository and runtime verification passed.`

## Import the release candidate

Build the candidate from committed sources:

```bash
TALENTAI_RC_VERSION='3.0.0-rc.1'
./scripts/build-phase45-mvp-package.sh "$TALENTAI_RC_VERSION"
TALENTAI_RC_PACKAGE="$PWD/exports/private/TalentAI-phase45-mvp-v${TALENTAI_RC_VERSION}.n8np"
test -s "$TALENTAI_RC_PACKAGE"
shasum -a 256 "$TALENTAI_RC_PACKAGE"
```

Import it into the project that owns the existing workflows:

```bash
TALENTAI_PROJECT_ID='<existing-n8n-project-id>'

n8n-cli package import \
  --file="$TALENTAI_RC_PACKAGE" \
  --project-id="$TALENTAI_PROJECT_ID" \
  --workflow-conflict-policy=new-version \
  --workflow-id-policy=source \
  --workflow-publishing-policy=preserve-published-state \
  --credential-matching-mode=id-only \
  --credential-missing-mode=must-preexist \
  --missing-node-type-mode=fail \
  --format=json
```

The import must report four workflows as `created` or `updated`, both
credentials as `matched`, and no stubbed credentials. Keep workflows inactive
until the smoke test is complete.

## Run the Phase 3 assessment

1. Open `TAI-01 Resume Intake & Extraction v2` and select **Execute workflow**.
2. Open its test form and submit a synthetic Java backend resume.
3. Use `JAVA_BACKEND`, a target grade such as `SENIOR`, and a matching job
   description.
4. Keep the returned `requestId`, `assessmentId` and `extractionId`.
5. Confirm the execution finishes at `COMPLETED / COMPLETED` with one extraction
   and one assessment.

Run the same request again with the same inputs. It must return `replayed: true`
without creating another extraction or assessment.

## Run the technical interview

1. Open `TAI-04 Candidate Interview & Final Grade v1` and select
   **Execute workflow**.
2. Submit the Phase 3 `extractionId` through the interview request form.
3. Answer all 20 first-round questions in the generated form.
4. Answer all 10 follow-up questions in the generated follow-up form.
5. Allow the workflow to score the answers and persist the final result.

Do not stop the workflow to execute individual nodes. Form executions retain
context across waits; isolated node execution can make an upstream expression
appear unexecuted and is not a supported recovery path.

The successful result must include:

- a completed interview session and immutable result version 1;
- two question sets and 30 answers, all evaluated;
- evidence-linked dimension scores and warnings;
- `gradeChecks` for Junior, Mid and Senior;
- an assigned grade equal to the highest grade whose overall and mandatory
  dimension checks pass, or `NO_MATCH` if none pass.

## Verify the persisted correlation

Run the live-data gate with the Phase 3 extraction ID:

```bash
./scripts/verify-phase45-correlation.sh '<phase3-extraction-uuid>'
```

The query prints the correlated identifiers and aggregate counts, asserts all
invariants in one transaction and rolls back its temporary state. It does not
print resume text, prompts or interview answers.

Run TAI-04 again with the same extraction ID. The completed result must be
replayed with the same session/result IDs and without additional question sets,
answers or results. Run the correlation command again.

## Recovery checks

Supported recovery is a new full workflow execution with the same extraction
ID. Retryable failures resume from the last valid persisted checkpoint:

- stored question sets are not regenerated;
- stored answers are not duplicated;
- evaluated answers can be reused for result persistence;
- a completed result is replayed unchanged.

Controlled failures store stable category/code metadata and omit private
provider payloads. Validation and incomplete/corrupt checkpoint failures are
non-retryable until their input or persisted state is corrected.

## Release evidence

Capture only the following:

- verification success lines;
- package filename and SHA-256;
- package import summary with credential matches;
- final output with synthetic candidate data;
- correlation query output;
- completed replay output;
- clean Git status and successful CI checks.

Never capture API keys, credential values, resume text, prompts, raw provider
responses or real candidate answers.
