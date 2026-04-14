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
- **Working branch convention:** `modernize/<run-id>` (using `github.run_id`)
- **Artifact paths:** `docs/modernization/stage-{1,2,3}/`
- **Inputs:** `target-branch` (default: main), `dotnet-version-override` (default: 9.0)
- **Job chain:** `stage-1-docs` → `stage-2-tests` → `stage-3-assessment` → `summary-pr`
- **Concurrency:** single run at a time via `concurrency: modernize-pipeline`
- **summary-pr** runs with `if: always()` so partial results still produce a PR
- **Existing CI uses** `actions/checkout@v2` and `dotnet-version: 7.0.x` — new workflow uses `@v4`
- **Placeholder steps** are labeled `[PLACEHOLDER]` with comments naming the work item that fills them
- **Each placeholder** documents: what the agent should do, output paths, and which prompt file to use

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

### Work Item #7 — PR Summary Job (completed)
- **File:** `.github/workflows/modernize-pipeline.yml` — `summary-pr` job
- **Fixed `needs:` declaration** — changed from `needs: stage-3-assessment` to `needs: [stage-1-docs, stage-2-tests, stage-3-assessment]` so all three results are available in the `needs` context
- **Three steps:** Build PR body → Create or update PR → Clean up temp files
- **PR body** uses heredoc + `sed` dedent pattern; includes stage results table with emoji status, artifact links, and workflow run URL
- **Create-or-update pattern:** `gh pr list --head <branch> --json number --jq` to detect existing PR, then `gh pr create` or `gh pr edit` accordingly
- **Auth:** `GH_TOKEN` env var from `secrets.GITHUB_TOKEN` (gh CLI reads it automatically)
- **Cleanup step** uses `if: always()` to remove `pr_body.md` temp file even on failure

