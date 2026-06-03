# GF AI 维护指南

本文档只给 AI 维护者使用，不作为面向普通用户的正式说明。它用于约束 AI 辅助维护 GF Framework 时的工作方式，重点说明：改完代码或文档后要同步检查哪些文件、文档应按什么标准补全、如何生成 AI 专用 API 文档，以及临时 AI 工作记录如何与 Git 提交内容隔离。

## 核心规则

- 文件优先按 UTF-8 读取和输出。
- GDScript 代码必须遵循 `CODING_STYLE.md`，包括文件结构、注释、类型提示、格式、编码和换行。
- 除非维护者明确批准破坏性升级，否则 GF 当前稳定主版本线保持向后兼容。
- 文档修改要小而聚焦。概念属于哪个页面，就优先补哪个页面，不要把同一段解释散落到多个地方。
- 不要修改 vendored `addons/gut/**`，除非任务明确要求处理 GUT。
- 不要提交临时分析、任务草稿、本地生成的临时上下文文件、调试报告或 AI 会话记录。
- 在大规模理解源码、补正式文档或检查 API 覆盖前，优先生成并阅读 AI 专用 API 文档。
- `.codex/skills/` 可以提交 GF 项目专用 Codex skill，用于沉淀维护流程、检查矩阵、发布流程和多子代理审查分工；它只描述“怎么做”，不能替代本文件、`CODING_STYLE.md`、`API_SURFACE.md` 的硬规则。评估 `ai_analysis/skills/` 中的外部候选时只能吸收可验证的工作流和检查点，不要直接复制玩法模板、示例脚本、强人格化话术或单个游戏项目业务规则。
- 参考项目维护在 GF 仓库同级目录 `../gf-reference-project`，也可用环境变量 `GF_REFERENCE_PROJECT_PATH` 指向其他本地路径；它不再位于仓库内 `examples/reference_project`。开发参考项目时，遇到重复劳动、框架痛点、抽象机会或最佳实践雏形，必须记录到 GF 侧 `ai_analysis/framework_feedback.md`。先判断它属于项目级约定、文档建议、工具能力还是框架候选，不要直接把单个示例项目的业务需求写进 `addons/gf`。
- `tools/sync_reference_project.py` 是显式写入同步命令；`tools/gf_maintenance.py check --suite examples` 默认只读校验外部项目中的 `addons/gf` 是否已经同步。需要在 examples suite 前自动写入同步时，必须显式传 `--sync-examples`，或先单独运行 `python tools\sync_reference_project.py --project-root ../gf-reference-project`。

## 层级边界规范

GF 源码依赖方向必须保持稳定单向：

```text
addons/gf/kernel <- addons/gf/standard <- addons/gf/extensions
```

