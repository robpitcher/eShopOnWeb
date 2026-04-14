# Contract Gate Validation Tests (PowerShell)
#
# Exercises the same validation logic used by the contract gates in
# .github/workflows/modernize-pipeline.yml — without running the full pipeline.
#
# Usage:  pwsh scripts/test-contract-gates.ps1
# Exit:   0 if all tests pass, 1 if any fail.

$ErrorActionPreference = "Stop"

# ── Bookkeeping ──────────────────────────────────────────────────
$script:PassCount = 0
$script:FailCount = 0
$script:Total     = 0

function Pass($msg) { $script:PassCount++; $script:Total++; Write-Host "[PASS] $msg" -ForegroundColor Green }
function Fail($msg) { $script:FailCount++; $script:Total++; Write-Host "[FAIL] $msg" -ForegroundColor Red }

# ── Section definitions ──────────────────────────────────────────
$Stage1Sections = @(
    "## Projects and Target Frameworks",
    "## Dependencies",
    "## External I/O",
    "## Configuration Surface",
    "## Entry Points",
    "## Upgrade Risks"
)

$Stage2Sections = @(
    "## Summary",
    "## Covered Behavior",
    "## Explicitly NOT Covered",
    "## Test Execution"
)

# ── Fixture builders ─────────────────────────────────────────────
function Build-Inventory {
    param(
        [string]$OutPath,
        [string[]]$SkipSections = @()
    )
    $dir = Split-Path $OutPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $lines = @("# Stage 1 Inventory", "")
    foreach ($section in $Stage1Sections) {
        if ($section -notin $SkipSections) {
            $lines += $section
            $lines += ""
            $lines += "Content for $section"
            $lines += ""
        }
    }
    $lines | Set-Content -Path $OutPath -Encoding UTF8
}

function Build-Baseline {
    param(
        [string]$OutPath,
        [string[]]$SkipSections = @()
    )
    $dir = Split-Path $OutPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $lines = @("# Stage 2 Baseline", "")
    foreach ($section in $Stage2Sections) {
        if ($section -notin $SkipSections) {
            $lines += $section
            $lines += ""
            $lines += "Content for $section"
            $lines += ""
        }
    }
    $lines | Set-Content -Path $OutPath -Encoding UTF8
}

function Build-TestProject {
    param(
        [string]$Dir,
        [int]$FileCount = 1
    )
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    for ($i = 1; $i -le $FileCount; $i++) {
        "// Test file $i" | Set-Content -Path (Join-Path $Dir "Test$i.cs") -Encoding UTF8
    }
}

# ── Gate validation functions (mirrors workflow logic) ───────────

function Invoke-Stage2Gate {
    param([string]$Root)

    $inventory = Join-Path $Root "docs\modernization\stage-1\inventory.md"
    $output = [System.Collections.Generic.List[string]]::new()
    $gatePassed = $true

    if (-not (Test-Path $inventory)) {
        $output.Add("::error::CONTRACT GATE FAILED: Stage 1 inventory file missing — expected '$inventory'")
        return @{ Passed = $false; Output = ($output -join "`n") }
    }
    $output.Add("✓ Inventory file exists: $inventory")

    $content = Get-Content -Path $inventory -Raw
    $failed = $false
    foreach ($section in $Stage1Sections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $output.Add("::error::CONTRACT GATE FAILED: Stage 1 inventory missing required section '$section'")
            $failed = $true
        } else {
            $output.Add("✓ Found required section: $section")
        }
    }

    if ($failed) {
        $output.Add("::error::CONTRACT GATE FAILED: One or more required sections are missing from $inventory")
        return @{ Passed = $false; Output = ($output -join "`n") }
    }

    $output.Add("")
    $output.Add("✅ Contract gate passed — Stage 1 inventory is complete (6/6 sections present)")
    return @{ Passed = $true; Output = ($output -join "`n") }
}

