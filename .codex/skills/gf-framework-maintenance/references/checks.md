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
python tools\gf_maintenance.py diagnostic-policy --json
python tests\gf_core\tools\test_gf_diagnostic_policy.py
python tools\gf_maintenance.py gdscript-readability --json
python -m unittest discover -s tests/gf_core/tools -p "test_gf_gdscript*.py"
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
- Native developer diagnostics or their producers: run `diagnostic-policy --json` and focused behavior tests. Preserve native severity, output count, call stacks, stable IDs and essential context assertions. Changes to the checker also require `python tests\gf_core\tools\test_gf_diagnostic_policy.py`; `diagnostic_policy` and `diagnostic_policy_tests` run automatically in quick, framework-static, full and release.
- Public API comments or signatures: run `python tools\generate_api_reference.py`, `python tools\generate_api_reference.py --check`, and `check --suite api`.
- Public API source or generated reference changes: run `public-api-boundary`; quick/full/release suites include it. It prevents planning route names from becoming public `class_name`, Catalog, or generated reference entries.
- Broad public API changes, removals, return type changes, or class moves: run `api-baseline-diff`. It compares the current generated API Catalog against the latest eligible lower SemVer tag and reports added/removed classes, added/removed members, compatible/breaking signature and schema changes, and extends changes. `release-status` reuses it; real stable-contract breaks require a major version. `--allow-breaking-api` is only for an evidenced baseline false positive or a historical surface explicitly excluded from the stable contract, documented in release notes. It cannot permit a real minor/patch compatibility break or waive the minor floor for compatible public additions.
- Public API comments or signatures in a dirty worktree: run `api-since-touched`; quick/full/release suites include it. It checks changed `public` / `protected` API doc blocks without failing untouched historical migration debt.
- Generated API docs: do not hand-edit `docs/api_catalog/**` or `docs/zh/reference/api/**`; regenerate with `tools/generate_api_reference.py`. The generator stages Catalog and Reference together and replaces both only after successful validation; changes to this path require rollback/escape-root self-tests.
- AI Developer Kit source, catalogs, schemas, Adapter templates, or builder changes: run `check --check ai_developer_kit` for pure Python behavior and `check --check ai_developer_adapter_acceptance` for the isolated Godot-backed executable contract. The pure behavior check belongs to the focused API and `framework-static` suites; the executable acceptance belongs to `framework-integration` and must not enter Draft or `framework-static`.
- Handwritten docs: run `check --suite docs`; use `public-docs-boundary` when docs mention optional extension defaults, editor workspace pages, AI maintenance paths, external research notes, full-framework installation, or retired Package Manager/registry/module-download paths.
- Layer, extension dependency, manifest, preset, or contribution-boundary changes: run `dependency-boundary`, the full suite, and the specific maintenance tests for layer boundary and GDScript parse validation when relevant.
- Resource loading, resolver, cache, owner handle, or scene/UI async loading changes: run `resource-boundary` and `asset-lifecycle-boundary`. The standalone `resource-boundary` command is report-only by default; Catalog suites pass `--fail-on-issues` and reject actionable resource loads while retaining script-dependency observations. `asset-lifecycle-boundary` remains report-only and lists GFAssetHandle acquisitions that lack both owner and group anchors.
- Content package manifest, package dependency, resource-domain, or project profile changes: run `content-package-boundary`; quick/full/release suites include it. It scans tracked and untracked `gf_content_package.json` files and fails invalid JSON, unsupported package policy fields, missing/duplicate package IDs, missing/cyclic dependencies, and resources outside their package root.
- Internal `packages/**/*.json` module ownership, dependency graph, or source-boundary changes: run `package-boundary`, `package-closure-audit`, and `package-source-boundary`; quick/full/release suites include them. These manifests describe repository layering only. They must not regain version, preset, archive, registry, lockfile, installer, download, or per-module release semantics.
- Internal module-owned runtime/editor source adding `OS.execute`, `OS.create_process`, `OS.shell_open`, or another external command dependency: run `package-external-command-audit`; quick/full/release suites run it with `--fail-on-warnings`. Direct command runs remain report-only for investigation, and strict suite runs allow only declared editor-jump exceptions.
- Root plugin entry or standard/editor contribution loading changes: run `core-only-smoke`; quick/full/release suites include it. It verifies parse-time layering, not a separately installable core distribution.
- Internal module ownership or focused GUT ownership changes: run `package-focused-gut-mapping`; quick/full/release suites include it. The mapping is maintenance policy only and does not prove a module can be installed or released separately.
- Project layout/profile changes: run the native Project Layout GUT suite and `project-profile-native-acceptance`. Quick / `framework-static` use `project-profile-artifacts` without Godot; executable acceptance belongs to `framework-integration`. `project-profile-boundary --root <directory>` delegates to the same GDScript Session in a private trusted fixture and never executes the target project. Profiles are optional and project-owned.
- Local example changes: run `check --suite examples` and focused tests under `tests/gf_core/examples`.
- Release metadata: use `$gf-release-flow`; build the immutable artifact set once, validate it with `release-status --artifact-manifest`, and keep tag CI set-equivalent to the release suite.