- 抽象边界判断优先看“机制”与“策略”。GF 应沉淀稳定、通用、可测试的机制；具体业务规则、内容语义、项目流程、视觉风格和跨扩展编排策略留在项目侧或独立插件中。
- 如果项目或多个扩展反复绕开、复制或重写某个 GF 功能，它是边界审查信号，不是自动上移信号。先判断重复的是稳定机制、扩展点不足、API 使用成本、文档缺口还是业务策略：稳定机制可以上移或增强扩展点；业务策略应收敛、拆分或删除；文档缺口先补文档。
- 如果两个或更多 GF 内置扩展需要同一份通用机制，优先把最小稳定能力上移到 `addons/gf/standard`，再由扩展依赖标准库入口；不要让扩展互相引用，也不要在多个扩展中长期复制同一实现。
- 只有当上移内容属于框架启动、生命周期、依赖、注册、基础协议或内核必须识别的最小契约时，才考虑进入 `addons/gf/kernel`；普通项目可用工具、Resource、Binder、校验器、格式化器和运行时服务优先进入 `standard`。
- `addons/gf/kernel/**` 不能 `preload()`、`load()`、直接写入路径或直接引用 `addons/gf/standard/**` 的具体类名。
- `standard` 可以依赖 `kernel`；扩展可以依赖 `kernel`，也可以按需依赖稳定的 `standard`。
- 如果 `kernel` 运行时必须直接识别某个能力，应把最小契约、协议或基础工具放入 `kernel`，再让 `standard` 或扩展提供具体实现。例如内核识别 `GFTimeProvider`，标准库的 `GFTimeUtility` 只是实现。
- 可选 GF 内置扩展不能被 `kernel` 或 `standard` 硬 preload、硬编码 `res://addons/gf/extensions/**` 脚本路径、硬编码 `gf.*` 扩展 ID，或直接引用扩展内 `class_name`。
- `standard` 不能主动认识、探测或弱联动任何 GF 内置扩展。需要让标准库能力呈现扩展信息时，必须由扩展侧依赖 `standard` 的通用注册入口主动贡献，例如向 `GFDiagnosticsUtility` 注册快照、监控项或命令。
- GF 内置扩展必须保持原子化。内置扩展 manifest 的 `dependencies` 只能声明 `gf.kernel` 与 `gf.standard`，不能声明其他内置扩展硬依赖或软协作字段。
- GF 内置扩展之间不能通过其他内置扩展的路径、扩展 ID、`class_name`、动态脚本加载、动态扩展探测或隐藏协议形成软协作。跨扩展组合属于项目 Installer 或 `addons/gf` 外的独立插件，不能写回 GF 内置扩展。
- `kernel/editor` 可以承载通用菜单、文件对话框和模板生成器，但不能硬编码 `standard` 或可选扩展的具体模板类型、基类或扩展 ID；标准库模板由 `gf_standard_editor_extensions.gd` 注入，可选扩展模板由扩展自己的 `editor_action_paths` 注入。
- `GFEditorWorkspace` 未来可以承载更多原子化扩展工具，但内核只负责工作区外壳、导航、通用 UI、工具记录和生命周期；具体页面必须由 kernel、standard 或扩展按归属主动贡献。不要把单个扩展、项目业务或跨扩展组合流程硬编码进 workspace。
- 根插件 `addons/gf/plugin.gd` 是组合入口，可以收集标准库编辑器增强并传给 `kernel/editor` 辅助脚本；这个例外不允许扩散到 `addons/gf/kernel/**`。
- 移动层级边界时，同步更新源码路径、测试、正式文档、`docs/zh/changelog.md`、API Catalog 和 API Reference；不要留下重复路径副本造成重复 `class_name` 或 UID 冲突。
- 修改层级依赖后，必须运行 `tests/gf_core/maintenance/test_layer_boundary_validation.gd`，确保 `kernel` 不引用 `standard` / GF 内置扩展具体类型、`kernel` 不硬编码内置扩展 ID、`standard` 不引用扩展路径、扩展 ID 或扩展内类名，并确保 GF 内置扩展保持原子化、只依赖 `gf.kernel` 与 `gf.standard`。
- 重命名、移动或移除公开脚本后，必须运行 `tests/gf_core/maintenance/test_gdscript_parse_validation.gd`，确认已移除公开类名没有残留、公开 `class_name` 没有重复、`.gd.uid` 没有孤儿文件或 UID 冲突。

## 按变更类型检查文件

### 源码变更

修改 `addons/gf/**` 的公开行为后，检查并按需更新：

- `tests/gf_core/**`：为新增或变化的行为补充聚焦的 GUT 测试。
- `docs/zh/**`：更新负责解释该模块或概念的文档页面。
- `docs/zh/changelog.md`：记录新增、修复、行为变化、API 变化和迁移说明。
- `README.md` 与 `addons/gf/README.md`：仅当功能列表、快速开始、安装说明或项目定位发生变化时更新。
- `ASSET_LIBRARY.md` / `ASSET_STORE.md`：仅当 Asset Library、Asset Store 描述、版本、最低 Godot 版本或发布元数据变化时更新。
- `addons/gf/plugin.cfg`：仅在明确进行版本号升级时更新。

修改任何 `.gd` 文件后，额外执行以下布局检查：

