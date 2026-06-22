# GF 维护者资料

本页收拢 GF 项目的维护规则、分层边界、扩展约束、生成文档和发布检查流程。面向使用者的项目实践建议维护在 `docs/zh/overview/best-practices/index.md`；公开 API 的可见性、类型分类和文档标签规范见仓库根目录的 `API_SURFACE.md`。编辑器层维护约束见 `docs/maintainers/editor.md`。

## 使用类型断言

从架构中取得模块后，推荐立刻使用 `as Type` 获得明确类型。这样能保留 IDE 补全，也能让调用点更清楚。

```gdscript
var player_model := Gf.get_model(PlayerModel) as PlayerModel
if player_model == null:
	return

player_model.set_run_speed(30.0)
```

如果一个查询可能失败，调用点应该显式处理 `null`。不要把依赖缺失隐藏在后续属性访问错误里。

## 不要让 Model 只剩字段

`GFModel` 是数据层，但不是只能保存裸变量。和数据一致性直接相关的操作应放在 Model 内部，例如生命值钳制、背包容量限制、进度合并和状态快照。

```gdscript
class_name PlayerModel
extends GFModel

var hp: int = 100
var max_hp: int = 100


func apply_damage(amount: int) -> void:
	hp = maxi(hp - maxi(amount, 0), 0)


func heal(amount: int) -> void:
	hp = mini(hp + maxi(amount, 0), max_hp)
```

`GFSystem` 负责规则流程，`GFModel` 负责状态自身的合法性。这样即使多个系统修改同一个 Model，也更不容易写出非法状态。

## Controller 应该可以被删除

`GFController` 是 Godot 场景树和 GF 架构之间的桥。它可以处理输入、动画、UI、节点引用和场景信号，但核心业务规则不应写死在 Controller 中。

一个简单检验是：删除某个表现节点后，底层 Model 和 System 是否仍能正常推进。如果删除 UI、角色显示节点或特效节点就让核心规则无法运行，说明表现层承担了过多职责。

## 合理使用事件

事件适合跨模块通知，但不适合替代所有函数调用。

- UI 展示 Model 字段变化时，优先用 `GFBindableProperty` 或明确的绑定逻辑。
- 同一个类内部的连续步骤，直接调用私有方法。
- 同一 System 内部的计算流程，直接传参。
- 跨 System、跨 Utility 或跨局部上下文的通知，再使用类型事件或 simple 事件。

事件监听应优先绑定 owner。动态节点、临时模块和场景对象释放时，应通过 owner 让框架自动清理监听。

## ready() 中保持防御

GF 会按生命周期阶段推进模块，但大型项目中模块可能由扩展 Installer、项目 Installer、局部 `GFNodeContext` 和运行时动态注册共同装配。`ready()` 中读取其他模块时，应允许依赖暂时不存在或尚未完成 ready。

需要强依赖时，使用依赖诊断或在 Installer 中明确装配顺序；需要弱依赖时，使用 `get_utility(..., require_ready = true)` 这类查询，并在缺失时跳过本轮逻辑。

## 分清代码归属

新增能力时，先判断它属于哪一层：

- `kernel`：GF 启动、架构容器、基础契约、事件、绑定、扩展基础设施、核心编辑器装配。
- `standard/foundation`：纯值对象、纯算法、纯格式化、纯转换、纯校验。
- `standard/utilities`：默认稳定、足够通用、需要生命周期或运行时状态的服务。
- `standard/input`、`standard/state_machine`、`standard/sequence`：稳定标准能力。
- `extensions`：通用但可选的 GF 内置原子能力。
- `addons/gf` 外的独立插件：项目本地、跨扩展组合或更偏业务的扩展。
- 项目代码：具体玩法、关卡、SDK 适配、资源路径、业务表结构。

如果一个能力不需要框架生命周期，优先保持为纯对象或 Resource；如果它开始管理缓存、异步、事件、全局状态或跨模块服务，再考虑成为 Utility 或扩展 Installer 注册项。

新增跨层能力时还要遵守加载边界：

- `kernel` 不能直接引用 `standard` 或 GF 内置扩展的具体类名；需要内核识别的能力先抽成 kernel 契约。
- `kernel/editor` 不能硬编码可选扩展 ID、扩展模板或扩展内 Inspector；这些能力由扩展 manifest 注入。
- `standard` 不能硬 preload GF 内置扩展、写死 GF 内置扩展脚本路径、硬编码 GF 内置扩展 ID、动态探测 GF 内置扩展或直接类型引用 GF 内置扩展类。
- GF 内置扩展必须保持原子化，只能依赖 `gf.kernel` 与 `gf.standard`，不能声明其他 GF 内置扩展硬依赖或软协作字段，也不能通过路径、扩展 ID、`class_name` 或动态加载引用其他 GF 内置扩展。
- 可选扩展需要出现在诊断、Overlay、工具快照或其他标准库通道时，必须由扩展侧向标准库提供的通用注册入口主动贡献。

