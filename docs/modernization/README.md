# Modernization Pipeline — Deep Dive

This directory contains artifacts from the **Agentic Modernization Pipeline**, a three-stage GitHub Actions workflow that assesses and plans the upgrade of eShopOnWeb from ASP.NET Core 7 to .NET 9.

## Quick Overview

| Stage | Job | Agent | Output | Duration |
|-------|-----|-------|--------|----------|
| 1 | `stage-1-docs` | Copilot CLI + prompt | `stage-1/inventory.md` | ~5–10 min |
| 2 | `stage-2-tests` | Copilot CLI + prompt | `stage-2/baseline.md` + test project | ~15–20 min |
| 3 | `stage-3-assessment` | Copilot CLI + `modernize-dotnet` agent | `stage-3/assessment.md` | ~10–15 min |

All jobs run sequentially on Ubuntu runners. Results are committed to a working branch (`modernize/<run-id>`) and collected in a pull request.

---

## Pipeline Architecture

### Sequential Job Design

```
stage-1-docs
    ↓ (commit artifacts)
    ↓ (contract gate validates)
stage-2-tests
    ↓ (commit artifacts)
    ↓ (contract gate validates)
stage-3-assessment
    ↓ (commit artifacts)
    ↓
summary-pr (runs regardless of success/failure)
```

**Key design choices:**
- **Concurrency control:** Only one pipeline run at a time (`concurrency: modernize-pipeline, cancel-in-progress: false`)
- **Artifact handoff:** Each stage commits its output to the working branch; downstream stages check out and validate
- **Contract gates:** Validation at job start ensures upstream work is complete before proceeding
- **Failure isolation:** Jobs use `needs:` to enforce dependencies. One failure stops downstream, but partial results still generate a PR

### Working Branch Naming

Each run creates its own working branch: `modernize/<github.run_id>`

**Why separate branches?**
- Each run is completely isolated—no conflicts between concurrent design scenarios
- Easy to trace results: `github.run_id` matches the Actions tab run number
- Cleanup is simple: delete the branch when done

### Artifact Locations

All artifacts live in `docs/modernization/` on the working branch:

```
docs/modernization/
├── stage-1/
│   └── inventory.md              ← What Stage 1 produces
├── stage-2/
│   └── baseline.md               ← What Stage 2 produces
└── stage-3/
    └── assessment.md             ← What Stage 3 produces
```

**Note:** The characterization test project (`tests/CharacterizationTests/`) is also a Stage 2 artifact but lives in `tests/` for organizational reasons.

---

## Stage Details and Outputs

### Stage 1: Documentation Inventory

**Prompt:** `.github/prompts/stage-1-documentation.md`

**Input:** None (starts from scratch, reads repo structure)

**Output:** `docs/modernization/stage-1/inventory.md`

**Six Required Sections:**
1. `## Projects and Target Frameworks` — All `.csproj` files, their frameworks, and dependencies
2. `## Dependencies` — Complete NuGet package list per project, flagging pinned/deprecated/risky packages
3. `## External I/O` — Database connections, HTTP clients, file access, caching, message queues, email services
4. `## Configuration Surface` — appsettings keys, environment variables, secrets, IOptions<T> bindings
5. `## Entry Points` — Web apps, APIs, console apps, background services, Blazor hosting models
6. `## Upgrade Risks` — Deprecated APIs, breaking changes, framework-specific patterns, third-party gaps, Docker/container concerns

**Contract gate (Stage 2):**
Validates file exists and contains all six section headings. If any section is missing, Stage 2 fails with a named error.

**What Stage 1 does NOT do:**
- Modify code or project files
- Run builds or tests
- Infer missing information—uses "UNKNOWN — <reason>" if data can't be traced

### Stage 2: Characterization Tests

**Prompt:** `.github/prompts/stage-2-characterization-tests.md`

**Input contract:**
- `docs/modernization/stage-1/inventory.md` (from Stage 1)
- Fails immediately if missing

