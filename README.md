# GF Framework

English | [简体中文](README.zh.md)

GF Framework is a lightweight game architecture framework for Godot 4. It separates data, logic, presentation, runtime services, and pure algorithm helpers so larger projects can keep predictable lifecycles, clear dependency boundaries, and testable gameplay code.

## Documentation

- Official docs: [Read the Docs](https://gf-framework.readthedocs.io/)
- Chinese docs source: [`docs/zh`](docs/zh)
- Generated API Reference source: [`docs/api_catalog`](docs/api_catalog)
- Changelog: [`docs/zh/changelog.md`](docs/zh/changelog.md)

The legacy GitHub Wiki keeps only entry links. Read the Docs is the single official documentation source.

## Requirements

- Godot 4.7 or newer.
- GUT, only when running the repository test suite.
- Python dependencies from [`docs/requirements.txt`](docs/requirements.txt), only when building the documentation locally.

## Installation

For normal installs, use the official Godot Asset Store/Asset Library package or the GitHub Release asset named `gf-framework-<version>.zip`. This package contains the full `addons/gf` addon folder: kernel, standard library, editor tooling, package manager, and bundled optional extensions. Optional extensions remain disabled until the project explicitly enables them, so the full package is the recommended first-install path.

Advanced users who want a minimal bootstrap can download `gf-kernel-<version>.zip` from the same GitHub Release, enable the plugin, then install only the needed packages from `GF Package Manager` or the Godot-native package CLI. This modular path is useful for controlled project templates and offline/internal registries, but it is not the default package for the Godot websites.

Copy `addons/gf` from the package into your Godot project, then enable `GF Framework` from `Project > Project Settings > Plugins`.

Godot does not automatically enable editor plugins after files are copied into `addons`. This is expected: plugin enablement belongs to the target project's `project.godot`, and the user must opt in before editor plugin code runs.

When enabled, the plugin registers the `Gf` AutoLoad automatically:

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

The plugin also opens the standalone `GF Workspace`. A new project starts with only the GF kernel and standard library active; bundled optional extensions remain disabled until the project explicitly enables them. Use the `GF Extensions` page to inspect extension manifests, enable or disable GF extensions, auto-run enabled extension installers, exclude disabled extension folders from exported builds, and make disabled-extension references fail export checks when needed.

Bundled GF extensions are atomic: they depend only on the GF kernel/standard surface and do not declare, probe, or load other bundled extensions. Project code or standalone Godot plugins outside `addons/gf` own cross-extension composition. Unused extensions can be disabled, excluded from export, or removed after project scripts, scenes, resources, and preloads no longer reference them.

## Quick Start

```gdscript
extends Node


func _ready() -> void:
	Gf.register_model(PlayerModel.new())
	Gf.register_utility(GFStorageUtility.new())
	Gf.register_system(BattleSystem.new())

	await Gf.init()

	var player_model := Gf.get_model(PlayerModel) as PlayerModel
	var battle_system := Gf.get_system(BattleSystem) as BattleSystem
	battle_system.start_encounter(player_model)
```

For larger projects, prefer a project installer:

```gdscript
class_name GameInstaller
extends GFInstaller


func install(architecture: GFArchitecture) -> void:
	architecture.register_model_instance(PlayerModel.new())
	architecture.register_utility_instance(GFStorageUtility.new())
	architecture.register_system_instance(BattleSystem.new())
```

Add the installer path to `Project Settings > gf/project/installers`, then call `await Gf.init()`.

## Core Concepts

- `GFModel`: data and state, including snapshot or save/restore entry points such as `to_dict()` and `from_dict()`.
- `GFSystem`: gameplay logic, rules, events, commands, queries, and frame updates.
- `GFController`: Godot `Node` bridge for scenes, UI, input, presentation, and local contexts.
- `GFUtility`: lifecycle-managed runtime services such as storage, resource loading, settings, time, audio, UI stacks, logging, diagnostics, input, jobs, object pools, and scene workflows.
- `standard/foundation`: pure algorithms, values, formatting, validation, formulas, tags, blackboards, graphs, grids, pathfinding, spatial helpers, and data conversion. It does not participate in `GFArchitecture` lifecycle registration.

## Layers And Extensions

GF source is organized around stable ownership boundaries:

- `addons/gf/kernel`: runtime kernel, base contracts, architecture container, binding, events, commands, queries, factories, AutoLoad entry, extension infrastructure, and core editor integration.
- `addons/gf/standard`: stable standard library, including foundation, input, utilities, state machines, command history, sequence helpers, and common support primitives.
- `addons/gf/extensions`: optional atomic GF extensions shipped with the framework, such as capability, interaction, feedback, camera, dialogue, action queue, combat, asset metadata, save, flow, network, turn-based flow, behavior tree, decision scoring, physics helpers, and domain models.

The kernel does not hard reference the standard library or optional extensions. The standard library depends only on the kernel and must not probe optional extensions through extension IDs, paths, dynamic loading, or extension class names. Bundled GF extensions are kept independent of each other; extensions that need to appear in standard diagnostics or tools contribute through generic registration APIs, and cross-extension orchestration stays in project code or standalone plugins.

## Editor Tools

GF includes core editor support for extension management, typed GF/config accessor generation, project constants, script templates, inspectors, docks, export helpers, and Node3D/Mesh/MeshLibrary thumbnail rendering. Optional extensions contribute their own editor tools, such as SaveGraph diagnostics and Pattern2D editing, only when enabled.

Extension-specific editor tools are declared by `gf_extension.json` manifests and loaded only when the extension is enabled.

## Testing

The test suite uses GUT through the maintenance runner, which imports a clean project first and validates the Godot log and whole-suite pass summary:

```powershell
python tools\gf_maintenance.py check --check gut --failed-only
```

Maintenance checks live under [`tests/gf_core/maintenance`](tests/gf_core/maintenance). They cover API comments, layer boundaries, removed public classes, generated docs consistency, Read the Docs structure, and legacy Wiki entry policy.

## Documentation Build

```powershell
python -m pip install -r docs\requirements.txt
python tools\generate_api_reference.py --check
python tools\check_docs_quality.py --strict
python -m mkdocs serve
python -m mkdocs build --strict
```

`generate_api_reference.py --check` verifies the XML catalog, generated Markdown pages, and class/member coverage for the API Reference.

## License

Apache License 2.0. See [`LICENSE.md`](LICENSE.md).
