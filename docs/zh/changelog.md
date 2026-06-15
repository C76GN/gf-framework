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

## [5.0.0] - 2026-06-15

### 🚀 新增特性 (Added)

- 新增 `GFProjectSettingsTools`，用于统一 ProjectSettings 缺失默认值、缺失键初始值和 Inspector 属性信息注册。
- 新增 `GFVoronoi2D`，用于二维点集的 Delaunay 三角剖分、Voronoi 顶点和开放 cell 标记计算。
- 新增 `GFPoissonDisc2D`，用于矩形区域内确定性最小距离点集采样。
- 新增 `GFScreenshotUtility`，用于无 UI 的 Viewport 截图捕获、Image 保存和尺寸/语言批量截图流程。
- 新增 `GFAudioLibraryTools`，用于音频素材库候选扫描、关键字过滤、导入计划和按计划复制。
- 新增 `GFDeque`，用于通用双端队列、两端裁剪、顺序导出和深拷贝复制。
- 新增 `GFRectPacking2D`，用于固定容器和自动正方形的通用 2D 矩形打包。
- 新增 `GFCollisionBroadphase2D` 与 `GFCollisionBroadphase3D`，用于纯 AABB body、候选 pair、SAP、2D Quadtree 和组合 broadphase 粗筛。
- 新增 `GFCollisionNarrowphase2D`，用于 2D 凸多边形与旋转盒的 SAT 精确重叠检测、相切策略、穿透深度和最小平移向量。
- 新增 `GFReactiveStateStore` 与 `GFReactiveStateControlBinder`，用于运行时 Dictionary 状态树、路径订阅、dirty queue、owner 自动解绑和 Control 值双向同步。
- 新增 `GFTextSearchScorer`，用于通用 token 文本匹配、字段权重评分和候选排序报告。
- 新增 `GFGraphPathSearchState`，用于封装 `GFGraphMath` 分步 A* / Dijkstra 的运行期回调、frontier 和路径重建状态，避免把内部堆结构暴露成公开 Dictionary ABI。
- 新增 `GFDeterministicRandom`，用于 foundation 层固定 xorshift32 序列、整数/浮点采样、状态恢复、子流派生和 deterministic golden 测试。
- 新增 `GFDeterministicVariantSerializer`，用于纯 Variant 数据的 canonical value、JSON、UTF-8 bytes 与 SHA-256，作为 deterministic math 状态 hash 和 golden 测试底座。
- `GFFixedDecimal` 新增 JSON 安全状态字典与固定字节序列 API，用于 deterministic math 的定点数序列化底座。
- 新增 `GFFixedVector2` 与 `GFFixedVector3`，用于 deterministic math 的二维/三维定点向量、定点 dot/length_squared 和稳定序列化。
- `GFSeedUtility` 新增 deterministic 分支随机源派生入口，用于把固定算法随机流纳入项目主种子和完整状态保存。
- 新增 `GFExtensionPreset` 与扩展 preset ProjectSettings/API，用于项目或外部插件声明可复用扩展启用组合；`GF Extensions` 面板支持添加和移除项目内 preset JSON 文件路径。
- `GFArchitecture` 新增分帧快照 API：`get_all_models_state_async()`、`restore_all_models_state_async()`、`get_global_snapshot_async()`、`restore_global_snapshot_async()` 与 `DEFAULT_SNAPSHOT_MODELS_PER_FRAME`，用于大型存档先分帧生成纯数据，再交给 Storage 异步写入。
- Dialogue 扩展的 `GFDialogueRunner` 新增运行快照创建与恢复能力，用于项目存档恢复当前对话行和上下文值。
- Save 扩展新增 `GFPersistPropertiesSource.properties` Inspector 选择器，用于从目标节点的可编辑可存储属性中填写属性白名单。
- `GF Workspace` 关于弹窗在检测到新版本后新增“打开更新页面”入口，跳转到对应 GitHub Release，由维护者手动决定更新方式。

### 🔄 机制更改 (Changed)

