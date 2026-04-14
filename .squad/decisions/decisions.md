# Decision Log

**Project:** eShopOnWeb Agentic Modernization Pipeline  
**Maintainer:** Keaton (Scribe)  
**Last Updated:** 2026-04-14

---

## Decision #1: Three-Stage Pipeline Architecture

**Date:** 2026-04-14  
**Author:** McManus  
**Status:** Approved

The agentic modernization pipeline follows a three-stage architecture:

1. **Stage 1 — Documentation Inventory:** Discover all .NET project metadata by reading `.csproj`, `.sln`, and `Directory.Packages.props` files. Output: `documentation-inventory.md`
2. **Stage 2 — Characterization Tests:** Generate baseline test suite (`CharacterizationTests.cs`) capturing current behavior, dependencies, and version constraints before upgrade.
3. **Stage 3 — Upgrade Assessment:** Analyze upgrade feasibility and recommend .NET 9 migration strategy. Output: `upgrade-assessment.md`

Each stage has explicit output contracts validated by PowerShell gates.

---

## Decision #2: Output Contract Validation Gates

**Date:** 2026-04-14  
**Author:** McManus  
**Status:** Approved

Each stage output is validated by a dedicated PowerShell gate:

- **Stage 1 Gate:** Validates `documentation-inventory.md` sections: Overview, Solution Structure, Project Dependencies, Configuration Analysis
- **Stage 2 Gate:** Validates `CharacterizationTests.cs` test structure, target framework setup, and baseline test count
- **Stage 3 Gate:** Validates `upgrade-assessment.md` sections: Summary, Risks, Dependencies, Recommendations

Gates run before PR delivery. If validation fails, the workflow stops; no PR is created.

---

## Decision #3: Section Heading Freeze

**Date:** 2026-04-14  
**Author:** Keaton  
**Status:** Approved

All section headings in output documents are locked:

- **Stage 1:** Overview, Solution Structure, Project Dependencies, Configuration Analysis
- **Stage 2:** (Test file structure, not section-based)
- **Stage 3:** Summary, Risks, Dependencies, Recommendations

These headings are embedded in validation gates and agent exit criteria. Changes require coordination with gate scripts and prompts.

---

## Decision #4: Test Category Structure (Stage 2)

**Date:** 2026-04-14  
**Author:** McManus  
**Status:** Approved

Characterization tests in Stage 2 are organized into categories:

1. **Basic Compilation Tests:** Verify project builds with current .NET version
2. **Dependency Resolution Tests:** Verify NuGet package resolution
3. **Version Constraint Tests:** Verify Framework Target and Managed Compatibility Pack constraints
4. **Integration Tests:** Verify inter-project dependencies compile and execute

Each category is a test class within `CharacterizationTests.cs`. No reordering or renaming without updating Stage 2 validation gate.

---

## Decision #5: Agent Prompt Refinement

**Date:** 2026-04-14  
**Author:** Keaton  
**Status:** Approved

All three stage prompts have been refined post-E2E testing based on Hockney's findings and observed LLM failure modes:

**Stage 1:** Added explicit "read files only" rule; banned all build/compilation commands.  
**Stage 2:** Fixed net7.0 reference; added "no solution file changes" constraint.  
**Stage 3:** Removed dead `TARGET_DOTNET` reference; added `modernize-dotnet` fallback agent.

Changes documented in `.squad/orchestration-log/2026-04-14T02-50-keaton-refinement.md`.

---

## Decision #6: Prompt Lock Policy

**Date:** 2026-04-14  
**Author:** Keaton  
**Status:** Approved

All stage prompts (`.github/prompts/stage-*.md`) are locked pending the first live `workflow_dispatch` run. No changes without team consensus and documented rationale. Post-run, prompts enter iteration cycle based on live pipeline results.

---

## Related Records

- **Orchestration Logs:** `.squad/orchestration-log/`
- **Session Logs:** `.squad/log/`
- **Agent Definitions:** `AGENTS.md`
- **Implementation Details:** `docs/modernization/`
- **Workflow Definition:** `.github/workflows/modernize-dotnet.yml`

---

**Archive Note:** All interim inbox decisions have been merged into this log. Inbox is now cleared.
