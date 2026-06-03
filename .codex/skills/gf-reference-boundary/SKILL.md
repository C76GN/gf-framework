---
name: gf-reference-boundary
description: Maintain the external GF reference project boundary and examples smoke workflow. Use when working with gf-reference-project, examples suite, sync_reference_project.py, smoke scenes, reference project feedback, or avoiding project-business leakage into addons/gf.
---

# GF Reference Boundary

Use this skill whenever GF maintenance touches the external reference project or examples suite. The reference project is a validation surface and feedback source, not part of the GF framework repository.

## Path

- Default project path: `../gf-reference-project`
- Override: `GF_REFERENCE_PROJECT_PATH`
- Boot scene override: `GF_REFERENCE_BOOT_SCENE` or `.gf_reference_project.json` `boot_scene`
- Smoke scene override: `GF_REFERENCE_SMOKE_SCENE` or `.gf_reference_project.json` `smoke_scene`

Always confirm the target contains `project.godot` before writing.

## Sync Rules

- `tools/gf_maintenance.py check --suite examples` is read-only by default and checks that external `addons/gf` is current.
- Write sync is explicit only:
  - `python tools\sync_reference_project.py --project-root ..\gf-reference-project`
  - or `python tools\gf_maintenance.py check --suite examples --sync-examples`
- The external project's `addons/gf/` is generated/synced content. Do not treat it as reference project source.

## Checks

Run these when examples are in scope:

```powershell
python tools\sync_reference_project.py --project-root ..\gf-reference-project --check
python tools\gf_maintenance.py check --suite examples --json
```

Use explicit write sync only when the user asked to sync, or when validation requires syncing after GF source changed.

## Feedback Boundary

If the reference project reveals repeated friction, classify it before changing framework code:

- project convention
- documentation suggestion
- maintenance tool improvement
- framework candidate

Record framework feedback on the GF side, especially in `ai_analysis/framework_feedback.md` when useful. Do not write reference-project gameplay rules into `addons/gf`.
