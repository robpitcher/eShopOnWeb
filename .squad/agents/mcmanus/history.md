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

