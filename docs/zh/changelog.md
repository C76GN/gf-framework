# 更新日志 (Changelog)

## 📝 日志条目结构标准

每次版本更新应包含以下核心模块（若无相关变动可省略该模块）：

1. **版本号与日期**：格式为 `## [主版本.次版本.修订号] - YYYY-MM-DD`
2. **版本概述**：简短描述该版本的核心目标（如：大型特性更新、紧急修复、性能重构等）。
3. **🚀 新增特性 (Added)**：新加入的类、方法、系统、扩展组件等。
4. **🔄 机制更改 (Changed)**：对现有功能逻辑的修改、内部重构、性能优化等。
5. **🐛 Bug 修复 (Fixed)**：修复的逻辑错误、内存泄漏、崩溃问题等。
6. **⚠️ 废弃与移除 (Deprecated/Removed)**：标记为废弃（将在未来移除）或本次直接移除的接口、文件。
7. **🔌 API 变动说明 (API Changes)**：详细列出函数签名改变、属性重命名等直接导致旧代码报错的改动。
8. **📘 升级指南 (Migration Guide)**：为使用旧版本框架的开发者提供 Step-by-Step 的升级建议和兼容性处理方案。
9. **📁 核心受影响文件 (Affected Files)**：列出改动最大的核心源码文件，方便开发者进行二次开发比对。

---

## 维护策略

正式文档中的更新日志只保留当前最新发布版本。发布新版本时，应将 `[未发布]` 合并为具体版本条目，并删除上一个正式版本条目；旧版本历史以 Git 历史和 GitHub Releases 为准，避免正式文档长期膨胀。

---

## [5.2.0] - 2026-06-22

本版本是 5.x 内的兼容性重整版本。为移除运行时 Git / 外部进程依赖、统一构建元数据写入入口，并推进 package registry schema 2，本次接受少量破坏性 API 变更；受影响入口见下方 API 变动说明与升级指南。

### 🚀 新增特性 (Added)

- `GFConfigTableResource` 新增通用 `.tres/.res` 配置表资源，支持表名、schema、记录列表、ID 索引、命名索引缓存和元数据。
- `GFConfigDatabaseResource` 新增通用 `.tres/.res` 配置数据库资源，支持多表聚合、表资源访问、索引重建和数据库级校验。
- `GFResourceConfigProvider` 新增 Resource 表 Provider，可把 `GFConfigTableResource` 或 `GFConfigDatabaseResource` 接入 `GFConfigProvider` 的整表、按 ID 和按命名索引查询协议。
- 新增可选 `gf.tool.config_pipeline` 工具包，可用 `GFConfigPipelineTableSource`、`GFConfigPipelineProfile` 与 `GFConfigPipelineRunner` 把 CSV / JSON / XLSX 表来源批量构建为 `GFConfigTableResource` / `GFConfigDatabaseResource` 并保存为 Godot `.tres/.res` 或 JSON 导出。
- `GFConfigPipelineTableSource.schema_options` 新增 `typed_headers` 表头声明能力，可从 `id:int!`、`name:string`、`power:float` 这类 CSV / XLSX 表头生成通用 schema 并清理记录字段名。
- `GFConfigAccessGenerator` 新增可选 `include_typed_records` 生成模式，可根据 schema 字段声明生成记录包装类和 typed record 读取方法。
- `GFConfigPipelineProfile` 新增可选访问器生成配置，`GFConfigPipeline.export_profile()` 可在保存数据库后同步生成静态配置访问器脚本并返回 `access_result`。
- `GFInputContextDiagnostics` 新增输入上下文诊断工具，可复用同一套标准报告检查输入映射结构、绑定冲突和 ProjectSettings/Input Map action 引用。
- `GFInputAssistUtility` 新增 `grace_window_expired(window_id, player_index)` 信号，用于监听宽容窗口自然倒计时结束。
- `GFDownloadUtility` 新增下载清单解析、批量入队、任务快照和多任务聚合进度 helper，可复用现有下载队列处理 manifest 驱动的文件批次。
- `GF Package Manager` 新增显式 `update` 操作与 CLI `update [<package-id>...] [--all-installed]`，可只更新 lockfile 中已安装的 package，或一次性对齐全部已安装 package。

### 🔄 机制更改 (Changed)