function Invoke-Stage3Gate {
    param([string]$Root)

    $output = [System.Collections.Generic.List[string]]::new()
    $gatePassed = $true

    $testDir = Join-Path $Root "tests\CharacterizationTests"
    if (-not (Test-Path $testDir)) {
        $output.Add("::error::CONTRACT GATE FAILED: Stage 2 test project directory missing — 'tests/CharacterizationTests/' not found")
        $gatePassed = $false
    } else {
        $csFiles = Get-ChildItem -Path $testDir -Filter "*.cs" -Recurse
        $csCount = @($csFiles).Count
        if ($csCount -eq 0) {
            $output.Add("::error::CONTRACT GATE FAILED: Stage 2 test project contains no .cs files — 'tests/CharacterizationTests/' has zero C# source files")
            $gatePassed = $false
        } else {
            $output.Add("✓ tests/CharacterizationTests/ exists with $csCount .cs file(s)")
        }
    }

    $baseline = Join-Path $Root "docs\modernization\stage-2\baseline.md"
    if (-not (Test-Path $baseline)) {
        $output.Add("::error::CONTRACT GATE FAILED: Stage 2 baseline document missing — '$baseline' not found")
        $gatePassed = $false
    } else {
        $output.Add("✓ $baseline exists")
        $content = Get-Content -Path $baseline -Raw
        foreach ($section in $Stage2Sections) {
            # Match section at start of line (mirrors grep -q "^${section}")
            if ($content -notmatch "(?m)^$([regex]::Escape($section))") {
                $output.Add("::error::CONTRACT GATE FAILED: Stage 2 baseline missing required section '$section'")
                $gatePassed = $false
            } else {
                $output.Add("✓ Found required section: $section")
            }
        }
    }

    if (-not $gatePassed) {
        $output.Add("")
        $output.Add("Stage 3 cannot proceed — stage 2 contract not satisfied.")
        return @{ Passed = $false; Output = ($output -join "`n") }
    }

    $output.Add("")
    $output.Add("✅ Contract gate passed — all stage 2 artifacts validated. Stage 3 may proceed.")
    return @{ Passed = $true; Output = ($output -join "`n") }
}

# ═════════════════════════════════════════════════════════════════
# TESTS
# ═════════════════════════════════════════════════════════════════

Write-Host "=== Contract Gate Validation Tests ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "--- Stage 2 Gate (validates stage 1 inventory) ---" -ForegroundColor Yellow

# TC-S2-01: Missing inventory file
$tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s2-01"
if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null
$result = Invoke-Stage2Gate -Root $tcRoot
if (-not $result.Passed -and $result.Output -match "Stage 1 inventory file missing") {
    Pass "Missing inventory file produces correct error"
} elseif ($result.Passed) {
    Fail "Missing inventory file — gate should have failed"
} else {
    Fail "Missing inventory file — wrong error message"
    Write-Host "  Got: $($result.Output)"
}

# TC-S2-02 through TC-S2-07: Each section missing individually
foreach ($section in $Stage1Sections) {
    $safeName = ($section -replace '[# .]', '-').Trim('-')
    $tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s2-$safeName"
    if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null

    Build-Inventory -OutPath (Join-Path $tcRoot "docs\modernization\stage-1\inventory.md") -SkipSections @($section)
    $result = Invoke-Stage2Gate -Root $tcRoot
    if (-not $result.Passed -and $result.Output -match [regex]::Escape("missing required section '$section'")) {
        Pass "Missing section: $section"
    } elseif ($result.Passed) {
        Fail "Missing section: $section — gate should have failed"
    } else {
        Fail "Missing section: $section — wrong error message"
        Write-Host "  Got: $($result.Output)"
    }
}

# TC-S2-08: Complete inventory passes
$tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s2-complete"
if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null
Build-Inventory -OutPath (Join-Path $tcRoot "docs\modernization\stage-1\inventory.md")
$result = Invoke-Stage2Gate -Root $tcRoot
if ($result.Passed -and $result.Output -match "Contract gate passed") {
    Pass "Complete inventory passes gate"
} elseif (-not $result.Passed) {
    Fail "Complete inventory — gate should have passed"
    Write-Host "  Got: $($result.Output)"
} else {
    Fail "Complete inventory — missing success message"
}

Write-Host ""
Write-Host "--- Stage 3 Gate (validates stage 2 artifacts) ---" -ForegroundColor Yellow

