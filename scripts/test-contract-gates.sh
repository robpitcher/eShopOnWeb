#!/usr/bin/env bash
# Contract Gate Validation Tests
#
# Exercises the same validation logic used by the contract gates in
# .github/workflows/modernize-pipeline.yml — without running the full pipeline.
#
# Usage:  chmod +x scripts/test-contract-gates.sh && ./scripts/test-contract-gates.sh
# Exit:   0 if all tests pass, 1 if any fail.

set -euo pipefail

# ── Bookkeeping ──────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); TOTAL=$((TOTAL + 1)); echo "[PASS] $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); TOTAL=$((TOTAL + 1)); echo "[FAIL] $1"; }

# ── Temp workspace ───────────────────────────────────────────────
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ── Fixture builders ─────────────────────────────────────────────
STAGE1_SECTIONS=(
  "## Projects and Target Frameworks"
  "## Dependencies"
  "## External I/O"
  "## Configuration Surface"
  "## Entry Points"
  "## Upgrade Risks"
)

STAGE2_SECTIONS=(
  "## Summary"
  "## Covered Behavior"
  "## Explicitly NOT Covered"
  "## Test Execution"
)

build_inventory() {
  # $1 = output path, remaining args = sections to SKIP
  local out="$1"; shift
  local skip=("$@")
  mkdir -p "$(dirname "$out")"
  echo "# Stage 1 Inventory" > "$out"
  echo "" >> "$out"
  for section in "${STAGE1_SECTIONS[@]}"; do
    local excluded=false
    for s in "${skip[@]+"${skip[@]}"}"; do
      if [ "$s" = "$section" ]; then excluded=true; break; fi
    done
    if [ "$excluded" = false ]; then
      echo "$section" >> "$out"
      echo "" >> "$out"
      echo "Content for $section" >> "$out"
      echo "" >> "$out"
    fi
  done
}

build_baseline() {
  # $1 = output path, remaining args = sections to SKIP
  local out="$1"; shift
  local skip=("$@")
  mkdir -p "$(dirname "$out")"
  echo "# Stage 2 Baseline" > "$out"
  echo "" >> "$out"
  for section in "${STAGE2_SECTIONS[@]}"; do
    local excluded=false
    for s in "${skip[@]+"${skip[@]}"}"; do
      if [ "$s" = "$section" ]; then excluded=true; break; fi
    done
    if [ "$excluded" = false ]; then
      echo "$section" >> "$out"
      echo "" >> "$out"
      echo "Content for $section" >> "$out"
      echo "" >> "$out"
    fi
  done
}

build_test_project() {
  # $1 = base dir, $2 = number of .cs files (0 = empty dir)
  local dir="$1"
  local count="${2:-1}"
  mkdir -p "$dir"
  for i in $(seq 1 "$count"); do
    echo "// Test file $i" > "$dir/Test${i}.cs"
  done
}

# ── Gate validation functions (extracted from workflow) ──────────

# Stage 2 gate: validates stage 1 inventory
# Returns 0 on pass, 1 on fail. Captures output in GATE_OUTPUT.
run_stage2_gate() {
  local root="$1"
  GATE_OUTPUT=$(
    INVENTORY="$root/docs/modernization/stage-1/inventory.md"
    FAILED=0

    if [ ! -f "$INVENTORY" ]; then
      echo "::error::CONTRACT GATE FAILED: Stage 1 inventory file missing — expected '$INVENTORY'"
      exit 1
    fi

    echo "✓ Inventory file exists: $INVENTORY"

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
        echo "::error::CONTRACT GATE FAILED: Stage 1 inventory missing required section '$section'"
        FAILED=1
      else
        echo "✓ Found required section: $section"
      fi
    done

    if [ "$FAILED" -eq 1 ]; then
      echo "::error::CONTRACT GATE FAILED: One or more required sections are missing from $INVENTORY"
      exit 1
    fi

    echo ""
    echo "✅ Contract gate passed — Stage 1 inventory is complete (6/6 sections present)"
  ) 2>&1
  return $?
}