- 对照 `CODING_STYLE.md` 的代码布局顺序检查被修改文件。
- 对照本文件的层级边界规范检查新增 preload、load、class_name 引用和路径常量。
- 顶层 section 必须遵循 `CODING_STYLE.md` 的整体顺序，不得在私有/辅助或内部类 section 后回到普通公共区。
- 以下划线 `_` 开头的内部方法，不得放在公共方法、获取方法、注册方法、事件方法等普通公共区。
- 供子类重写的 `_` 方法必须放在明确的可重写钩子或虚方法区。
- Godot 生命周期方法和信号回调方法必须放在对应区，或在确有必要时放在私有/辅助区。
- 通过反射、`has_method()`、`call()` 或约定名称调用的内部方法，不因此变成公共方法；仍按命名和语义归类。
- 带 `class_name` 的文件必须先写文件级 `##` 说明，再声明 `class_name` 与 `extends`。
- 顶层内部类必须放在明确的内部类 section 中，并优先位于文件末尾。

### 公开 API 变更

公开 API 包括 `class_name`、信号、导出变量、公共变量、枚举、公共方法、Resource 字段、ProjectSettings 项、存档格式和已文档化的行为。

新增或修改公开 API 后，检查：

- 变更文件中的 API 注释，尤其是公共函数的 `## @param`。
- 新增公开类型、公开成员或扩展点时，按 `API_SURFACE.md` 标注 `@api`、`@category`、`@since`、`@param`、`@return` 和必要的 `@schema`。
- 历史文件未完成规范文档注释迁移时，使用普通注释 `# @api_surface_migration partial` 标记；严格规则全部满足后必须移除该标记。
- 私有实现细节不要使用 `##`；需要解释实现原因时使用普通 `#`。
- `tests/gf_core/maintenance/test_api_docs_validation.gd` 的隐含要求：注释参数必须和函数签名双向一致。
- `tests/gf_core/maintenance/test_api_surface_contract_validation.gd` 固化 API Surface Contract 的正反例，后续迁移 `addons/gf` 时应扩展扫描范围或引入 baseline。
- 对应文档页面。
- `docs/zh/changelog.md` 的 `API Changes` 与 `Migration Guide`。

移除公开 API 或改变默认行为时：

- 当前稳定主版本线默认不做，除非维护者明确批准。
- 一旦批准，应说明为什么破坏兼容，并按 SemVer 的下一个主版本处理。

### 纯文档变更

只改文档时，检查：

- `docs/zh/index.md` 与 `mkdocs.yml`：新增、删除、重命名页面或调整阅读顺序时更新。
- `docs/api_catalog/**` 与 `docs/zh/reference/api/**`：生成物只能通过 `tools/generate_api_reference.py` 更新，不手写。
- `README.md` 与 `README.zh.md`：根目录概览、文档索引或项目定位过期时同步更新，保持同一章节顺序和信息粒度。
- `addons/gf/README.md`：安装扩展内说明需要与根目录概览保持一致时更新。
- `docs/wiki/**`：只保留 GitHub Wiki 入口、侧栏和页脚；正式正文只能维护在 Read the Docs 源文件 `docs/zh/**` 中。
- 新增、删除或重命名 `docs/zh/**/*.md` 时，运行 `tests/gf_core/maintenance/test_docs_structure_validation.gd`、`python tools\check_docs_quality.py --strict` 和 `python -m mkdocs build --strict`，确认页面已进入导航或可从导航入口通过文档链接访问、页面形态可维护且链接有效。`docs/zh/reference/api/classes/*.md` 是生成的单类 API 详情页，允许通过 `mkdocs.yml` 的 `not_in_nav` 保持可访问但不进入左侧导航。公开 API 变化后还要运行 `python tools\generate_api_reference.py --check`。
- 修改 `docs/wiki/**` 时，同样运行 `tests/gf_core/maintenance/test_docs_structure_validation.gd`，确认旧 Wiki 没有重新变成正文副本。

仅修错字或改善措辞时，不需要为 changelog 添加条目，除非改动影响发布说明或迁移指导。

### 发布变更

明确进行版本发布或版本号升级时，这些文件必须一起检查：

