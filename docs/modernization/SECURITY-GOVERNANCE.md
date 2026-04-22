# Security and Governance Model — Agentic Modernization Pipeline

**Document Version:** 1.0
**Last Updated:** 2026-04-22
**For:** InfoSec Review & Platform Governance
**Status:** POC Implementation

---

## Executive Summary

This document describes the security and governance model for the **Agentic Modernization Pipeline**, a proof-of-concept system that uses GitHub Actions and GitHub Copilot CLI to automate .NET application modernization assessments.

**Key Security Properties:**
- **Zero production access:** Pipeline runs in isolated GitHub Actions runners; no access to production systems
- **Immutable audit trail:** All actions logged via GitHub Actions; artifacts version-controlled in git
- **Least-privilege execution:** Uses scoped GitHub tokens with minimal required permissions
- **Fail-safe design:** Contract gates enforce upstream validation; failures halt execution
- **Code review required:** All artifacts committed to a working branch and reviewed via PR before merge

**Governance Model:**
- Sequential stage execution with defined handoffs
- Artifact-based communication (no inter-agent messaging)
- Contract gates validate upstream work before downstream execution
- All prompts, workflows, and artifacts version-controlled and auditable
- No automated code deployment—assessment only

---

## Threat Model

### In-Scope Threats

| Threat | Mitigation | Status |
|--------|-----------|--------|
| **Unauthorized code execution in CI** | GitHub Actions permissions limited to `contents: write` and `pull-requests: write`; no deployment permissions | ✅ Mitigated |
| **Secrets exposure in artifacts** | Agents instructed to exclude secrets; stage 1 explicitly documents "do NOT include actual values or secrets" | ✅ Mitigated |
| **Malicious agent modification of unrelated code** | Each stage has declared output paths; contract gates validate only expected files are modified | ✅ Mitigated |
| **Supply chain compromise via dependencies** | Copilot CLI installed from official npm registry; .NET SDK and GitHub Actions from official sources; versions pinned in workflow | ✅ Mitigated |
| **Cascading hallucination failures** | Contract gates enforce fail-loud on missing inputs; agents abort if required data unavailable | ✅ Mitigated |
| **Unauthorized PR merge** | PR requires manual review; no auto-merge; branch protection rules apply per repo settings | ⚠️ Depends on repo configuration |

### Out-of-Scope Threats

- **Threats to production systems:** Pipeline does not interact with production
- **Threats from post-merge deployment:** Pipeline produces assessment artifacts only, no deployment
- **Insider threats with repo write access:** Standard GitHub access control applies
- **Compromise of GitHub infrastructure:** Relies on GitHub's security model

---

## Authentication and Authorization

### GitHub Token Usage

The pipeline uses **two distinct tokens** with minimal scoped permissions:

#### 1. `GITHUB_TOKEN` (Built-in Actions Token)
- **Scope:** `contents: write`, `pull-requests: write`
- **Usage:** Branch creation, commit/push artifacts, PR creation
- **Lifetime:** Scoped to single workflow run
- **Revocation:** Automatic at workflow completion
- **Audit:** All actions logged in GitHub audit log

#### 2. `COPILOT_GITHUB_TOKEN` (Fine-Grained PAT)
- **Scope:** `Copilot Requests: Read` (required for Copilot CLI API access)
- **Usage:** Copilot CLI authentication for agent invocations
- **Storage:** Repository secret (encrypted at rest)
- **Rotation:** Manually managed; recommend 90-day rotation
- **Audit:** Copilot API calls logged; token access logged via GitHub audit log
- **Validation:** Workflow includes preflight check; fails with clear error if token missing or invalid

**Why two tokens?**
The default `GITHUB_TOKEN` does not include Copilot API scope. A separate PAT with narrower scope provides least-privilege access to Copilot while maintaining isolation.

**Token Security Checklist:**
- ✅ Tokens stored as GitHub Secrets (encrypted at rest)
- ✅ Tokens scoped to minimum required permissions
- ✅ Workflow validates token presence before execution
- ✅ Token usage auditable via GitHub audit log
- ⚠️ Manual rotation required for `COPILOT_GITHUB_TOKEN` (recommend automation)

---

