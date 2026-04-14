# Project Context

- **Owner:** Rob
- **Project:** eShopOnWeb — ASP.NET Core 7 monolithic e-commerce reference application
- **Stack:** C#, ASP.NET Core 7, Blazor (admin), Razor Pages (web), Entity Framework Core, SQL Server, Docker
- **Architecture:** Clean Architecture — ApplicationCore, Infrastructure, Web, PublicApi, BlazorAdmin, BlazorShared
- **Created:** 2026-04-14

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2025-07-18 — Pipeline Documentation (Work Item #13)

- **Artifact:** `AGENTS.md` created in repo root; `docs/modernization/README.md` created in docs/
- **Scope:** Documented the three-stage agentic pipeline architecture, contract gate pattern, artifact handoffs, and debugging guidance
- **Key insight:** Contract gates are the quality enforcement mechanism—section headings in prompts must stay in sync with gate validation scripts, or gates fail loudly. This is by design (defensive against prompt drift).
- **Audience:** Developers reading the repo with no prior context should be able to understand the pipeline in 5 minutes (AGENTS.md) or dive deep (modernization/README.md) for architecture details.
- **Rationale:** The pipeline is the heart of .NET modernization automation. Transparent, debuggable documentation reduces friction and prevents confusion when stages fail.

### 2025-07-17 — Open Questions Resolution (Work Item #15)

- **Decision record location:** `.squad/decisions/inbox/keaton-open-questions.md` — formally documents three PRD open questions as confirmed team decisions.
- **Decisions:** Target .NET 9 (not 7, not 10), Ubuntu runner (not Windows), xUnit (not NUnit or MSTest).
- **Rationale:** All three reflect defaults already baked into workflow skeleton (work item #1) and prompts (work items #2–#4). The record closes the loop by explaining *why* these choices were made and *what evidence* exists in the codebase.
- **Governance:** No further discussion needed; decisions locked in and inform all downstream work items.

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

### 2025-07-18 — Prompt Refinement Pass (Work Item #14)

- **Reviewed:** All three stage prompts against Hockney's E2E findings (53 checks, 0 blockers, 4 warnings).
- **Key pattern:** LLM agents commonly attempt build commands during analysis-only stages, modify .sln files unprompted, and create extra files outside declared output paths. Added explicit DO NOT constraints for each.
- **Stage 1 fixes:** Added "read files only" rule banning build/compile commands; clarified overwrite-on-rerun behavior; tightened scope boundary.
- **Stage 2 fixes:** Corrected incorrect `Directory.Packages.props` parenthetical for target framework; added .sln modification ban; added output path boundary constraint; made exit criteria enumerate exact baseline section names.
- **Stage 3 fixes:** Removed dead `dotnet-version-override` reference (Hockney Warning #1); added fallback if `modernize-dotnet` agent unavailable; expanded constraint specificity with explicit command bans.
- **Lesson:** Prompt quality gates should check for both "does it say the right things" AND "does it explicitly ban the wrong things." Agents treat silence as permission.