## Godot 物理以引擎为准

碰撞、刚体、导航、Area 和 RayCast 这类能力应由 Godot 节点负责采集事实，再交给 GF 的命令、事件或系统处理业务结果。

推荐流程：

1. Controller 或桥接节点读取 Godot 物理结果。
2. 把命中、接触、输入或区域变化转换成清晰的命令/事件/Payload。
3. System 根据这些事实修改 Model 或派发后续结果。

不要在纯 System 中维护一套和 Godot 场景树并行的“影子物理世界”，除非它是明确的纯模拟模型，并且不依赖实际场景节点。

## Controller 宿主引用

当 Controller 作为某个场景节点的输入、动画或状态桥接层时，推荐把 Controller 放在宿主节点下面，并使用 `get_host()`、`get_host_as()` 或 `host` 获取宿主引用。

```gdscript
class_name MovementController
extends GFController

@export var speed: float = 160.0

@onready var _body: CharacterBody2D = get_host_as(CharacterBody2D) as CharacterBody2D


func _physics_process(_delta: float) -> void:
	if _body == null:
		return

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_body.velocity = input_vector * speed
	_body.move_and_slide()
```

不推荐把 `owner` 当作运行时宿主引用。`owner` 表示编辑器场景所有权，不等同于父节点，也不一定是逻辑控制目标。

## 扩展使用规则

GF 内置扩展默认随 GF 启用，但仍保持可选边界。项目不用某个 GF 内置扩展时，可以在 `GF` 工作区的 `GF Extensions` 页面禁用它；如果导出时启用了排除禁用扩展，扩展目录不会进入导出产物。

禁用或删除扩展前，应确认项目没有直接引用该扩展：

- 脚本中的 `preload()` / `load()` 路径。
- 场景、资源或导入文件中的脚本路径。
- 生成访问器中的扩展类型或扩展路径。
- 直接使用扩展内 `class_name` 的类型声明。

`GF` 工作区的 `GF Extensions` 页面提供“扫描引用”，导出开始时也会检查禁用扩展引用。发布前可启用“引用禁用扩展时阻止导出”，把这类问题提升为导出错误。

分层边界必须按硬规则维护：`kernel` 不认识 `standard` 或任何 extension；`standard` 只认识 `kernel`，不能通过扩展 ID、扩展路径、动态脚本探测或扩展内类名弱联动 GF 内置扩展；GF 内置扩展只能依赖 `kernel` 和稳定的 `standard`，彼此保持互不认识。需要跨 GF 内置扩展协作时，应放到项目 Installer 或 `addons/gf` 外的独立插件中。如果扩展能力需要显示在标准库诊断、Overlay 或工具快照里，应由扩展侧向标准库的通用注册入口贡献能力，而不是在标准库中写扩展探测逻辑。

需要导出阶段能力时，优先通过扩展 manifest 的 `export_plugin_paths` 声明入口，并让导出逻辑只处理扩展目录、审计结果或平台无关的资源准备。平台 SDK、项目账号、在线服务和私有后端应放在项目 Installer、独立插件或可替换 backend 中；GF 内置扩展最多提供抽象 facade 与空实现 fallback，避免把平台或业务假设写入框架层。

## 测试建议

源码变更后优先运行：

```powershell
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gf_core -ginclude_subdirs -gexit
```

测试目录按框架层级组织：

- `tests/gf_core/maintenance`：API 注释、API Surface Contract、GDScript 布局、脚本解析、扩展边界等静态维护检查。
- `tests/gf_core/kernel`：内核、生命周期、事件、编辑器基础设施和扩展基础设施。
- `tests/gf_core/standard`：标准库。
- `tests/gf_core/extensions`：GF 内置扩展。
- `tests/gf_core/fixtures`：测试夹具。

移动目录、重命名公开类或移除公开脚本后，维护测试还会检查已移除公开类名、重复 `class_name` 和 `.gd.uid` 冲突。不要保留副本脚本；公开入口应只有一处真实定义。

公开 API、文档或生成器变化后，还应检查正式 API Catalog 和 API Reference：

