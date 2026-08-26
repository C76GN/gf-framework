# GF Framework Addon

[Project README](https://github.com/C76GN/gf-framework/blob/main/README.md) | [简体中文](https://github.com/C76GN/gf-framework/blob/main/README.zh.md) | [Read the Docs](https://gf-framework.readthedocs.io/)

This directory is the distributable Godot addon for GF Framework. Copy `addons/gf` into a Godot 4 project, enable `GF Framework` from `Project > Project Settings > Plugins`, and the plugin will register:

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

The plugin also opens the standalone `GF Workspace`. New projects start with only the GF kernel and standard library active; bundled optional extensions are disabled until explicitly enabled. The `GF Extensions` page is used for inspecting extension manifests, enabling or disabling extensions, auto-running enabled extension installers, excluding disabled extensions during export, and reporting disabled-extension references when strict export checks are enabled.

The official Godot Asset Store/Asset Library download and the GitHub Release asset named `gf-framework-<version>.zip` both contain the complete addon. Bundled optional extensions are present but remain disabled until the project enables them locally.

The optional GF AI Developer Kit provides project intent, version-bound API discovery, managed agent instructions, and approval-gated GF feedback tooling without affecting the Godot runtime or exported game. See the [AI Developer Kit guide](https://github.com/C76GN/gf-framework/blob/main/docs/zh/editor/tools/ai-developer.md).

## Installation And Upgrades

GF 11 is installed and upgraded as one addon. Close Godot, commit or back up the project, then replace the whole `addons/gf` directory with the directory from one `gf-framework-<version>.zip` release. Do not overlay files from different versions.

GF 11 does not include a Package Manager, a package CLI, online registries, offline bundles, or per-module release archives. Projects created with the GF 10 modular installer must complete the [GF 10 migration procedure](https://github.com/C76GN/gf-framework/blob/main/docs/zh/overview/quickstart/package-manager-migration.md) before replacing the addon.

## Layout

- `kernel`: runtime kernel, base contracts, architecture container, binding, events, commands, queries, factories, AutoLoad entry, extension infrastructure, and core editor integration.
- `standard`: stable standard library, including foundation, input, utilities, state machines, command history, sequence helpers, and common support primitives.
- `extensions`: optional atomic GF extensions shipped with the framework.

Bundled GF extensions are atomic and disabled by default: they depend only on the GF kernel/standard surface and do not declare, probe, or load other bundled extensions. Project code or standalone Godot plugins outside `addons/gf` own cross-extension composition. Unused extensions may be excluded from export or removed after project references are gone.

## 中文说明

本目录是 GF Framework 的 Godot 插件分发目录。将 `addons/gf` 复制到 Godot 4 项目后，在 `Project > Project Settings > Plugins` 启用 `GF Framework`，插件会自动注册 `Gf` AutoLoad，并默认打开独立的 `GF Workspace`；其中的 `GF Extensions` 页面用于查看、启用、禁用和导出管理 GF 扩展。

Godot Asset Store / Asset Library 官方页面和 GitHub Release 中的 `gf-framework-<version>.zip` 都提供完整插件。可选内置扩展随包存在，但只有项目在本地显式启用后才会参与装配。

可选 GF AI Developer Kit 提供项目意图、版本化 API 查询、Agent 规则和审批式 GF 反馈工具，不影响 Godot 运行时或导出游戏。完整说明见 [AI Developer Kit 指南](https://github.com/C76GN/gf-framework/blob/main/docs/zh/editor/tools/ai-developer.md)。

## 安装与升级

GF 11 以完整插件为单位安装和升级。先关闭 Godot，提交或备份项目，再用某一个 `gf-framework-<version>.zip` 发布包中的完整目录替换整个 `addons/gf`；不要叠加不同版本的文件。

GF 11 不再包含 Package Manager、包管理命令行、在线 registry、离线 bundle 或逐模块发布包。曾使用 GF 10 模块化安装器的项目，必须先完成[从 GF 10 模块化安装迁移](https://github.com/C76GN/gf-framework/blob/main/docs/zh/overview/quickstart/package-manager-migration.md)，再替换插件目录。

完整项目说明请看 GitHub 上的 [`README.md`](https://github.com/C76GN/gf-framework/blob/main/README.md) 和 [`README.zh.md`](https://github.com/C76GN/gf-framework/blob/main/README.zh.md)，正式文档请看 [Read the Docs](https://gf-framework.readthedocs.io/)。

## License

Apache License 2.0. See [`LICENSE.md`](LICENSE.md).
