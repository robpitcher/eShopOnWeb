# Agentic Modernization Pipeline

This repository uses an automated agentic pipeline to assess and plan the modernization of the eShopOnWeb application from ASP.NET Core 7 to .NET 9.

## What the Pipeline Does

The **Modernize Pipeline (Stages 1–3)** is a multi-stage GitHub Actions workflow that:

1. **Documents the current state** of the codebase (projects, dependencies, entry points, risks)
2. **Generates characterization tests** to lock in observable behavior before upgrade
3. **Assesses upgrade feasibility** for .NET 9 (breaking changes, dependency compatibility, effort estimates)

The pipeline is sequential and artifact-driven: each stage produces documented outputs that feed into the next stage. Contract gates between stages ensure quality and fail loudly with named errors if upstream work is incomplete.

## The Three Stages

### Stage 1: Documentation Inventory
- **Job:** `stage-1-docs`
- **Agent:** Copilot CLI with `.github/prompts/stage-1-documentation.md`
- **Output:** `docs/modernization/stage-1/inventory.md`
- **What it produces:**
  - Catalog of all projects and their target frameworks
  - Complete NuGet dependency list (direct + notes on transitive)
  - External I/O surfaces (databases, HTTP clients, file access, caching, event buses)
  - Configuration surface (appsettings keys, environment variables, secrets)
  - All entry points (web apps, APIs, background services, Blazor)
  - Upgrade risks by category (deprecated APIs, breaking changes, framework-specific patterns, third-party gaps)

**Why this matters:** Downstream stages depend on a complete and accurate inventory. The contract gate in Stage 2 validates that all six required sections are present.

### Stage 2: Characterization Tests
- **Job:** `stage-2-tests`
- **Agent:** Copilot CLI with `.github/prompts/stage-2-characterization-tests.md`
- **Artifacts:**
  - `tests/CharacterizationTests/` (new xUnit test project)
  - `docs/modernization/stage-2/baseline.md` (test summary and coverage gaps)
- **What it produces:**
  - xUnit-based test suite that locks in **current observable behavior** without refactoring
  - Five test categories: API endpoints, web app pages, services, configuration loading, data access
  - Black-box tests through HTTP and public API surface only
  - In-memory database fixtures so tests run without SQL Server
- **Critical gate:** Tests must pass against the current codebase before Stage 3 proceeds. If a test fails, the agent must fix the test (not the app).

**Why this matters:** Characterization tests are a safety net—they define what "working" looks like before code changes. If tests pass before upgrade and fail after, you know something broke.

### Stage 3: Upgrade Assessment
- **Job:** `stage-3-assessment`
- **Agent:** Copilot CLI invoking the `modernize-dotnet` custom agent with `.github/prompts/stage-3-upgrade-assessment.md`
- **Output:** `docs/modernization/stage-3/assessment.md`
- **What it produces:**
  - Feasibility analysis per project (can it upgrade to .NET 9?)
  - Breaking changes summary (API removals, behavioral changes, obsoleted patterns)
  - Dependency compatibility matrix (which NuGet packages block upgrade?)
  - Effort and risk estimates (low/medium/high per area)
  - Recommended upgrade path and sequencing rationale
- **Critical constraint:** Assessment only—no code changes, no builds, no test execution, no migration plans.

**Why this matters:** The assessment is the basis for decision-making. It tells you whether upgrade is feasible, what the main blockers are, and what order to tackle projects.

## How to Trigger a Run

The pipeline is triggered manually via **workflow_dispatch**:

1. Go to **Actions** → **Modernize Pipeline (Stages 1–3)**
2. Click **Run workflow**
3. (Optional) Override:
   - **target-branch:** Base branch to modernize from (default: `main`)
   - **dotnet-version-override:** Target .NET version (default: `9.0`)
4. Click **Run workflow**