```powershell
python tools\generate_api_reference.py
python tools\generate_api_reference.py --check
```

`--check` 会同时校验三件事：XML Catalog 与源码一致、Markdown Reference 与生成器一致、Catalog 中的公开类和成员都能在对应 Reference 页面找到。

`tools/generate_api_reference.py` 与 `tools/generate_ai_api.py` 共用 `tools/gdscript_api_parser.py` 的 GDScript 声明扫描和 API 注释解析规则。维护生成器时应优先扩展共享解析器，避免正式 Reference 和 AI 摘要对 `class_name`、内部类、装饰导出变量或文档标签产生不同理解。

手写文档页面还应通过质量检查，避免页面重新变成长文堆积、缺少 H1 或代码块没有语言标注：

```powershell
python tools\check_docs_quality.py --strict
```

AI 维护任务需要快速索引源码时，仍可使用 `tools/generate_ai_api.py` 生成 `ai_analysis/generated_api`。该目录只服务 AI 阅读，不作为正式文档中间源。

## AI MCP 维护入口

GF 提供一个可选的本地 MCP server，作为 AI 维护工具入口。它只读取仓库状态、公开 API 索引和维护文档，并可按白名单运行既有检查命令；它不是 GF 运行时功能，也不进入 `addons/gf`。

```powershell
python tools\gf_mcp_server.py
```

常用的非 MCP CLI 入口：

```powershell
python tools\gf_maintenance.py summary
python tools\gf_maintenance.py workspace-status
python tools\gf_maintenance.py api-search GFAudioClip
python tools\gf_maintenance.py api-class GFValidationReportDictionary
python tools\gf_maintenance.py api-module extensions/domain
python tools\generate_api_coverage_matrix.py
python tools\gf_maintenance.py check --suite quick
python tools\gf_maintenance.py check --suite package
python tools\gf_maintenance.py check --suite full
python tools\gf_maintenance.py release-status --version 3.19.0
```

MCP 暴露的主要工具：

- `gf_project_summary`：返回 Git 状态、版本元数据、API Catalog 统计和维护入口。
- `gf_workspace_status`：返回按运行时代码、测试、手写文档、生成文档和维护工具分类的变更快照，并给出推荐检查命令。
- `gf_api_search`：按类名、成员名、路径或注释搜索 GF API，避免一次性读取大量源码。
- `gf_api_class`：返回单个 `class_name` 的路径、摘要、Reference 页面和公开成员。
- `gf_api_module`：返回单个模块的类清单、路径和成员计数，适合先理解模块边界再打开具体源码。
- `gf_run_checks`：运行 `api`、`docs`、`quick`、`package`、`full` 或 `release` 检查套件。
- `gf_release_status`：校验 `plugin.cfg`、扩展 manifest、`ASSET_LIBRARY.md`、`ASSET_STORE.md`、changelog、发布包归档规则和本地 tag 状态。

接入 MCP 客户端时，将 server 命令指向仓库根目录下的 `python tools/gf_mcp_server.py` 即可。不要把个人客户端配置、会话记录或 MCP 运行日志提交到仓库；需要新增维护能力时，优先扩展 `tools/gf_maintenance.py`，再让 MCP server 调用同一套函数。

准备补指南、测试或示例项目覆盖时，先运行 `python tools\generate_api_coverage_matrix.py`。生成结果位于 `ai_analysis/api_coverage/`，用于查看公开类和成员在非 Reference 正文、`tests/gf_core` 和未来 example 根目录中的命中情况；它是维护排查清单，不作为正式用户文档提交。

## 发布流程

GF 正式版本 tag 统一使用不带 `v` 的 SemVer 格式，例如 `3.5.0`。不要使用 `v3.5.0`，避免编辑器版本检测、发布自动化和 Asset Library 元数据出现两套版本名。

准备发布时，应先把 `[未发布]` 合并为对应版本条目，并同步更新这些位置：

- `addons/gf/plugin.cfg` 的 `version`。
- `ASSET_LIBRARY.md` 的 `Asset Version` 与 `Download Commit/URL`。
- `ASSET_STORE.md` 的 `Current release version` 与 `Release tag`。
- 所有 `addons/gf/extensions/*/gf_extension.json` 的 `version`。
- `docs/zh/changelog.md` 中对应 `## [x.y.z] - YYYY-MM-DD` 段落。

