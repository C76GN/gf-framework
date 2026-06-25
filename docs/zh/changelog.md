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

## [6.0.0] - 2026-06-25

本版本是 GF 6.0.0 主版本发布，汇总运行时生命周期、资源安全边界、编辑器工具、Package 管线和标准库能力的大规模增强。由于本轮包含移除旧构建元数据入口、调整部分项目设置键，以及 System/Utility tick 策略属性实现方式等破坏性 API 变化，因此按主版本发布。


### 🚀 新增特性 (Added)

- `GFSettingsUtility` 新增设置暂存层，可先 `stage_value()` 预览待应用值，再通过 `apply_staged_values()` 或 `discard_staged_values()` 完成设置页的“应用 / 取消”事务。
- 新增 `GFTableDataView`、`GFTableColumnDefinition` 与 `GFTableSelectionModel`，提供不绑定 Control 的通用表格数据视图、排序、过滤、单元格提交和稳定 row id 选择模型。
- `GFTableDataView` 与 `GFResourceTableEditor` 新增批量单元格提交入口，可一次应用多格变更、统一刷新，并返回包含成功、未变化与失败项的结构化报告。
- `GFViewportUtility` 新增移动安全区边距计算与 `MarginContainer` 应用入口，可把 `DisplayServer` 物理安全区转换为当前 Viewport 逻辑边距，并叠加项目自定义遮挡。
- 新增 `GFQuerySignature` 与 `GFCacheDiagnostics`，提供领域隔离的稳定查询签名和通用缓存命中/失效诊断快照。
- `GFTileMapCache` 新增区域片段、平移、占用矩形和 `TileMapLayer` 写回报告，便于编辑器工具或导入流程复用通用 tile 数据片段。
- `GFVariantReferenceCodec.decode_reference()` 新增 Resource 路径允许根目录与通配模式选项，便于从未确认来源恢复显式 Resource 引用时先收窄加载边界。
- `GFAssetUtility` 新增加载通道、并发上限、队列信号和缓存诊断快照，可对成组预热或流式加载做串行/限流调度。
- 新增 `GFResourceGraphScanner`、`GFResourceVariantProvider` 与 `GFRawResourceArtifact`，提供资源图诊断、资源键变体回退和原始文件字节物化能力。
- 新增 `GFImportPlan`，提供导入来源、目标、操作类型、source trace、预检报告和修复建议的通用计划结构。
- 新增 `GFPolicyProvider` 与 `GFPolicyRegistry`，为资源导入、构建产物、内容审查和项目工具提供通用 artifact 策略分发协议。
- 新增 `GFEditorCommandSession`，为编辑器工具提供 preview、commit、revert history 和命令调试快照。
- `GFContentPackageExportPlan` 新增内容包导出计划报告，可从 manifest 或 catalog 生成可审计的 source/archive 条目。
- Combat 新增 `GFBuffRecipe`、`GFBuffCheck`、`GFBuffEffect` 和 Buff 状态快照/移除原因入口，用于数据化 Buff、检查、生命周期效果和存档诊断。
- 新增 `GFThemeOverridePropertyList`，为自定义 `Control` 生成 Inspector 可识别的 theme override 属性列表，并可按声明收集、清空覆盖值或生成 `Theme`。
- `GFDiagnosticsUtility` 新增 Godot 调试器 bridge，标准编辑器插件提供 `GF Runtime Debugger` 会话页，可请求运行时快照、命令目录和受保护命令结果。
- 新增 `GFNetworkDirtyStateTracker`，为 Network 状态字典提供字段级脏检查、优先级分组和基线更新 helper。
- `GFObjectPropertyTools` 新增对象属性字典快照与批量应用入口，便于工具状态、编辑器草稿和轻量配置复用统一属性边界判断。
- 新增 `GFInputMapPresetTools`，可把运行时 `InputMap` 捕获为通用预设字典并应用回动作表；`GFInputProfileBank` 新增整体字典往返能力。
- `GFInputFormatter` 新增 `action_as_text()`、`action_as_rich_text()` 与 `action_icon()`，可按 InputMap 动作名读取 runtime / ProjectSettings 事件，并按首选设备类型输出文本或图标。
- 新增 `GFRuntimeTask`、`GFCallableRuntimeTask`、`GFRuntimeTaskGroup` 与 `GFRuntimeTaskScheduler`，提供按运行时对象 requirement 仲裁的任务调度、默认任务恢复和组合任务编排。
- `GFResourceRegistry` 新增搜索候选生成和文本搜索入口，复用 `GFTextSearchScorer` 对注册表 ID、路径、类型提示和字段值进行通用排序。
- `GFResourceRegistry` 新增条目摘要与分页搜索报告入口，可为资源选择器、调试面板或编辑器列表导出稳定的标题、说明、预览路径、标签、页码和当前页条目 ID。
- `GFResourceRegistry` 新增 `group_entry_ids()` 和通用分组来源常量，可按 ID、路径、basename、类型提示或条目字段导出非唯一条目 ID 分组。
- `GFConfigPipelineTableSource.schema_options` 新增 `typed_header_type_row`，支持字段名与类型声明分行的轻量 schema 生成方式。
- `GFAssetMetadataUtility` 新增 `read_object_metadata_with_schema()` 与 `validate_object_metadata()`，复用 `GFDictionarySchema` 为对象 metadata 补默认值、转换和校验。
- `GFSchemaField` 新增字段级 `validation_rules`，可组合 `GFValidationRule` 表达范围、集合、格式或项目自定义约束。
- `GFGraphMath` 新增 `sort_topological()`，为依赖、加载顺序和任务流水线提供稳定拓扑排序与循环报告。
- `GFSpatialHash3D` 新增世界坐标到格子的映射、格子级候选查询和调试快照，便于项目在不引入业务 chunk 策略的前提下复用通用空间桶索引。
- 新增 `GFGeneratedArtifactReport`，为访问器生成、导表 JSON 和项目工具提供统一的产物状态、dry-run、写入和错误报告。
- `GFConfigTableEditorTools` 新增 schema 列描述、字段编辑描述和跨表引用候选记录辅助，供项目编辑器、Inspector 或 CI 预览复用通用配置表结构。
- `GFCapabilityQuery` 新增资源化能力查询条件，`GFCapabilityUtility` 可直接按查询资源筛选或检查 receiver。
- 新增 `GFResourcePathHint`，为资源路径字符串和资源路径数组提供 GF 自定义 Inspector hint；`Array[String]` 与 `PackedStringArray` 可显示为可排序的 ResourcePicker 列表。
- `GFArchitecture` / `Gf` 新增 `unregister_*_alias()`，用于只删除 Model/System/Utility 查询别名而不释放目标实例。
- `GFArchitecture`、`GFTypeEventSystem` 与 `Gf` 新增 owner 精确事件注销入口，`listen_owned()` 可搭配 `unlisten_owned()`，避免同一 `Callable` 被不同 owner 注册时互相误删。
- `GFArchitecture` 新增 `fail_on_missing_declared_dependencies`、`get_lifecycle_generation()` 与 `is_lifecycle_generation_active()`，用于严格依赖装配和异步生命周期校验。
- `GFVariantData` 新增 `values_equal()`，集中处理浅层 Variant 等值判断、数值跨类型比较和可选 `String` / `StringName` 同名匹配。
- `GFStorageUtility` 新增 `allow_resource_loads`、`allowed_resource_load_extensions`、`allowed_resource_load_type_hints` 与 `require_resource_load_type_hint`，用于显式开启并收窄 ResourceLoader 读取边界。
- `GFNodePropertySerializer` 与 `GFPersistPropertiesSource` 新增 `allowed_resource_roots` / `allowed_resource_patterns`，用于恢复属性 Resource 引用时声明可加载路径边界。

