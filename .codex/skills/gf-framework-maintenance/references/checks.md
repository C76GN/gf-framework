# GF Check Matrix

Start with `python tools\gf_maintenance.py workspace-status --json`. It categorizes dirty files and recommends checks. In a dirty long-running workspace, use repeated `--path <file>` arguments to get a check plan for the current turn's files instead of all historical local changes.

## Common Commands

```powershell
python tools\gf_maintenance.py check --suite quick --json
python tools\gf_maintenance.py check --suite framework-gut --json
python tools\gf_maintenance.py check --suite framework-lsp --json
python tools\gf_maintenance.py check --suite framework-static --json
python tools\gf_maintenance.py check --suite framework-integration --json
python tools\gf_maintenance.py check --suite full --json
python tools\gf_maintenance.py check --suite full --jobs 1 --json
python tools\gf_maintenance.py check --suite api --json
python tools\gf_maintenance.py check --check ai_developer_adapter_acceptance --json
python tools\gf_maintenance.py check --suite docs --json
python tools\gf_maintenance.py check --suite examples --json
python tools\gf_maintenance.py summary --json
python tools\gf_maintenance.py summary --release --artifact-manifest <manifest-path> --json
python tools\gf_maintenance.py workspace-status --path <file> --path <file> --json
python tools\gf_maintenance.py api-since-touched --json
python tools\gf_maintenance.py dependency-boundary --json
python tools\gf_maintenance.py public-docs-boundary --json
python tools\gf_maintenance.py public-api-boundary --json
python tools\gf_maintenance.py resource-boundary --json
python tools\gf_maintenance.py content-package-boundary --json
python tools\gf_maintenance.py asset-lifecycle-boundary --json
python tools\gf_maintenance.py project-profile-boundary --json
python tools\gf_maintenance.py package-boundary --json
python tools\gf_maintenance.py package-closure-audit --json
python tools\gf_maintenance.py package-source-boundary --json
python tools\gf_maintenance.py package-external-command-audit --json
python tools\gf_maintenance.py core-only-smoke --json
python tools\gf_maintenance.py package-focused-gut-mapping --json
python tools\gf_maintenance.py api-baseline-diff --json
python tools\gf_maintenance.py check --check gdscript_warnings --json
python tools\gf_maintenance.py check --check gdscript_lsp_diagnostics --json
python tools\gf_maintenance.py project-settings-drift --json
python tools\gf_maintenance.py log-hygiene --dry-run --json
python tools\gf_maintenance.py release-status --version <version> --artifact-manifest <manifest-path> --json
git diff --check
git diff --cached --check
```

## By Change Type

- `addons/gf/**`: run focused tests when possible, run `check --check gdscript_warnings` and the standalone LSP check for early warning diagnosis, then `check --suite full` before commit. Full and release suites always include the strict LSP error-and-warning gate.
- Public API comments or signatures: run `python tools\generate_api_reference.py`, `python tools\generate_api_reference.py --check`, and `check --suite api`.
- Public API source or generated reference changes: run `public-api-boundary`; quick/full/release suites include it. It prevents planning route names from becoming public `class_name`, Catalog, or generated reference entries.
- Broad public API changes, removals, return type changes, or class moves: run `api-baseline-diff`. It compares the current generated API Catalog against the latest lower SemVer tag and reports added/removed classes, added/removed members, compatible/breaking signature changes, and extends changes. `release-status` reuses it and fails breaking changes unless the target release is a major bump, or the maintainer explicitly approves and records a minor/patch compatibility break before running `release-status --allow-breaking-api`.
- Public API comments or signatures in a dirty worktree: run `api-since-touched`; quick/full/release suites include it. It checks changed `public` / `protected` API doc blocks without failing untouched historical migration debt.
- Generated API docs: do not hand-edit `docs/api_catalog/**` or `docs/zh/reference/api/**`; regenerate with `tools/generate_api_reference.py`. The generator stages Catalog and Reference together and replaces both only after successful validation; changes to this path require rollback/escape-root self-tests.
- AI Developer Kit source, catalogs, schemas, Adapter templates, or builder changes: run `check --check ai_developer_kit` for pure Python behavior and `check --check ai_developer_adapter_acceptance` for the isolated Godot-backed executable contract. The pure behavior check belongs to the focused API and `framework-static` suites; the executable acceptance belongs to `framework-integration` and must not enter Draft or `framework-static`.
- Handwritten docs: run `check --suite docs`; use `public-docs-boundary` when docs mention optional extension defaults, editor workspace pages, AI maintenance paths, external research notes, full-framework installation, or retired Package Manager/registry/module-download paths.
- Layer, extension dependency, manifest, preset, or contribution-boundary changes: run `dependency-boundary`, the full suite, and the specific maintenance tests for layer boundary and GDScript parse validation when relevant.
- Resource loading, resolver, cache, owner handle, or scene/UI async loading changes: run `resource-boundary` and `asset-lifecycle-boundary`; `resource-boundary` is report-only by default and lists direct `preload()` / `load()` / `ResourceLoader.*` path literals before strict resource-domain gates are enabled, while `asset-lifecycle-boundary` reports GFAssetHandle acquisitions that lack both owner and group anchors.
- Content package manifest, package dependency, resource-domain, or project profile changes: run `content-package-boundary`; quick/full/release suites include it. It scans tracked and untracked `gf_content_package.json` files and fails invalid JSON, unsupported package policy fields, missing/duplicate package IDs, missing/cyclic dependencies, and resources outside their package root.
- Internal `packages/**/*.json` module ownership, dependency graph, or source-boundary changes: run `package-boundary`, `package-closure-audit`, and `package-source-boundary`; quick/full/release suites include them. These manifests describe repository layering only. They must not regain version, preset, archive, registry, lockfile, installer, download, or per-module release semantics.
- Internal module-owned runtime/editor source adding `OS.execute`, `OS.create_process`, `OS.shell_open`, or another external command dependency: run `package-external-command-audit`; quick/full/release suites run it with `--fail-on-warnings`. Direct command runs remain report-only for investigation, and strict suite runs allow only declared editor-jump exceptions.
- Root plugin entry or standard/editor contribution loading changes: run `core-only-smoke`; quick/full/release suites include it. It verifies parse-time layering, not a separately installable core distribution.
- Internal module ownership or focused GUT ownership changes: run `package-focused-gut-mapping`; quick/full/release suites include it. The mapping is maintenance policy only and does not prove a module can be installed or released separately.
- Project layout/profile changes: run `project-profile-boundary`; quick/full/release suites include it. Profiles are optional and project-owned, so GF provides the validator but does not require a fixed directory layout.
- Reference project changes: use `$gf-reference-boundary`.
- Release metadata: use `$gf-release-flow`; build the immutable artifact set once, validate it with `release-status --artifact-manifest`, and keep tag CI set-equivalent to the release suite.