推送 `x.y.z` tag 后，GitHub Actions 的 `Release` 工作流会从该 tag 对应源码中提取 changelog 版本段，校验上述版本号一致，并检查 Asset Store 标签与 AI 披露字段，构建文档，然后创建 GitHub Release。Release 的源码 zip/tar.gz 由 GitHub 自动提供；GF 当前不额外上传插件包，除非后续发布策略明确需要独立附件。

## 文档维护

文档应按功能归属更新：

- 内核、生命周期、依赖、事件、命令、查询：更新 `docs/zh/kernel/**`。
- 使用入口和项目落地建议：更新 `docs/zh/overview/**`。
- Foundation 与 Standard Utilities：更新 `docs/zh/standard/**`。
- 扩展规范和 GF 内置扩展：更新 `docs/zh/extensions/**`。
- 编辑器工具和代码生成：更新 `docs/zh/editor/**`。
- API Reference：更新源码 API 注释后运行 `tools/generate_api_reference.py`，并用 `--check` 校验生成物一致性和公开 API 覆盖。
- 维护流程、测试和发布规则：更新 `AI_MAINTENANCE.md` 或 `docs/maintainers/**`，不要写入公开正文。

行为变化、公开 API 变化、路径调整、移除和升级说明应写入 `docs/zh/changelog.md`。

根 README 使用双语入口：`README.md` 是 GitHub 默认英文页，`README.zh.md` 是中文页。两者应保持同一章节顺序和信息粒度；安装步骤、核心概念、分层说明、测试命令和文档入口变化时必须同步更新。`addons/gf/README.md` 只作为插件目录内的简短分发说明，链接根 README 与 Read the Docs，不承载完整正文。

## Read the Docs 结构

GF 文档使用 MkDocs 构建，并由 Read the Docs 托管。源码结构如下：

- `docs/zh/` 是中文文档源文件。
- `docs/en/` 是未来英文文档源文件。
- `mkdocs.yml` 维护全站导航、主题和 Markdown 扩展。
- `.readthedocs.yaml` 维护 Read the Docs 构建环境。
- `docs/requirements.txt` 锁定文档构建依赖。
- `docs/wiki/` 只保留 GitHub Wiki 的 Home、Sidebar 和 Footer 入口，不再作为正式正文来源。
- `docs/api_catalog/` 是正式 API Reference 的 XML 中间层，由 `tools/generate_api_reference.py` 生成；索引使用全局 `sourceDigest`，单类 XML 使用自身 `classDigest` 且不记录源码行号，避免单类 API 变化或纯位置变化造成无关 class XML 噪声。
- `tools/gdscript_api_parser.py` 是正式 API Reference 和 AI API 摘要的共享 GDScript 解析入口；除非检查目标必须运行在 Godot 内，否则不要在其他 Python 生成器里复制声明解析逻辑。

调整阅读顺序、增加页面或重命名页面时，应同步检查 `mkdocs.yml`、`docs/zh/index.md`、`README.md` 和站内交叉链接。除非确实改变页面职责，不应为了局部措辞优化重命名文件；文档 URL 会跟随 slug 变化，反复重命名会影响外部链接和翻译配对。

站内链接使用标准 Markdown 相对链接，例如 `[本地存储、编码、同步与快照](../standard/utilities/io/storage-snapshot.md)`。指向源码、命令、类名、设置键和文件路径时继续使用反引号。

`docs/zh` 的文件目录应和网站导航保持一致：顶层是 `overview/`、`kernel/`、`standard/`、`extensions/`、`editor/`、`reference/` 等语义目录，顶层 Markdown 只保留 `index.md`、`faq.md` 和 `changelog.md`。各组的 `index.md` 只作为导读，例如 `standard/utilities/io/index.md` 负责说明资源、存储与 IO 的页面入口；具体能力放到所属语义目录下的子页，例如 `standard/utilities/io/storage-snapshot.md`。新增专题时优先追加同组子页，不要把无关能力重新堆回一个长页面。

导航中的嵌套专题组必须对应真实目录，并用该目录的 `index.md` 作为总览。子页应放在同一目录内，保持导航层级、文件目录和未来本地化 slug 一一对应。

## 页面模板

普通能力页应先说明解决的问题和边界，再说明主要入口、典型用法和必要示例。目录入口页应保持更短，只承担导读职责。

目录 `index.md` 的推荐骨架：

- H1：目录或能力组名称。
- 导语：一句到两段说明本组职责。
- `## 阅读入口`：列出本目录下的稳定子页，并说明每页覆盖的主题。
- `## 使用边界`：说明本组负责什么、不负责什么，以及和项目层或其他模块的边界。
- `## API Reference`：顶层扩展入口和 Kernel / Standard 顶层入口应链接对应生成 Reference；普通专题入口可按需要链接。

