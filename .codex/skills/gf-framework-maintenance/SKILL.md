---
name: gf-framework-maintenance
description: Maintain GF Framework source, docs, tests, API surface, generated references, and maintenance tooling. Use when Codex modifies addons/gf, tests/gf_core, docs/zh, API docs, tools, AI maintenance policy, or needs to choose GF-specific validation commands.
---

# GF Framework Maintenance

Use this skill as the default project workflow for GF Framework maintenance. It does not replace `AI_MAINTENANCE.md`, `CODING_STYLE.md`, or `API_SURFACE.md`; those files remain the authority.

## Start

1. Read `AI_MAINTENANCE.md` first. Read `CODING_STYLE.md` before editing `.gd` files. Read `API_SURFACE.md` before changing public API, API comments, section layout, or generated API docs.
2. Run `python tools\gf_maintenance.py workspace-status --json` to classify current changes before choosing checks. If ordinary work starts from a clean synchronized `main`, create a short-lived branch that satisfies `.github/repository-policy.json` before editing. Preserve an existing user branch or dirty worktree; never move unrelated work just to satisfy this default. In a dirty long-running workspace, pass repeated `--path <file>` arguments for the current turn's touched files before using the global recommendation list.
3. Use lightweight `python tools\gf_maintenance.py summary` or the API commands (`api-search`, `api-class`, `api-module`) to gather context before scanning broad source trees. Use `summary --release --artifact-manifest <path>` only after the immutable release artifact set exists.
4. Keep `ai_analysis/` ignored and out of commits. Write diagnostic logs only under `ai_analysis/godot_logs/`, never as `.gf/*.log` or beside source files. Do not submit temporary reports, generated AI API summaries, local logs, or session notes. Successful maintenance commands remove only logs created or rewritten by that invocation; failed runs and unrelated historical evidence are never pruned as a side effect. Use `--keep-logs` only while invocation evidence is still needed. Save machine-readable CLI results with `--json-output build/<name>.json`; do not use Windows PowerShell's default redirection because it rewrites native stdout as UTF-16. Before deleting retained evidence, run `log-hygiene --dry-run --json`, confirm every candidate belongs to the current task, then use bounded `log-hygiene --json`. Use `log-hygiene --all --json` only when the user explicitly authorizes workspace-wide cleanup and no concurrent task owns evidence.
5. For any `.gd` edit, keep Godot reload warning clean while writing the code: do not generate `Variant as GFType` casts, direct `Variant` method calls, discarded return values, `Script.new()` on a `Script`-typed value, or constants/locals that shadow `class_name` values. Use explicit `is` checks, typed helper functions, `_result` variables, and `_SCRIPT` suffixes where needed. Run `python tools\gf_maintenance.py check --check gdscript_lsp_diagnostics --json` early when editor diagnostics help localize a warning; this Catalog action always owns an isolated LSP on a dynamic port, independently of any user editor. `check --suite full`, Ready/main's `framework-lsp` shard, and the release framework shard run that same strict ownership, cleanup, error, warning and transport gate. For manual focused scans, `python tools\gdscript_lsp_diagnostics.py --file <path> --format json` can connect to the active editor, but this is non-authoritative diagnostic evidence and cannot replace the owned gate. Never terminate unrelated Godot processes as LSP cleanup.

## Decision Tree

