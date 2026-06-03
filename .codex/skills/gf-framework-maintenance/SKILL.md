---
name: gf-framework-maintenance
description: Maintain GF Framework source, docs, tests, API surface, generated references, and maintenance tooling. Use when Codex modifies addons/gf, tests/gf_core, docs/zh, API docs, tools, AI maintenance policy, or needs to choose GF-specific validation commands.
---

# GF Framework Maintenance

Use this skill as the default project workflow for GF Framework maintenance. It does not replace `AI_MAINTENANCE.md`, `CODING_STYLE.md`, or `API_SURFACE.md`; those files remain the authority.

## Start

1. Read `AI_MAINTENANCE.md` first. Read `CODING_STYLE.md` before editing `.gd` files. Read `API_SURFACE.md` before changing public API, API comments, section layout, or generated API docs.
2. Run `python tools\gf_maintenance.py workspace-status --json` to classify current changes before choosing checks.
3. Use `python tools\gf_maintenance.py summary` or the API commands (`api-search`, `api-class`, `api-module`) to gather context before scanning broad source trees.
4. Keep `ai_analysis/` ignored and out of commits. Do not submit temporary reports, generated AI API summaries, local logs, or session notes.

## Decision Tree

- Runtime source changed under `addons/gf/**`: update focused `tests/gf_core/**`, `docs/zh/changelog.md`, relevant docs, generated API reference if public docs changed, and run the checks in [checks.md](references/checks.md).
- Public API changed: apply `API_SURFACE.md`, update `@api`, `@category`, `@since`, `@param`, `@return`, and `@schema`, regenerate API reference, and verify AI API summaries.
- Docs changed: keep handwritten docs in `docs/zh/**`; regenerate reference docs only with `tools/generate_api_reference.py`; run docs checks.
- Release metadata changed: use `$gf-release-flow`.
- External reference project changed or examples suite is involved: use `$gf-reference-boundary`.
- Broad refactor, layer move, or multi-module behavior change: use `$gf-change-audit`.

## Testing Style

Prefer tests that verify observable GF behavior through public or documented interfaces. Do not expose private helpers just to test them. For bug fixes, establish a failing behavior signal first, then implement the smallest fix that makes that signal pass. See [tdd-diagnose.md](references/tdd-diagnose.md) for the detailed loop.

## Boundaries

- Keep dependency direction stable: `addons/gf/kernel <- addons/gf/standard <- addons/gf/extensions`.
- Do not write reference-project business rules into `addons/gf`.
- Do not turn the external reference project's directory layout into a framework requirement.
- When reviewing external reference projects, exported plugin sources, or design notes, classify each idea before adopting it: stable GF mechanism, editor/tooling pattern, documentation reminder, third-party service adapter, or project business rule. Implement only the stable GF mechanism or clearly reusable tooling pattern.
- Do not change vendored `addons/gut/**` unless the task explicitly requires GUT maintenance.
- Use `apply_patch` for manual edits; avoid reverting user or other-session changes.
