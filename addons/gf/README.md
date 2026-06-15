# GF Framework Addon

[Project README](../../README.md) | [简体中文](../../README.zh.md) | [Read the Docs](https://gf-framework.readthedocs.io/)

This directory is the distributable Godot addon for GF Framework. Copy `addons/gf` into a Godot 4 project, enable `GF Framework` from `Project > Project Settings > Plugins`, and the plugin will register:

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

The plugin also opens the standalone `GF Workspace`. New projects start with only the GF kernel and standard library active; bundled optional extensions are disabled until explicitly enabled. The `GF Extensions` page is used for inspecting extension manifests, enabling or disabling extensions, auto-running enabled extension installers, excluding disabled extensions during export, and reporting disabled-extension references when strict export checks are enabled.

## Layout

- `kernel`: runtime kernel, base contracts, architecture container, binding, events, commands, queries, factories, AutoLoad entry, extension infrastructure, and core editor integration.
- `standard`: stable standard library, including foundation, input, utilities, state machines, command history, sequence helpers, and common support primitives.
- `extensions`: optional atomic GF extensions shipped with the framework.

Bundled GF extensions are atomic and disabled by default: they depend only on the GF kernel/standard surface and do not declare, probe, or load other bundled extensions. Project code or standalone Godot plugins outside `addons/gf` own cross-extension composition. Unused extensions may be excluded from export or removed after project references are gone.

## 中文说明

本目录是 GF Framework 的 Godot 插件分发目录。将 `addons/gf` 复制到 Godot 4 项目后，在 `Project > Project Settings > Plugins` 启用 `GF Framework`，插件会自动注册 `Gf` AutoLoad，并默认打开独立的 `GF Workspace`；其中的 `GF Extensions` 页面用于查看、启用、禁用和导出管理 GF 扩展。

完整项目说明请看仓库根目录的 [`README.md`](../../README.md) 和 [`README.zh.md`](../../README.zh.md)，正式文档请看 [Read the Docs](https://gf-framework.readthedocs.io/)。

## License

Apache License 2.0. See [`../../LICENSE.md`](../../LICENSE.md).