- Runtime source changed under `addons/gf/**`: update focused `tests/gf_core/**`, `docs/zh/changelog.md`, relevant docs, generated API reference if public docs changed, and run the checks in [checks.md](references/checks.md).
- Public API changed: apply `API_SURFACE.md`, update `@api`, `@category`, `@since`, `@param`, `@return`, and `@schema`, regenerate API reference, and verify AI API summaries.
- Docs changed: keep handwritten docs in `docs/zh/**`; regenerate reference docs only with `tools/generate_api_reference.py`; run docs checks.
- Generator or generated-tree logic changed: keep generated output roots fail-closed, stage and validate every related tree before replacing any of them, and test rollback behavior. `generate_ai_api.py` may write outside `ai_analysis/generated_api` only with the explicit unsafe-output flag.
- Maintenance runner or CI topology changed: run `maintenance-self-test` and follow the execution and CI contracts in [核心规则](../../../AI_MAINTENANCE.md#核心规则). That authority defines Full isolation and admission ordering, budgets, process cleanup, required-check eligibility and workflow deadlines. Use [checks.md](references/checks.md) to choose the relevant commands.
- Release metadata changed: use `$gf-release-flow`.
- Broad refactor, layer move, or multi-module behavior change: use `$gf-change-audit`.
- GDScript warning fixes: prefer real type narrowing and ownership changes over `@warning_ignore`; after edits run focused GUT for the touched scripts plus `python tools\gf_maintenance.py check --check gdscript_warnings --json`. Use `python tools\gf_maintenance.py check --check gdscript_lsp_diagnostics --json` or the focused `tools/gdscript_lsp_diagnostics.py --file` form for early diagnosis; the final full/release suite must also pass its unconditional LSP hard gate. If the change touches shadowed names, GF class casts, or dynamic script instantiation, also run `tests/gf_core/maintenance/test_gdscript_parse_validation.gd`.
- Project settings drift: if GUT, editor reload checks, or plugin tests appear to modify `project.godot`, run `python tools\gf_maintenance.py project-settings-drift --json` and fix the leaking test or plugin state instead of committing transient settings.
- Signature changes: search `addons/gf` and `tests/gf_core` for same-name `func` declarations, mocks, and reflective call sites before validating, because override signature drift is a Godot parse error.
- Editor-only plugin tests: do not instantiate editor-owned Godot plugin classes such as `EditorDebuggerPlugin` in plain headless GUT. Validate contributed records, script metadata, inheritance, and helper wiring unless the test runs through a real editor plugin lifecycle.
- Godot command wrappers: delete configured stale log files before launch, merge the newly written log into the result, fail when the log is missing or unreadable, and require a non-empty GUT pass summary even when the process exits with code 0. Let the maintenance CLI delete successful session logs; use `--keep-logs` or `GF_MAINTENANCE_KEEP_LOGS=1` only for follow-up diagnostics, then explicitly clean them.

## Product-Ready Delivery

Apply [产品化交付](../../../AI_MAINTENANCE.md#产品化交付) while implementing and before handing off. Translate accepted choices into stable domain terms and self-contained contracts across code comments, configuration, UI, tests, examples, docs, generated references, changelog and the final response. Review the complete current change, including untracked files, as a developer who has not read the conversation. Resolve discussion-only labels and references semantically; a keyword scan alone is not acceptance. Regenerate affected documentation after source-comment edits. Keep actual capability limits explicit and stay within the authorized scope.

## Testing Style

Prefer tests that verify observable GF behavior through public or documented interfaces. Do not expose private helpers just to test them. For bug fixes, establish a failing behavior signal first, then implement the smallest fix that makes that signal pass. See [tdd-diagnose.md](references/tdd-diagnose.md) for the detailed loop.

## Boundaries

- Keep dependency direction stable: `addons/gf/kernel <- addons/gf/standard <- addons/gf/extensions`.
- Keep project business rules and layout outside `addons/gf`; document concise usage in the relevant guide and validate reusable mechanisms with framework regression tests.
- The external Reference project and sync workflow are retired; do not restore or synchronize them.
- When reviewing exported plugin sources or design notes, classify each idea before adopting it: stable GF mechanism, editor/tooling pattern, documentation reminder, third-party service adapter, or project business rule. Implement only the stable GF mechanism or clearly reusable tooling pattern.
- Do not change vendored `addons/gut/**` unless the task explicitly requires GUT maintenance.
- Use `apply_patch` for manual edits; avoid reverting user or other-session changes.