- `addons/gf/plugin.cfg`
- `ASSET_LIBRARY.md`
- `ASSET_STORE.md`
- `docs/zh/changelog.md`
- `README.md` 与 `addons/gf/README.md`，如果公开概览发生变化

版本与提交流程：

- 功能开发、修复或文档补充过程中，如果需要记录发布说明，先写入 `docs/zh/changelog.md` 的 `[未发布]` 小节；如果没有 `[未发布]` 小节，就在最新正式版本上方创建。
- 在用户确认本轮修改没有问题之前，不要把 `[未发布]` 改成具体版本号，也不要更新 `addons/gf/plugin.cfg`、`ASSET_LIBRARY.md` 或 `ASSET_STORE.md` 的版本号。
- 用户确认进入发布或提交阶段后，根据实际变更确定 SemVer 版本号：兼容 bug 修复或小型加固用 patch；向后兼容的新公开 API、设置或功能通常用 minor；破坏兼容只允许在用户明确批准后按 major 处理。
- 确定版本后，把 `[未发布]` 改为具体版本条目，同步更新 `addons/gf/plugin.cfg`、`ASSET_LIBRARY.md`、`ASSET_STORE.md`、所有 GF 内置扩展 `gf_extension.json` 的 `version` 和必要的发布说明；保留未来新工作的 `[未发布]` 创建时机由下一轮维护决定。
- GF 内置扩展 manifest 的 `version` 表示 GF 发行版本，发布时所有 `addons/gf/extensions/*/gf_extension.json` 必须同步为当前 GF 版本。内置扩展 manifest 的 `extension_version` 表示单个扩展自身版本，只有该扩展的公开 API、配置、行为或兼容性契约发生变化时才按 SemVer 递增；本轮未改变的内置扩展只同步 `version`，不递增 `extension_version`。
- 正式 `docs/zh/changelog.md` 只保留当前最新发布版本。发布新版本时必须删除上一个正式版本条目，旧版本历史以 Git 历史和 GitHub Releases 为准，不要让旧日志长期堆积在正式文档中。
- GF 版本 tag 统一使用不带 `v` 的 SemVer 格式，例如 `3.5.0`。推送这类 tag 后，`.github/workflows/release.yml` 会校验 `plugin.cfg`、内置扩展 manifest、`ASSET_LIBRARY.md`、`ASSET_STORE.md` 与 changelog 版本一致，构建文档，并用对应 changelog 段落创建 GitHub Release。
- Godot Asset Store 下载包必须使用 `tools/build_asset_store_package.py` 生成的专用 ZIP，不使用 GitHub 自动生成的 `Source code (zip)`。专用 ZIP 的根目录必须直接是 `addons/`，插件内容位于 `addons/gf/**`，不能多包一层仓库名或版本目录。
- Asset Store 专用 ZIP 默认输出到被 Git 忽略的 `build/gf-framework-<version>.zip`。打包脚本只写入可安装插件载荷，排除 `.import`、`.godot`、`.import/`、临时日志和本地缓存文件；Godot 会在用户项目中从源资源重新生成导入缓存。
- 发布前运行 `python tools\build_asset_store_package.py --version <version>` 并确认输出中 `top=['addons']`；再运行 `python tools\gf_maintenance.py release-status --version <version>`，该检查会临时生成并校验 Asset Store ZIP 结构。
- 除非用户明确要求 AI 直接提交，否则只准备 commit message 和待提交文件清单，让用户手动提交。若用户明确要求 AI 提交，提交前必须再次运行相关测试和文档/API 校验。
- 提交后不要自动创建 Git tag；只有用户明确要求打 tag 时，才创建对应版本 tag。

Commit message 模板：

```text
<Imperative summary>

<One paragraph or short bullet-style body describing what changed. Files changed: list the main modules, tests, docs, and metadata touched. Purpose: explain why the change exists and what project-level problem it solves.>
```

示例：

