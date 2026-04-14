# Stage 3 — Upgrade Assessment Prompt

> **Pipeline role:** Assessment phase only. No planning. No code execution. No source transformation.

---

## Input Contracts

Before doing ANY work, verify the following files exist on the current branch.
If any input is missing, **abort immediately** with an error naming the missing file.

| Input artifact | Path | Produced by |
|---|---|---|
| Repository inventory | `docs/modernization/stage-1/inventory.md` | Stage 1 |
| Characterization test baseline | `docs/modernization/stage-2/baseline.md` | Stage 2 |

```
REQUIRED_INPUTS=(
  "docs/modernization/stage-1/inventory.md"
  "docs/modernization/stage-2/baseline.md"
)
```

**Fail-loud rule:** If either file is absent or empty, print `STAGE-3 ABORT: Missing required input — <path>` and exit. Do not attempt partial work.

---

## Target

- **Target framework:** .NET 9 (`net9.0`)
- This is the fixed target for this pipeline iteration. Do not assess for any other version.

---

## Instructions

### Step 1 — Read prior stage artifacts

1. Read `docs/modernization/stage-1/inventory.md` in full. Extract:
   - All projects and their current target frameworks
   - All NuGet dependencies and their versions
   - External I/O surfaces (database, HTTP, filesystem)
   - Configuration patterns
   - Entry points
   - Upgrade risks already flagged by stage 1

2. Read `docs/modernization/stage-2/baseline.md` in full. Extract:
   - Test coverage summary
   - Explicit coverage gaps
   - Behavioral contracts locked by characterization tests

### Step 2 — Invoke the `modernize-dotnet` custom agent (ASSESSMENT PHASE ONLY)

Invoke the `modernize-dotnet` custom agent to perform **assessment only** for upgrading to .NET 9.
If the `modernize-dotnet` agent is unavailable or fails to respond, perform the assessment directly yourself using the same criteria listed below.

Pass it the following context:
- The full stage 1 inventory
- The stage 2 baseline summary
- The explicit instruction: **assessment phase only — do NOT plan, do NOT execute, do NOT modify any source files**

The assessment must cover:
1. **Upgrade feasibility analysis** — Can each project in the solution upgrade to .NET 9? What blocks it?
2. **Breaking changes identified** — API removals, behavioral changes, obsoleted patterns between the current framework version and .NET 9.
3. **Dependency compatibility matrix** — For every NuGet package listed in stage 1, determine whether a .NET 9–compatible version exists. Flag packages with no compatible version.
4. **Estimated effort and risk areas** — Classify each project/area as low / medium / high effort and risk. Call out the riskiest areas explicitly.
5. **Recommended upgrade path** — Suggested ordering of projects, any prerequisite steps, and a sequencing rationale.

### Step 3 — Write the assessment artifact

Write the full assessment to:

```
docs/modernization/stage-3/assessment.md
```

The document **must** include these sections (use these exact headings):

```markdown
# .NET 9 Upgrade Assessment

## Summary
## Upgrade Feasibility Analysis
## Breaking Changes
## Dependency Compatibility Matrix
## Effort and Risk Estimates
## Recommended Upgrade Path
## Input References
```

The `## Input References` section must link to both input artifacts:
- `docs/modernization/stage-1/inventory.md`
- `docs/modernization/stage-2/baseline.md`

---

## Output Contract

| Output artifact | Path |
|---|---|
| Upgrade assessment | `docs/modernization/stage-3/assessment.md` |

**Output directory:** `docs/modernization/stage-3/`

The output file must exist and contain all required sections before this stage is considered successful.

---

## Constraints

- **Assessment only.** Do not create migration plans, do not generate upgrade scripts, do not modify any project files or source code.
- **No execution.** Do NOT run `dotnet build`, `dotnet test`, `dotnet restore`, `dotnet run`, or any compilation/execution commands. All analysis is based on reading files.
- **No package installation.** Do NOT install any npm or NuGet packages.
- **Single output file.** The only file you create is `docs/modernization/stage-3/assessment.md`. Do NOT write to any other path. Do NOT modify any existing file in the repository.
- **Fail loud.** If you cannot produce a complete assessment (e.g., missing inputs, agent failure), exit with a non-zero status and a clear error message.