### 🔄 机制更改 (Changed)

- GF 最低 Godot 版本抬到 4.7，并同步 README、Asset Library、Asset Store 与 GitHub Actions 的默认验证版本。
- 标准编辑器扩展记录新增 debugger plugin 贡献入口，`kernel/editor` 只负责通用注册，不硬编码标准层调试器实现。
- `GFInputRemapConfig` 的输入事件记录编码/解码收敛到标准输入内部工具，运行时重映射和 InputMap 预设共享同一套事件字段白名单。
- `GFConfigPipeline.save_database()` 与配置访问器生成结果会返回 `artifact_report`，并支持 dry-run / 禁止覆盖语义，便于制作期差异审查。
- `工具 > GF` 新增“刷新 GF 编辑器贡献”，可重新收集 GF 标准库编辑器贡献记录并重建菜单、Inspector、Debugger 和工作区记录。
- Capability Inspector 的添加、Recipe 应用、启停和移除能力操作现在会写入 Godot 编辑器撤销栈，批量 Recipe 应用会作为一次编辑器事务提交。
- `GFCapabilityUtility` 的多条件查询在同时指定分组与 required 能力时，会先选取更窄的候选索引并与分组取交集，减少大场景 receiver 扫描成本。
- `replace_model()`、`replace_system()` 与 `replace_utility()` 改为事务式替换：新实例完成当前生命周期阶段后才提交，初始化失败或超时时保留旧实例。
- `Gf.set_architecture()` 改为事务式全局架构切换，新架构 installer/init 成功后才替换当前架构；失败时保留旧架构。
- Tick 调度改为 System/Utility 共用全局优先级队列，`tick_priority` 与 `physics_tick_priority` 可跨模块类型排序；运行时修改 tick 优先级或时间策略会刷新缓存。
- `GFReadOnlyBindableProperty` 与 `GFComputedProperty` 读取 `Array` / `Dictionary` 时返回深拷贝，避免通过 `get_value()` 原地修改只读集合。
- `GFCommand` / `GFQuery` 通过 `send_command()` / `send_query()` 执行时绑定一次性生命周期作用域，同一实例重复发送会被拒绝。
- `GFNodeContext` 现在会等待重写的异步 `install()` 与 `install_bindings()` 完成后才清除安装状态并进入上下文初始化，避免场景级容器提前 ready。
- `GFVariantReferenceCodec.decode_reference()` 现在默认拒绝 Resource 标记解码，必须提供 `allowed_resource_roots` 或 `allowed_resource_patterns` 才会进入 `ResourceLoader`。
- `GFNodePropertySerializer` 与 `GFPersistPropertiesSource` 恢复 Resource 属性引用时会复用 context 中的 Resource 路径策略；没有 context 策略时才使用自身 allowlist。
- `GFStorageUtility.load_resource()` 默认拒绝调用 Godot `ResourceLoader`；项目需显式启用 `allow_resource_loads`，并提供类型提示与扩展名策略。
- `GFReactiveStateStore.set_state()` 在 diff 达到 `max_changes` 上限时会派发根级 `state_replaced` 变更，避免内部状态已替换但部分路径订阅者漏通知。
- `GFReactiveStateStore` 的状态等值判断改为复用 `GFVariantData.values_equal()`，避免状态、导入和工具链各自维护不同的浅层比较规则。
- `GF Package Manager` 的安装计划支持 `--all-concrete`、`--kind` 和 `--exclude-kind` 选择器，lockfile 会记录 registry source、channel、mirror、hash 和 size 等来源信息。
- Content Package manifest 支持 `user://` 来源根、`safety_kind` 和 `forbidden_resource_extensions`，默认 data-only 包会拒绝脚本、动态库和 shader 等代码形态资源。
- `GFArchitecture` 查询失效 alias 时不再落到同架构内的 assignable fallback，命令历史快照工具也要求唯一完整契约，避免注册顺序决定快照结果。
- `release-status` 会在目标版本 tag 已存在但不指向当前 HEAD 时失败，避免发布版本事实分裂。

