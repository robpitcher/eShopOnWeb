# Project Context

- **Owner:** Rob
- **Project:** eShopOnWeb — ASP.NET Core 7 monolithic e-commerce reference application
- **Stack:** C#, ASP.NET Core 7, Blazor (admin), Razor Pages (web), Entity Framework Core, SQL Server, Docker
- **Architecture:** Clean Architecture — ApplicationCore, Infrastructure, Web, PublicApi, BlazorAdmin, BlazorShared
- **Created:** 2026-04-14

## Work Assignment — 2026-04-14

**PRD Decomposition (Keaton):** Agentic modernization pipeline (stages 1–3) decomposed into 15 work items.

**Assigned Items:** #1–10 (Workflow skeleton, prompts, contract gates, integration wiring)
- **Priority:** P0–P1
- **Start:** Workflow skeleton (#1)
- **Critical path:** #1 → #2 → #8 → #5 → #9 → #10
- **Blockers:** None

See `.squad/decisions.md` for full backlog and dependency graph.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### Work Item #1 — Workflow Skeleton (completed)
- **File:** `.github/workflows/modernize-pipeline.yml`
- **No naming conflict** — existing workflows: `dotnetcore.yml`, `richnav.yml`, `squad-*.yml`, `sync-squad-labels.yml`
- **Working branch convention:** `modernize-run/<run-id>` (using `github.run_id`)
- **Artifact paths:** `docs/modernization/stage-{1,2,3}/`
- **Inputs:** `target-branch` (default: main), `dotnet-version-override` (default: 9.0)
- **Job chain:** `stage-1-docs` → `stage-2-tests` → `stage-3-assessment` → `summary-pr`
- **Concurrency:** single run at a time via `concurrency: modernize-pipeline`
- **summary-pr** runs with `if: always()` so partial results still produce a PR
- **Existing CI uses** `actions/checkout@v2` and `dotnet-version: 7.0.x` — new workflow uses `@v4`
- **Placeholder steps** are labeled `[PLACEHOLDER]` with comments naming the work item that fills them
- **Each placeholder** documents: what the agent should do, output paths, and which prompt file to use

### Work Item #3 — Stage 2 Agent Prompt (completed)
- **File:** `.github/prompts/stage-2-characterization-tests.md`
- **Input contract:** `docs/modernization/stage-1/inventory.md` — agent aborts if missing
- **Test project path:** `tests/CharacterizationTests/CharacterizationTests.csproj`
- **Namespace:** `Microsoft.eShopWeb.CharacterizationTests` (matches repo convention `Microsoft.eShopWeb.<ProjectName>`)
- **Existing test projects:** FunctionalTests (xUnit), IntegrationTests (xUnit), UnitTests (xUnit), PublicApiIntegrationTests (MSTest — outlier)
- **Centralized packages:** `Directory.Packages.props` controls all versions; test csproj must NOT specify versions
- **Test fixture pattern:** `WebApplicationFactory<T>` with in-memory EF Core overrides — two existing fixtures (Web → `TestApplication`, PublicApi → `TestApiApplication`)
- **Five test categories:** Api, Web, Service, Configuration, DataAccess — mapped to `[Trait("Category", "...")]`
- **Baseline output:** `docs/modernization/stage-2/baseline.md` with covered, not-covered, and counts
- **Blazor exclusion:** BlazorAdmin/BlazorShared cannot be tested with xUnit (requires browser automation)
- **Exit criteria:** tests build and pass, baseline exists, no `src/` modifications

### Work Item #2 — Stage 1 Agent Prompt (completed)
- **File:** `.github/prompts/stage-1-documentation.md`
- **Prompt is self-contained** — assumes the receiving agent has zero prior context about the repo
- **Output path declared explicitly:** `docs/modernization/stage-1/inventory.md` — matches workflow artifact path
- **Six required sections** with exact heading names for downstream contract gate parsing: Projects and Target Frameworks, Dependencies, External I/O, Configuration Surface, Entry Points, Upgrade Risks
- **Fail-loud principle enforced:** agent instructed to write `UNKNOWN — <reason>` rather than guess
- **No-code-changes rule** stated three times (Role, Rules, and inline) to prevent scope creep
- **Analysis walkthrough included** — step-by-step instructions: start from .sln, read .csproj, check Directory.Packages.props, scan Program.cs/Startup.cs, trace DbContext/HttpClient/IHostedService, read appsettings, check Docker and CI files, check global.json
- **Heading names matter** — work item #5 (contract gate) will grep for these exact section headings

### Work Item #4 — Stage 3 Agent Prompt (completed)
- **File:** `.github/prompts/stage-3-upgrade-assessment.md`
- **Created `.github/prompts/` directory** — first prompt file in the repo; stages 1 and 2 prompts not yet written
- **Input contracts:** requires `docs/modernization/stage-1/inventory.md` and `docs/modernization/stage-2/baseline.md`
- **Fail-loud pattern:** abort with named error if either input is missing or empty
- **Delegates to `modernize-dotnet` custom agent** — assessment phase only, explicitly forbids planning/execution
- **Output:** single file `docs/modernization/stage-3/assessment.md` with 7 required sections
- **Required sections:** Summary, Upgrade Feasibility Analysis, Breaking Changes, Dependency Compatibility Matrix, Effort and Risk Estimates, Recommended Upgrade Path, Input References
- **Constraints block** explicitly bans `dotnet build`, `dotnet test`, source modifications, and migration plan generation
- **Target:** .NET 9 (per team decision #5 in decisions.md)

### Work Item #6 — Contract Gate: Stage 3 Validates Stage 2 (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `stage-3-assessment` job
- **Replaced placeholder** with a real shell-based contract gate (first step after checkout)
- **Three checks:** (1) `tests/CharacterizationTests/` directory exists, (2) contains at least one `.cs` file, (3) `docs/modernization/stage-2/baseline.md` exists with all four required sections
- **Required sections** sourced from `.github/prompts/stage-2-characterization-tests.md`: `## Summary`, `## Covered Behavior`, `## Explicitly NOT Covered`, `## Test Execution`
- **Fail-loud pattern:** each check emits `::error::CONTRACT GATE FAILED:` with the specific missing item; gate collects all failures before exiting 1 (reports everything, not just the first miss)
- **Success path:** prints per-check confirmations then a final `✅ Contract gate passed` line
- **Same pattern as #5:** downstream-validates-upstream, shell `run:` step (not a separate action), per team decision #4

### Work Item #8 — Stage 1 Integration Wiring (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `stage-1-docs` job
- **Agent invocation pattern:** Copilot CLI in autopilot mode (`copilot --autopilot --yolo --max-autopilot-continues 30 -p "$PROMPT"`)
- **CLI install:** `actions/setup-node@v4` (Node 22) + `npm install -g @github/copilot`
- **Auth:** `COPILOT_GITHUB_TOKEN` env var, prefers `secrets.COPILOT_TOKEN` with fallback to `secrets.GITHUB_TOKEN`
- **Prompt delivery:** reads `.github/prompts/stage-1-documentation.md` via `cat` into a shell variable, passed to `-p`
- **Commit identity:** `github-actions[bot]` — standard bot user for Actions-authored commits
- **Fail-loud on empty output:** commit step checks `git diff --cached --quiet` and exits 1 with `::error::` annotation if no artifacts produced
- **Working branch:** created and pushed only in stage 1; stages 2/3 just check out the existing branch
- **No official `uses:` action** exists for Copilot coding agent invocation (as of 2025) — CLI is the standard approach
- **Commit message convention:** `Stage 1: Documentation inventory [run #<run_id>]`

### Work Item #7 — PR Summary Job (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `summary-pr` job
- **Fixed `needs:` declaration** — changed from `needs: stage-3-assessment` to `needs: [stage-1-docs, stage-2-tests, stage-3-assessment]` so all three results are available in the `needs` context
- **Three steps:** Build PR body → Create or update PR → Clean up temp files
- **PR body** uses heredoc + `sed` dedent pattern; includes stage results table with emoji status, artifact links, and workflow run URL
- **Create-or-update pattern:** `gh pr list --head <branch> --json number --jq` to detect existing PR, then `gh pr create` or `gh pr edit` accordingly
- **Auth:** `GH_TOKEN` env var from `secrets.GITHUB_TOKEN` (gh CLI reads it automatically)
- **Cleanup step** uses `if: always()` to remove `pr_body.md` temp file even on failure

### Work Item #5 — Contract Gate: Stage 2 Validates Stage 1 (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `stage-2-tests` job, first step after checkout
- **Replaced placeholder** with real shell `run:` step — no separate action, per team decision #4
- **File existence check:** verifies `docs/modernization/stage-1/inventory.md` exists; exits immediately with named error if missing
- **Section validation:** checks all 6 required headings from `.github/prompts/stage-1-documentation.md` using `grep -qF` (fixed-string match, no regex surprises)
- **Six required sections:** `## Projects and Target Frameworks`, `## Dependencies`, `## External I/O`, `## Configuration Surface`, `## Entry Points`, `## Upgrade Risks`
- **Reports every missing section** before exiting — accumulates failures so the error log names ALL missing sections, not just the first one
- **Uses `::error::` annotations** so failures appear as red error annotations in the GitHub Actions UI
- **Pattern is reusable** for work item #6 (Stage 3 validates Stage 2) — same structure, different file and headings

### Work Item #9 — Stage 2 Integration Wiring (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `stage-2-tests` job
- **Replaced all 3 placeholders** — agent invocation, test run, and artifact commit steps now fully wired
- **Step order (8 total):** Checkout → Contract gate → Setup Node → Install Copilot CLI → Invoke agent → Setup .NET SDK → Run tests → Commit & push
- **Agent invocation:** same pattern as stage 1 — `copilot --autopilot --yolo --max-autopilot-continues 30 -p "$PROMPT"`, reads `.github/prompts/stage-2-characterization-tests.md`
- **Auth:** identical to stage 1 — `COPILOT_GITHUB_TOKEN` from `secrets.COPILOT_TOKEN || secrets.GITHUB_TOKEN`
- **.NET SDK setup:** `actions/setup-dotnet@v4` with `7.0.x` (matches `global.json`) — placed after agent invocation, before test run
- **Test execution is a hard gate:** `dotnet test tests/CharacterizationTests/ --configuration Release --verbosity normal` — no `--no-restore` (safer, since agent may not have restored)
- **Commit pattern mirrors stage 1:** `github-actions[bot]` identity, fail-loud on empty `git diff --cached`, descriptive commit message with run ID
- **Artifacts committed:** `tests/CharacterizationTests/` + `docs/modernization/stage-2/` — both test code and baseline document
- **Working branch:** stage 2 checks out existing `modernize-run/<run_id>` branch (created by stage 1), does not create a new one
- **Contract gate (#5) confirmed** in position — first step after checkout, before any agent work

### Work Item #10 — Stage 3 Integration Wiring (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `stage-3-assessment` job
- **Replaced both placeholders** — agent invocation and artifact commit steps now fully wired
- **Step order (7 total):** Checkout → Contract gate → Setup Node → Install Copilot CLI → Invoke agent → Commit & push
- **Agent invocation:** same pattern as stages 1 and 2 — `copilot --autopilot --yolo --max-autopilot-continues 30 --agent modernize-dotnet -p "$PROMPT"`, reads `.github/prompts/stage-3-upgrade-assessment.md`
- **Custom agent flag:** `--agent modernize-dotnet` passes the custom agent reference through to the CLI (stage 3 prompt delegates to this agent)
- **Auth:** identical to stages 1 and 2 — `COPILOT_GITHUB_TOKEN` from `secrets.COPILOT_TOKEN || secrets.GITHUB_TOKEN`
- **Commit pattern mirrors stages 1 and 2:** `github-actions[bot]` identity, fail-loud on empty `git diff --cached`, commit message `Stage 3: Upgrade assessment [run #<run_id>]`
- **Artifacts committed:** `docs/modernization/stage-3/` only (assessment is analysis-only, no code outputs)
- **Working branch:** stage 3 checks out existing `modernize-run/<run_id>` branch (created by stage 1)
- **Contract gate (#6) confirmed** in position — first step after checkout, before any agent work
- **No .NET SDK needed** — stage 3 is assessment-only (no builds, no tests), unlike stage 2
- **Zero placeholders remain** in the entire workflow file — pipeline skeleton fully wired end-to-end
- **This was McManus's last pipeline wiring item** — all 10 work items (#1–10) complete

### PR #8 — Copilot Auth Error Handling (PR Review Response) (completed)
- **Branch:** `fix/copilot-auth-error-handling`
- **File:** `.github/workflows/modernize-pipeline.yml`
- **Addressed 6 review comments** from `copilot-pull-request-reviewer`:
  1. **Comments 1–3:** Removed `GITHUB_TOKEN` fallback from all 3 stages — changed `COPILOT_GITHUB_TOKEN: ${{ secrets.COPILOT_TOKEN || secrets.GITHUB_TOKEN }}` to just `secrets.COPILOT_TOKEN` (no fallback)
  2. **Comments 1–3:** Added preflight checks at start of each stage's run block — tests if `$COPILOT_GITHUB_TOKEN` is empty, prints actionable error with PAT URL, exits 1
  3. **Comment 4:** Added missing PAT URL to Stage 2 error messages (both preflight and post-CLI handler)
  4. **Comment 5:** Added missing PAT URL to Stage 3 error messages (both preflight and post-CLI handler)
  5. **Comment 6:** Quoted `$COPILOT_EXIT` in all 3 stages — changed `if [ $COPILOT_EXIT -ne 0 ]` to `if [ "$COPILOT_EXIT" -ne 0 ]` for robustness
- **Consistency achieved:** All 3 stages now have identical structure for token validation:
  1. `env:` block with `GITHUB_TOKEN` and `COPILOT_GITHUB_TOKEN` (no fallback)
  2. Preflight check for empty `$COPILOT_GITHUB_TOKEN` with full error messaging
  3. Copilot CLI invocation with `set +e` / `set -e`
  4. Post-CLI error handler with quoted `$COPILOT_EXIT` and all 5 error lines (including PAT URL)
- **Fail-loud from the start:** Preflight check catches missing secret before CLI invocation, providing immediate feedback with actionable error message
- **Rationale:** The fallback pattern was misleading — `GITHUB_TOKEN` lacks Copilot API scope, so fallback would always fail but with less clear error. New pattern fails fast with explicit instructions.