## Notes

`gdscript-readability` enforces the hard layout rules in `CODING_STYLE.md` across owned source, tests and GDScript templates. Its lexer, source inventory and negative fixtures must fail closed on incomplete input. `gdscript_readability` and the four independent fixture checks (`gdscript_readability_tests`, `gdscript_list_layout_tests`, `gdscript_expression_layout_tests`, `gdscript_layout_integrity_tests`) are mandatory in quick, framework-static, framework, full and release; existing CI and release shards inherit these Catalog actions. Each test module has one named Catalog owner and runs once; direct discovery with the command above also runs the complete fixture set once. Formatting preserves comments, literal bytes, operand order and deferred Callable behavior. Do not use per-file debt baselines or changed-line-only scanning.

`check --suite examples` runs only `first_task_smoke`, preceded by `godot_import`, against `res://examples/first_task/first_task.tscn` with `-- --first-task-smoke`. The same smoke is included in Integration, Full and Release. It has a 60-second supervised process budget and keeps resource-error and exit-lifecycle gates. The external Reference project, sync commands and configuration are retired; this workflow never selects or writes an external project.

`check --suite quick` is the lightweight static development loop and deliberately excludes `maintenance-self-test`; its duration depends on the workspace and machine. When maintenance Python, CI, release workflow, or this check matrix changes, run `maintenance-self-test` explicitly; `framework` and `full` also retain it.

`diagnostic-policy` lexically checks the `[GFOwner][owner_snake.reason] English explanation.` shape, ASCII English templates with a final period, supported format placeholders, and one owner/template/severity per ID within the source tree. It does not restrict Unicode runtime arguments or translate project messages. Reuse an existing ID for the same meaning; wording corrections may retain that ID. Result fields such as `error_kind` remain separate contracts, and natural-language text must not drive program behavior.

Dynamic native calls require exact reviewed bindings in `tools/gf_diagnostic_forwarders.json`: `path`, `function`, `callee`, `argument`, `count`, `kind` and `reason`. The current 21 entries are reviewed forwarding sites, not a permanent violation baseline; wildcard exemptions are forbidden. Follow framework message producers and detail fields manually when they change, and preserve caller-owned text at `project_message` sites. The lexical gate is not a complete dataflow proof. Editor display localization remains separate: existing tool catalogs support `en` / `zh_CN` with English fallback, without promising bilingual coverage for every panel.

`check --check gdscript_warnings` opens the project editor headlessly and fails on GDScript reload warnings. It is meant to catch typed-Variant, unnecessary-await, and shadowing warnings that regular GUT runs can miss.

All maintenance-owned Godot commands resolve through `tools/gf_godot_process.py` and run under the shared process supervisor. On Windows this bypasses the detached Steam `godot.exe` launcher when its foreground tools executable is available. Set `GF_GODOT_EXECUTABLE` only when an explicit executable override is required.

`check --check gdscript_lsp_diagnostics` imports the project, then always starts an invocation-owned, isolated LSP with `--spawn-lsp --port 0`. It verifies that the established connection belongs to the published owned process and that the owned process boundary is quiet before accepting evidence. The full and release suites, Ready/main's `framework-lsp` shard, and the release framework shard run it unconditionally and fail on errors, warnings, diagnostic timeouts, connection, transport, ownership or cleanup failures. A manual connection to a user editor remains non-authoritative diagnostic evidence.

