# Squad Decisions

## Active Decisions

### 1. Workflow Skeleton Conventions

**Author:** McManus (Backend Dev)  
**Date:** 2025-07-17  
**Status:** Implemented  
**Work Item:** #1  

Created `.github/workflows/modernize-pipeline.yml` as the structural shell for the agentic modernization pipeline.

**Conventions established:**

1. **Working branch:** `modernize-run/<github.run_id>` — unique per run, easily traceable.
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

### 3. Stage 1 Prompt — Section Heading Contract

**Author:** McManus (Backend Dev)  
**Date:** 2025-07-17  
**Work Item:** #2  
**Status:** Implemented  

The Stage 1 prompt (`.github/prompts/stage-1-documentation.md`) defines six required sections in the inventory output. The Stage 2 contract gate (work item #5) will validate that these sections exist before allowing Stage 2 to proceed.

**Section headings (fixed):**
1. `## Projects and Target Frameworks`
2. `## Dependencies`
3. `## External I/O`
4. `## Configuration Surface`
5. `## Entry Points`
6. `## Upgrade Risks`

Work item #5 (contract gate) **must** validate against these exact heading strings. If we rename a section in the prompt, the gate must be updated in lockstep.

**Rationale:** The PRD requires contract gates to "fail loud with a named error identifying what's missing." Exact heading names make grep-based validation deterministic and debuggable.

---

### 4. Stage 2 Prompt — Characterization Test Scope and Conventions

**Author:** McManus (Backend Dev)  
**Date:** 2025-07-17  
**Work Item:** #3  
**Status:** Implemented  

**Test Scope Decisions:**
1. **xUnit only** — matches 3 of 4 existing projects and the PRD decision
2. **Namespace:** `Microsoft.eShopWeb.CharacterizationTests` — follows `Microsoft.eShopWeb.<ProjectName>` convention
3. **In-memory EF Core** — same pattern as existing fixtures (`WebApplicationFactory<T>` with `UseInMemoryDatabase`)
4. **Blazor explicitly excluded** — BlazorAdmin and BlazorShared are WebAssembly apps requiring browser automation (out of scope)
5. **Five test categories with Trait markers:** Api, Web, Service, Configuration, DataAccess
6. **Fail-loud on missing inventory** — agent aborts with named error if `docs/modernization/stage-1/inventory.md` is missing
7. **No new packages** — only packages already in `Directory.Packages.props`

**Rationale:** Balances comprehensive characterization with practical execution constraints. xUnit dominates existing codebase, in-memory EF Core avoids SQL dependencies, trait markers enable selective filtering.

---

### 5. Stage 3 Prompt — Assessment-Only Scope and `modernize-dotnet` Delegation

**Author:** McManus (Backend Dev)  
**Date:** 2025-07-17  
**Work Item:** #4  
**Status:** Implemented  

**Assessment Constraints:**
1. **Analysis only** — no code changes, no builds, no test execution
2. **7 fixed output section headings** — makes contract gate validation simple (grep-based)
3. **Input References section** — cites stage 1 and stage 2 inputs for traceability
4. **Single output file** — exactly `docs/modernization/stage-3/assessment.md` (no side outputs)

**Explicit Bans:**
- `dotnet build`, `dotnet test`
- Source modifications
- Migration plans or upgrade scripts
- New packages

**Rationale:** Assessment-only prevents risky automation while gathering data for decision-making. Prescribed headings and single output file keep contract gates simple and artifact directory clean. Redundant constraints (both in prompt text and step instructions) mitigate agent drift risk.

---

### 6. Contract Gate Test Strategy

**Author:** Hockney (Tester)  
**Date:** 2025-07-17  
**Work Item:** #11  
**Status:** Implemented  

## Context

The PRD success criterion requires: *"Deliberately breaking a stage 1 artifact causes stage 2's contract gate to fail with a clear error message naming the missing piece."* We need a repeatable way to verify this without running the full pipeline every time.

## Decision

1. **Offline testing via extracted gate logic** — The validation scripts (`scripts/test-contract-gates.sh` and `.ps1`) reproduce the exact gate logic from the workflow, using temporary fixture files. This lets us validate gate behavior in seconds without triggering a full pipeline run.

2. **One test per failure mode** — Each required section gets its own test case (not just "remove any section"). This catches regressions where a specific heading string drifts between the prompt and the gate.

3. **Dual script (bash + PowerShell)** — Bash for CI (Ubuntu runner), PowerShell for local dev (Windows). Both exercise identical logic.

4. **grep behavior difference documented** — Stage 2 gate uses `grep -qF` (substring match), stage 3 uses `grep -q "^…"` (line-anchored). Scripts respect this difference. If someone changes the grep flags in the workflow, they need to update the test scripts too.

## Implications

- Any change to section headings in prompts must update: (a) the workflow gate, (b) the test scripts, (c) the test plan doc. Three-way lockstep.
- The test scripts can be added to a CI pre-check or run as a smoke test before merging prompt changes.

---

### 7. PRD Open Questions Resolution

**Author:** Keaton (Lead)  
**Date:** 2025-07-17  
**Work Item:** #15  
**Status:** Closed  
**Requested by:** Rob

#### Context

The Agentic Modernization Pipeline PRD (`docs/prd.md`) identified three open questions requiring team consensus. During implementation planning and PRD decomposition, the team made deliberate default choices aligned with the existing codebase. This decision record formally closes the loop on those questions.

#### Question 1: Target .NET Version

**PRD Question:** Which .NET version should the assessment target?

**Decision:** **.NET 9**

**Rationale:**
- eShopOnWeb currently runs on .NET 7 (end-of-support November 2024)
- .NET 9 is the latest LTS release and represents a pragmatic modernization target
- Aligns with Microsoft's mainstream upgrade guidance for production ASP.NET Core workloads
- Assessment scope must target a supported, modern framework version

**Evidence in Codebase:**
- Global workflow input `dotnet-version-override` defaults to `9.0` in `.github/workflows/modernize-pipeline.yml`
- PRD decomposition (decision #2) explicitly names "Target .NET 9 for assessment"

#### Question 2: Runner OS

**PRD Question:** Should stages run on Windows or Linux runners?

**Decision:** **Ubuntu (Linux)**

**Rationale:**
- eShopOnWeb is a modern ASP.NET Core application (.NET 7+), not .NET Framework
- Modern ASP.NET Core runs identically on Linux and Windows; testing on Linux reduces cost and complexity
- GitHub Actions Ubuntu runners are faster and more cost-efficient for build/test workflows
- Industry standard for cross-platform .NET Core validation
- No Windows-specific technologies in the stack (no desktop projects, no WinForms, no legacy dependencies)

**Evidence in Codebase:**
- Existing `.github/workflows/dotnetcore.yml` uses `ubuntu-latest` for .NET tests
- Docker Compose setup (`docker-compose.yml`, `docker-compose.override.yml`) runs on Linux containers
- No project files target `net7.0-windows` or other Windows-specific frameworks

#### Question 3: Test Framework

**PRD Question:** Should characterization tests use xUnit, NUnit, or MSTest?

**Decision:** **xUnit**

**Rationale:**
- Three of four existing test projects already use xUnit (UnitTests, IntegrationTests, FunctionalTests)
- eShopOnWeb has established xUnit conventions: namespace patterns, fixture setup, trait markers
- Consistency with existing codebase reduces cognitive load and leverages existing test infrastructure
- Stage 2 prompt explicitly requires xUnit as the framework for characterization tests

**Evidence in Codebase:**
- `tests/UnitTests/UnitTests.csproj` — xUnit
- `tests/IntegrationTests/IntegrationTests.csproj` — xUnit
- `tests/FunctionalTests/FunctionalTests.csproj` — xUnit
- Only `tests/PublicApiIntegrationTests/PublicApiIntegrationTests.csproj` uses NUnit; will not be affected by characterization tests
- Stage 2 decision (decision #4) names xUnit as the framework, not an option

#### Impact and Sign-off

These decisions are **locked in** and inform:
1. **Stage 1:** Target inventory documentation for .NET 9 migration analysis
2. **Stage 2:** Test environment setup (xUnit project, in-memory EF Core, Ubuntu runner)
3. **Stage 3:** Assessment assumptions and recommendations

All downstream work items (#2–#12, prompts, wiring, contract gates) assume these choices.

**No further discussion needed** — these represent consolidated team consensus captured during implementation planning.

---

### 8. E2E Pipeline Validation Findings

**Author:** Hockney (Tester)  
**Date:** 2025-07-17  
**Work Item:** #12  
**Severity:** Non-blocking (4 warnings, 0 failures)  
**Status:** Complete

#### Context

E2E validation of `.github/workflows/modernize-pipeline.yml` and all contract gates. Verified structural correctness, job chaining, fail-loud guarantees, and PR creation logic.

#### Findings

##### 1. `TARGET_DOTNET` env var is dead code (Low)

The `dotnet-version-override` workflow input is captured into `env.TARGET_DOTNET` but never consumed by any step. The stage 3 prompt hardcodes ".NET 9." The input is effectively cosmetic.

**Recommendation:** Either inject the value into the stage 3 agent invocation (e.g., prompt substitution) or remove the input and env var to avoid confusion. Not blocking — .NET 9 is the only target for now.

##### 2. Copilot CLI npm package name unverified (Medium)

All three stages run `npm install -g @github/copilot`. If this is not the correct published package name, all stages fail at install. This cannot be validated offline.

**Recommendation:** Before the first live run, verify with `npm view @github/copilot`. If incorrect, update all three agent invocation blocks.

##### 3. PR body heredoc fragile to re-indentation (Low)

The `sed -i 's/^          //' pr_body.md` command assumes exactly 10 leading spaces. If the YAML is reformatted, the PR body breaks silently (extra whitespace, not a crash).

**Recommendation:** No action required now. Consider a non-indented heredoc in a future cleanup pass.

##### 4. `COPILOT_TOKEN` secret needs documentation (Low)

The `COPILOT_TOKEN || GITHUB_TOKEN` fallback is fine, but operators need to know whether their org requires a dedicated PAT with Copilot scope. Not documented outside the workflow comments.

**Recommendation:** Add a note to the repo README or pipeline docs about when/how to configure `COPILOT_TOKEN`.

#### Verdict

**No blocking issues.** Pipeline is structurally correct. All contract gates match their prompt contracts exactly (6/6 stage 1 headings, 4/4 stage 2 headings). Job chaining, fail-loud guards, and PR creation logic are all sound.

Ready for a first live run pending Copilot CLI package name verification.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
