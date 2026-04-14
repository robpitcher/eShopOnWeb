# Project Context

- **Owner:** Rob
- **Project:** eShopOnWeb — ASP.NET Core 7 monolithic e-commerce reference application
- **Stack:** C#, ASP.NET Core 7, Blazor (admin), Razor Pages (web), Entity Framework Core, SQL Server, Docker
- **Architecture:** Clean Architecture — ApplicationCore, Infrastructure, Web, PublicApi, BlazorAdmin, BlazorShared
- **Created:** 2026-04-14

## Work Assignment — 2026-04-14

**PRD Decomposition (Keaton):** Agentic modernization pipeline (stages 1–3) decomposed into 15 work items.

**Assigned Items:** #11–12 (Contract gate failure testing, end-to-end validation)
- **Priority:** P0
- **Blockers:** Waiting for McManus to complete integration wiring (#1–10)
- **Start:** After stage 2 contract gate (#5) and stage 1 wiring (#8) complete

See `.squad/decisions.md` for full backlog and dependency graph.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2025-07-17 — Work Item #11: Contract Gate Failure Tests

- Both contract gates (stage 2→1 and stage 3→2) are pure shell scripts with grep-based heading checks — no external dependencies, easy to test offline.
- Stage 2 gate uses `grep -qF` (fixed-string match anywhere in file); stage 3 gate uses `grep -q "^${section}"` (anchored to start of line). This matters for test fixtures.
- Created 16 test cases (8 per gate): file/dir missing, each required section missing individually, and a happy-path pass. All 16 green on first run.
- Deliverables: `docs/modernization/test-plans/contract-gate-validation.md`, `scripts/test-contract-gates.sh`, `scripts/test-contract-gates.ps1`.
- The PowerShell script mirrors the bash logic but uses `[regex]::Escape()` and `(?m)` multiline flag for line-anchored matches.

### 2025-07-17 — Work Item #12: End-to-End Pipeline Validation

- Ran 53 checks across 12 categories against the full wired pipeline. Zero failures, four non-blocking warnings.
- Contract gate headings match prompt-declared headings exactly: 6/6 for gate #5 (stage 1→2), 4/4 for gate #6 (stage 2→3). Cross-reference is clean.
- `TARGET_DOTNET` env var is defined at workflow level but never consumed — the `dotnet-version-override` input is dead code. Not blocking since .NET 9 is hardcoded in the stage 3 prompt.
- Copilot CLI package name (`@github/copilot`) cannot be verified offline — flagged as medium-risk for the first live run.
- PR body heredoc uses a fragile `sed` strip for indentation — works but breaks if YAML is reformatted. Low-priority cleanup.
- Deliverables: `docs/modernization/test-plans/e2e-validation-report.md`, `.squad/decisions/inbox/hockney-e2e-findings.md`.

