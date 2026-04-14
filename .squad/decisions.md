# Squad Decisions

## Active Decisions

### 1. Workflow Skeleton Conventions

**Author:** McManus (Backend Dev)  
**Date:** 2025-07-17  
**Status:** Implemented  
**Work Item:** #1  

Created `.github/workflows/modernize-pipeline.yml` as the structural shell for the agentic modernization pipeline.

**Conventions established:**

1. **Working branch:** `modernize/<github.run_id>` — unique per run, easily traceable.
2. **Artifact paths:** `docs/modernization/stage-{1,2,3}/` — consistent with Keaton's decomposition.
3. **Workflow inputs:** `target-branch` (default: main), `dotnet-version-override` (default: 9.0).
4. **Concurrency:** single pipeline run at a time (`concurrency: modernize-pipeline, cancel-in-progress: false`).
5. **Permissions:** `contents: write` + `pull-requests: write` at workflow level.
6. **Summary job:** runs with `if: always()` so partial results produce a PR.
7. **Placeholder naming:** steps prefixed with `[PLACEHOLDER]` and annotated with work item numbers.
8. **Checkout:** `actions/checkout@v4` with `fetch-depth: 0` for full history.

**Plug-in points for downstream work items:**

| Work Item | What to fill in | Job | Step(s) |
|-----------|----------------|-----|---------|
| #2, #8 | Stage 1 agent prompt + wiring | `stage-1-docs` | Agent invocation, artifact commit |
| #3, #9 | Stage 2 agent prompt + wiring | `stage-2-tests` | Agent invocation, test run, artifact commit |
| #4, #10 | Stage 3 agent prompt + wiring | `stage-3-assessment` | Agent invocation, artifact commit |
| #5 | Contract gate: S2 validates S1 | `stage-2-tests` | Contract gate step |
| #6 | Contract gate: S3 validates S2 | `stage-3-assessment` | Contract gate step |
| #7 | PR creation logic | `summary-pr` | PR creation step |

---

### 2. PRD Decomposition — Agentic Modernization Pipeline (Stages 1–3)

**Author:** Keaton (Lead)  
**Date:** 2025-07-17  
**Status:** Merged  
**Requested by:** Rob  
**Input:** `docs/prd.md`  

**Context:** The PRD describes a multi-stage agentic pipeline for .NET modernization running inside GitHub Actions. This iteration covers stages 1–3 only: Documentation, Characterization Tests, and Upgrade Assessment. The pipeline must be sequential, artifact-driven, and fail-loud.

The eShopOnWeb repo is ASP.NET Core (currently targeting .NET 7) with clean architecture (6 src projects, 4 test projects), existing GitHub workflows, and existing test suites using xUnit.

**Architecture Decisions:**
1. Single workflow file: `.github/workflows/modernize-pipeline.yml` with sequential jobs chained via `needs:`
2. Artifact directory convention: Each stage writes to `docs/modernization/stage-N/`
3. Prompt files live in `.github/prompts/` — version-controlled and separate from workflow YAML
4. Contract gates are shell scripts in the workflow (not separate actions)
5. Target .NET 9 for assessment
6. Use xUnit for stage 2 characterization tests
7. Use Ubuntu runner for all stages

**Work Backlog:** 15 items assigned to McManus (#1–10), Hockney (#11–12), Keaton (#13–15). See detailed breakdown in orchestration log.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