**Outputs:**
1. `tests/CharacterizationTests/CharacterizationTests.csproj` — New xUnit test project
2. `tests/CharacterizationTests/**/*.cs` — Test source files organized by category
3. `docs/modernization/stage-2/baseline.md` — Test summary and coverage documentation

**Test Structure (5 Categories):**

| Category | What It Tests | Example |
|----------|--------------|---------|
| `ApiEndpoints/` | Public API contracts (authentication, catalog CRUD, response shapes) | POST `/login` with valid creds → 200, invalid → 401 |
| `WebApp/` | Web UI behavior (home page, filtering, basket, orders, redirects) | GET `/` → 200, contains product content |
| `Services/` | Service-layer contracts (catalog, basket, orders) | Catalog service returns seeded data through app stack |
| `Configuration/` | DI and configuration (services registered, DbContext resolvable) | Application starts with default config, required services available |
| `DataAccess/` | Repository and specification patterns | Seeded data is accessible, queries return expected shapes |

**Test Execution:**
```bash
dotnet test tests/CharacterizationTests/ --configuration Release
```

**Test fixtures pattern:**
- `WebApplicationFactory<T>` (from existing functional tests)
- In-memory EF Core database (`UseInMemoryDatabase`)
- No SQL Server dependency
- Follows existing patterns in `tests/FunctionalTests/`

**Baseline.md Required Sections:**
1. `## Summary` — Total test count, per-category breakdown, all passing yes/no, target framework
2. `## Covered Behavior` — Observable behavior locked in by category
3. `## Explicitly NOT Covered` — Blazor (WebAssembly), email, external payments, CSS/JS rendering, migrations, performance
4. `## Test Execution` — Command and expected result

**Contract gate (Stage 3):**
- Validates `tests/CharacterizationTests/` exists with ≥1 `.cs` file
- Validates `docs/modernization/stage-2/baseline.md` exists and contains four section headings
- Fails with named error if any check fails

