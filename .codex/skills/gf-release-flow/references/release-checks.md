# GF Release Checks

Run these after release metadata is final and before commit/tag/push.

Before running the commands, ensure `docs/zh/changelog.md` contains exactly one formal section and that section is the target release. Do not retain older formal sections or create a parallel Markdown history; immutable Git tags and GitHub Releases are the historical record. `release-status` rejects stale, duplicate, unsupported, or unreleased sections.

The `full` and `package` suites run isolated editor wizard and local/network package CLI matrices. On a clean Windows workspace, package checks can take tens of minutes; use measured per-check policies and reserve `--suite-timeout` for an intentional total deadline. `--timeout` only raises the minimum per-check budget. Maintenance-owned Godot commands run through the shared process supervisor and bypass the detached Windows Steam launcher when possible. Do not launch duplicate suites or treat an outer-shell timeout as a passing result. CI may run the set-equivalent `framework`, `package-contract`, `package-editor`, `package-cli-local`, `package-cli-network`, and `package-godot-ci` shards; release replaces the last shard with `package-godot-release`.

```powershell
python tools\gf_maintenance.py check --suite full --json
python tools\build_gf_release_artifacts.py --version <version> --output-dir build\release
python tools\gf_maintenance.py release-status --version <version> --artifact-manifest build\release\gf-release-artifacts-<version>.json --json
python tools\build_gf_release_artifacts.py --version <version> --manifest build\release\gf-release-artifacts-<version>.json --validate-only
git diff --check
git diff --cached --check
```

Build the artifact set once. Every later validation and publish step must consume the same manifest and bytes; do not rerun the Asset Store or modular package builders independently.

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