```text
Release 1.23.3 lifecycle dependency hardening

Add installer timeout protection, manual scoped context initialization, assignable lookup caching, factory lifetime validation, factory alias warnings, and GFAccess fallback injection consistency. Files changed: core lifecycle and binding scripts under addons/gf/kernel/core, accessor generation under addons/gf/kernel/editor, plugin project settings metadata, focused gf_core tests, lifecycle/accessor docs, changelog, plugin.cfg, and ASSET_LIBRARY.md. Purpose: make lifecycle and dependency ownership failures surface earlier while keeping GF current stable behavior compatible.
```

源码变更后优先运行：

```powershell
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gf_core -ginclude_subdirs -gexit
```

该测试集包含静态维护检查，例如 API 注释同步和 GDScript 布局约束。能用机器稳定判断的维护规则，应优先补到测试或工具中，而不是只写在文字说明里。

层级边界变更后至少额外运行：

```powershell
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/gf_core/maintenance/test_layer_boundary_validation.gd -gexit
```

## 文档维护标准

每个文档页面应尽量回答这些问题：

- 这个模块解决什么问题？
- 项目什么时候应该用它，什么时候不该用？
- 主要入口类有哪些？
- 生命周期、所有权或注册规则是什么？
- 常见工作流是什么？
- 和旧版本或兼容 API 有什么关系？
- 哪些源码或测试文件适合作为参考？

页面可按需要使用这些章节：

- `定位`
- `核心类`
- `典型流程`
- `常用 API`
- `注意事项`
- `与其他模块的关系`
- `迁移与兼容`

示例要短，并尽量保持 Godot 4.6 / GDScript 风格可用。除非页面就是示例页，否则不要把具体项目玩法规则写成框架规则。

MkDocs 页面拆分约定：

- `docs/zh` 的文件目录必须和 Read the Docs 信息架构保持一致，顶层只保留 `index.md`、`faq.md`、`changelog.md` 以及 `overview/`、`kernel/`、`standard/`、`extensions/`、`editor/`、`reference/` 等语义目录。左侧导航只承载主入口、专题总览和参考索引，细节页通过对应总览页的“阅读入口”链接进入。`tests/gf_core/maintenance/test_docs_structure_validation.gd` 会限制导航规模和最大深度，新增页面时不要为了消除 MkDocs omitted warning 把细节页重新挂回导航，应优先补入口页链接和 `not_in_nav`。
- 每个语义目录的 `index.md` 作为本组导读，只放定位、入口和边界，不再承载大量具体 API 说明。
- 导航中的嵌套专题组必须对应一个真实目录，并用该目录的 `index.md` 作为“总览”。例如 `standard/utilities/io/assets-jobs-warmup/index.md` 承载“资源加载、下载、任务队列与预热”总览，子页放在同一目录下；不要把同组子页平铺在父目录中。
- 具体能力放入所属层级下的语义子目录或子页，例如 `standard/utilities/io/storage-snapshot.md`；新增专题时优先追加同组子页，不要把无关能力重新塞回一个长页面。
- 中英文本地化时，`docs/zh` 与未来 `docs/en` 应保持相同目录 slug、子页 slug 和导航层级；翻译标题可以不同，但页面职责和内容边界必须一致。

正式 API Reference 生成命令：

```powershell
python tools\generate_api_reference.py
```

校验当前 XML Catalog 和 Markdown Reference 是否与源码一致：

```powershell
python tools\generate_api_reference.py --check
```

该检查同时确认 XML Catalog 与源码一致、Markdown Reference 与生成器一致，并验证 Catalog 中的公开类和成员都出现在对应 Reference 页面中。

校验手写文档页面长度、段落长度、H1 数量、代码块语言标注、页面粒度、顶层扩展入口模板和公开正文中的维护流程泄漏：

```powershell
python tools\check_docs_quality.py --strict
```

生成链路固定为 `addons/gf/**/*.gd` 中的 API 注释 -> `docs/api_catalog/index.xml` 与 `docs/api_catalog/classes/*.xml` -> `docs/zh/reference/api/*.md` 模块索引和 `docs/zh/reference/api/classes/*.md` 单类页面。`docs/api_catalog` 是结构化中间层，可用于 schema 校验、翻译和多格式输出；不做反向写回源码，不允许手写 Markdown Reference，也不允许从 Catalog 覆盖源码签名或业务代码。Catalog 索引保存全局 `sourceDigest`，单个 class XML 保存自身 `classDigest`，且不记录源码行号，避免单类 API 变化或纯位置变化引发无关 class XML 变更。

