# Project Layout native validation

The editor and maintenance CLI call `GFProjectLayoutSession`. GDScript owns strict
JSON admission, profile compilation, inventory capture, the nine rules and zones,
coverage, graph validation, queries and plans. Python has no profile interpreter
or legacy/shadow evaluator.

```powershell
python tools/gf_maintenance.py project-profile-boundary --root D:/my_game --json
python tools/gf_maintenance.py project-profile-native-acceptance --json
python tools/gf_maintenance.py project-profile-artifacts --json
```

The target directory supplies read-only filesystem data. The maintenance process
never starts Godot with that directory as `--path`: it snapshots trusted GF source
into a private project with no target autoloads, plugins, scenes or project settings.
It pins the engine selection and creates private OS user/config/cache directories.
Import, execution, output drains and process-tree cleanup share one absolute
deadline. An unavailable executor produces a transport diagnostic, never a
synthetic native analysis report or a fallback evaluator.

| Boundary | Limit |
| --- | --- |
| Raw UTF-8 profile | 1 MiB |
| Escaped request transport | 8 MiB |
| Encoded analysis transport | 16 MiB; measured before whole-report encoding |
| Captured trusted source | 8192 files / 128 MiB |
| Trusted-source enumeration | 16,384 entries per pass; cache descendants pruned before enumeration |
| Import and analysis | 120 seconds together |
| Process stdout / stderr | 1 MiB / 256 KiB |

These are maintenance transport budgets. Exhaustion fails closed without partial
rule results; it does not change the admitted profile or silently shrink its
included scope. The native session's profile, inventory, evaluation and graph
budgets apply independently. A report that exceeds a transport budget is reported
as unavailable by the CLI; it is not reinterpreted by Python.

Quick and `framework-static` check five trusted artifacts and the native compiler's
pinned contract digest without launching Godot. This checks source freshness, not
profile semantics. `framework-integration` runs executable native acceptance: a target fixture
contains an autoload sentinel and 20,050 generated files. The generated directory
is explicitly excluded, the required source remains protected, included inventory
completes below 20,000 files, the target hashes stay equal and the sentinel is never
executed. The native GUT suite owns rule semantics, strict JSON, budgets, capture
identity and producer/consumer regression coverage.

When running independent maintenance jobs concurrently in one source workspace,
set `GF_MAINTENANCE_KEEP_LOGS=1`. Automatic end-of-invocation hygiene observes the
workspace's changed log files and cannot attribute newly written files to another
concurrent invocation. Preserve evidence under each job's unique artifact directory
and clean only explicitly owned logs after all jobs finish. All repository-local
Godot diagnostics stay under `ai_analysis/godot_logs/`.

Profile schema 1 and `--profile-mode` are removed. Schema 2 declarations use a
logical `res://` container anchored to the supplied physical `source_root`.
Python normalizes Windows separators for transport but does not rewrite profile
values. The CLI transmits `source_root` without overriding `root_path`; after
strict compilation, the native authority resolves the declared logical container
against that source root. Without a Profile declaration it admits an option
declaration, or uses the source root when neither exists. Session file/data and
direct Profile analysis share this resolution; observation retains its default
`res://`. Native admission checks the real profile bytes before scanning; that
file may be outside the capture subdirectory while remaining inside `source_root`.
An explicit capture root must match the declaration and cannot retarget it.

If the supervisor proves a typed command-start failure created no child, native
transport preserves that positive quiet-boundary evidence for fixture cleanup.
Generic I/O failures, an unproven start boundary and any chained cleanup debt keep
cleanup closed. A start failure still reports unavailable analysis, never success.

## Semantic coverage after removing the Python evaluator

| Former guarantee | Native owner |
| --- | --- |
| Strict fields, types, paths, globs, regexes, duplicate entries and integer admission | All 33 cases in `profile_conformance_v2.json`, exercised by `test_gf_project_layout_tool_package.gd` |
| All nine rule classes and optional zone filters | `test_gf_project_layout_authority.gd`; no separate maintenance rule engine |
| JSON duplicate keys, lone surrogates, nonfinite values and invalid UTF-8 | Native lexical admission before inventory capture |
| Inventory, text, evaluation work and diagnostic limits | Compiler, snapshot producer, Analyzer and Worker terminal-budget tests |
| One policy and captured inventory for analysis, queries and plans | Session compile/capture counters, owned cached index and Planner regression tests |
| Declared root, excluded directory identity and required-source protection | Shared capture-scope tests, direct/editor digest equality and rejection of root reanchoring |
| Query generation and source identity | Snapshot tamper, Worker closed-envelope and Dock stale-result/cancel/join tests |

Python tests retain transport guarantees: pinned source reading, bounded output,
shared execution/cleanup deadline, unavailable-engine diagnostics and unexpected
exception propagation. Product rule tests execute in Godot. Legacy/shadow modes,
the deprecated Validator and ignored cross-rule compatibility operands are
deliberately removed; the former operand conformance case now asserts strict
rejection. Their removal must not remove coverage of the accepted v2 rules.

Directory declarations must match actual directory-entry spelling, even on a
case-insensitive filesystem. A finite parent-entry check distinguishes an alias
from the declared entry without scanning excluded descendants. Case-sensitive
filesystems may contain both `Cache` and `cache`; excluding one keeps the other
visible. A Windows native regression also checks ordinary nested exclusions and
rejects a junction. Platform-specific probes supplement the native GUT tests;
they do not establish unobserved filesystem behavior on other platforms.