- `GFSceneSignalAudit.build_signal_graph()` 新增 `participating_nodes_only` 选项；`GFSignalGraphDock` 默认使用该选项，让信号诊断节点统计聚焦实际参与连接的节点。
- `GFTextFitter` 的适配选项新增 `font_size_candidates`，可把自动字体尺寸约束到项目设计字阶。
- `GFPluginProjectSettings` 与 `GFExtensionSettings` 现在复用 `GFProjectSettingsTools` 注册默认值和 ProjectSettings 属性信息，减少内核编辑器与扩展设置声明的重复实现。
- `GFSupportReportUtility` 的截图附件捕获现在复用 `GFScreenshotUtility`，保持支持报告外部字段不变并减少截图逻辑重复。
- `GFPersistPropertiesSource` 的编辑器配置体验现在由 Save 扩展提供属性候选列表；运行时 SaveGraph 协议和载荷格式不变。
- 维护工具与 GitHub workflow 现在把 PR / push CI 对齐到 `check --suite full`，tag release 对齐到 `release-status --version <tag>` 与 `check --suite release`；`path-hygiene` 同时扫描未跟踪文件，GUT 输出中的脚本错误或 GDScript reload warning 不再被通过摘要覆盖，Godot 退出期 ObjectDB/resource leak warning 会先记录为清理债务。
- 维护工具中的 Godot 检查现在显式把 `--log-file` 写入被忽略的本地日志目录，避免受限环境中默认 `user://logs` 写入失败导致 headless GUT 或 editor warning 检查在进入测试前崩溃。
- `maintenance-self-test` 现在会校验 `GFExtensionPreset` 的字段白名单、软关系禁止字段和下载包禁止字段，并确认 Python 维护规则与运行时常量保持一致。
- `maintenance-self-test` 现在会校验 `GFExtensionManifest` 运行时字段白名单与 bundled manifest 严格白名单保持一致，不再为旧字段别名保留例外。
- 维护工具新增 `dependency-boundary` 检查，并接入 quick/full/release suite，用于静态校验内置扩展 manifest 字段白名单、默认关闭策略、禁止软依赖字段，以及 `kernel`、`standard`、内置扩展之间的跨层路径、扩展 ID 和 `class_name` 引用。
- GF 内置可选扩展默认关闭，项目需要时通过 `GF Extensions` 页面或 `GFExtensionSettings.set_enabled_extension_ids()` 显式启用；`@since unreleased` 作为未定版新增 API 的唯一占位，并在 release 检查中被阻断到替换为最终 SemVer。
- `GF Package Manager` 工作区页面的 registry 状态读取、安装预览、安装、卸载预览和卸载操作改为优先使用 Godot 原生后端；本地与 HTTP(S) registry 会共用 package cache，远程 archive 会在写入项目前完成下载缓存、sha256/size、路径归属审计和失败回滚，卸载会按 lockfile 文件清单删除包文件并在失败时恢复备份；页面默认先展示 preset 推荐组合，并隐藏普通用户不需要的 Python fallback 字段。新增 Godot 原生命令行入口 `addons/gf/kernel/package/gf_package_cli.gd`，可通过 Godot headless 对本地或 HTTP(S) registry 执行 status、install、verify 和 uninstall；默认输出人读摘要，传入 `--json` 时输出机器 JSON。编辑器页、Python installer 与 Godot CLI 均支持 registry source manifest 的 channel/mirror fallback，减少普通用户安装扩展时对外部 Python 命令的依赖。
- `GFExtensionManifest.get_validation_errors()` 现在会报告未知字段，以及 `optional_dependencies`、`preset`、`load_after` 等软依赖、组合和加载顺序字段，避免外部 manifest 在运行时静默绕过边界规则。
- `GFExtensionPreset.get_validation_errors()` 现在会报告未知字段、软关系字段和下载包字段，确保项目 preset 只描述启用 ID 组合，不承载下载器、Installer 覆盖或跨扩展编排。
- `GFAudioLibraryTools.copy_import_plan()` 的底层文件复制改为固定缓冲区分块写入，避免导入大音频文件时整文件读入内存。
- `GFAudioLibraryTools.copy_import_plan()` 新增整批文件数和总字节预算预检，超过 `max_copy_files` 或 `max_copy_bytes` 时返回 `GFValidationReport` 错误且不执行部分复制。
- `GFScreenshotUtility.capture_burst()` 新增 `max_captures` 组合数量上限，超过限制时返回结构化失败报告，避免批量截图误触发过大的语言/分辨率/格式组合。
- `GFArchitecture` 的生命周期与 tick 热路径改为基于 `GFModel` / `GFSystem` / `GFUtility` 基类协议的强类型分派；tick 缓存现在保存已验证 `Callable`、优先级和时间策略记录，不再在每帧通过字符串方法名反射调用模块。
- `GFArchitecture` 的 tick 调度和全局快照实现拆入内部协作者 `GFArchitectureTickScheduler` 与 `GFArchitectureSnapshotCoordinator`，公共 API 保持由 `GFArchitecture` 统一暴露。
- `GFArchitecture` 的 Model 快照恢复现在只接受每个 Model 条目为 `Dictionary` 的数据，非字典条目会被跳过并记录 warning。
- `GFGraphMath.begin_path_search()`、`GFGridMath.begin_path_a_star_search()` 与 `GFHexGridMath.begin_path_a_star_search()` 现在返回 `GFGraphPathSearchState` 运行期句柄，不再把 Callable、frontier heap 和分数表作为公开 Dictionary schema 暴露。
- `GFSeedUtility.get_full_state()` 的 `state_schema_version` 更新为 `3`，新增 `deterministic_branch_counters` 字段；Godot RNG 分支计数和 deterministic 分支计数分开保存，避免同标签随机流互相消耗。
- `GFSeedUtility.set_full_state()` 会拒绝当前 GF 尚不认识的未来状态 schema 版本，避免旧代码误读未来字段。
- `GFDeterministicRandom.apply_dict()` 现在返回 `bool`，并在 `state = 0` 或字段格式不受支持时返回 `false`。
- `GFPoissonDisc2D` 的采样随机源改为 `GFDeterministicRandom`，避免新纯算法继续依赖 Godot `RandomNumberGenerator` 的内部序列。
- `GFTileRuleSet` 的带权重结果选择改为稳定 FNV seed 与 `GFDeterministicRandom`，避免依赖 Godot `hash()` 或 `RandomNumberGenerator` 内部序列。
- `GFWeightedTable.deterministic_seed` 的后备随机源改为 `GFDeterministicRandom`；`pick_entry()`、`pick_value()` 与 `pick_many()` 现在也可显式接收 `GFDeterministicRandom`，便于直接消费 `GFSeedUtility.get_branched_deterministic_random()` 派生的固定算法随机流。显式传入 `RandomNumberGenerator` 的运行时随机流行为保持不变。
- `GFFixedDecimal.to_dict()` 的 `raw_value` 固定保存为十进制字符串；`to_bytes()` 使用 `GFFD` magic、版本、小数位、符号位和 8 字节大端绝对 raw 值，不依赖 Godot `Variant` 二进制格式。
- `GFFixedVector2` / `GFFixedVector3` 通过 `GFFixedDecimal` 处理分量缩放、舍入和溢出；`to_bytes()` 使用 `GFF2` / `GFF3` magic 与每分量 8 字节大端绝对 raw 值，不依赖 Godot `Vector2/3` 浮点格式。
- `GFFixedDecimal`、`GFFixedVector2` 与 `GFFixedVector3` 的 raw 文本校验、decimal_places 范围和 signed magnitude 字节编解码收敛到 numeric 内部共享实现，统一采用对称安全 raw 范围。
- `GFReactiveStateStore.flush()` 现在会把订阅回调中产生的新 dirty change 延后到当前订阅者批次结束后再派发，避免嵌套 flush 打乱同一批订阅者顺序。
- `GFCollisionBroadphase2D.find_pairs_quadtree()` 在 `world_bounds` 未覆盖全部 body 时会退回当前节点局部暴力枚举，避免 world 外 body 的候选 pair 被静默丢弃。
- `GFRectPacking2D.pack_fixed()` 与 `pack_square()` 新增 `max_rects` 输入数量上限，超过限制时返回带 `error` 字段的结构化失败结果，避免误把纯 GDScript 打包算法用于实时大批量数据。
- Domain 与 Combat 内置扩展标记为业务型外置候选，继续随包分发但必须保持默认关闭、只依赖 `gf.kernel` / `gf.standard`，并由维护测试阻止其回到基础能力或跨扩展硬依赖。

