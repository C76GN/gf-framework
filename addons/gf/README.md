# GF Framework Addon

[Project README](../../README.md) | [简体中文](../../README.zh.md) | [Read the Docs](https://gf-framework.readthedocs.io/)

This directory is the distributable Godot addon for GF Framework. Copy `addons/gf` into a Godot 4 project, enable `GF Framework` from `Project > Project Settings > Plugins`, and the plugin will register:

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

The plugin also opens the standalone `GF Workspace`. New projects start with only the GF kernel and standard library active; bundled optional extensions are disabled until explicitly enabled. The `GF Extensions` page is used for inspecting extension manifests, enabling or disabling extensions, auto-running enabled extension installers, excluding disabled extensions during export, and reporting disabled-extension references when strict export checks are enabled.

The official Godot Asset Store/Asset Library package and the main GitHub Release package are the full `gf-framework-<version>.zip` addon package. Minimal `gf-kernel-<version>.zip` release assets are intended for advanced modular bootstrap flows where a project installs additional GF packages through the package manager.

## Package Management

If this project was installed from the minimal `gf.kernel` package, open `Tools > GF > Open GF Workspace` and use the `GF Package Manager` page to inspect, install, update, or remove additional GF packages.

The same package manager is also available without Python:

```powershell
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- status
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- install <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- update [<package-id>...] [--all-installed]
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- uninstall <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- verify
```

Common options are:

- `--registry <index.json-or-url-or-source.json>`: use a local registry, remote registry, registry source, or offline bundle source instead of the default GF release source.
- `--channel <name>`: select a channel from a registry source; defaults to the source's stable channel.
- `--project-root <path>`: install into another Godot project; defaults to the current `--path` project.
- `--lockfile <path>`: override the package lockfile; defaults to `.gf/packages.lock.json`.
- `--cache-dir <path>`: override the download cache; defaults to `.gf/package_cache`.
- `--dry-run`: preview install or uninstall without writing files.
- `--all-installed`: with `update`, update every installed package recorded in the lockfile.
- `--force`: allow uninstall when the package manager would normally block removal.
- `--json`: print machine-readable output.

When `--registry` is omitted, GF uses the registry source for the installed framework version from `addons/gf/plugin.cfg`. For example, a project on GF `1.0.0` reads the `1.0.0` release registry by default. A registry or package whose `minimum_framework_version` / `maximum_framework_version_exclusive` does not match the target project is rejected before files are downloaded, staged, or overwritten.

The package manager is not a self-updater for the running framework. With the default source, `install gf.kernel` on GF `1.0.0` targets the `1.0.0` registry. To move a project to GF `1.0.1`, replace the framework from the GF `1.0.1` release first, then run `status` and use `update --all-installed` to align installed optional packages with the new registry.

Installed packages are tracked in `.gf/packages.lock.json`. GF does not update existing packages automatically when the framework is manually replaced; run `status`, then `update <package-id>` or `update --all-installed` to apply updates from the currently selected registry. `update` only targets packages already present in the lockfile. Use `install` to add new packages.

## Layout

- `kernel`: runtime kernel, base contracts, architecture container, binding, events, commands, queries, factories, AutoLoad entry, extension infrastructure, and core editor integration.
- `standard`: stable standard library, including foundation, input, utilities, state machines, command history, sequence helpers, and common support primitives.
- `extensions`: optional atomic GF extensions shipped with the framework.

Bundled GF extensions are atomic and disabled by default: they depend only on the GF kernel/standard surface and do not declare, probe, or load other bundled extensions. Project code or standalone Godot plugins outside `addons/gf` own cross-extension composition. Unused extensions may be excluded from export or removed after project references are gone.

## 中文说明

本目录是 GF Framework 的 Godot 插件分发目录。将 `addons/gf` 复制到 Godot 4 项目后，在 `Project > Project Settings > Plugins` 启用 `GF Framework`，插件会自动注册 `Gf` AutoLoad，并默认打开独立的 `GF Workspace`；其中的 `GF Extensions` 页面用于查看、启用、禁用和导出管理 GF 扩展。

Godot Asset Store / Asset Library 官方页面和 GitHub Release 主下载包使用完整的 `gf-framework-<version>.zip` 插件包。`gf-kernel-<version>.zip` 是高级模块化引导入口，适合项目先安装最小 kernel，再通过包管理器按需安装其他 GF package。

## 包管理快速入口

如果项目只安装了最小 `gf.kernel` 包，可以从 `工具 > GF > 打开 GF 工作区` 进入 `GF Package Manager` 页面，查看、安装、更新或移除其他 GF package。

也可以直接使用 Godot 原生命令行，不需要 Python：

```powershell
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- status
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- install <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- update [<package-id>...] [--all-installed]
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- uninstall <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- verify
```

常用参数：

- `--registry <index.json-or-url-or-source.json>`：改用本地 registry、远程 registry、registry source 或离线包 source。
- `--channel <name>`：选择 registry source 中的 channel；默认使用 stable channel。
- `--project-root <path>`：把 package 安装到另一个 Godot 项目；默认是当前 `--path` 项目。
- `--lockfile <path>`：覆盖 package lockfile 路径；默认是 `.gf/packages.lock.json`。
- `--cache-dir <path>`：覆盖下载缓存目录；默认是 `.gf/package_cache`。
- `--dry-run`：只预览安装或卸载，不写项目文件。
- `--all-installed`：配合 `update` 使用，更新 lockfile 中全部已安装 package。
- `--force`：强制执行通常会被阻止的卸载。
- `--json`：输出机器可读 JSON。

不传 `--registry` 时，GF 会根据当前项目 `addons/gf/plugin.cfg` 中的框架版本选择同版本 release registry source。例如 GF `1.0.0` 项目默认读取 `1.0.0` registry。registry 或 package 的 `minimum_framework_version` / `maximum_framework_version_exclusive` 与目标项目不匹配时，安装会在下载、暂存和覆盖文件前失败。

包管理器不是正在运行的 GF 框架自更新器。使用默认源时，GF `1.0.0` 项目执行 `install gf.kernel` 仍然会对齐 `1.0.0` registry。要把项目升级到 GF `1.0.1`，应先用 GF `1.0.1` release 替换框架，再运行 `status` 并用 `update --all-installed` 对齐已安装的可选 package。

已安装 package 记录在 `.gf/packages.lock.json`。手动替换或升级 GF 框架不会自动同步更新已安装 package；先运行 `status` 查看状态，再执行 `update <package-id>` 或 `update --all-installed`，即可按当前 registry 更新。`update` 只处理 lockfile 里已经安装的 package；新增 package 仍使用 `install`。

完整项目说明请看仓库根目录的 [`README.md`](../../README.md) 和 [`README.zh.md`](../../README.zh.md)，正式文档请看 [Read the Docs](https://gf-framework.readthedocs.io/)。

## License

Apache License 2.0. See [`../../LICENSE.md`](../../LICENSE.md).