- 资源路径字符串 Inspector 现在会为 `uid://` 字段显示解析后的 `res://` 路径，并对无效 UID、缺失资源或类型不匹配给出字段级状态提示。
- `GFInputMappingDock` 现在复用 `GFInputContextDiagnostics` 构建报告，避免编辑器页面私有诊断逻辑与项目工具重复实现。
- `GFConfigPipeline` 现在会把空来源数据库构建报告为失败，避免静默生成没有表来源的配置数据库。
- `GFConfigAccessGenerator` 现在会规范化和去重生成的 class、常量、方法、记录类与字段 getter 名称，避免脏表名、保留字或重复字段生成不可编译的 GDScript。
- `GFConfigPipeline.save_database()` 现在会按 `.json` 扩展名或 `output_format` 保存通用 JSON 导出，`make_database_export()` 可在不写文件时返回同结构导出字典，便于项目侧差异审查、热更新打包或外部发布流水线接管。
- `GFConfigPipelineProfile` 与 `GFConfigPipelineTableSource` 现在明确归类为 tool API，并在工具包文档入口中说明制作期边界。
- `GF Package Manager` 工作区页面新增工具包过滤视图，并在包排序中明确处理 `tool` package kind。
- `GF Package Manager` 生成的 registry index 升级为 schema 2，根节点和每个 package entry 都声明 GF 框架版本兼容范围；状态、安装预览和真实安装会在 staging 前拒绝不兼容的 registry 或 package。
- `GF Package Manager` 默认在线源现在优先使用当前 GF 版本对应的 release registry source，只有开发版无法解析 SemVer 时才回退到 latest。
- `GF Package Manager` 的编辑器页面新增“预览更新”“更新”和“更新全部”操作；更新会复用安装事务的闭包解析、archive 校验、staging、回滚和 lockfile 写入，但不会把依赖包误标为手动安装。
- `GFResourceConfigProvider` 现在拒绝注册 `table_name` 与 `schema.table_name` 不一致的表资源，`GFConfigDatabaseResource` 校验会报告同类问题。
- `path-hygiene` 现在会拒绝带 UTF-8 BOM 的 `.gd` 文件，确保 GDScript 源码维持 UTF-8 无 BOM。
- `GFBuildInfo` 不再从运行时包内直接调用 Git，而是通过构建系统无关的 `write_metadata_to_project_settings()` 接收外部流水线提供的构建元数据。
- 构建信息导出的 ProjectSettings 注册现在由标准库 debug 编辑器贡献主动声明，`kernel/editor` 只保留通用设置注册机制。
- `package-external-command-audit` 在维护检查套件中升级为严格模式，只有显式 allowlist 的编辑器跳转可保留，新的 package 内外部命令调用会被拦截。
- `resource-boundary` 默认将脚本依赖和编辑器 metadata 加载归入 observations 汇总，按 runtime / editor / tool / test 来源、source / target package 和 source-to-target package 矩阵分组，`issues` 只保留需要行动的资源加载问题，并在维护检查套件中启用 `--fail-on-issues`。
- GDScript 解析维护测试新增 warning-clean 静态门禁，提前拦截遮蔽全局 `class_name` 的脚本常量、未收窄的 GF 类强转，以及对 `Script` 类型变量直接 `.new()` 的写法。
- `check --suite quick` 收敛为轻量日常检查，并新增 `check --suite package` 聚合 package 构建、安装、Godot CLI 和卸载 smoke；`full` / `release` 仍覆盖完整生态验证。

### 🐛 Bug 修复 (Fixed)

- `GFConfigPipeline` 与 Runner 的结果摘要不再先深拷贝完整表或数据库 Resource 后再移除重字段，降低大表导入时的内存峰值。
- `resource-boundary` 不再把普通字符串内容里的 `preload()` / `load()` 文本误判为真实资源加载调用，减少测试生成源码字符串带来的观测噪音。
- 清理 `GFBuildInfo`、下载 manifest 解析、配置导表资源复制、资源注册表依赖测试和相关测试的 Godot reload warning，并在维护规范中补充 GDScript warning-clean 规则。
- `GFDownloadUtility.get_tasks_progress()` 现在按请求 ID 一次性构建任务快照 lookup，避免大清单进度聚合对等待队列重复线性扫描；断点续传分段追加改为固定块写入，避免一次性读取完整 segment。
- 配置引用校验与解析现在在单次调用内复用目标表索引，`GFConfigTableResource.get_index_record()` 也不再为了获取第一条记录复制整个索引 bucket。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `GFBuildInfo.collect_git_metadata()` 与 `GFBuildInfo.write_git_metadata_to_project_settings()`。项目需要 Git 信息时，应由 CI、编辑器脚本或外部构建工具采集后写入通用构建元数据。

### 🔌 API 变动说明 (API Changes)

- 新增 `GFBuildInfo.write_metadata_to_project_settings(build_data, extra_metadata, save_settings)`，替代 Git 专用构建信息写入入口。
- `GFBuildInfoExportPlugin.ENABLED_SETTING` 对应的 ProjectSettings 键从 `gf/build/export/write_git_metadata` 调整为 `gf/build/export/write_metadata`，并新增 `GFBuildInfoExportPlugin.BUILD_METADATA_SETTING` 对应 `gf/build/export/build_metadata`。

### 📘 升级指南 (Migration Guide)

- 旧项目如果调用 `GFBuildInfo.write_git_metadata_to_project_settings()`，改为先在项目侧采集 Git/CI 字段，再调用 `GFBuildInfo.write_metadata_to_project_settings()`。
- 旧项目如果启用了 `gf/build/export/write_git_metadata`，改为启用 `gf/build/export/write_metadata`，并按需把构建字段写入 `gf/build/export/build_metadata`。
- 自建 GF package registry 需要用当前 `tools/build_gf_package.py` 重新生成 schema 2；旧 schema 1 registry 会被当前安装器拒绝。旧 GF 项目安装 package 时应使用同版本 release registry / offline bundle，或先升级 GF 框架后再安装新版 package。
- 手动替换或升级 `addons/gf` 后，先刷新 Package Manager 或运行 `status`，再执行 `update --all-installed` 对齐已安装 package。`update` 不会隐式安装未在 lockfile 中的 package，新增包仍使用 `install`。
