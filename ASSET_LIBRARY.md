# Godot Asset Library Submission Notes

This file is maintainer-facing metadata for legacy Godot Asset Library submissions. Godot does not read this file at runtime; keep it updated so future version bumps and release work can update the submission form consistently.

For the new Godot Asset Store website, use `ASSET_STORE.md`.

This repository is prepared for Godot Asset Library submission with a focused installable payload:

- `addons/gf/**`

The plugin folder contains its own `README.md` and `LICENSE.md`. Root-level docs, tests, and maintainer files are excluded from GitHub archive downloads through `.gitattributes`, so `docs/wiki` stays in the repository without being installed with the addon.

## Submission Form Values

- Asset Name: `GF Framework`
- Description:

```text
GF Framework is a lightweight architecture framework for Godot 4. It helps organize games into models, systems, controllers, utilities, foundation helpers, and optional extensions with managed lifecycles, typed events, bindable properties, commands and queries, installers, extension manifests, extension enablement/export filtering, capability components, action queues with resourceized tween configs, state machines with guards and blackboards, resourceized flow graphs with port metadata, connections, and validation, pluggable network backend foundations with optional ENet transport plus session/channel metadata, versioned storage/codecs with migration hooks and file management, snapshot history, save slot workflows, save graph composition with generic data sources, pipeline hooks, traces, and diagnostics, settings/audio/scene/remote-cache utilities, asset handles and groups, scene transition configs, player-scoped input mapping with modifiers, triggers, 3D values, formatter providers, rich text formatting, and conflict reports, debug draw command buffering, analytics transport hooks, governed runtime diagnostics, notification queues, grid/hex pathfinding helpers, stable 3D grid keys, 3D region maps, surface plane mapping helpers, tag expressions, generic domain data models, and lightweight combat helpers. New projects start with only the kernel and standard library active; bundled optional extensions are disabled by default and must be explicitly enabled by the project.

Enable the plugin to register the Gf AutoLoad and use the editor tools for extension management, GF module templates, typed accessors, and project constants.
```

- Category: `Tools`
- License: `Apache-2.0`
- Repository host: `GitHub`
- Repository URL: `https://github.com/C76GN/gf-framework`
- Issues URL: `https://github.com/C76GN/gf-framework/issues`
- Minimum Godot Version: `4.6`
- Asset Version: `5.2.0`
- Download Commit/URL: `5.2.0`
- Icon URL: `https://raw.githubusercontent.com/C76GN/gf-framework/5.2.0/addons/gf/icon.png`

## Short Description

Lightweight Godot 4 game architecture framework for lifecycle management, events, data binding, utilities, and gameplay extensions.

## Preview Assets

No preview images are currently pinned. If previews are added, store their source URLs here and keep the Asset Library form synchronized.

## Before Submitting

1. Commit and push the Asset Library preparation changes.
2. Use the new full commit hash in the submission form.
3. Use the icon raw URL with that same commit hash.
4. Build the Asset Store package with `python tools\build_asset_store_package.py --version 5.2.0` and verify the zip root is `addons/`.
5. Run the GUT test suite on the target minimum Godot version.
6. Run `python tools\gf_maintenance.py release-status --version 5.2.0 --allow-breaking-api`.
7. Create the GitHub Release from a no-prefix SemVer tag such as `5.2.0`.

## Version Bump Checklist

When the asset version changes, update these locations together:

1. `addons/gf/plugin.cfg`
2. `ASSET_LIBRARY.md`
3. `ASSET_STORE.md`
4. `docs/zh/changelog.md`
5. The Godot Asset Library `Download Commit/URL` after the release tag is pushed.
6. The Godot Asset Library `Icon URL` so it uses the same release tag.