API Reference 必须保持“总览 -> 模块索引 -> 单类详情页”的形态。模块页只放模块内类表和到单类页的链接，不承载成员详情；成员详情只生成到 `docs/zh/reference/api/classes/*.md`。结构测试会限制模块 API 页长度并拒绝成员详情标题回流到模块页。

`tools/generate_api_reference.py` 与 `tools/generate_ai_api.py` 必须复用 `tools/gdscript_api_parser.py` 的 GDScript 声明扫描和 API 注释解析规则；不要在生成器里新增第二套 `class_name`、内部类、装饰导出变量或文档标签解析逻辑。GUT 中的 API Surface Contract 仍保留为独立的 Godot 运行时校验，因为它验证的是公开契约规则，不是生成器输出格式。

旧 GitHub Wiki 维护约定：

- `docs/wiki/Home.md`、`_Sidebar.md` 和 `_Footer.md` 只作为 Read the Docs 入口与旧链接导航。
- 不保留其他 `docs/wiki/*.md` 章节页、迁移页或兼容页。
- 不在 Wiki 中复制正式正文、API 说明、迁移指南或示例代码，避免与 Read the Docs 双写分叉。

README 双语维护约定：

- `README.md` 是 GitHub 默认英文入口，顶部保留 `README.zh.md` 的语言切换链接。
- `README.zh.md` 是中文入口，顶部保留返回 `README.md` 的语言切换链接。
- 两个根 README 的章节顺序、项目定位、安装步骤、核心概念、分层说明、测试命令和文档入口应保持一致；只允许语言表达不同。
- `addons/gf/README.md` 是插件分发目录的简短说明，只链接根 README 与 Read the Docs，不承载完整项目正文。

## AI 专用 API 文档

GF 的公开类和函数数量较多，AI 不可能每次都完整重读全部源码。维护任务开始时，应先生成或校验一份面向 AI 的 API 摘要，再按模块打开相关源码做抽查。

生成命令：

```powershell
python tools\generate_ai_api.py --source addons\gf --output ai_analysis\generated_api
```

校验当前生成结果是否和源码一致：

```powershell
python tools\generate_ai_api.py --source addons\gf --output ai_analysis\generated_api --check
```

旧 AI 摘要脚本仍保留 class name 入口覆盖检查：

```powershell
python tools\generate_ai_api.py --source addons\gf --output ai_analysis\generated_api --check --check-wiki-coverage
```

使用规则：

- 生成结果默认放在 `ai_analysis/generated_api/`，该目录被 Git 忽略，不提交。
- 生成脚本 `tools/generate_ai_api.py` 与共享解析器 `tools/gdscript_api_parser.py` 是维护工具，可以提交。
- 如果 `--check` 失败，先重新生成，再继续文档维护。
- `--check-wiki-coverage` 会递归扫描 `docs/zh/**/*.md` 并排除 `changelog.md`，要求每个公开 `class_name` 至少在正式功能页中出现一次；它只证明有入口，不证明描述已经足够准确。正式 API Reference 的类和成员覆盖以 `tools/generate_api_reference.py --check` 为准。
- 先读 `ai_analysis/generated_api/index.md`，确认模块分组和类路径。
- 查具体模块时读 `ai_analysis/generated_api/modules/*.md`。
- 需要结构化检索时读 `ai_analysis/generated_api/api.json`。
- 生成文档只是索引，不是最终事实来源。涉及行为细节、兼容语义、生命周期、副作用、存档格式或迁移说明时，必须再打开对应 `.gd` 源码和相关 `tests/gf_core/**` 测试核对。

生成内容包含：

- `class_name`、`extends`、文件路径和类摘要。
- 公共信号、枚举、常量、导出变量、公共变量和公共方法。
- 方法签名及其附近的 `##` 文档注释。
- 按目录或模块分组的 Markdown 摘要。
- `api.json` 结构化索引和 `source_digest`，用于判断摘要是否来自同一批源码。