### 🐛 Bug 修复 (Fixed)

- `GFReactiveStateControlBinder` 现在会在 store 释放后由控件值变化回调主动清理失效绑定和控件信号连接，避免绑定记录只等后续懒清理才移除。
- `GFExtensionUsageAudit` 增加 `max_scan_depth` 截断 warning 回归测试，确保深层目录被跳过时会给出可见诊断。

### 🔌 API 变动说明 (API Changes)

- 新增公开类 `GFProjectSettingsTools`、`GFExtensionPreset`、`GFVoronoi2D`、`GFPoissonDisc2D`、`GFScreenshotUtility`、`GFAudioLibraryTools`、`GFDeque`、`GFRectPacking2D`、`GFCollisionBroadphase2D`、`GFCollisionBroadphase3D`、`GFCollisionNarrowphase2D`、`GFReactiveStateStore`、`GFReactiveStateControlBinder`、`GFTextSearchScorer`、`GFDeterministicRandom`、`GFFixedVector2` 与 `GFFixedVector3`。
- 新增公开类 `GFDeterministicVariantSerializer` 与 `GFGraphPathSearchState`。
- 新增公开方法 `GFProjectSettingsTools.ensure_setting()` 与 `GFProjectSettingsTools.register_property_info()`。
- 新增公开常量 `GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING` 与 `EXTENSION_PRESET_PATHS_DEFAULT`。
- 新增公开方法 `GFExtensionSettings.get_extension_preset_paths()`、`set_extension_preset_paths()`、`add_extension_preset_path()`、`remove_extension_preset_path()`、`get_extension_presets()`、`get_extension_preset_by_id()` 与 `apply_extension_preset()`。
- 新增公开方法 `GFPoissonDisc2D.generate_points()`。
- 新增公开常量 `GFScreenshotUtility.DEFAULT_MAX_BURST_CAPTURES`。
- 新增公开方法 `GFScreenshotUtility.capture_viewport_image()`、`capture_viewport_png_buffer()`、`save_viewport_screenshot()`、`save_image()`、`build_screenshot_path()` 与 `capture_burst()`。
- 新增公开常量 `GFAudioLibraryTools.DEFAULT_MAX_COPY_FILES` 与 `DEFAULT_MAX_COPY_BYTES`。
- 新增公开方法 `GFAudioLibraryTools.scan_library()`、`build_entries()`、`filter_entries()`、`make_import_plan()`、`copy_import_plan()` 与 `get_plan_target_paths()`。
- 新增公开方法 `GFDeque.from_array()`、`push_front()`、`push_back()`、`pop_front()`、`pop_back()`、`peek_front()`、`peek_back()`、`at()`、`set_at()`、`reserve()`、`trim_front()`、`trim_back()`、`clear()`、`is_empty()`、`size()`、`capacity()`、`to_array()`、`duplicate_deque()` 与 `get_debug_snapshot()`。
- 新增公开常量 `GFRectPacking2D.DEFAULT_MAX_RECTS`。
- 新增公开方法 `GFRectPacking2D.pack_fixed()`、`pack_square()` 与 `normalize_placements()`。
- 新增公开方法 `GFCollisionBroadphase2D.make_body()`、`find_pairs_bruteforce()`、`find_pairs_sap()`、`find_pairs_quadtree()`、`find_pairs_combined()` 与 `build_pair_report()`。
- 新增公开方法 `GFCollisionBroadphase3D.make_body()`、`find_pairs_bruteforce()`、`find_pairs_sap()`、`find_pairs_combined()` 与 `build_pair_report()`。
- 新增公开方法 `GFCollisionNarrowphase2D.make_polygon()`、`make_box()`、`is_convex_polygon()`、`project_polygon()`、`test_polygon_overlap()` 与 `test_shapes_overlap()`。
- 新增公开方法 `GFReactiveStateStore.normalize_path()`、`format_path()`、`get_state()`、`set_state()`、`get_value()`、`has_value()`、`set_value()`、`set_values()`、`erase_value()`、`begin_batch()`、`end_batch()`、`is_batching()`、`flush()`、`get_dirty_changes()`、`subscribe()`、`unsubscribe()`、`clear_subscriptions()`、`get_subscription_count()` 与 `dispose()`。
- 新增公开方法 `GFReactiveStateControlBinder.bind_control()`、`unbind_control()`、`unbind_path()`、`clear()`、`get_binding_count()` 与 `dispose()`。
- 新增公开方法 `GFTextSearchScorer.tokenize()`、`score_text()`、`score_candidate()` 与 `rank_candidates()`。
- 新增公开方法 `GFFixedDecimal.from_dict()`、`from_bytes()`、`to_dict()`、`apply_dict()`、`to_bytes()` 与 `apply_bytes()`。
- 新增公开方法 `GFFixedVector2.from_raw()`、`from_decimal_strings()`、`from_vector2()`、`from_dict()`、`from_bytes()`、`clone()`、`is_zero()`、`get_x_decimal()`、`get_y_decimal()`、`to_vector2()`、`rescaled()`、`negated()`、`add()`、`subtract()`、`multiply_scalar()`、`dot()`、`length_squared()`、`equals_exact()`、`to_dict()`、`apply_dict()`、`to_bytes()` 与 `apply_bytes()`。
- 新增公开方法 `GFFixedVector3.from_raw()`、`from_decimal_strings()`、`from_vector3()`、`from_dict()`、`from_bytes()`、`clone()`、`is_zero()`、`get_x_decimal()`、`get_y_decimal()`、`get_z_decimal()`、`to_vector3()`、`rescaled()`、`negated()`、`add()`、`subtract()`、`multiply_scalar()`、`dot()`、`length_squared()`、`equals_exact()`、`to_dict()`、`apply_dict()`、`to_bytes()` 与 `apply_bytes()`。
- 新增公开方法 `GFDeterministicRandom.from_seed()`、`from_dict()`、`set_seed()`、`get_initial_seed()`、`get_state()`、`set_state()`、`next_u32()`、`next_int_range()`、`next_float_unit()`、`next_float_range()`、`next_bool()`、`skip()`、`fork()`、`to_dict()` 与 `apply_dict()`。
- 新增公开方法 `GFDeterministicVariantSerializer.to_canonical_value()`、`to_canonical_json()`、`to_canonical_bytes()` 与 `sha256()`。
- 新增公开方法 `GFSeedUtility.get_branched_deterministic_random()`。
- `GFWeightedTable.pick_entry()`、`pick_value()` 与 `pick_many()` 的 `rng` 参数契约从仅接收 `RandomNumberGenerator` 扩展为接收 `RandomNumberGenerator` 或 `GFDeterministicRandom`。
- 新增公开常量 `GFArchitecture.DEFAULT_SNAPSHOT_MODELS_PER_FRAME`。
- 新增公开方法 `GFArchitecture.get_all_models_state_async()`、`restore_all_models_state_async()`、`get_global_snapshot_async()` 与 `restore_global_snapshot_async()`。
- 新增公开常量 `GFDialogueRunner.SNAPSHOT_SCHEMA_VERSION`。
- 新增公开方法 `GFDialogueRunner.create_runtime_snapshot()` 与 `restore_runtime_snapshot()`。
- `GFSceneSignalAudit.build_signal_graph()` 新增 `options.participating_nodes_only` 字段。
- `GFTextFitter.fit_control()`、`fit_label()` 与 `fit_rich_text_label()` 的 options 新增 `font_size_candidates` 字段。