**What Stage 2 does NOT do:**
- Refactor or fix app code
- Modify existing test projects or source code
- Add new NuGet dependencies (only uses what's already in Directory.Packages.props)
- Test private methods or implementation details (black-box only)

### Stage 3: Upgrade Assessment

**Prompt:** `.github/prompts/stage-3-upgrade-assessment.md`

**Input contract:**
- `docs/modernization/stage-1/inventory.md`
- `docs/modernization/stage-2/baseline.md`
- Fails immediately if either is missing

**Output:** `docs/modernization/stage-3/assessment.md`

**Seven Required Sections:**
1. `## Summary` — Top-line feasibility, main blockers, estimated effort
2. `## Upgrade Feasibility Analysis` — Per-project analysis (can it upgrade to .NET 9? What blocks it?)
3. `## Breaking Changes` — API removals, behavioral changes, obsoleted patterns between current and .NET 9
4. `## Dependency Compatibility Matrix` — For every NuGet package in Stage 1, is there a .NET 9–compatible version?
5. `## Effort and Risk Estimates` — Low/medium/high classification per project/area, riskiest items called out
6. `## Recommended Upgrade Path` — Suggested project ordering, prerequisites, sequencing rationale
7. `## Input References` — Links to `stage-1/inventory.md` and `stage-2/baseline.md`

**Agent invocation:**
```bash
copilot --autopilot --yolo \
  --agent modernize-dotnet \
  -p "$(cat .github/prompts/stage-3-upgrade-assessment.md)"
```

The `modernize-dotnet` custom agent is specialized for .NET upgrade analysis. Stage 3 prompt feeds it the inventory and baseline, instructing "assessment phase only—do NOT plan, do NOT execute, do NOT modify sources."

**What Stage 3 does NOT do:**
- Modify code or project files
- Run `dotnet build` or `dotnet test`
- Generate migration scripts or upgrade automation
- Create an upgrade plan (only assessment, not sequencing—though recommended path is part of assessment)
- Add new dependencies

---

## Contract Gates: Fail-Loud Validation

Contract gates are shell scripts that run at the **start** of downstream jobs. They validate upstream outputs before proceeding.

### Stage 2's Contract Gate on Stage 1

```bash
# Check 1: Inventory file exists
if [ ! -f "docs/modernization/stage-1/inventory.md" ]; then
  echo "::error::CONTRACT GATE FAILED: Stage 1 inventory file missing"
  exit 1
fi

# Check 2: All six required sections present
SECTIONS=(
  "## Projects and Target Frameworks"
  "## Dependencies"
  "## External I/O"
  "## Configuration Surface"
  "## Entry Points"
  "## Upgrade Risks"
)
for section in "${SECTIONS[@]}"; do
  if ! grep -qF "$section" "$INVENTORY"; then
    echo "::error::CONTRACT GATE FAILED: Missing '$section'"
    exit 1
  fi
done
```

**Why `grep -qF` (fixed-string search)?**
- Exact heading match (no regex interpretation)
- Fast and deterministic
- Section headings are version-controlled in `.github/prompts/stage-1-documentation.md`; if you rename a section, **update the gate in lockstep**

### Stage 3's Contract Gate on Stage 2

```bash
# Check 1: Test project directory exists with .cs files
if [ ! -d "tests/CharacterizationTests" ]; then
  echo "::error::CONTRACT GATE FAILED: tests/CharacterizationTests/ not found"
  exit 1
fi
CS_COUNT=$(find tests/CharacterizationTests -name '*.cs' | wc -l)
if [ "$CS_COUNT" -eq 0 ]; then
  echo "::error::CONTRACT GATE FAILED: No .cs files in tests/CharacterizationTests/"
  exit 1
fi

# Check 2: Baseline document exists with required sections
if [ ! -f "docs/modernization/stage-2/baseline.md" ]; then
  echo "::error::CONTRACT GATE FAILED: baseline.md not found"
  exit 1
fi
REQUIRED_SECTIONS=(
  "## Summary"
  "## Covered Behavior"
  "## Explicitly NOT Covered"
  "## Test Execution"
)
for section in "${REQUIRED_SECTIONS[@]}"; do
  if ! grep -q "^${section}" "$BASELINE"; then
    echo "::error::CONTRACT GATE FAILED: Missing '$section' in baseline"
    exit 1
  fi
done
```

### Why Contract Gates Matter

1. **Fail fast:** If Stage 1 output is incomplete, Stage 2 fails before wasting time running the agent
2. **Named errors:** "Missing '## External I/O'" is debuggable. A cryptic agent failure is not
3. **Deterministic validation:** Shell scripts + grep are more reliable than agent-based validation
4. **Version control enforcement:** Prompts and gates must stay in sync (document changes in `.squad/decisions.md`)

---

## Debugging a Failed Run

### 1. Check the Contract Gate First

If Stage 2 or Stage 3 fails, scroll to the "Contract gate" step in the logs. It will explicitly name:
- Which file is missing
- Which section is missing
- What was expected

**Example:**
```
::error::CONTRACT GATE FAILED: Stage 1 inventory missing required section '## External I/O'
```

This tells you Stage 1's agent didn't produce a complete inventory. Review Stage 1's logs.

### 2. Check Agent Logs

Each stage has an "Invoke Stage N agent" step. The agent logs show:
- What the agent was doing
- Error messages
- Output artifacts created

**Common issues:**
- Agent timed out: increase `--max-autopilot-continues` or increase `initial_wait` in the workflow
- Authentication failed: check `COPILOT_TOKEN` secret is set and valid
- Missing input file: prior stage didn't commit artifacts (check prior stage's "Commit and push" step)

### 3. Check Artifact Commits

Each stage has a "Commit and push stage N artifacts" step. It verifies:
- Files exist in the expected paths
- `git add` successfully stages them
- `git commit` and `git push` succeed

**If this step fails:**
- The agent didn't produce the expected output
- Review the agent logs (above)
- Check working branch permissions (ensure `contents: write` is set at workflow level)

### 4. Review the Artifact Files

Once the workflow completes (or fails), check the working branch `modernize/<run-id>`:

