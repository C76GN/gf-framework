# GF Check Matrix

Start with `python tools\gf_maintenance.py workspace-status --json`. It categorizes dirty files and recommends checks.

## Common Commands

```powershell
python tools\gf_maintenance.py check --suite quick --json
python tools\gf_maintenance.py check --suite full --json
python tools\gf_maintenance.py check --suite api --json
python tools\gf_maintenance.py check --suite docs --json
python tools\gf_maintenance.py check --suite examples --json
python tools\gf_maintenance.py release-status --version <version> --json
git diff --check
git diff --cached --check
```

## By Change Type

- `addons/gf/**`: run focused tests when possible, then `check --suite full` before commit when behavior changed.
- Public API comments or signatures: run `python tools\generate_api_reference.py`, `python tools\generate_api_reference.py --check`, and `check --suite api`.
- Generated API docs: do not hand-edit `docs/api_catalog/**` or `docs/zh/reference/api/**`; regenerate with `tools/generate_api_reference.py`.
- Handwritten docs: run `check --suite docs`; if links or structure changed, run full docs validation and MkDocs through the suite.
- Layer boundary changes: run the full suite and the specific maintenance tests for layer boundary and GDScript parse validation when relevant.
- Reference project changes: use `$gf-reference-boundary`.
- Release metadata: use `$gf-release-flow`.

## Notes

`check --suite examples` is read-only unless `--sync-examples` is passed. Do not write-sync the external reference project by accident.