## Execution Environment

### Runner Isolation

- **Runner Type:** GitHub-hosted Ubuntu runners (`ubuntu-latest`)
- **Network Access:** Public internet only (no private network access)
- **Filesystem:** Ephemeral; destroyed after workflow completion
- **Resource Limits:** Per GitHub Actions standard limits (6 hours max runtime, 14 GB RAM)
- **Concurrency Control:** Single pipeline run at a time (`concurrency: modernize-pipeline, cancel-in-progress: false`)

### Installed Software

| Component | Source | Version Control | Purpose |
|-----------|--------|-----------------|---------|
| Node.js | GitHub Actions marketplace (`actions/setup-node@v4`) | Pinned to v22 | Copilot CLI runtime |
| .NET SDK | GitHub Actions marketplace (`actions/setup-dotnet@v4`) | Pinned to 7.0.x | Build and test characterization tests |
| Copilot CLI | npm registry (`@github/copilot`) | Latest (installed via `npm install -g`) | Agent execution |
| Git | Pre-installed on runner | GitHub-managed | Version control operations |

**Supply Chain Security:**
- GitHub Actions sourced from official `actions/*` repos
- npm packages installed from public npm registry (recommend: verify checksums in production)
- .NET SDK sourced from official Microsoft feeds

**Recommendations for Hardening:**
- Pin Copilot CLI version (`npm install -g @github/copilot@<version>`) instead of `latest`
- Use GitHub Actions dependency review to monitor action updates
- Enable Dependabot for automated dependency updates and vulnerability alerts

---

## Data Flow and Artifact Handling

### Stage-to-Stage Handoff

```
┌─────────────────┐
│   Stage 1       │
│   (Analysis)    │
│                 │
│   Reads: repo   │
│   Writes:       │
│   inventory.md  │
└────────┬────────┘
         │ git commit & push
         │
         ▼
┌─────────────────┐
│  Contract Gate  │◄── Validates inventory.md exists & has 6 sections
│  (Shell script) │
└────────┬────────┘
         │ (on success)
         ▼
┌─────────────────┐
│   Stage 2       │
│   (Tests)       │
│                 │
│   Reads:        │
│   inventory.md  │
│   Writes:       │
│   baseline.md   │
│   test project  │
└────────┬────────┘
         │ git commit & push
         │
         ▼
┌─────────────────┐
│  Contract Gate  │◄── Validates baseline.md & test files exist
│  (Shell script) │
└────────┬────────┘
         │ (on success)
         ▼
┌─────────────────┐
│   Stage 3       │
│   (Assessment)  │
│                 │
│   Reads:        │
│   inventory.md  │
│   baseline.md   │
│   Writes:       │
│   assessment.md │
└────────┬────────┘
         │ git commit & push
         ▼
┌─────────────────┐
│  Summary PR     │◄── Collects all artifacts, creates PR for review
└─────────────────┘
```

**Key Properties:**
1. **Agents do not communicate directly:** All handoffs via committed files
2. **Version-controlled artifacts:** All outputs in git; full history available
3. **Fail-loud on missing inputs:** Contract gates abort if upstream work incomplete
4. **Immutable after commit:** Once committed, artifacts cannot be silently modified (git history preserves all changes)

### Artifact Locations

All artifacts committed to a **working branch** (`modernize-run/<run-id>`):

```
docs/modernization/
├── stage-1/
│   └── inventory.md              (Stage 1 output)
├── stage-2/
│   └── baseline.md               (Stage 2 summary)
└── stage-3/
    └── assessment.md             (Stage 3 output)

tests/CharacterizationTests/      (Stage 2 output)
├── CharacterizationTests.csproj
└── **/*.cs
```

**Access Control:**
- Working branch created by GitHub Actions bot account
- All commits signed with `github-actions[bot]` identity
- PR requires manual review before merge to main
- Branch protection rules (if configured) apply to merge

---

## Auditability and Traceability

### Audit Trail Components