```bash
# Clone/fetch the working branch
git fetch origin modernize/<run-id>
git checkout modernize/<run-id>

# Read the artifacts
cat docs/modernization/stage-1/inventory.md
cat docs/modernization/stage-2/baseline.md
cat docs/modernization/stage-3/assessment.md
```

Artifacts are in the PR description and linked for easy viewing.

---

## Prompt Files and Their Relationship to the Workflow

### `.github/prompts/stage-1-documentation.md`

- **Role:** Agent instructions for analyzing the repo
- **Output contract:** Produces inventory.md with six fixed sections
- **Gate dependency:** Stage 2's contract gate validates these section headings. If you change a section name, update `.github/workflows/modernize-pipeline.yml` in the Stage 2 contract gate step
- **Change control:** Document section renames in `.squad/decisions.md` decision log

### `.github/prompts/stage-2-characterization-tests.md`

- **Role:** Agent instructions for generating black-box tests
- **Input contract:** Reads stage-1/inventory.md (agent aborts if missing)
- **Output contract:** Produces baseline.md with four fixed sections, test project in tests/CharacterizationTests/
- **Gate dependency:** Stage 3's contract gate validates baseline.md section headings and test project structure
- **Change control:** Section renames must be coordinated with contract gate updates

### `.github/prompts/stage-3-upgrade-assessment.md`

- **Role:** Agent instructions for assessing .NET 9 upgrade
- **Custom agent:** Invokes `modernize-dotnet` (specialized for .NET upgrades)
- **Input contract:** Reads stage-1/inventory.md and stage-2/baseline.md (agent aborts if either missing)
- **Output contract:** Produces assessment.md with seven fixed sections
- **Change control:** No downstream contract gate (this is the final stage), but section renames should be noted in decisions.md

---

## Target Versions and Platform

### .NET Target

- **Assessment target:** .NET 9 (`net9.0`)
- **Current baseline:** .NET 7 (`net7.0`)
- **Override:** `dotnet-version-override` workflow input (default `9.0`)

### Test Framework

- **xUnit** (matches 3 of 4 existing test projects; Stage 2 uses it exclusively)
- **Existing projects:** UnitTests, IntegrationTests, FunctionalTests, PublicApiIntegrationTests (all xUnit)

### Platform

- **Runner:** `ubuntu-latest`
- **Node.js:** 22 (for Copilot CLI)
- **.NET SDK:** 7.0.x (current app framework)

---

## Summary PR and Results

### Summary Job (`summary-pr`)

Runs after all stages (whether they succeed or fail) with `if: always()`:

1. **Builds a markdown PR body** with stage results and artifact links
2. **Creates or updates a PR** from working branch to target branch
3. **Links all artifact files** so reviewers can inspect results without cloning

**PR title:** `Modernization Pipeline Run #<run-id>`

**PR body includes:**
- Status emojis per stage (✅ success, ❌ failure, ⏭️ skipped, 🚫 cancelled)
- Pass rate ("2 of 3" stages successful)
- Direct links to artifact files
- Link to workflow run logs

### Partial Results

If one stage fails, later stages are skipped (`needs:` dependency), but the PR is still created with partial results. This is intentional:
- Shows what succeeded
- Preserves logs for debugging
- Allows re-runs without losing earlier progress

---

## Key Takeaways

1. **Sequential and atomic:** Each stage is independent; one failure stops downstream work
2. **Contract gates catch incomplete work early:** No wasted effort on bad inputs
3. **Artifact-driven handoffs:** Files committed to working branch are the communication protocol
4. **Prompts and gates must stay in sync:** If you rename a section in a prompt, update the corresponding gate
5. **Assessment, not execution:** Pipeline produces data for decision-making, not automation
6. **Fail loud with names:** Errors identify exactly what's missing, making debugging straightforward

---

## Further Resources

- **Workflow file:** `.github/workflows/modernize-pipeline.yml`
- **Prompt files:** `.github/prompts/stage-*.md`
- **Decision log:** `.squad/decisions.md`
- **PRD:** `docs/prd.md`
- **AGENTS.md:** Root-level overview of agentic workflows in this project
