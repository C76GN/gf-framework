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
5. For any `.gd` edit, keep Godot reload warning clean while writing the code: do not generate `Variant as GFType` casts, direct `Variant` method calls, discarded return values, `Script.new()` on a `Script`-typed value, or constants/locals that shadow `class_name` values. Use explicit `is` checks, typed helper functions, `_result` variables, and `_SCRIPT` suffixes where needed. When editor-visible warnings are suspected but normal logs do not show them, run `python tools\gf_maintenance.py check --check gdscript_lsp_diagnostics --json` or scan touched files with `python tools\gdscript_lsp_diagnostics.py --spawn-lsp --file <path> --format json`.

## Decision Tree

- Runtime source changed under `addons/gf/**`: update focused `tests/gf_core/**`, `docs/zh/changelog.md`, relevant docs, generated API reference if public docs changed, and run the checks in [checks.md](references/checks.md).
- Public API changed: apply `API_SURFACE.md`, update `@api`, `@category`, `@since`, `@param`, `@return`, and `@schema`, regenerate API reference, and verify AI API summaries.
- Docs changed: keep handwritten docs in `docs/zh/**`; regenerate reference docs only with `tools/generate_api_reference.py`; run docs checks.
- Release metadata changed: use `$gf-release-flow`.
- External reference project changed or examples suite is involved: use `$gf-reference-boundary`.
- Broad refactor, layer move, or multi-module behavior change: use `$gf-change-audit`.
- GDScript warning fixes: prefer real type narrowing and ownership changes over `@warning_ignore`; after edits run focused GUT for the touched scripts plus `python tools\gf_maintenance.py check --check gdscript_warnings --json`. If the warning only appears in the Godot editor diagnostics panel or the touched code is warning-prone, also run `python tools\gf_maintenance.py check --check gdscript_lsp_diagnostics --json` or the focused `tools\gdscript_lsp_diagnostics.py --file` form. If the change touches shadowed names, GF class casts, or dynamic script instantiation, also run `tests/gf_core/maintenance/test_gdscript_parse_validation.gd`.
- Signature changes: search `addons/gf` and `tests/gf_core` for same-name `func` declarations, mocks, and reflective call sites before validating, because override signature drift is a Godot parse error.
- Editor-only plugin tests: do not instantiate editor-owned Godot plugin classes such as `EditorDebuggerPlugin` in plain headless GUT. Validate contributed records, script metadata, inheritance, and helper wiring unless the test runs through a real editor plugin lifecycle.

## Testing Style

Prefer tests that verify observable GF behavior through public or documented interfaces. Do not expose private helpers just to test them. For bug fixes, establish a failing behavior signal first, then implement the smallest fix that makes that signal pass. See [tdd-diagnose.md](references/tdd-diagnose.md) for the detailed loop.

## Boundaries

- Keep dependency direction stable: `addons/gf/kernel <- addons/gf/standard <- addons/gf/extensions`.
- Do not write reference-project business rules into `addons/gf`.
- Do not turn the external reference project's directory layout into a framework requirement.
- When reviewing external reference projects, exported plugin sources, or design notes, classify each idea before adopting it: stable GF mechanism, editor/tooling pattern, documentation reminder, third-party service adapter, or project business rule. Implement only the stable GF mechanism or clearly reusable tooling pattern.
- Do not change vendored `addons/gut/**` unless the task explicitly requires GUT maintenance.
- Use `apply_patch` for manual edits; avoid reverting user or other-session changes.
