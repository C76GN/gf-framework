# GF Release Checks

Run these after release metadata is final and before commit/tag/push.

The `full` and `package` suites run isolated editor wizard and package CLI matrices. On a clean Windows workspace, the package checks can take tens of minutes; let the maintenance tool enforce its measured per-check policies and use `--suite-timeout` only for an intentional total deadline. `--timeout` raises the minimum per-check budget and never shortens dedicated long-check budgets. Maintenance-owned Godot commands run through the shared process supervisor and automatically bypass the detached Windows Steam launcher; use `GF_GODOT_EXECUTABLE` only for an explicit executable override. Do not launch a duplicate suite while one is still running, and do not treat an outer-shell timeout as a passing result. CI may run the set-equivalent `framework`, `package-contract`, `package-editor`, `package-cli`, and `package-godot-ci` shards in parallel; release validation replaces the last shard with `package-godot-release` after `release-status`.

```powershell
python tools\gf_maintenance.py check --suite full --json
python tools\build_asset_store_package.py --version <version>
python tools\gf_maintenance.py release-status --version <version> --json
git diff --check
git diff --cached --check
```

Use `release-status --allow-breaking-api` only for an evidenced baseline false positive or a historical surface already excluded from the stable compatibility contract, with that evidence recorded in the changelog or release notes. Real stable-contract breaks require a major version; the flag must not turn them into a minor or patch release and does not waive the minor floor for compatible public additions.

For releases involving the external reference project, also run:

```powershell
python tools\sync_reference_project.py --project-root ..\gf-reference-project --check
python tools\gf_maintenance.py check --suite examples --json
```

If `addons/gf` changed and the external reference project must be brought current, write-sync explicitly before examples validation:

```powershell
python tools\sync_reference_project.py --project-root ..\gf-reference-project
```

## Tag Verification

`release-status` reports local tag existence and whether the local tag points at `HEAD`. After pushing, verify the remote peeled tag:

```powershell
git ls-remote --tags origin "refs/tags/<version>*"
```

The `refs/tags/<version>^{}` line should point at the intended release commit.