| Evidence | Location | Retention | Purpose |
|----------|----------|-----------|---------|
| **Workflow execution logs** | GitHub Actions run logs | 90 days (GitHub default) | Full execution trace, agent outputs, error messages |
| **Artifact files** | Git history on working branch | Permanent (until branch deleted) | Stage outputs, test code, assessment results |
| **Commits** | Git history | Permanent | Each stage produces exactly one commit with structured message |
| **Pull request** | GitHub PR | Permanent | Summary of run, links to artifacts, status of each stage |
| **GitHub audit log** | GitHub organization audit log | Per org retention policy | Token usage, PR creation, branch operations |

### Commit Structure

Each stage produces a commit with a structured message:

```
Stage 1: Documentation inventory [run #<run_id>]
Stage 2: Characterization tests [run #<run_id>]
Stage 3: Upgrade assessment [run #<run_id>]
```

**Traceability:**
- `<run_id>` links commit to GitHub Actions run (e.g., run #12345 → github.com/repo/actions/runs/12345)
- Branch name encodes run ID (`modernize-run/<run_id>`)
- PR title encodes run ID (`Modernization Pipeline Run #<run_id>`)

### Reconstruction Capability

A human auditor can reconstruct the full pipeline execution by:

1. **Finding the run:** Search GitHub Actions for run ID
2. **Reading logs:** View full agent execution logs, contract gate outputs, test results
3. **Inspecting artifacts:** Check out working branch, read markdown documents and test code
4. **Verifying integrity:** Compare commit timestamps, author identity, and file hashes

**Example Audit Query:**
```bash
# Given run ID 12345
gh run view 12345 --log                     # View logs
git fetch origin modernize-run/12345        # Fetch working branch
git log modernize-run/12345 --oneline       # View commits
git show modernize-run/12345:docs/modernization/stage-1/inventory.md  # Read artifact
```

---

## Contract Gates: Fail-Safe Validation

Contract gates are **security boundaries** that enforce upstream work quality before downstream execution.

### Stage 2 Gate (Validates Stage 1)

**Location:** `.github/workflows/modernize-pipeline.yml` (lines 153–193)

**Checks:**
1. File existence: `docs/modernization/stage-1/inventory.md` exists
2. Structural validation: File contains all six required section headings

**Failure Behavior:**
- Workflow job fails with `exit 1`
- Error message names specific missing section (e.g., `"CONTRACT GATE FAILED: Missing '## External I/O'"`)
- Stage 2 agent is **never invoked** (prevents cascading failures)
- Partial results (Stage 1 only) still produce a PR for debugging

**Security Property:**
Prevents Stage 2 from operating on incomplete or hallucinated inputs. If Stage 1's agent malfunctioned or was compromised, Stage 2 cannot proceed without explicit section validation.

### Stage 3 Gate (Validates Stage 2)

**Location:** `.github/workflows/modernize-pipeline.yml` (lines 287–339)

**Checks:**
1. Directory existence: `tests/CharacterizationTests/` exists with ≥1 `.cs` file
2. File existence: `docs/modernization/stage-2/baseline.md` exists
3. Structural validation: Baseline contains all four required section headings

**Failure Behavior:**
- Same as Stage 2 gate: fail loud, named error, Stage 3 never invoked

**Security Property:**
Ensures Stage 3 operates on validated test suite and documented baseline. Prevents assessment from proceeding if Stage 2 failed to lock in behavioral contracts.

### Gate Design Principles

1. **Downstream validates upstream:** Validation occurs at the **start** of the downstream job (not end of upstream)
2. **Deterministic checks:** Shell scripts + `grep` (no agent-based validation)
3. **Exact string matching:** Section headings must match prompts exactly (`grep -qF` or `grep -q "^section"`)
4. **Fail-safe default:** Any missing input causes immediate failure (no "best effort" execution)

**Governance Implication:**
If a prompt is modified to change section headings, the corresponding contract gate **must be updated in lockstep**. Mismatch detection is manual (recommend: CI check to validate prompt/gate alignment).

---

## Agent Constraints and Sandboxing

### Declared Output Paths

Each agent has a **narrowly scoped output path** defined in its prompt:

| Stage | Allowed Write Paths | Enforced By |
|-------|---------------------|-------------|
| Stage 1 | `docs/modernization/stage-1/inventory.md` | Agent prompt + git commit step validation |
| Stage 2 | `tests/CharacterizationTests/**`, `docs/modernization/stage-2/baseline.md` | Agent prompt + git commit step validation |
| Stage 3 | `docs/modernization/stage-3/assessment.md` | Agent prompt + git commit step validation |

**Enforcement Mechanism:**
1. **Agent prompts explicitly forbid writes outside declared paths** (e.g., "Do NOT modify any file except `inventory.md`")
2. **Git commit steps use scoped `git add`** (e.g., `git add docs/modernization/stage-1/`) — files outside path are not committed
3. **Commit validation fails if no files staged** — catches agents that didn't produce expected output

### Prohibited Actions (Per Agent Prompts)

All agent prompts **explicitly forbid** the following:

- ❌ Running `dotnet build`, `dotnet test`, `dotnet restore`, `dotnet run` (stages 1 and 3)
- ❌ Running `git add`, `git commit`, `git push` directly (workflow handles all git operations)
- ❌ Modifying source code under `src/` (all stages)
- ❌ Modifying solution files (`.sln`) (stage 2)
- ❌ Installing new dependencies not already in `Directory.Packages.props` (stage 2)
- ❌ Creating helper scripts or temporary files outside output paths (all stages)
- ❌ Accessing secrets or credentials (all stages)

**Rationale:**
Explicit constraints reduce attack surface. If an agent is compromised or malfunctioning, these rules limit blast radius.

### Stage 2 Special Case: Test Execution

Stage 2 **is allowed** to run `dotnet test` as part of its critical gate:

- **Why:** Tests must pass against the current codebase before commit (behavioral lock-in validation)
- **Scope:** Only `tests/CharacterizationTests/` (isolated test project)
- **Risk:** Test execution could theoretically execute malicious code in tests
- **Mitigation:** Tests use in-memory database (no external I/O); test project has no production dependencies; runner environment is ephemeral

---

## Pull Request Review Process

### Automated PR Creation

The `summary-pr` job (runs `if: always()` after all stages):

1. **Collects results:** Reads stage job statuses (`needs.stage-N.result`)
2. **Builds PR body:** Markdown table with stage results, artifact links, workflow run link
3. **Creates or updates PR:** From working branch to target branch (default: `main`)

**PR Template:**
```markdown
## 🤖 Automated Modernization Pipeline Run

Stage Results:
| Stage | Job | Result |
|-------|-----|--------|
| 1 | Documentation Inventory | ✅ success |
| 2 | Characterization Tests  | ✅ success |
| 3 | Upgrade Assessment      | ✅ success |

**3 of 3** stages completed successfully.

Artifact Files:
- [Stage 1 — Inventory](link)
- [Stage 2 — Baseline](link)
- [Stage 3 — Assessment](link)

[View workflow run](link)
```

### Human Review Requirements

**Pre-Merge Checklist (for reviewers):**

1. **Verify all stages succeeded** (check PR status table)
2. **Review Stage 1 inventory** — Does it accurately describe the repo? Any secrets exposed?
3. **Review Stage 2 tests** — Are tests black-box only? Do they lock in current behavior?
4. **Review Stage 3 assessment** — Is upgrade feasibility analysis reasonable? Any red flags?
5. **Check workflow logs** — Any unexpected agent behavior? Any error messages?
6. **Validate commit signatures** — All commits by `github-actions[bot]`?

**Approval Authority:**
Recommend: Require approval from both a platform engineer and a security reviewer before merge.

**Branch Protection (Recommended):**
- Require PR review before merge
- Require status checks to pass (if additional CI configured)
- Restrict push to `main` branch
- Require signed commits (GitHub Actions bot commits are signed by default)

---

## Failure Modes and Recovery

### Known Failure Scenarios

| Failure | Detection | Impact | Recovery |
|---------|-----------|--------|----------|
| **Stage 1 agent produces incomplete inventory** | Stage 2 contract gate fails with named error | Stage 2/3 skipped; partial PR created | Review Stage 1 logs; fix agent or retry |
| **Stage 2 tests fail against current codebase** | `dotnet test` step fails | Stage 3 skipped; partial PR created | Agent must fix test (not app); retry stage 2 |
| **Stage 3 agent timeout** | Copilot CLI exits with non-zero status | No assessment produced; partial PR created | Increase `--max-autopilot-continues` or retry |
| **COPILOT_GITHUB_TOKEN missing/invalid** | Preflight check fails before agent invocation | Workflow fails immediately; no artifacts | Configure token secret; retry |
| **Git push fails (permissions)** | Commit step fails | No artifacts on branch; PR not created | Check `contents: write` permission; retry |

### Graceful Degradation

- **Partial success is preserved:** If Stage 1 succeeds but Stage 2 fails, Stage 1's inventory is still committed and linked in the PR
- **No cleanup on failure:** Working branch remains for debugging (manual deletion required)
- **Idempotent re-runs:** Workflow can be re-triggered; creates a new working branch (no overwrites)

### Security Implications of Failures

- **Agent hallucination:** Contract gates catch incomplete outputs; downstream stages never see bad data
- **Compromised agent:** Scoped output paths limit blast radius; git history preserves evidence
- **Token compromise:** Short-lived `GITHUB_TOKEN`, scoped `COPILOT_GITHUB_TOKEN`, audit trail available

---

## Operational Security Recommendations

### For Initial Deployment

1. ✅ **Configure `COPILOT_GITHUB_TOKEN` secret**
   - Create fine-grained PAT with `Copilot Requests: Read` only
   - Set expiration (90 days recommended)
   - Store as repository secret (Settings → Secrets and variables → Actions)

2. ✅ **Enable branch protection on `main`**
   - Require PR review
   - Require status checks (if applicable)
   - Restrict direct pushes

3. ✅ **Test with a manual workflow_dispatch trigger**
   - Verify all stages complete
   - Review PR artifacts
   - Validate contract gates work (manually break Stage 1 output to test Stage 2 gate)

4. ⚠️ **Review GitHub audit logs after first run**
   - Confirm token usage is logged
   - Verify no unexpected API calls

### For Production Use

1. **Automate token rotation**
   - GitHub does not auto-rotate PATs; implement manual process or use GitHub App tokens (short-lived)

2. **Pin Copilot CLI version**
   - Change `npm install -g @github/copilot` to `npm install -g @github/copilot@<version>`
   - Validate updates in a test environment before production

3. **Add additional contract gates (optional)**
   - Validate artifact file sizes (detect accidental binary commits)
   - Scan artifacts for secrets (use GitHub Secret Scanning API)

4. **Monitor workflow runs**
   - Alert on failures (use GitHub Actions webhook or CODEOWNERS notifications)
   - Periodic audit of working branch cleanup (delete stale branches)

5. **Document deviations**
   - If prompts are modified, update contract gates in lockstep
   - Document all changes in `.squad/decisions.md`

### For Org-Wide Rollout

1. **Centralize workflow as reusable workflow**
   - Move `.github/workflows/modernize-pipeline.yml` to shared repo
   - Call from individual repos with `workflow_call`

2. **Implement org-level policy checks**
   - Use GitHub Actions policy enforcement (if available)
   - Add org-level secret scanning and code scanning

3. **Standardize token management**
   - Use GitHub App with installation tokens (preferred over PATs)
   - Centralize secret storage (GitHub organization secrets or Azure Key Vault)

---

## Compliance and Audit Evidence

### Evidence Artifacts (for auditors)

| Artifact | Location | Purpose |
|----------|----------|---------|
| **Workflow definition** | `.github/workflows/modernize-pipeline.yml` | What the pipeline does, how it's orchestrated |
| **Agent prompts** | `.github/prompts/stage-*.md` | What agents are instructed to do, constraints enforced |
| **Execution logs** | GitHub Actions run page | Full trace of what happened during execution |
| **Artifact files** | Working branch in git | What the agents produced |
| **Commits** | Git history | When and by whom each artifact was committed |
| **Pull request** | GitHub PR | Review and approval history |
| **Audit log entries** | GitHub organization audit log | Token usage, API calls, PR events |

### Common Audit Questions

**Q: How do you ensure agents don't modify unrelated code?**
A: (1) Agent prompts explicitly forbid it, (2) git commit steps use scoped `git add`, (3) git history shows all changes, (4) contract gates validate only expected files are present.

**Q: What prevents a malicious agent from exfiltrating secrets?**
A: (1) Runner has no access to production systems, (2) prompts instruct "do NOT include secrets", (3) Stage 1 prompt explicitly documents connection strings "do NOT include actual values", (4) artifacts are reviewable before merge.

**Q: How do you recover from a compromised agent?**
A: (1) Working branch is isolated (no impact on main), (2) git history preserves evidence, (3) PR review catches anomalies before merge, (4) workflow can be paused or disabled, (5) affected branch can be deleted.

**Q: What's the audit trail for a specific pipeline run?**
A: Given run ID `12345`: (1) View logs at `github.com/repo/actions/runs/12345`, (2) find working branch `modernize-run/12345`, (3) view commits and artifacts on that branch, (4) inspect PR for approval history, (5) query GitHub audit log for token usage.

---

## Risk Assessment Summary

### Residual Risks

| Risk | Severity | Likelihood | Mitigation Status |
|------|----------|------------|-------------------|
| **Agent hallucinates sensitive data into artifacts** | Medium | Low | Partial (agent prompts forbid; manual review required) |
| **Copilot CLI supply chain compromise** | High | Very Low | Partial (use official npm registry; recommend version pinning) |
| **Token compromise via secret leak** | High | Low | Mitigated (scoped tokens, audit trail, short TTL for built-in token) |
| **Reviewer merges malicious PR without inspection** | High | Low | Partial (branch protection, required reviews; recommend dual approval) |
| **Agent timeout allows incomplete work to commit** | Low | Medium | Mitigated (contract gates catch incomplete outputs) |

### Accepted Risks (for POC)

- **No automated secret scanning of artifacts:** Relies on manual review (recommend: add GitHub Secret Scanning integration)
- **No runtime sandboxing of agent process:** Copilot CLI runs in standard GitHub Actions runner (no additional containerization)
- **Manual token rotation:** `COPILOT_GITHUB_TOKEN` requires manual refresh every 90 days (recommend: automate via GitHub App)

### Risk Acceptance (for Production)

Before production deployment, recommend:
- [ ] Security team review of this document
- [ ] Test failure scenarios (contract gate validation, token expiry, agent timeout)
- [ ] Establish token rotation procedure
- [ ] Define escalation path for anomalous agent behavior
- [ ] Document approval authority for PR merges

---

## Summary

### Security Posture

✅ **Strengths:**
- Immutable audit trail via git and GitHub Actions
- Fail-loud contract gates prevent cascading failures
- Scoped permissions (least privilege)
- No production access
- Version-controlled prompts and workflow

⚠️ **Moderate Risks:**
- Manual token rotation required
- Relies on agent prompt adherence (not enforced by sandbox)
- Secret exposure depends on agent behavior + manual review

❌ **Gaps (for production):**
- Copilot CLI version not pinned (supply chain risk)
- No automated secret scanning of artifacts
- No automated testing of contract gates

### Governance Posture

✅ **Strengths:**
- Sequential execution with defined handoffs
- Artifact-based communication (no hidden state)
- All outputs reviewable via PR
- Prompts and workflow are version-controlled

⚠️ **Moderate Risks:**
- Prompt/gate alignment is manual (no CI enforcement)
- Working branch cleanup is manual
- Approval requirements depend on repo configuration

### Recommendation

**For POC / pilot use:** The current implementation is **acceptable** for controlled testing with manual review of all outputs.

**For production use:** Address gaps above (version pinning, automated secret scanning, contract gate testing) and obtain security team sign-off.

---

## Contact and Escalation

**For questions about this pipeline:**
- Review: `docs/prd.md`, `docs/modernization/README.md`, `AGENTS.md`
- Decision log: `.squad/decisions.md`

**For security concerns:**
- Contact: [Your Security Team]
- Escalation: [Your Incident Response Process]

**For operational issues:**
- GitHub Actions logs: Repository → Actions tab → Modernize Pipeline
- Workflow file: `.github/workflows/modernize-pipeline.yml`
- Agent prompts: `.github/prompts/stage-*.md`

---

**Document Status:** Ready for InfoSec Review
**Next Review:** After POC validation
**Version History:** 1.0 (initial)