# Stage 3 gate: validates stage 2 artifacts
run_stage3_gate() {
  local root="$1"
  GATE_OUTPUT=$(
    GATE_PASS=true

    if [ ! -d "$root/tests/CharacterizationTests" ]; then
      echo "::error::CONTRACT GATE FAILED: Stage 2 test project directory missing — 'tests/CharacterizationTests/' not found"
      GATE_PASS=false
    else
      CS_COUNT=$(find "$root/tests/CharacterizationTests" -name '*.cs' | wc -l)
      if [ "$CS_COUNT" -eq 0 ]; then
        echo "::error::CONTRACT GATE FAILED: Stage 2 test project contains no .cs files — 'tests/CharacterizationTests/' has zero C# source files"
        GATE_PASS=false
      else
        echo "✓ tests/CharacterizationTests/ exists with ${CS_COUNT} .cs file(s)"
      fi
    fi

    BASELINE="$root/docs/modernization/stage-2/baseline.md"
    if [ ! -f "$BASELINE" ]; then
      echo "::error::CONTRACT GATE FAILED: Stage 2 baseline document missing — '${BASELINE}' not found"
      GATE_PASS=false
    else
      echo "✓ ${BASELINE} exists"

      REQUIRED_SECTIONS=(
        "## Summary"
        "## Covered Behavior"
        "## Explicitly NOT Covered"
        "## Test Execution"
      )
      for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -q "^${section}" "$BASELINE"; then
          echo "::error::CONTRACT GATE FAILED: Stage 2 baseline missing required section '${section}'"
          GATE_PASS=false
        else
          echo "✓ Found required section: ${section}"
        fi
      done
    fi

    if [ "$GATE_PASS" = false ]; then
      echo ""
      echo "Stage 3 cannot proceed — stage 2 contract not satisfied."
      exit 1
    fi

    echo ""
    echo "✅ Contract gate passed — all stage 2 artifacts validated. Stage 3 may proceed."
  ) 2>&1
  return $?
}

# ═════════════════════════════════════════════════════════════════
# TESTS
# ═════════════════════════════════════════════════════════════════

echo "=== Contract Gate Validation Tests ==="
echo ""
echo "--- Stage 2 Gate (validates stage 1 inventory) ---"

# TC-S2-01: Missing inventory file
tc_root="$WORK_DIR/tc-s2-01"
mkdir -p "$tc_root"
if ! run_stage2_gate "$tc_root"; then
  if echo "$GATE_OUTPUT" | grep -q "Stage 1 inventory file missing"; then
    pass "Missing inventory file produces correct error"
  else
    fail "Missing inventory file — wrong error message"
    echo "  Got: $GATE_OUTPUT"
  fi
else
  fail "Missing inventory file — gate should have failed"
fi

# TC-S2-02 through TC-S2-07: Each section missing individually
for section in "${STAGE1_SECTIONS[@]}"; do
  tc_root="$WORK_DIR/tc-s2-section-$(echo "$section" | tr ' #' '-' | tr -d '.')"
  mkdir -p "$tc_root"
  build_inventory "$tc_root/docs/modernization/stage-1/inventory.md" "$section"
  if ! run_stage2_gate "$tc_root"; then
    if echo "$GATE_OUTPUT" | grep -q "missing required section '$section'"; then
      pass "Missing section: $section"
    else
      fail "Missing section: $section — wrong error message"
      echo "  Got: $GATE_OUTPUT"
    fi
  else
    fail "Missing section: $section — gate should have failed"
  fi
done

# TC-S2-08: Complete inventory passes
tc_root="$WORK_DIR/tc-s2-complete"
mkdir -p "$tc_root"
build_inventory "$tc_root/docs/modernization/stage-1/inventory.md"
if run_stage2_gate "$tc_root"; then
  if echo "$GATE_OUTPUT" | grep -q "Contract gate passed"; then
    pass "Complete inventory passes gate"
  else
    fail "Complete inventory — missing success message"
  fi
