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
./scripts/verify-phase1.sh
```

The repository verification includes the rollback-safe Phase 4/5 persistence
contract and query suite in `scripts/test-technical-interview-persistence.sh`.
It never leaves synthetic interview sessions, questions, answers or results in
the database. The same suite verifies controlled failure recording, ownership
checks and retry metadata without retaining provider payloads.

Retryable Phase 4/5 executions resume from the persisted interview stage.
Question sets and answers are reloaded through the checkpoint query instead of
being regenerated, and answer-evaluation metadata is retained for final-result
recovery.

`scripts/build-phase45-mvp-package.sh` creates a private four-workflow release
candidate from the verified Phase 3 package and the committed TAI-04 source. It
derives credential references from the source package, rejects source drift and
scans the assembled archive for likely secrets. Release artifacts remain under
`exports/private` and must not be committed.

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
