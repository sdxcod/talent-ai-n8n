# TalentAI automation scripts

The repository separates automation by execution environment and responsibility:

| Location | Runtime | Purpose |
|---|---|---|
| `scripts/*.sh` | Bash on macOS/Linux/WSL | Operator commands for bootstrap, verification, tests and release builds |
| `scripts/*.mjs` | Node.js | Cross-platform workflow transforms and deterministic source tests |
| `scripts/lib/` | Node.js | Shared non-executable JavaScript modules |
| `scripts/windows/*.ps1` | PowerShell on Windows | Native Windows operator helpers |
| `database/bootstrap/*.sh` | PostgreSQL Linux container | First-volume initialization hooks mounted by Docker Compose |

The files in `database/bootstrap` are not host operating-system launchers. Docker
executes them inside the PostgreSQL container only when a new database volume is
created. Day-to-day database synchronization uses `scripts/apply-database.sh`.

## Supported entry points

The supported Windows path for the MVP is **Docker Desktop with WSL2**. This
uses the same Bash entry points and verification path as Linux and CI, avoiding
two implementations of release-critical behavior. Git attributes force LF line
endings for container and Bash scripts so Git for Windows cannot corrupt their
shebangs.

macOS, Linux or WSL:

```bash
./scripts/bootstrap-local.sh
./scripts/apply-database.sh
./scripts/verify-talentai.sh
```

Workflow sources are grouped by business domain rather than implementation
phase:

| Location | Scope |
|---|---|
| `workflows/resume-assessment/` | TAI-01 through TAI-03 |
| `workflows/technical-interview/` | TAI-04 and TAI-05 |
| `workflows/shared/` | Shared form assets |

The canonical release and live-correlation entry points are:

```bash
./scripts/build-talentai-mvp-package.sh <semver>
./scripts/verify-talentai-correlation.sh <phase3-extraction-uuid>
```

The former Phase-based entry points remain as thin deprecated wrappers for
compatibility with v3.1.0 runbooks and existing operator automation:

```text
verify-phase1.sh
build-phase45-mvp-package.sh
verify-phase45-correlation.sh
test-phase1-operational-workflows.sh
```

New documentation and automation must use the canonical domain-oriented names.

After one complete synthetic Phase 1 through Phase 5 run, verify that its
persisted records form one consistent chain:

```bash
./scripts/verify-talentai-correlation.sh <phase3-extraction-uuid>
```

This live-data release gate is intentionally not part of CI: a clean CI
database has no provider-backed interview result. It reads identifiers,
statuses and aggregate counts only; it does not print resumes, prompts or
answer text.

The repository verification includes the rollback-safe Phase 4/5 persistence
contract and query suite in `scripts/test-technical-interview-persistence.sh`.
It never leaves synthetic interview sessions, questions, answers or results in
the database. The same suite verifies controlled failure recording, ownership
checks and retry metadata without retaining provider payloads.

Retryable Phase 4/5 executions resume from the persisted interview stage.
Question sets and answers are reloaded through the checkpoint query instead of
being regenerated, and answer-evaluation metadata is retained for final-result
recovery.

`scripts/build-talentai-mvp-package.sh` creates a private five-workflow release
candidate from the verified Phase 3 package and the committed TAI-04 and TAI-05
sources. It derives credential references from the source package, rejects
source drift and scans the assembled archive for likely secrets. Release
artifacts remain under `exports/private` and must not be committed.

`scripts/build-tai05-secure-invitation.mjs` deterministically rebuilds the
authenticated invitation-management workflow. The associated
`scripts/test-secure-invitation-workflows.mjs` suite verifies one-time opaque
token delivery, TAI-04 claim routing, form privacy settings, source
synchronization and sanitized candidate-facing failures.

`scripts/test-form-access-and-rtl.mjs` verifies authenticated HR form access,
the conditional `MEETS_TARGET` invitation action and shared RTL styling across
TAI-01, TAI-04 and TAI-05.

Optional native Windows PowerShell database initialization:

```powershell
.\scripts\windows\initialize-database.ps1
```

The PowerShell helper is not a full Windows bootstrap. It reads `.env` from the repository root, connects to the
host-published PostgreSQL port, creates the required roles/database when needed,
and applies the same versioned migrations and seeds. Full local-stack automation
currently uses the Bash entry points; Windows users should run those through WSL
or invoke Docker Compose and the PowerShell database helper explicitly.

When adding automation:

1. keep Docker entrypoint hooks under `database/bootstrap`;
2. keep portable Node.js logic under `scripts` or `scripts/lib`;
3. keep native Windows counterparts under `scripts/windows`;
4. never duplicate business rules between shell variants—both variants should
   execute the same migrations, schemas and workflow sources.