## Notes

`check --suite examples` is read-only unless `--sync-examples` is passed. Do not write-sync the external reference project by accident.

`check --suite quick` is the sub-30-second development loop and deliberately excludes `maintenance-self-test`. When maintenance Python, CI, release workflow, or this check matrix changes, run `maintenance-self-test` explicitly; `framework` and `full` also retain it.

`check --check gdscript_warnings` opens the project editor headlessly and fails on GDScript reload warnings. It is meant to catch typed-Variant, unnecessary-await, and shadowing warnings that regular GUT runs can miss.

All maintenance-owned Godot commands resolve through `tools/gf_godot_process.py` and run under the shared process supervisor. On Windows this bypasses the detached Steam `godot.exe` launcher when its foreground tools executable is available. Set `GF_GODOT_EXECUTABLE` only when an explicit executable override is required.

`check --check gdscript_lsp_diagnostics` imports the project, then connects to the active editor LSP or spawns a temporary headless LSP when none is available. The full and release suites, Ready/main's `framework-lsp` shard, and the release framework shard run it unconditionally and fail on errors, warnings, diagnostic timeouts, connection failures, or transport failures.

`check --suite full` defaults to three isolated workers; explicit `--jobs 2` through `--jobs 6` tune the bounded parallelism. Workspaces are materialized, run, validated, and cleaned with their private OS roots in batches no larger than `jobs`. Before shards start, two real same-name Godot probe projects must prove that platform data/config/cache paths and `user://` stay inside separate private roots; unsupported or self-contained layouts fail closed. On Windows, clone, materialization staging, and private temporary paths must also fit the projected short-path budget. If the automatic local root is unavailable, `GF_MAINTENANCE_VALIDATION_TEMP_ROOT` may point to an existing short local fixed-volume parent; the runner validates its direct volume identity and creates a random identity-pinned child, while relative, missing, source-owned, linked/reparse, UNC, device, mapped, and substituted roots are rejected. Untracked regular files are captured from stable handles in deadline-aware 1 MiB chunks, with hard limits of 64 MiB per file and 256 MiB in total. The absolute suite deadline covers capture, the probe, shard execution, and final revalidation. Each shard runs inside a retained POSIX process group or Windows Job Object that is force-cleared before the report is trusted. The parent also rejects duplicate/non-finite JSON, oversized or unexpected report fields, workspace escapes, linked/replaced report or log directory chains, schema drift, shard-coverage mismatches, source-fingerprint changes, unowned failure logs. Use `--jobs 1` only to diagnose concurrency, resource contention, or order-sensitive failures; it preserves the complete check set and does not weaken the LSP gate.

