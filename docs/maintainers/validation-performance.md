# Validation performance and failed-check retries

Run the same checks with the same failure criteria, and measure expensive work before changing execution policy. Use `--json-output build/<name>.json` to retain per-check wall time, timeout layers, source fingerprint, command identity and failure output. A high worker count is not a speed guarantee: the local GUT lane runs alone to avoid contention. With the default three workers, static, integration and LSP share the first batch, followed by GUT alone. With two workers, LSP occupies a separate batch before GUT. All lanes retain their private workspaces, dependencies and existing process budgets; the separate LSP and GUT imports still both run.

Before a long Full run, prefer cheap checks for the changed surface: `python tools/gf_gdscript_readability.py --path <changed-file>` catches layout issues, and Catalog contract tests catch stale command snapshots and timeout expectations. Use owned LSP diagnostics for typed GDScript changes, since passing runtime assertions does not establish a warning-clean result. These focused checks help find failures early; the required complete gates remain unchanged.

## Temporary validation files

Project Layout and Code Quality native fixtures prefer `build/validation/`. Git ignores this directory, and `build/.gdignore` excludes it from Godot's resource scan. If the fixture would write inside the read-only analysis target or exceed its Windows path budget, the runner selects a compatible temporary directory.

Parallel Full and GUT sharding require source-independent workspaces. When the Windows system temporary directory exceeds the short-path budget, the runner uses `gft` on the checkout's drive, such as `D:\gft`. `GF_MAINTENANCE_VALIDATION_TEMP_ROOT` can select an explicit compatible parent directory.

Each run removes the temporary directories it owns after confirming that their process trees have stopped. The same cleanup applies after a failed check or a handled interruption. The runner preserves failed shard logs in `ai_analysis/godot_logs/` and reports directories that cannot be safely removed. A forced process termination can interrupt cleanup before it runs.

## Continue after a failure

When a Full run fails, inspect the failed checks before starting another Full:

```text
python tools/gf_maintenance.py --json-output build/full.json check --suite full
python tools/gf_maintenance.py --json-output build/full-retry.json check-retry --from-report build/full.json
```

The retry selects failed, blocked and unexecuted actions. The current Catalog expands dependencies and constructs every command; report-provided commands are never executed. Dependencies that produce state, including `godot_import`, run again. The report reader pins ordinary files beneath `build/`, enforces a 16 MiB limit and rejects duplicate keys, non-finite JSON, contradictory statuses, unknown actions, release context and orchestration or cleanup failures. Source fingerprint mismatch refuses dispatch instead of silently launching a fresh Full.

This is explicit focused execution, not a persistent success cache. Previous PASS records remain in the original report and are listed only as information. The retry report does not claim a new successful Full run or provide merge/release evidence. Existing Shadow and affected-analysis observations remain non-authoritative. The original Full report must be preserved; the CLI rejects using it as the retry output.

Before relying on the earlier local observations, confirm that the toolchain and environment are unchanged. Ordinary reports do not establish a hermetic toolchain/environment closure, so a matching source fingerprint alone cannot authorize cross-environment PASS reuse. Ready/main/release workflows still run their complete canonical checks.

## Timeouts and measurement

- A process timeout is different from a failed assertion. Preserve failures; do not retry repeatedly until green.
- For a measured outer process timeout, `check-retry --from-report build/full.json --timeout 2400` raises the minimum only for the selected retry and its dependencies. The number is an example, not a universal budget. Dedicated policy floors remain in force; `--suite-timeout` remains an overall hard deadline.
- An inner deadline, such as LSP initialization or inventory scanning, is not extended by the outer `--timeout`. Diagnose that phase directly. The owned LSP handshake allows 120 seconds; its 600-second process lifetime, per-file 3/12-second bounds, two diagnostic timeout retries, error/warning rejection and cleanup proof remain unchanged.
- The authoritative GUT floor is 1800 seconds (30 minutes), shared by Full, explicit full-suite observation and qualification control. The measured optimized run took about 25 minutes, so the former 20-minute floor interrupted normal work. The complete child budget is 3420 seconds, still below the unchanged 60-minute CI job limit; suite deadlines remain hard upper bounds. Fast completion never waits for the budget to expire.
- Compare representative inputs under the same profiler, then validate the real action without profiler overhead. Record input sizes, operation counts and diagnostics alongside elapsed time; do not extrapolate a microbenchmark into a whole-suite speedup.

The measured optimizations preserve validation work:

- Windows copy validation reuses ABI definitions and avoids constructing intermediate `Path` objects from already available strings. It never caches file identity observations. Every registered directory still receives live native queries at every existing validation boundary, including siblings of the active target. This reduces allocation cost but preserves the quadratic sweep count as the tree grows.
- Unicode scalar rejection uses the same forbidden code-point interval. API contract tests reuse pure parsing only within one testcase, keyed by exact text and path/state. Mutable declaration results are detached, caches are bounded and cleared at testcase boundaries, and capacity exhaustion falls back to ordinary parsing. Annotation argument scanning advances once through strings, escapes, comments and nested delimiters instead of repeatedly scanning prefixes.
- The layout test script shares pure structure parsing between its rules. Every rule still enumerates and reads current files and renders templates before lookup. A path retains only its latest exact rendered text; changed text invalidates it, and returned lines are detached. The script clears its cache at start and end, with limits of 2,048 paths and 32 Mi characters across source and parsed lines. This character limit is not a byte-accurate heap limit. Saturation uses ordinary parsing, never skips a file or rule.
- Layer checks build an ASCII token index once per current source projection. Plain ASCII identifier queries use that index with the original ASCII boundary semantics, including digit prefixes. Other query shapes retain the original regular expression. Comments, literals and reflected dependency extraction keep their existing projections. Only query syntax classification is cached, at most 2,048 entries per script; source match results are never cached across files.

Test discovery, assertions, warning/orphan tracking and exit-leak gates remain intact. Timing fixtures and focused regressions establish local behavior and cost; only an actual complete run can establish Full duration and acceptance.