The workflow creates a working branch `modernize-run/<run-id>` and commits artifacts to it. Once all stages complete (or fail), the **Summary: Create/Update PR** job opens a pull request with results.

**Viewing Results:**
- Check the workflow run in the **Actions** tab
- Inspect the PR created on the working branch—it contains artifact links
- Read the artifact files directly in the PR for detailed findings

## The Contract Gate Pattern

Contract gates are **validation scripts** that run at the start of downstream jobs. They verify that upstream work is complete and valid before proceeding.

### Why It Matters

- **Fail loud with named errors:** If Stage 1 didn't produce an inventory or missed a required section, the contract gate in Stage 2 stops immediately with a clear error message (not a cryptic agent failure).
- **Prevent wasted work:** No point running Stage 2 tests if Stage 1's inventory is incomplete. Contract gates catch this early.
- **Artifact contract enforcement:** Each stage outputs specific files with specific structures. Contract gates are the enforcement mechanism.

### How It Works

**Stage 2's gate on Stage 1:**
- Verifies `docs/modernization/stage-1/inventory.md` exists
- Validates it contains six required section headings (using `grep`)
- Fails with a specific error if any section is missing

**Stage 3's gate on Stage 2:**
- Verifies `tests/CharacterizationTests/` exists with at least one `.cs` file
- Verifies `docs/modernization/stage-2/baseline.md` exists
- Validates baseline.md contains four required sections
- Fails with a specific error if any check fails

### Implications for Prompt Changes

If you update a prompt and change output section headings, the corresponding contract gate **must be updated in lockstep**. For example:
- If Stage 1's prompt changes "## Upgrade Risks" to "## Migration Blockers", the Stage 2 contract gate must be updated to grep for "## Migration Blockers" instead.
- Document these changes in `.squad/decisions.md` to keep the team aligned.

## Artifact Directory Structure

```
docs/modernization/
├── stage-1/
│   └── inventory.md              (Stage 1 output)
├── stage-2/
│   ├── baseline.md               (Stage 2 summary)
│   └── (CharacterizationTests/ lives in tests/—not here)
└── stage-3/
    └── assessment.md             (Stage 3 output)
```

## Running the Pipeline Locally (Development)

For developers modifying the workflow or prompts:

1. **Test locally with act:**
   ```bash
   act workflow_dispatch -j stage-1-docs
   ```
   (Requires Docker and the `act` tool; limited Copilot CLI support)

2. **Manual testing:**
   - Install Copilot CLI: `npm install -g @github/copilot`
   - Test a prompt in isolation: `copilot --autopilot --yolo -p "$(cat .github/prompts/stage-1-documentation.md)"`

3. **Full workflow test:**
   - Trigger a workflow run from the Actions tab (no local environment setup needed)

## Troubleshooting

### Pipeline Fails at Contract Gate
1. Check the gate output in the workflow logs—it names the missing file or section
2. Review the corresponding prompt (`.github/prompts/stage-N-*.md`) to confirm expected section headings
3. If the gate message doesn't match the prompt, file a bug—they must stay in sync

### Agent Output Is Missing or Incomplete
1. Check agent logs in the workflow run: scroll to the agent invocation step
2. Verify inputs are available (for Stage 2+, check that prior stage artifacts exist)
3. Copilot CLI may have timed out—check if `--max-autopilot-continues 30` needs increase
4. Check the GITHUB_TOKEN / COPILOT_TOKEN secrets are properly configured

### Test Failures in Stage 2
1. Review `dotnet test` output in the workflow logs
2. Remember: the agent must fix the test, not the app code
3. Check that the test fixture pattern matches existing tests (e.g., `WebApplicationFactory<T>` with in-memory database)

## Further Reading

- **Pipeline specification:** See `docs/prd.md`
- **Architecture decisions:** See `.squad/decisions.md`
- **Prompt details:** See `.github/prompts/stage-*.md`
- **Modern pipeline docs:** See `docs/modernization/README.md`
