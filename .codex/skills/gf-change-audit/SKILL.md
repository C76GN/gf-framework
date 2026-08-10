---
name: gf-change-audit
description: Split large GF Framework changes into focused review tracks before commit, release, or risky integration. Use after broad refactors, API changes, layer moves, extension restructuring, reference-project migration work, or when the user asks for multi-agent audit.
---

# GF Change Audit

Use this skill to review large GF changes without mixing concerns. When sub-agents are available, run independent read-only tracks in parallel; otherwise run the same tracks sequentially.

## Prepare

1. Pin the review scope:
   - For committed work, ask or infer a base and use `git diff <base>...HEAD`.
   - For dirty work, inspect `git status --short --branch`, `git diff --name-status`, and staged diff if present.
2. List touched files and classify them with `python tools\gf_maintenance.py workspace-status --json`.
3. Identify the user's task intent, acceptance criteria, and explicit out-of-scope boundaries. If no spec exists, audit only against repository rules and stated conversation intent.
4. Freeze an audit input manifest before dispatch. Record the exact base and HEAD, porcelain status bytes, SHA-256 of staged and unstaged binary diffs, and SHA-256 plus file identity for every touched or untracked regular file and every policy file used by the review. For a dirty scope, materialize those bytes into an ignored, read-only snapshot and give tracks that snapshot plus the manifest; tracks must not reread mutable workspace paths as evidence.

## Parallel Tracks

Use the prompts and output format in [review-axes.md](references/review-axes.md). Keep each track bounded and independent:

- Standards: `AI_MAINTENANCE.md`, `CODING_STYLE.md`, `API_SURFACE.md`, layer boundaries, generated-doc rules, release rules.
- API and compatibility: public API surface, `@since`, schema docs, SemVer, deprecated/removed behavior, generated reference drift.
- Verification: tests, docs checks, examples checks, release checks, skipped commands, and whether failures were expected.
- Reference boundary: external `gf-reference-project`, sync behavior, smoke paths, framework feedback, and project-business leakage.
- Architecture: module depth, locality, dependency direction, extension atomicity, and whether a new seam earns its interface cost.

## Aggregate

Report blocking findings first, then warnings, then clean tracks. Cite local file paths and commands for concrete review findings. Do not merge away disagreement between tracks; preserve it as an explicit open question.

Before accepting track results, recompute the audit input manifest. If any identity or digest changed, mark every affected result stale, do not describe it as a review of the current worktree, and rerun only after freezing a new snapshot. A final live diff recheck is still required, but it cannot substitute for immutable track inputs.

When a track finds a deterministic rule that is not automated yet, recommend whether it belongs in `tests/gf_core/maintenance`, `tools/gf_maintenance.py`, or `AI_MAINTENANCE.md`.
