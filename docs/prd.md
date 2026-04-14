### Problem

Modernizing legacy .NET applications — documentation, test backfill, framework upgrade, containerization, deployment — is repetitive, expensive, and error-prone when done manually. AI coding agents can now do most of this work, but treating the whole modernization as a single agent prompt produces unpredictable results and is impossible to audit. We need a pattern that lets agents do the work while keeping the process deterministic, debuggable, and reviewable.

### Goal

Build a multi-stage agentic pipeline, running inside a single GitHub Actions workflow, that takes a legacy .NET repository through a fixed sequence of specialist agent stages and produces reviewable artifacts at every step. The pipeline must be boring to operate and obvious to debug.

### Non-goals

- Full end-to-end modernization in this iteration. We are proving the pattern, not finishing the journey.
- Director agents, dynamic stage selection, multi-agent orchestration frameworks, or message buses.
- Cross-repo matrix runs or fleet-scale dispatching.
- Any automated production deployment.

### Architecture principles

These are load-bearing and should not be compromised for convenience.

1. **Sequential jobs in one workflow.** Stages are GitHub Actions jobs chained with `needs:`. One workflow run = one full pipeline execution = one audit trail.
2. **Handoffs are files committed to the working branch.** Agents do not talk to each other. Stage N writes artifacts, commits them, and exits. Stage N+1 checks out the branch and reads them. The repo is the shared memory.
3. **Contract gates live at the start of the downstream job.** Before stage N+1 invokes its agent, a shell step verifies that stage N's artifacts exist and contain the structure stage N+1 depends on. If the contract fails, the job exits with a clear error naming the missing piece. Downstream-validates-upstream, so humans debugging a failed run see exactly where and why the chain broke.
4. **Fail loud on missing inputs.** An agent whose required input is missing must abort, not improvise. This is the single defense against cascading hallucination failures.
5. **Each agent has a narrow, declared scope.** A stage may only write to its declared output paths. A stage that wants to modify something outside its scope is a bug.
6. **Unattended by default.** The pipeline is designed to run without human intervention. Artifacts, PR descriptions, and logs are the audit record, not checkpoints for a human to approve mid-run.

### Scope for this iteration (stages 1–3)

The full pipeline will eventually cover: document → characterization test → upgrade → re-test → doc refresh → containerize → deploy. This iteration implements only the first three stages, and stage 3 stops at the upgrade *assessment* step — no source transformation yet. That is enough surface area to prove the handoff pattern works before investing in the rest.

**Stage 1 — Documentation.** An agent analyzes the repository and produces a durable inventory document covering projects and target frameworks, dependencies, external I/O, configuration surface, entry points, and upgrade risks. Analysis only, no code changes.

**Stage 2 — Characterization tests.** An agent reads the stage 1 inventory and generates black-box tests that lock in the application's current observable behavior, so post-upgrade regressions are detectable. Tests must pass against the current (pre-upgrade) codebase before the stage exits. A short baseline document describes what is locked in and what is explicitly not covered.

**Stage 3 — Upgrade assessment (stop here).** An agent invokes the `modernize-dotnet` custom agent and runs only its assessment phase against a target framework version, producing the assessment artifact in the repo. The stage does not proceed to planning or execution.

### Success criteria

- The workflow runs to completion on `workflow_dispatch` against a representative .NET repo with no human intervention during the run.
- Each stage produces its declared artifacts, committed to a working branch, visible in the workflow run log.
- Deliberately breaking a stage 1 artifact (deleting a required section) causes stage 2's contract gate to fail with a clear error message naming the missing piece, and the run stops cleanly.
- A final PR summarizes the run and links to every stage's artifacts.
- A human reading only the repo (workflow file, prompts, artifacts, PR) can reconstruct what happened without reading this PRD.

### Out of scope / deliberate omissions

- `modernize-dotnet` planning and execution phases (stage 3b/3c).
- Stages 4 through 7 (re-test, doc refresh, containerize, deploy).
- Custom skills, org-level policy enforcement, and reusable workflow packaging — all valuable, all later.
- Matrix runs across multiple repos.

### Open questions the implementer should resolve or ask about

- Target .NET version for the assessment stage (default to .NET 9 unless the repo suggests otherwise).
- Runner OS for the upgrade job (depends on whether source is .NET Framework or modern .NET).
- Test framework for stage 2 if the repo has no existing tests (default to xUnit).

---

## Part 2 — Bootstrap prompt

Paste this into the coding agent after committing the PRD to `docs/agentic-sdlc-prd.md`.

> Read `docs/agentic-sdlc-prd.md`. That document is the spec for what I want you to build.
>
> Scan the repo to understand what we're working with: .NET projects and their target frameworks, existing tests, existing `.github/` contents, and anything else relevant to the PRD's scope.
>
> Implement the iteration described in the PRD. You decide file layout, exact prompt wording, gate commands, and workflow structure — the PRD specifies principles and outcomes, not implementation details. Where the PRD leaves something open (target version, runner OS, test framework), use the defaults it lists unless the repo clearly indicates otherwise.
>
> Deliver the work as a draft PR on a new branch. The PR description should include: a summary of what you found when scanning the repo, every assumption you made where the repo or PRD was ambiguous, and instructions for running the pipeline end-to-end for the first time. If `AGENTS.md` or `copilot-instructions.md` already exist, append to them rather than overwriting. If any workflow or prompt filename would collide with an existing file, pick a non-colliding name and note it.
>
> If the PRD is ambiguous in a way the defaults don't resolve, ask before implementing rather than guessing.