`check --suite full` runs the complete local validation plan in isolated workspaces. Use `--jobs` to adjust concurrency or `--jobs 1` to diagnose resource contention or order-sensitive failures. If automatic Windows temporary-root selection fails, configure `GF_MAINTENANCE_VALIDATION_TEMP_ROOT` according to [核心规则](../../../../AI_MAINTENANCE.md#核心规则). That authority defines worker limits, global admission ordering, workspace and Godot isolation, capture/report budgets, process cleanup and accepted evidence.

For Draft, Ready, `main`, manual and release workflows, follow [核心规则](../../../../AI_MAINTENANCE.md#核心规则) for required-context eligibility, Full-equivalent check sets, metadata-only validation and exact workflow deadlines. Run `maintenance-self-test` after changing maintenance execution or CI topology; use `$gf-release-flow` for release validation and immutable artifacts.

`project-settings-drift` fails when `project.godot` has staged or unstaged local changes. Use it after tests or headless editor checks when `ProjectSettings` writes may have leaked transient test state into the project file. Do not use it to block intentional project metadata edits; instead, review and commit those edits deliberately.

Use `@since unreleased` only for newly added public API whose release version is not final yet. `release-status --version <tag>` fails until every `@since` marker is a SemVer and no marker is newer than the release tag.

Use `api-baseline-diff --version <version> --enforce-version` before version decisions when the API surface changed substantially. Added classes are reported for release review. Removed classes, removed members, breaking or unknown signature changes, and extends changes are treated as breaking. Compatible signature changes such as adding defaulted tail parameters, widening parameter types to `Variant` or untyped, and appending enum values remain visible but do not force a major version bump.

`path-hygiene` scans both tracked files and untracked, non-ignored files. New files must not rely on `git diff --check` alone; `git diff --check` does not inspect untracked paths. It also checks that local workflow actions referenced as `./.github/actions/...` have an `action.yml`, and that GF-owned GDScript under `addons/gf` and `tests/gf_core` is strict UTF-8 without BOM, LF-only, final-newline terminated, and tab-indented outside multiline strings.

`api-since-touched` scans modified `addons/gf/**/*.gd` files. Untracked files are checked fully; tracked files are checked only where the current diff touches a `public` / `protected` API documentation block or its bound declaration. This keeps new API strict without turning historical untouched migration debt into a release blocker.

`dependency-boundary` statically scans bundled extension manifests, framework project defaults, and GF source boundaries. It fails on unsupported manifest fields, optional/soft dependency fields, default-enabled bundled extensions, non-empty `project.godot` `gf/extensions/enabled`, `kernel` or `standard` references to optional extension paths, IDs or classes, and cross-extension references inside bundled extensions.

`public-docs-boundary` scans public README, Asset Store text, Wiki entry pages, and handwritten `docs/zh` pages except generated API reference. It fails on AI-only maintenance paths, external research notes, planning track names, claims that optional extension pages or tools are fixed core workspace/editor features, wording that makes Python/npm/npx/Git/Node/pip a prerequisite for full-framework installation or local extension enablement, and current-product claims for the retired Package Manager, registry, offline bundle, or per-module downloads.

`public-api-boundary` scans `addons/gf` source, API Catalog, and generated API Reference. It fails if internal planning route names appear as public API names or generated reference entries.

`resource-boundary` scans tracked and untracked, non-ignored `.gd` files outside vendored/local caches. It reports direct resource load literals and classifies script dependency loads as observations, while actionable runtime resource loads remain issues. The standalone command does not fail by default; Catalog suites already pass `--fail-on-issues` as a hard gate.

`content-package-boundary` scans tracked and untracked, non-ignored `gf_content_package.json` manifests. It enforces the framework-level package contract: manifest and resource entry fields are whitelisted, package dependencies must resolve without cycles, and resource paths must stay inside the package root. It deliberately rejects installer/download/package-manager fields; those belong in project installers or external plugins, not GF content package manifests.

`asset-lifecycle-boundary` scans tracked and untracked runtime `.gd` files outside tests, vendored addons, and local caches. It reports `acquire_handle()`, `load_handle_async()`, and `request_entry_handle_async()` calls that omit both owner and group, because those handles depend on manual release and are common sources of long-lived cache pins. The command is report-only by default; use `--fail-on-warnings` only after a zero baseline is stable.

`project-profile-boundary` looks for `gf_project_profile.json`, `.gf/project_profile.json`, or `project_profile.json`, unless `--profile <path>` is passed. No profile means the check passes. Schema 2 is the only admitted product schema; legacy and shadow evaluators and flags are removed. GDScript owns strict admission, all nine rules, capture, analysis and coverage. Python only reads bounded UTF-8 inputs and supervises an isolated trusted Godot fixture. `--root` supplies read-only target data; the target project configuration, scripts and autoloads are never executed. Explicit generated/disposable exclusions apply before the 20,000-file budget; inferred required sources and profile identity stay protected. `project-profile-native-acceptance` proves this boundary with an autoload sentinel and 20,050 excluded files.

`package-boundary` scans tracked and untracked, non-ignored `packages/**/*.json` manifests. These files are internal module descriptors, despite the retained command and directory name. Their closed schema contains only module identity, kind, dependencies, owned paths, optional excluded paths, and an optional bundled-extension ID. Version, preset, archive, checksum, registry, lockfile, installer, download, and release metadata are rejected. Dependency edges follow `kernel <- standard <- extension`, tool modules mount one-way, and owned paths do not overlap.

`package-closure-audit` computes internal module dependency closures, per-kind counts, source payload, and standard fan-in directly from `packages/**/*.json`. Warnings expose oversized extension closures and debug/UI layering debt. Runtime extension closures that include `gf.standard.editor` are errors. The result is not an install plan or a claim that any module is separately distributable.

`package-source-boundary` scans all tracked and untracked framework files under `addons/gf` and requires one internal module owner even for Markdown, images, and other non-source payloads; Godot-generated `.import` sidecars are the explicit exception. It resolves `addons/gf` path literals and GDScript `class_name` references to owners and fails undeclared direct dependencies. The retained package terminology is internal and must not leak into user installation guidance.

`package-external-command-audit` scans internal-module-owned `.gd` files under `addons/gf` and reports `OS.execute`, `OS.create_process`, and `OS.shell_open` calls by module id, API, command literal, and severity. Direct command runs are report-only by default for investigation. Quick, full, and release suites pass `--fail-on-warnings`, so newly introduced calls fail unless they match an explicit editor-jump allowlist entry.

`core-only-smoke` checks the root plugin entry for parse-time standard dependencies. It allows optional path-based discovery of standard editor contributions, but rejects direct `preload("res://addons/gf/standard/...")`, direct standard `load()` literals, and references to standard `class_name` values from `addons/gf/plugin.gd`. This is a layering check, not a core-only distribution test.

`package-focused-gut-mapping` validates `tests/gf_core/package_focused_gut_mapping.json` against the internal module descriptors. Every module must map to at least one focused GUT script. Test paths must exist, stay under `res://tests/gf_core/`, and match the module's test scope, with a narrow exception for `gf.standard.editor` integration coverage under `res://tests/gf_core/kernel/editor/`.

`check --timeout N` raises the minimum per-check budget but cannot shorten a dedicated policy. Use `--suite-timeout N` for an intentional overall deadline. Full execution and workflow budget contracts are defined in [核心规则](../../../../AI_MAINTENANCE.md#核心规则).

GUT output is not allowed to mask Godot script errors or reload warnings. If Godot reports `SCRIPT ERROR`, parse errors, or GDScript reload warnings, the maintenance check fails even when the GUT summary says all tests passed.

Authoritative GUT treats unconsumed warnings, newly orphaned Nodes and ObjectDB/resource/RID exit leaks as hard failures, and requires valid zero-debt lifecycle evidence plus a passing GUT summary. Other Godot checks record exit leaks as cleanup debt until their own zero baseline is established. Successful maintenance commands remove only logs created or rewritten by that invocation; failed or interrupted invocations and unrelated historical evidence are retained. `ai_analysis/godot_logs/` is the only repository-local diagnostic log root. Historical retention and legacy top-level `.gf/*.log` cleanup occur only through an explicit `log-hygiene` command. For verbose log triage, produce the source log with `--keep-logs` (or `GF_MAINTENANCE_KEEP_LOGS=1`), then run `python tools\gf_maintenance.py godot-exit-leak-report --log <stdout.log> --log <stderr.log> --json`; its standalone `--fail-on-leaks` option does not control the mandatory GUT gate. Inspect `log-hygiene --dry-run --json` first and delete only current-task evidence; reserve `log-hygiene --all --json` for explicit workspace-wide cleanup after confirming no concurrent task owns candidates.