# TC-S3-01: Missing CharacterizationTests directory
$tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s3-01"
if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null
Build-Baseline -OutPath (Join-Path $tcRoot "docs\modernization\stage-2\baseline.md")
$result = Invoke-Stage3Gate -Root $tcRoot
if (-not $result.Passed -and $result.Output -match "Stage 2 test project directory missing") {
    Pass "Missing CharacterizationTests directory produces correct error"
} elseif ($result.Passed) {
    Fail "Missing CharacterizationTests dir — gate should have failed"
} else {
    Fail "Missing CharacterizationTests dir — wrong error message"
    Write-Host "  Got: $($result.Output)"
}

# TC-S3-02: Empty CharacterizationTests directory (no .cs files)
$tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s3-02"
if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tcRoot "tests\CharacterizationTests") -Force | Out-Null
Build-Baseline -OutPath (Join-Path $tcRoot "docs\modernization\stage-2\baseline.md")
$result = Invoke-Stage3Gate -Root $tcRoot
if (-not $result.Passed -and $result.Output -match "contains no \.cs files") {
    Pass "Empty CharacterizationTests directory (no .cs) produces correct error"
} elseif ($result.Passed) {
    Fail "Empty CharacterizationTests dir — gate should have failed"
} else {
    Fail "Empty CharacterizationTests dir — wrong error message"
    Write-Host "  Got: $($result.Output)"
}

# TC-S3-03: Missing baseline.md
$tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s3-03"
if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null
Build-TestProject -Dir (Join-Path $tcRoot "tests\CharacterizationTests") -FileCount 2
$result = Invoke-Stage3Gate -Root $tcRoot
if (-not $result.Passed -and $result.Output -match "Stage 2 baseline document missing") {
    Pass "Missing baseline.md produces correct error"
} elseif ($result.Passed) {
    Fail "Missing baseline.md — gate should have failed"
} else {
    Fail "Missing baseline.md — wrong error message"
    Write-Host "  Got: $($result.Output)"
}

# TC-S3-04 through TC-S3-07: Each baseline section missing individually
foreach ($section in $Stage2Sections) {
    $safeName = ($section -replace '[# .]', '-').Trim('-')
    $tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s3-$safeName"
    if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null

    Build-TestProject -Dir (Join-Path $tcRoot "tests\CharacterizationTests") -FileCount 1
    Build-Baseline -OutPath (Join-Path $tcRoot "docs\modernization\stage-2\baseline.md") -SkipSections @($section)
    $result = Invoke-Stage3Gate -Root $tcRoot
    if (-not $result.Passed -and $result.Output -match [regex]::Escape("missing required section '$section'")) {
        Pass "Missing section: $section"
    } elseif ($result.Passed) {
        Fail "Missing section: $section — gate should have failed"
    } else {
        Fail "Missing section: $section — wrong error message"
        Write-Host "  Got: $($result.Output)"
    }
}

# TC-S3-08: Complete stage 2 artifacts pass gate
$tcRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests\tc-s3-complete"
if (Test-Path $tcRoot) { Remove-Item $tcRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tcRoot -Force | Out-Null
Build-TestProject -Dir (Join-Path $tcRoot "tests\CharacterizationTests") -FileCount 3
Build-Baseline -OutPath (Join-Path $tcRoot "docs\modernization\stage-2\baseline.md")
$result = Invoke-Stage3Gate -Root $tcRoot
if ($result.Passed -and $result.Output -match "Contract gate passed") {
    Pass "Complete stage 2 artifacts pass gate"
} elseif (-not $result.Passed) {
    Fail "Complete stage 2 artifacts — gate should have passed"
    Write-Host "  Got: $($result.Output)"
} else {
    Fail "Complete stage 2 artifacts — missing success message"
}

# ── Summary ──────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 40) -ForegroundColor Cyan
Write-Host "$($script:PassCount)/$($script:Total) tests passed"
if ($script:FailCount -gt 0) {
    Write-Host "$($script:FailCount) FAILED" -ForegroundColor Red
    # Clean up
    $cleanDir = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests"
    if (Test-Path $cleanDir) { Remove-Item $cleanDir -Recurse -Force }
    exit 1
}
Write-Host "All gates validated ✅" -ForegroundColor Green

# Clean up
$cleanDir = Join-Path ([System.IO.Path]::GetTempPath()) "gate-tests"
if (Test-Path $cleanDir) { Remove-Item $cleanDir -Recurse -Force }
exit 0