### 🐛 Bug 修复 (Fixed)

- `GFAudioUtility` 在空间 SFX 未提供 `GFAudioSpatialSettings` 时会显式保留 `area_mask = 1`，避免 Godot 4.7 的空默认区域掩码影响 Area 音频总线覆盖。
- `GFInputBinding.match_device` 会把旧资源中的键鼠 `device = 0` 视为 Godot 4.7 键盘/鼠标设备 ID 的兼容占位，同时保留非 0 设备 ID 的精确匹配语义。
- 修复通过 alias 调用 `unregister_*()` 会间接销毁真实模块的问题；现在该调用会报错并要求使用 `unregister_*_alias()`。
- 修复事件系统按 `Callable` 注销时会误删其它 owner 监听的问题，派发中的 pending remove 也会按 owner 匹配。
- 修复同一模块实例可通过多个脚本键重复进入注册表导致 dispose、alias 和生命周期状态不一致的问题。
- 修复 Architecture Model 快照在多个 Model 使用同一 `get_save_key()` 时静默覆盖的问题；现在 capture 与 restore 都会先拒绝重复键。

### 📘 升级指南 (Migration Guide)

- 项目需要使用 Godot 4.7 或更新版本打开 GF。仍保存了键鼠 `device = 0` 的旧输入绑定可继续匹配；如果项目希望区分明确设备，应保存 Godot 4.7 产生的非 0 键盘/鼠标设备 ID。
- 空间音效如果需要禁用 Area 音频总线覆盖，请显式提供 `GFAudioSpatialSettings` 并把对应 `area_mask_2d` 或 `area_mask_3d` 设为 0。
- 如果旧代码依赖 `unregister_utility(AbstractAlias)` 这类 alias 注销目标实例的行为，请改为 `unregister_utility(TargetScript)`；只删除 alias 时使用 `unregister_utility_alias(AbstractAlias)`。
- 如果旧代码复用同一个 `GFCommand` / `GFQuery` 实例多次发送，请改为每次发送创建新实例，避免异步执行上下文被覆盖。
- 如果项目使用 `Gf.listen_owned()` 或通过框架对象注册 owner 监听，单个注销应使用对应 owner-aware 入口；普通 `unlisten()` 只移除无 owner 监听。
- 如果项目需要恢复 `GFVariantReferenceCodec` 生成的 Resource 标记，必须传入允许根目录或通配模式；不再支持无策略默认加载。
- 如果项目用 `GFNodePropertySerializer` 或 `GFPersistPropertiesSource` 保存 Resource 属性，请在 SaveGraph context 中传入 `allowed_resource_roots` / `allowed_resource_patterns`，或直接配置 Source / Serializer 上的同名 allowlist。
- 如果项目使用 `GFStorageUtility.load_resource()`，先设置 `allow_resource_loads = true`，并传入非空 `type_hint`；必要时收窄 `allowed_resource_load_extensions` 与 `allowed_resource_load_type_hints`。

---

### 🔁 5.x 预发布内容合并

以下内容原作为 5.x 兼容性重整记录维护，本次随 6.0.0 一并发布；受影响入口见下方 API 变动说明与升级指南。

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
