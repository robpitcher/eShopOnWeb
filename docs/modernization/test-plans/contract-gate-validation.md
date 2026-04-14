# Contract Gate Validation — Test Plan

> **Work Item:** #11  
> **Author:** Hockney (Tester)  
> **Date:** 2025-07-17  
> **Status:** Active  

## Purpose

The PRD requires that every stage's contract gate **fail loud with a named error identifying what's missing** when upstream artifacts are incomplete. This test plan documents how to deliberately break each gate and verify the error output.

The pipeline contract gates are shell scripts embedded in `.github/workflows/modernize-pipeline.yml`. This plan covers the stage 2 gate (validates stage 1 output) and stage 3 gate (validates stage 2 output).

---

## Gate 1: Stage 2 Validates Stage 1 Inventory

### What the gate checks

The stage 2 contract gate (job `stage-2-tests`) validates:

1. **File existence** — `docs/modernization/stage-1/inventory.md` must exist.
2. **Required sections** — The inventory must contain all six section headings:
   - `## Projects and Target Frameworks`
   - `## Dependencies`
   - `## External I/O`
   - `## Configuration Surface`
   - `## Entry Points`
   - `## Upgrade Risks`

### Test procedure — manual

| Step | Action | Expected Outcome |
|------|--------|------------------|
| 1 | Run the pipeline normally (via `workflow_dispatch`) | Stage 1 produces `inventory.md`, stage 2 gate passes |
| 2 | On the working branch, delete `docs/modernization/stage-1/inventory.md` entirely, then re-run stage 2 | Gate fails with: `CONTRACT GATE FAILED: Stage 1 inventory file missing — expected 'docs/modernization/stage-1/inventory.md'` |
| 3 | Restore the file but remove the `## Dependencies` heading | Gate fails with: `CONTRACT GATE FAILED: Stage 1 inventory missing required section '## Dependencies'` |
| 4 | Remove multiple headings (e.g., `## External I/O` and `## Entry Points`) | Gate fails with one error per missing section, then a summary: `CONTRACT GATE FAILED: One or more required sections are missing` |
| 5 | Verify the job exits with a non-zero code | GitHub Actions marks the job as ❌ failed; stage 3 is skipped |

### What "stopped cleanly" means

- The gate step exits with code 1.
- No subsequent steps in the `stage-2-tests` job execute (the agent invocation and test execution placeholders do not run).
- The `summary-pr` job still runs (it has `if: always()`), showing stage 2 as ❌.
- The working branch is not polluted with partial artifacts.

---

## Gate 2: Stage 3 Validates Stage 2 Artifacts

### What the gate checks

The stage 3 contract gate (job `stage-3-assessment`) validates:

1. **Test project directory** — `tests/CharacterizationTests/` must exist.
2. **C# source files** — At least one `.cs` file inside that directory.
3. **Baseline document** — `docs/modernization/stage-2/baseline.md` must exist.
4. **Required sections in baseline** — The baseline must contain:
   - `## Summary`
   - `## Covered Behavior`
   - `## Explicitly NOT Covered`
   - `## Test Execution`

### Test procedure — manual

| Step | Action | Expected Outcome |
|------|--------|------------------|
| 1 | Run the full pipeline normally | All three stages complete; stage 3 gate passes |
| 2 | Delete the `tests/CharacterizationTests/` directory | Gate fails with: `CONTRACT GATE FAILED: Stage 2 test project directory missing — 'tests/CharacterizationTests/' not found` |
| 3 | Restore the directory but delete all `.cs` files inside it | Gate fails with: `CONTRACT GATE FAILED: Stage 2 test project contains no .cs files` |
| 4 | Restore `.cs` files but delete `docs/modernization/stage-2/baseline.md` | Gate fails with: `CONTRACT GATE FAILED: Stage 2 baseline document missing` |
| 5 | Restore `baseline.md` but remove the `## Summary` heading | Gate fails with: `CONTRACT GATE FAILED: Stage 2 baseline missing required section '## Summary'` |
| 6 | Remove multiple headings | One error per missing section, job exits with code 1 |
| 7 | Verify the job exits with a non-zero code and no downstream steps run | Stage 3 agent placeholder does not execute |

### What "stopped cleanly" means

- Same criteria as Gate 1: non-zero exit, no subsequent steps, summary PR still fires, no partial artifacts.

---

## Automated Validation

An automated script exercises the same validation logic offline, without needing to trigger the full pipeline.

| Script | Purpose |
|--------|---------|
| `scripts/test-contract-gates.sh` | Bash — runs on the CI runner (Ubuntu) or WSL |
| `scripts/test-contract-gates.ps1` | PowerShell — runs on Windows dev machines |

Both scripts:

1. Create temporary fixture files (inventory.md, baseline.md, test .cs files)
2. Run the gate validation logic extracted from the workflow
3. Test each missing section individually
4. Test file-missing scenarios
5. Report pass/fail per test case with a final summary

### Running the scripts

```bash
# Bash (Linux / macOS / WSL)
chmod +x scripts/test-contract-gates.sh
./scripts/test-contract-gates.sh

# PowerShell (Windows)
pwsh scripts/test-contract-gates.ps1
```

### Expected output (all tests passing)

```
=== Contract Gate Validation Tests ===

--- Stage 2 Gate (validates stage 1 inventory) ---
[PASS] Missing inventory file produces correct error
[PASS] Missing section: ## Projects and Target Frameworks
[PASS] Missing section: ## Dependencies
[PASS] Missing section: ## External I/O
[PASS] Missing section: ## Configuration Surface
[PASS] Missing section: ## Entry Points
[PASS] Missing section: ## Upgrade Risks
[PASS] Complete inventory passes gate

--- Stage 3 Gate (validates stage 2 artifacts) ---
[PASS] Missing CharacterizationTests directory produces correct error
[PASS] Empty CharacterizationTests directory (no .cs) produces correct error
[PASS] Missing baseline.md produces correct error
[PASS] Missing section: ## Summary
[PASS] Missing section: ## Covered Behavior
[PASS] Missing section: ## Explicitly NOT Covered
[PASS] Missing section: ## Test Execution
[PASS] Complete stage 2 artifacts pass gate

16/16 tests passed
```

---

## Traceability

| Artifact | Source |
|----------|--------|
| Stage 2 gate shell commands | `.github/workflows/modernize-pipeline.yml`, lines 130–168 |
| Stage 3 gate shell commands | `.github/workflows/modernize-pipeline.yml`, lines 232–282 |
| Stage 1 section headings | `.github/prompts/stage-1-documentation.md` (Decision #3) |
| Stage 2 baseline sections | `.github/prompts/stage-2-characterization-tests.md` (Decision #4) |
