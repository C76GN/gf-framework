# Godot Asset Library Submission Notes

This file is maintainer-facing metadata for legacy Godot Asset Library submissions. Godot does not read this file at runtime; keep it updated so future version bumps and release work can update the submission form consistently.

For the new Godot Asset Store website, use `ASSET_STORE.md`.

This repository is prepared for Godot Asset Library submission with a focused installable payload:

- `addons/gf/**`

The legacy Asset Library submission should represent the complete GF addon. Use the `gf-framework-11.0.0.zip` GitHub Release asset when the form accepts a package URL. If the legacy form only accepts a tag or commit, keep `Download Commit/URL` at `11.0.0`; `.gitattributes` keeps GitHub archive downloads focused on `addons/gf/**`.

GF 11 and later do not publish a minimal kernel, registry, offline bundle, or per-module archives. A release contains the complete framework ZIP, the optional standalone AI Developer Kit ZIP, and the release artifact manifest.

The plugin folder contains its own `README.md` and `LICENSE.md`. Root-level docs, tests, and maintainer files are excluded from GitHub archive downloads through `.gitattributes`, so `docs/wiki` stays in the repository without being installed with the addon.

## Submission Form Values

- Asset Name: `GF Framework`
- Description:

```text
GF Framework is a lightweight architecture framework for Godot 4. It organizes project code into lifecycle-managed models, systems, controllers, utilities, events, commands, queries, installers, and typed accessors.

Its standard library groups reusable input, storage, settings, audio, scene, UI, diagnostics, jobs, data-validation, graph, grid, pathfinding, and formatting tools. Optional atomic extensions add save graphs, flow graphs, networking, interaction, feedback, camera, dialogue, combat, and domain helpers without defining project gameplay rules.

The Godot editor workspace manages extensions, templates, diagnostics, export filtering, and project tools. New projects start with kernel and standard active while optional extensions remain disabled. The official package contains the complete `addons/gf` addon.

Documentation: https://gf-framework.readthedocs.io/
```

- Category: `Tools`
- License: `Apache-2.0`
- Repository host: `GitHub`
- Repository URL: `https://github.com/C76GN/gf-framework`
- Issues URL: `https://github.com/C76GN/gf-framework/issues`
- Minimum Godot Version: `4.7`
- Asset Version: `11.0.0`
- Download Commit/URL: `11.0.0`
- Preferred Package URL: `https://github.com/C76GN/gf-framework/releases/download/11.0.0/gf-framework-11.0.0.zip`
- Icon URL: `https://raw.githubusercontent.com/C76GN/gf-framework/11.0.0/addons/gf/icon.png`

## Short Description

Lightweight Godot 4 game architecture framework for lifecycle management, events, data binding, utilities, and gameplay extensions.

## Preview Assets

No preview images are currently pinned. If previews are added, store their source URLs here and keep the Asset Library form synchronized.

## Before Submitting

1. Commit and push the Asset Library preparation changes.
2. Prefer the `gf-framework-11.0.0.zip` release asset URL if the legacy form accepts a direct package URL.
3. If the form only accepts a tag or commit, use `11.0.0` for `Download Commit/URL`.
4. Do not publish legacy kernel-only, registry, offline-bundle, or per-module artifacts.
5. Use the icon raw URL with the same release tag.
6. From a clean release commit, build the complete immutable artifact set once with `python tools\build_gf_release_artifacts.py --version 11.0.0 --output-dir build\release`; do not rebuild individual attachments separately.
7. Validate the same bytes with `python tools\build_gf_release_artifacts.py --version 11.0.0 --manifest build\release\gf-release-artifacts-11.0.0.json --validate-only`.
8. Run `python tools\gf_maintenance.py check --suite full --json` on the target minimum Godot version.
9. Run `python tools\gf_maintenance.py release-status --version 11.0.0 --artifact-manifest build\release\gf-release-artifacts-11.0.0.json`.
10. Create the GitHub Release from a no-prefix SemVer tag such as `11.0.0`.

## Version Bump Checklist

When the asset version changes, update these locations together:

1. `addons/gf/plugin.cfg`
2. `ASSET_LIBRARY.md`
3. `ASSET_STORE.md`
4. `docs/zh/changelog.md`
5. The Godot Asset Library `Download Commit/URL` after the release tag is pushed.
6. The Godot Asset Library `Icon URL` so it uses the same release tag.
7. The preferred package URL and upload checklist in this file.