### 📘 升级指南 (Migration Guide)

- 本轮包含新增公开 API 和若干兼容敏感的默认行为收敛，按 5.0.0 主版本升级处理；如果项目依赖旧的随机 golden 序列、扩展默认启用状态或定点数极端 raw 边界，应在升级前先跑项目自己的回归测试。
- GF 内置可选扩展现在默认关闭。项目如果依赖 Save、Combat、Domain、Network、Flow、Dialogue 等扩展的 Installer、编辑器贡献或导出内容，应在 `GF Extensions` 页面、项目 preset JSON、项目 Installer 或项目脚本中显式写入 `gf/extensions/enabled`。不要再依赖扩展目录存在就自动进入运行时装配。
- 外部扩展 manifest 如果省略 `enabled_by_default`，`kind = "extension"` 会按默认关闭处理；GF 内置可选扩展必须显式写为 `false`。需要默认启用的项目侧组合应放在项目 preset 或安装向导中，不要把推荐组合写成 manifest 软依赖。
- `GFWeightedTable.deterministic_seed` 的后备随机源改为 `GFDeterministicRandom`，相同 seed 的输出序列可能不同于旧版本基于 Godot `RandomNumberGenerator` 的结果。依赖旧 golden 序列的项目应更新 golden；如果需要继续使用 Godot RNG 行为，请显式创建并传入 `RandomNumberGenerator`，不要依赖 `deterministic_seed` 后备路径。
- `GFSeedUtility.get_full_state()` 的 `state_schema_version` 提升到 `3`，新增 `deterministic_branch_counters`。旧状态仍可由当前工具按缺省字段读取；项目自定义存档、调试 UI 或网络同步 payload 如果白名单校验完整状态字段，应加入该字段并保留未来 schema 版本拒绝逻辑。
- `GFFixedDecimal`、`GFFixedVector2` 与 `GFFixedVector3` 的稳定字节格式使用 signed magnitude，并统一采用对称安全 raw 范围。曾直接构造或断言 `int64` 最小 raw 边界的项目，应改为使用公开构造、`to_dict()` / `from_dict()` 或 `to_bytes()` / `from_bytes()`，并更新边界测试。
- `GFGraphMath.begin_path_search()`、`GFGridMath.begin_path_a_star_search()` 与 `GFHexGridMath.begin_path_a_star_search()` 返回的 `GFGraphPathSearchState` 只适合运行期跨帧推进，内部包含 `Callable` 和 mutable search state；不要把它写入存档或网络同步 payload。需要保存寻路任务时，保存项目自己的起点、终点、图版本和查询参数，再重新创建 search state。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/kernel/core/gf_project_settings_tools.gd`
- `addons/gf/kernel/core/gf_architecture_tick_scheduler.gd`
- `addons/gf/kernel/core/gf_architecture_snapshot_coordinator.gd`
- `addons/gf/kernel/extension/gf_extension_manifest.gd`
- `addons/gf/kernel/extension/gf_extension_preset.gd`
- `addons/gf/kernel/editor/gf_plugin_project_settings.gd`
- `addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd`
- `addons/gf/kernel/editor/gf_editor_workspace_dock.gd`
- `addons/gf/kernel/editor/gf_scene_signal_audit.gd`
- `addons/gf/kernel/extension/gf_extension_settings.gd`
- `addons/gf/standard/foundation/collections/gf_deque.gd`
- `addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd`
- `addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd`
- `addons/gf/standard/foundation/collections/gf_text_search_scorer.gd`
- `addons/gf/standard/foundation/math/gf_graph_path_search_state.gd`
- `addons/gf/standard/foundation/numeric/gf_fixed_decimal.gd`
- `addons/gf/standard/foundation/numeric/gf_fixed_numeric_serialization_support.gd`
- `addons/gf/standard/foundation/numeric/gf_fixed_vector2.gd`
- `addons/gf/standard/foundation/numeric/gf_fixed_vector3.gd`
- `addons/gf/standard/foundation/math/gf_poisson_disc_2d.gd`
- `addons/gf/standard/foundation/math/gf_rect_packing_2d.gd`
- `addons/gf/standard/foundation/math/gf_collision_broadphase_2d.gd`
- `addons/gf/standard/foundation/math/gf_collision_broadphase_3d.gd`
- `addons/gf/standard/foundation/math/gf_collision_narrowphase_2d.gd`
- `addons/gf/standard/foundation/math/gf_voronoi_2d.gd`
- `addons/gf/standard/utilities/audio/gf_audio_library_tools.gd`
- `addons/gf/standard/utilities/debug/gf_screenshot_utility.gd`
- `addons/gf/standard/utilities/debug/gf_support_report_utility.gd`
- `addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd`
- `addons/gf/standard/utilities/random/gf_seed_utility.gd`
- `addons/gf/standard/utilities/state/gf_reactive_state_store.gd`
- `addons/gf/standard/utilities/ui/gf_reactive_state_control_binder.gd`
- `addons/gf/standard/utilities/ui/gf_text_fitter.gd`
- `addons/gf/extensions/dialogue/runtime/gf_dialogue_runner.gd`
- `addons/gf/extensions/save/editor/gf_persist_properties_inspector_plugin.gd`
- `addons/gf/extensions/save/editor/gf_persist_properties_editor_property.gd`
- `addons/gf/extensions/save/gf_extension.json`
- `addons/gf/extensions/*/gf_extension.json`
- `tests/gf_core/kernel/extension/test_gf_extension_manifest.gd`
- `tests/gf_core/maintenance/test_layer_boundary_validation.gd`
- `.github/actions/setup-godot/action.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `tools/gf_maintenance.py`

---
