# GF Release Checks

Run these after release metadata is final and before commit/tag/push.

```powershell
python tools\gf_maintenance.py check --suite full --json
python tools\build_asset_store_package.py --version <version>
python tools\gf_maintenance.py release-status --version <version> --json
git diff --check
git diff --cached --check
```

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
