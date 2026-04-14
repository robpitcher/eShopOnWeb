# Project Context

- **Owner:** Rob
- **Project:** eShopOnWeb — ASP.NET Core 7 monolithic e-commerce reference application
- **Stack:** C#, ASP.NET Core 7, Blazor (admin), Razor Pages (web), Entity Framework Core, SQL Server, Docker
- **Architecture:** Clean Architecture — ApplicationCore, Infrastructure, Web, PublicApi, BlazorAdmin, BlazorShared
- **Created:** 2026-04-14

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2025-07-17 — PRD Decomposition (Agentic Modernization Pipeline)

- **PRD location:** `docs/prd.md` — multi-stage agentic pipeline for .NET modernization via GitHub Actions.
- **Iteration scope:** Stages 1–3 only (Documentation, Characterization Tests, Upgrade Assessment).
- **Architecture:** Single workflow file, sequential jobs via `needs:`, artifacts committed to working branch, contract gates at top of downstream jobs, prompts in `.github/prompts/`.
- **Key decisions:** Target .NET 9, xUnit for tests, Ubuntu runner, artifact dir `docs/modernization/stage-N/`.
- **Existing workflows:** `.github/workflows/dotnetcore.yml`, `richnav.yml`, squad workflows. New workflow named `modernize-pipeline.yml` to avoid collision.
- **Existing test projects:** UnitTests, IntegrationTests, FunctionalTests, PublicApiIntegrationTests — all xUnit.
- **Rob's preference:** eShopOnWeb is the sample app for testing upgrades. Keep it boring and auditable.
- **Decomposition:** 15 work items filed to `.squad/decisions/inbox/keaton-prd-decomposition.md`. McManus owns the critical path (items 1–10), Hockney owns validation (11–12), Keaton owns docs/review (13–15). Fenster has no work this iteration.
- **Critical path:** Workflow skeleton → S1 prompt → S1 wiring → S2 gate → S2 wiring → S3 wiring → E2E validation.