Ready PRs and `main` runs are the only events allowed to emit the exact `GF repository policy` and `GF merge gate` required contexts. A manual run on another ref uses a non-required policy name and skips the Full-equivalent matrices, so it cannot substitute for PR validation.

Outer workflow deadlines are governed evidence boundaries. Ready/main and tag release use the same exact per-shard limits: `framework-gut` 60 minutes, `framework-lsp` 15 minutes, `framework-static` 20 minutes, and `framework-integration` 30 minutes; manual `main` Full remains exactly 90 minutes. The GUT job stays above its current 2,820-second closed envelope (600 seconds import + 360 lifecycle + 1,200 authoritative GUT + 600 warnings + 60 child-process envelope). Every shard must retain a maintenance-owned inner deadline and leave time for setup, teardown, and structured timeout cleanup so GitHub does not terminate the job before the maintenance tool can publish bounded failure evidence.

`project-settings-drift` fails when `project.godot` has staged or unstaged local changes. Use it after tests or headless editor checks when `ProjectSettings` writes may have leaked transient test state into the project file. Do not use it to block intentional project metadata edits; instead, review and commit those edits deliberately.

Use `@since unreleased` only for newly added public API whose release version is not final yet. `release-status --version <tag>` fails until every `@since` marker is a SemVer and no marker is newer than the release tag.

Use `api-baseline-diff --version <version> --enforce-version` before version decisions when the API surface changed substantially. Added classes are reported for release review. Removed classes, removed members, breaking or unknown signature changes, and extends changes are treated as breaking. Compatible signature changes such as adding defaulted tail parameters, widening parameter types to `Variant` or untyped, and appending enum values remain visible but do not force a major version bump.

`path-hygiene` scans both tracked files and untracked, non-ignored files. New files must not rely on `git diff --check` alone; `git diff --check` does not inspect untracked paths. It also checks that local workflow actions referenced as `./.github/actions/...` have an `action.yml`, and that GF-owned GDScript under `addons/gf` and `tests/gf_core` is strict UTF-8 without BOM, LF-only, final-newline terminated, and tab-indented outside multiline strings.

`api-since-touched` scans modified `addons/gf/**/*.gd` files. Untracked files are checked fully; tracked files are checked only where the current diff touches a `public` / `protected` API documentation block or its bound declaration. This keeps new API strict without turning historical untouched migration debt into a release blocker.

`dependency-boundary` statically scans bundled extension manifests, framework project defaults, and GF source boundaries. It fails on unsupported manifest fields, optional/soft dependency fields, default-enabled bundled extensions, non-empty `project.godot` `gf/extensions/enabled`, `kernel` or `standard` references to optional extension paths, IDs or classes, and cross-extension references inside bundled extensions.

`public-docs-boundary` scans public README, Asset Store text, Wiki entry pages, and handwritten `docs/zh` pages except generated API reference. It fails on AI-only maintenance paths, external research notes, planning track names, claims that optional extension pages or tools are fixed core workspace/editor features, wording that makes Python/npm/npx/Git/Node/pip a prerequisite for full-framework installation or local extension enablement, and current-product claims for the retired Package Manager, registry, offline bundle, or per-module downloads.

`public-api-boundary` scans `addons/gf` source, API Catalog, and generated API Reference. It fails if internal planning route names appear as public API names or generated reference entries.

`resource-boundary` scans tracked and untracked, non-ignored `.gd` files outside vendored/local caches. It reports direct resource load literals and classifies script dependency loads as info, while `res://` / `uid://` runtime resource loads are warning-level debt. The command does not fail by default; use `--fail-on-issues` only after a project or release gate has an explicit allowlist/baseline.

`content-package-boundary` scans tracked and untracked, non-ignored `gf_content_package.json` manifests. It enforces the framework-level package contract: manifest and resource entry fields are whitelisted, package dependencies must resolve without cycles, and resource paths must stay inside the package root. It deliberately rejects installer/download/package-manager fields; those belong in project installers or external plugins, not GF content package manifests.

`asset-lifecycle-boundary` scans tracked and untracked runtime `.gd` files outside tests, vendored addons, and local caches. It reports `acquire_handle()`, `load_handle_async()`, and `request_entry_handle_async()` calls that omit both owner and group, because those handles depend on manual release and are common sources of long-lived cache pins. The command is report-only by default; use `--fail-on-warnings` only after a zero baseline is stable.

`project-profile-boundary` looks for `gf_project_profile.json`, `.gf/project_profile.json`, or `project_profile.json`, unless `--profile <path>` is passed. No profile means the check passes. The profile schema supports optional `zones` and `rules` with per-rule severity, roots, include/exclude globs, extension allow/deny lists, path existence checks, naming conventions, feature module contracts, generated-file boundaries, and bucket-size limits. This keeps GF flexible: projects opt into their own structure without turning any one layout into a framework requirement.