单页能力文档不必强行拆出 `## 阅读入口`。如果该能力没有子页，应保留完整的 `## 使用边界`、核心类型或流程说明，并链接 API Reference。

顶层入口页的最低模板可以用脚本校验：

```powershell
python tools\check_docs_quality.py --fail-entry-templates
```

该检查会覆盖 `kernel/`、`standard/` 和 `extensions/` 下所有带子页的 `index.md`，要求这些目录入口至少包含 `## 阅读入口` 与 `## 使用边界`。Kernel / Standard 顶层入口和 GF 内置扩展入口还会检查对应 API Reference 链接。

发布前使用严格模式统一检查页面粒度、入口模板、本地链接、渲染敏感语法和公开正文中的维护流程泄漏：

```powershell
python tools\check_docs_quality.py --strict
```

## 页面粒度边界

拆分文档时必须先判断“这个页面是否值得单独阅读”，不能把每个段落都拆成独立页。目录和导航应对应真实主题边界，而不是对应每个二级标题。

一个普通正文页应至少满足这些条件：

- 有一个独立任务、概念、API 族或工作流，读者可以只打开这一页获得完整答案。
- 除 H1 外，通常应包含背景/边界说明、用法或规则、至少一个示例或明确的交叉引用。
- 通常不少于 12 行；低于这个阈值的正文页默认视为碎片候选。
- 页面标题能稳定作为 URL slug 存在，不会因为补充一两句说明就需要重命名。

这些内容不应单独成页，应合并到相邻主题页：

- 只有一段边界声明、限制说明或小型注意事项。
- 只有一个字段、一个设置、一个布尔开关或一个短列表。
- 必须和前后小节一起读才有意义的 setup/cleanup、格式/限制、概念/边界。
- 为了让导航“更细”而拆出的 5 到 8 行短页。

`index.md` 是例外：它可以很短，只负责说明该目录的职责、阅读入口和使用边界。正文子页如果低于粒度阈值，应优先回收合并，而不是继续扩展导航层级。

可以用脚本检查拆分粒度：

```powershell
python tools\check_docs_quality.py --report-fragments
```

当前碎片页合并完成后，应把粒度检查提升为失败模式：

```powershell
python tools\check_docs_quality.py --fail-fragments
```

`tests/gf_core/maintenance/test_docs_structure_validation.gd` 会检查 `docs/zh` 页面是否能从 `mkdocs.yml` 导航入口通过文档链接访问、导航路径是否真实存在、顶层目录是否为允许的语义目录、旧编号目录是否没有回流，并确认旧 GitHub Wiki 目录只保留入口文件。该测试还会限制左侧导航规模和深度，防止细节页重新塞回导航。`reference/api/classes/*.md` 是生成的 API 详情页，可通过 `not_in_nav` 保持可链接但不进入左侧导航；API 模块页必须保持索引形态，成员详情只放在单类页。这类结构问题应先修测试失败，再补正文内容。

旧 Wiki 不再维护正文副本、章节页或迁移页。`docs/wiki/Home.md`、`_Sidebar.md` 和 `_Footer.md` 只提供 Read the Docs 入口。需要修改正式内容时，应修改 `docs/zh/**`，再由 MkDocs / Read the Docs 发布。

## 本地化维护

后续维护中英文两份文档时，应把“编号 + 章节顺序”作为对齐标准，而不是只依赖翻译后的标题：

- 中文页和英文页保留相同语义目录与子页 slug，例如 `standard/utilities/io/storage-snapshot.md` 对应同一个存储与快照主题。
- 同 slug 页面保持相同一级标题数量和主要二级标题顺序；允许翻译标题，但不要改变内容边界。
- 代码示例、类名、方法名、ProjectSettings 键、路径、manifest 字段和命令行保持一致，不做语言本地化。
- 中文页新增或删除一段行为说明时，英文页应同步新增或删除同一信息；如果暂时不能翻译，应在维护记录或 PR 描述中明确标记待同步页。
- 不把同一概念复制到两种语言的多个页面中。中文和英文都应遵循“一个概念一个主说明页，其他页面只交叉引用”的规则。
- Changelog 的版本、API Changes 和 Migration Guide 应保持事实一致；翻译可以不同，但不得让两个语言版本描述出不同迁移路径。

双语文档准备阶段不建议先批量生成粗糙译文。应先保证中文主线页面边界稳定、重复内容归零、示例可运行，再按编号逐页翻译和校验。
