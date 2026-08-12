# GF Framework

[English](README.md) | 简体中文

[![CI](https://github.com/C76GN/gf-framework/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/C76GN/gf-framework/actions/workflows/ci.yml)
[![文档](https://readthedocs.org/projects/gf-framework/badge/?version=latest)](https://gf-framework.readthedocs.io/)
[![最新版本](https://img.shields.io/github/v/release/C76GN/gf-framework?display_name=tag&sort=semver)](https://github.com/C76GN/gf-framework/releases/latest)
[![许可证](https://img.shields.io/github/license/C76GN/gf-framework)](LICENSE.md)
[![Godot 4.7+](https://img.shields.io/badge/Godot-4.7%2B-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/C76GN/gf-framework)

GF Framework 是一个面向 Godot 4 的轻量级游戏架构框架。它把数据、逻辑、表现、运行时服务和纯算法基础件拆开管理，让规模更大的项目仍然能保持可预测的生命周期、清晰的依赖边界和可测试的玩法代码。

## 文档

- 正式文档：[Read the Docs](https://gf-framework.readthedocs.io/)
- 中文文档源码：[`docs/zh`](docs/zh)
- 生成式 API Reference 中间源：[`docs/api_catalog`](docs/api_catalog)
- 更新日志：[`docs/zh/changelog.md`](docs/zh/changelog.md)
- 贡献与协作流程：[`CONTRIBUTING.md`](CONTRIBUTING.md)

旧 GitHub Wiki 只保留入口链接。Read the Docs 是唯一正式文档来源。

## Star History

[![Star History Chart](https://api.star-history.com/chart?repos=C76GN/gf-framework&type=date&legend=top-left)](https://www.star-history.com/?repos=C76GN%2Fgf-framework&type=date&legend=top-left)

该图表由 Star History 提供。GitHub 当前的 stargazer API 政策可能要求仓库级 token 才能获取最新历史；如果图片停止更新，可以打开上面的图表链接，并在 Star History 页面重新生成 README 嵌入代码。

## 环境要求

- Godot 4.7 或更新版本。
- 只有运行仓库测试时需要 GUT。
- 只有本地构建文档时需要安装 [`docs/requirements.txt`](docs/requirements.txt) 中的 Python 依赖。
- 只有使用可选 GF AI Developer Kit 项目工具时需要 Python 3.10 或更新版本。

## 安装

普通安装推荐使用 Godot Asset Store / Asset Library 官方页面下载的包，或 GitHub Release 中的 `gf-framework-<version>.zip`。这个包包含完整的 `addons/gf` 插件目录：kernel、standard、编辑器工具、包管理器和随包发布的可选内置扩展。可选扩展默认仍是关闭的，只有项目显式启用后才参与装配，所以完整包是默认首装入口。

如果只想做最小引导，可以从同一个 GitHub Release 下载 `gf-kernel-<version>.zip`，启用插件后再通过 `GF Package Manager` 或 Godot 原生命令行按需安装 package。这个模块化路径适合受控项目模板、离线包或团队内部 registry，但不作为 Godot 官方站点的默认下载包。

将包里的 `addons/gf` 复制到 Godot 项目中，然后在 `Project > Project Settings > Plugins` 启用 `GF Framework`。

Godot 不会在文件复制到 `addons` 后自动启用编辑器插件，这是正常行为。插件启用状态属于目标项目的 `project.godot`，需要用户明确启用后，编辑器插件代码才会运行。

插件启用后会自动注册 `Gf` AutoLoad：

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

插件还会默认打开独立的 `GF Workspace`。新项目只默认启用 GF kernel 与 standard 基础能力；随包发布的可选内置扩展保持关闭，直到项目显式启用。你可以在 `GF Extensions` 页面查看扩展 manifest、启用或禁用 GF 扩展、自动运行启用扩展的安装器、在导出时排除禁用扩展目录，并在需要时让禁用扩展引用导致导出检查失败。

GF 内置扩展保持原子化：只依赖 GF 的 kernel/standard 表面，不声明、不探测、不加载其他内置扩展。跨扩展组合由项目代码或 `addons/gf` 外的独立 Godot 插件负责。未使用的扩展可以禁用、从导出中排除，或在项目脚本、场景、资源和 preload 都不再引用后直接移除。

## 快速开始

```gdscript
extends Node


func _ready() -> void:
	if not await Gf.register_model(PlayerModel.new()):
		push_error("PlayerModel registration failed.")
		return
	if not await Gf.register_utility(GFStorageUtility.new()):
		push_error("GFStorageUtility registration failed.")
		return
	if not await Gf.register_system(BattleSystem.new()):
		push_error("BattleSystem registration failed.")
		return

	if not await Gf.init():
		push_error("GF initialization failed.")
		return

	var player_model := Gf.get_model(PlayerModel) as PlayerModel
	var battle_system := Gf.get_system(BattleSystem) as BattleSystem
	if player_model == null or battle_system == null:
		push_error("GF module lookup failed.")
		return
	battle_system.start_encounter(player_model)
```

较大的项目更建议使用项目安装器：

```gdscript
class_name GameInstaller
extends GFInstaller


func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var model_registered: bool = await architecture.register_model_instance(PlayerModel.new())
	if scope.is_cancel_requested():
		return
	if not model_registered:
		architecture.fail_initialization("PlayerModel registration failed.")
		return

	var utility_registered: bool = await architecture.register_utility_instance(GFStorageUtility.new())
	if scope.is_cancel_requested():
		return
	if not utility_registered:
		architecture.fail_initialization("GFStorageUtility registration failed.")
		return

	var system_registered: bool = await architecture.register_system_instance(BattleSystem.new())
	if scope.is_cancel_requested():
		return
	if not system_registered:
		architecture.fail_initialization("BattleSystem registration failed.")
		return
```

将安装器路径加入 `Project Settings > gf/project/installers`，然后用 `await` 调用 `Gf.init()`；如果返回 `false`，立即停止启动流程。Installer 只在初始化期间提供注册项，不能替代初始化调用及其结果检查。

需要移除 GF 时，按 [卸载、清理与恢复](docs/zh/overview/quickstart/uninstall.md) 的安全顺序操作；先禁用插件，再删除 `addons/gf`。

## 核心概念

- `GFModel`：数据与状态，包括 `to_dict()`、`from_dict()` 等快照或存档恢复入口。
- `GFSystem`：玩法逻辑、规则、事件、命令、查询和逐帧更新。
- `GFController`：基于 Godot `Node` 的桥接层，用于场景、UI、输入、表现和局部上下文。
- `GFUtility`：参与生命周期的运行时服务，例如存储、资源加载、设置、时间、音频、UI 栈、日志、诊断、输入、任务、对象池和场景流程。
- `standard/foundation`：纯算法、值对象、格式化、校验、公式、标签、黑板、图、网格、寻路、空间辅助和数据转换。它不参与 `GFArchitecture` 生命周期注册。

## 分层与扩展

GF 源码按稳定的所有权边界组织：

- `addons/gf/kernel`：运行内核、基础契约、架构容器、绑定、事件、命令、查询、工厂、AutoLoad 入口、扩展基础设施和核心编辑器集成。
- `addons/gf/standard`：稳定标准库，包括 foundation、input、utilities、状态机、命令历史、序列辅助和 common 支撑原语。
- `addons/gf/extensions`：随 GF 发布的可选原子内置扩展，例如 capability、interaction、feedback、camera、dialogue、action queue、combat、asset metadata、save、flow、network、turn-based、behavior tree、decision 评分、physics 辅助和 domain model。

`kernel` 不硬引用 `standard` 或可选扩展。`standard` 只依赖 `kernel`，不能通过扩展 ID、路径、动态加载或扩展内类名探测可选扩展。GF 内置扩展之间也保持互不认识；需要出现在标准库诊断或工具里的扩展能力，应由扩展侧通过通用注册 API 主动贡献，跨扩展编排留给项目代码或独立插件。

## 编辑器工具

GF 核心编辑器能力包括扩展管理、强类型 GF/config 访问器生成、项目常量、脚本模板、Inspector、Dock、导出辅助和 Node3D/Mesh/MeshLibrary 缩略图渲染。SaveGraph 诊断、Pattern2D 编辑等扩展工具只在对应可选扩展启用后贡献。

扩展专属编辑器工具由 `gf_extension.json` manifest 声明，并且只会在扩展启用时加载。

## AI 辅助项目开发

可选 `gf.tool.ai_developer` 包提供严格项目意图契约、观测快照、与 GF 版本绑定的能力/API 目录、受控 Agent 规则和审批式框架反馈流程。它要求项目业务与平台 SDK Adapter 留在 GF 外部，不会给游戏运行时或导出产物增加 AI/Python 依赖。

完整用法见 [AI Developer Kit 指南](docs/zh/editor/tools/ai-developer.md)。每个 GF Release 同时提供同版本 `gf-ai-developer-kit-<version>.zip` 独立产物，供支持的 Agent 宿主使用。

## 测试

测试套件通过维护入口运行 GUT；该入口会先导入干净项目，并校验 Godot 日志与整套测试通过摘要：

```powershell
python tools\gf_maintenance.py check --check gut --failed-only
```

维护检查位于 [`tests/gf_core/maintenance`](tests/gf_core/maintenance)，覆盖 API 注释、层级边界、已移除路径/类名、生成文档一致性、Read the Docs 结构和旧 Wiki 入口策略。

## 文档构建

```powershell
python -m pip install -r docs\requirements.txt
python tools\generate_api_reference.py --check
python tools\check_docs_quality.py --strict
python -m mkdocs serve
python -m mkdocs build --strict
```

`generate_api_reference.py --check` 会同时校验 XML Catalog、生成的 Markdown 页面，以及 API Reference 中的类和成员覆盖。

## 许可证

Apache License 2.0。见 [`LICENSE.md`](LICENSE.md)。