`package-boundary` scans tracked and untracked, non-ignored `packages/**/*.json` manifests. These files are internal module descriptors, despite the retained command and directory name. Their closed schema contains only module identity, kind, dependencies, owned paths, optional excluded paths, and an optional bundled-extension ID. Version, preset, archive, checksum, registry, lockfile, installer, download, and release metadata are rejected. Dependency edges follow `kernel <- standard <- extension`, tool modules mount one-way, and owned paths do not overlap.

`package-closure-audit` computes internal module dependency closures, per-kind counts, source payload, and standard fan-in directly from `packages/**/*.json`. Warnings expose oversized extension closures and debug/UI layering debt. Runtime extension closures that include `gf.standard.editor` are errors. The result is not an install plan or a claim that any module is separately distributable.

`package-source-boundary` scans all tracked and untracked framework files under `addons/gf` and requires one internal module owner even for Markdown, images, and other non-source payloads; Godot-generated `.import` sidecars are the explicit exception. It resolves `addons/gf` path literals and GDScript `class_name` references to owners and fails undeclared direct dependencies. The retained package terminology is internal and must not leak into user installation guidance.

`package-external-command-audit` scans internal-module-owned `.gd` files under `addons/gf` and reports `OS.execute`, `OS.create_process`, and `OS.shell_open` calls by module id, API, command literal, and severity. Direct command runs are report-only by default for investigation. Quick, full, and release suites pass `--fail-on-warnings`, so newly introduced calls fail unless they match an explicit editor-jump allowlist entry.

`core-only-smoke` checks the root plugin entry for parse-time standard dependencies. It allows optional path-based discovery of standard editor contributions, but rejects direct `preload("res://addons/gf/standard/...")`, direct standard `load()` literals, and references to standard `class_name` values from `addons/gf/plugin.gd`. This is a layering check, not a core-only distribution test.

`package-focused-gut-mapping` validates `tests/gf_core/package_focused_gut_mapping.json` against the internal module descriptors. Every module must map to at least one focused GUT script. Test paths must exist, stay under `res://tests/gf_core/`, and match the module's test scope, with a narrow exception for `gf.standard.editor` integration coverage under `res://tests/gf_core/kernel/editor/`.

Ordinary checks retain the generic 600-second default, while the unfiltered authoritative `gut` check has a dedicated 1200-second policy floor. `check --timeout N` raises the minimum per-check budget but cannot shorten a dedicated policy. Use `--suite-timeout N` only for an intentional overall deadline.

GUT output is not allowed to mask Godot script errors or reload warnings. If Godot reports `SCRIPT ERROR`, parse errors, or GDScript reload warnings, the maintenance check fails even when the GUT summary says all tests passed.

Godot ObjectDB, resource still in use, and RID allocation leak warnings are recorded in check output as cleanup debt. They are not CI-failing yet; after the leak baseline is cleaned, promote them to hard fail. Successful maintenance commands remove only logs created or rewritten by that invocation; failed or interrupted invocations and unrelated historical evidence are retained. `ai_analysis/godot_logs/` is the only repository-local diagnostic log root. Historical retention and legacy top-level `.gf/*.log` cleanup occur only through an explicit `log-hygiene` command. For verbose log triage, produce the source log with `--keep-logs` (or `GF_MAINTENANCE_KEEP_LOGS=1`), then run `python tools\gf_maintenance.py godot-exit-leak-report --log <stdout.log> --log <stderr.log> --json`; use `--fail-on-leaks` only when the baseline is ready to become a gate. Inspect `log-hygiene --dry-run --json` first and delete only current-task evidence; reserve `log-hygiene --all --json` for explicit workspace-wide cleanup after confirming no concurrent task owns candidates.

The GitHub Ready PR / push CI must stay set-equivalent to `check --suite full`; its required shards are `framework-gut`, `framework-lsp`, `framework-static`, and `framework-integration`. A focused `windows-process-supervision` job also runs `maintenance-self-test` plus the process-supervisor staging/startup modules on `windows-latest`, and must feed the merge gate so native Job Object cleanup remains covered. Branch protection requires both `GF repository policy` and the aggregate `GF merge gate`, so a title/body-only metadata edit can rerun policy without cancelling validation already running for the same source SHA while still failing closed. Draft PRs instead use repository policy plus the pure-Python quick suite behind an independent `GF draft gate`; changing the PR base reruns the applicable Draft or Ready gate. Release uses the same four framework shards, builds exactly the complete framework ZIP, standalone AI Developer Kit ZIP, and release manifest once, validates those bytes with `release-status --artifact-manifest`, and publishes them only after every required job succeeds. If CI must be weakened temporarily, record the reason before merging.