每次公开 API 变化后，都要重新运行生成命令，并用 `--check` 确认当前 AI API 摘要准确。

## API 覆盖矩阵

规划指南、测试和未来示例项目覆盖时，先生成公开 API 覆盖矩阵：

```powershell
python tools\generate_api_coverage_matrix.py
```

生成结果默认放在 `ai_analysis/api_coverage/`，该目录被 Git 忽略，不作为正式用户文档提交。矩阵会从公开 API、非 Reference 正文、`tests/gf_core` 和显式传入的 example 根目录建立对应关系：

- API Reference 覆盖仍以 `python tools\generate_api_reference.py --check` 为准。
- Guide docs 覆盖表示非 Reference 正文中出现类名，或同一文件同时出现类名和成员名。
- Test / example 覆盖表示测试或示例文件中出现对应名称；它是排查入口，不等同于行为断言。
- 当前没有示例项目时，examples 覆盖为 0 是预期状态；后续新增示例项目后，用 `--examples <path>` 纳入矩阵。

公开 API 大规模变更、准备补示例项目或审计测试空洞时，应重新生成该矩阵，再按模块查看 `ai_analysis/api_coverage/modules/*.md`。

## AI MCP 维护入口

GF 的 MCP 接入只作为本地维护基础设施，不属于 `addons/gf` 运行时能力。普通用户安装 GF 时不需要 MCP，也不应让框架代码依赖 MCP 或任何 AI 插件。

可选本地 server：

```powershell
python tools\gf_mcp_server.py
```

无 MCP 客户端时使用同一套 CLI：

```powershell
python tools\gf_maintenance.py summary
python tools\gf_maintenance.py workspace-status
python tools\gf_maintenance.py api-search GFUuid
python tools\gf_maintenance.py api-class GFAudioClip
python tools\gf_maintenance.py api-module extensions/domain
python tools\gf_maintenance.py check --suite quick
python tools\gf_maintenance.py check --suite full
python tools\build_asset_store_package.py --version 3.19.0
python tools\gf_maintenance.py release-status --version 3.19.0
```

维护规则：

- MCP server 只暴露白名单工具：项目摘要、工作区变更快照、API 搜索、单类或单模块 API、预设检查套件、版本一致性检查、Asset Store 专用包结构检查和发布包元数据审计。
- 需要新增 AI 维护能力时，优先扩展 `tools/gf_maintenance.py` 的普通 CLI，再由 `tools/gf_mcp_server.py` 复用，避免 MCP 协议层和维护逻辑分叉。
- 不提交个人 MCP 客户端配置、会话记录或运行日志。
- 不把 MCP 当作正式文档或 API Reference 的事实来源；涉及行为细节仍需打开源码、测试和正式文档核对。

## AI 临时工作区

`ai_analysis/` 是 AI 临时工作区，已在 `.gitignore` 中忽略。

建议用途：

- `ai_analysis/ai_analysis.md`：当前任务摘要、决策、开放问题和下一步。
- `ai_analysis/todo.md`：大型未完成任务的临时清单。
- `ai_analysis/generated_api/`：本地生成的 AI API 摘要。
- `ai_analysis/reports/`：本地审计、diff、一次性检查结果。

使用规则：

- 内容要事实化、简洁，只记录恢复上下文所需的信息。
- 不让 `ai_analysis/` 无限堆积。每次新增分析、报告或生成物前，先判断是否已有同类文件可覆盖、合并或删除；任务结束时清理一次性草稿、过期快照和已被正式文档或最新报告替代的内容。
- 不确定某个文件是否仍有价值时，优先保留用户提供的素材源码、当前任务进度、最新生成索引和仍被维护命令引用的输出；只删除能确认已经过时、重复或临时的文件。
- 不把它当作面向用户的正式文档。
- 不在公开文档中把它写成必需项目文件。
- 除非维护者明确改变忽略策略，否则不要提交其中内容。