else
  fail "Complete inventory — gate should have passed"
  echo "  Got: $GATE_OUTPUT"
fi

echo ""
echo "--- Stage 3 Gate (validates stage 2 artifacts) ---"

# TC-S3-01: Missing CharacterizationTests directory
tc_root="$WORK_DIR/tc-s3-01"
mkdir -p "$tc_root/docs/modernization/stage-2"
build_baseline "$tc_root/docs/modernization/stage-2/baseline.md"
if ! run_stage3_gate "$tc_root"; then
  if echo "$GATE_OUTPUT" | grep -q "Stage 2 test project directory missing"; then
    pass "Missing CharacterizationTests directory produces correct error"
  else
    fail "Missing CharacterizationTests dir — wrong error message"
    echo "  Got: $GATE_OUTPUT"
  fi
else
  fail "Missing CharacterizationTests dir — gate should have failed"
fi

# TC-S3-02: Empty CharacterizationTests directory (no .cs files)
tc_root="$WORK_DIR/tc-s3-02"
mkdir -p "$tc_root/tests/CharacterizationTests"
mkdir -p "$tc_root/docs/modernization/stage-2"
build_baseline "$tc_root/docs/modernization/stage-2/baseline.md"
if ! run_stage3_gate "$tc_root"; then
  if echo "$GATE_OUTPUT" | grep -q "contains no .cs files"; then
    pass "Empty CharacterizationTests directory (no .cs) produces correct error"
  else
    fail "Empty CharacterizationTests dir — wrong error message"
    echo "  Got: $GATE_OUTPUT"
  fi
else
  fail "Empty CharacterizationTests dir — gate should have failed"
fi

# TC-S3-03: Missing baseline.md
tc_root="$WORK_DIR/tc-s3-03"
mkdir -p "$tc_root"
build_test_project "$tc_root/tests/CharacterizationTests" 2
if ! run_stage3_gate "$tc_root"; then
  if echo "$GATE_OUTPUT" | grep -q "Stage 2 baseline document missing"; then
    pass "Missing baseline.md produces correct error"
  else
    fail "Missing baseline.md — wrong error message"
    echo "  Got: $GATE_OUTPUT"
  fi
else
  fail "Missing baseline.md — gate should have failed"
fi

# TC-S3-04 through TC-S3-07: Each baseline section missing individually
for section in "${STAGE2_SECTIONS[@]}"; do
  tc_root="$WORK_DIR/tc-s3-section-$(echo "$section" | tr ' #' '-' | tr -d '.')"
  mkdir -p "$tc_root"
  build_test_project "$tc_root/tests/CharacterizationTests" 1
  build_baseline "$tc_root/docs/modernization/stage-2/baseline.md" "$section"
  if ! run_stage3_gate "$tc_root"; then
    if echo "$GATE_OUTPUT" | grep -q "missing required section '${section}'"; then
      pass "Missing section: $section"
    else
      fail "Missing section: $section — wrong error message"
      echo "  Got: $GATE_OUTPUT"
    fi
  else
    fail "Missing section: $section — gate should have failed"
  fi
done

# TC-S3-08: Complete stage 2 artifacts pass gate
tc_root="$WORK_DIR/tc-s3-complete"
mkdir -p "$tc_root"
build_test_project "$tc_root/tests/CharacterizationTests" 3
build_baseline "$tc_root/docs/modernization/stage-2/baseline.md"
if run_stage3_gate "$tc_root"; then
  if echo "$GATE_OUTPUT" | grep -q "Contract gate passed"; then
    pass "Complete stage 2 artifacts pass gate"
  else
    fail "Complete stage 2 artifacts — missing success message"
  fi
else
  fail "Complete stage 2 artifacts — gate should have passed"
  echo "  Got: $GATE_OUTPUT"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "${PASS_COUNT}/${TOTAL} tests passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "${FAIL_COUNT} FAILED"
  exit 1
fi
echo "All gates validated ✅"
exit 0
