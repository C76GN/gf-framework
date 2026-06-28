# 更新日志 (Changelog)
## 维护策略
正式文档中的更新日志只保留当前最新发布版本。发布新版本时，应将 `[未发布]` 合并为具体版本条目，并删除上一个正式版本条目；旧版本历史以 Git 历史和 GitHub Releases 为准，避免正式文档长期膨胀。
---

## [7.0.0] - 2026-06-29

本版本是 GF 7.0.0 主版本发布，集中收敛 Godot 4.7 基线、原生 Package 管线、运行时生命周期、异步控制流、资源安全边界、输入确定性、编辑器工具和内置扩展契约。由于本轮包含公开 API 签名和严格契约变化，因此按主版本发布。


### 🚀 新增特性 (Added)

- `GFResourceRegistryTools.scan_resource_paths()` / `create_registry_from_scan()` 新增 `include_patterns`、`exclude_patterns` 与 `pattern_base_path` 扫描选项，可用通用 glob 模式收窄进入注册表的资源路径。
- 新增 `GFDriftReport`，提供通用 matched / missing / extra / stale 比对报告，供资源注册表、配置表、内容包、package lockfile 或编辑器缓存做双源一致性审查。
- 新增 `GFBridgeContractReport`，提供通用桥接契约覆盖报告，可审查外部 SDK、GDExtension、编辑器工具或请求 handler 的缺失、孤儿、重复和签名/能力不匹配适配器。
- `GFConfigTableImporter` 新增 ConfigFile 表解析与校验入口，配置导表 pipeline 可自动识别 `.cfg` / `.ini` 来源并构建 `GFConfigTableResource`。
- 新增 `GFHeightfield3D` 与 `GFSurfaceScatterSampler3D`，提供通用 3D 高度场采样、Terrain-RGB 图像解码、法线估算和纯数据表面散布 Transform 报告。
- 新增 `GFOperationDiagnosticsUtility`，提供通用操作时间线、阶段耗时、异常事件聚合和健康快照，并可被 `GFDiagnosticsUtility` 采集到工具快照。
- 新增 `GFEditorCommandRegistry`，可按稳定动作 ID 收集编辑器动作贡献、解析工具栏或命令面板布局并统一调用 `GFEditorActionDefinition`。
- 新增 `GFEditorSceneMetadataPatch`，把编辑器工具对场景节点 metadata 的写入或移除收敛为可撤销 `GFEditorCommand`。
- 新增 `GFTemplateGenerationManifest`，为代码生成器提供模板 sidecar JSON 解析、必要字段校验、变量/要求元数据和 `GFGeneratedArtifactReport` 保存选项衔接。
- 新增 `GFPointerGestureUtility`，把鼠标、触摸、触控板手势和滚轮输入归一为平移、缩放、旋转的纯数据摘要。
- 新增 `GFResourcePropertyPatch`，用声明式属性列表和覆盖值构建通用 Resource 差异补丁，可复制 base Resource 后安全应用局部属性变体。
- 新增 `GFResourceOverlay`，按顺序组合多份 `GFResourcePropertyPatch` 构建资源覆盖链，并输出逐 patch 应用报告。
- 新增 `GFProtocolAckLedger`，为自定义协议、SDK 包装层或请求桥接提供纯数据 packet ack / failed / expired 状态账本。
- 新增 `GFResourceFeatureRemapTools`，根据 active feature 与 remap 声明生成资源重映射计划、未命中 source 和 unused target 诊断，供项目导出器、包构建器或安装器在执行前审查。
- 新增 `GFScriptStructureTools`，提供脚本路径扫描、结构描述、契约检查报告、方法签名格式化和方法桩生成，供编辑器工具、导入预检、生成器自检和测试断言复用。
- `GFNodeTreeOps` 新增直接子节点、后代、祖先和前后同级节点的通用收集入口，并支持深度与结果数量限制。
- `GFDictionarySchema` 新增 `normalize_dictionary_array()`，可批量规范化 `Array[Dictionary]`，补默认值、转换字段、剔除额外字段并汇总行级校验报告。
- `GFContentPackageExportPlan` 新增 `get_artifact_report()`，可为导出条目生成本地文件大小、sha256、总量和 expected metadata 校验报告。
- 新增 `GFCancelToken`、`GFCancelSource`、`GFTimeoutController`、`GFAsyncCompletion`、`GFAsyncWaitUtility`、`GFAsyncChannel` 与 `GFAsyncProgress`，提供通用取消、可复用超时、一次性异步终态、Signal / 帧 / 条件等待、异步事件通道和进度节流原语。
- 新增 `GFAsyncKeyedGate`、`GFAsyncGateLease`、`GFRequestHandlerRegistry` 与 `GFExecutionLaneDiagnostics`，提供按 key 并发租约、单处理器请求调用契约和通用执行通道诊断；`GFExecutionLaneDiagnostics` 新增 lane 容量上限、inactive lane 年龄清理和 `compact_lanes()`，避免长期运行会话中诊断 lane map 无界增长。
- 新增 `GFAsyncFlowTools`，在现有 completion/wait 原语之上提供重试、顺序遍历和折叠 helper，统一返回结果字典而不引入 Promise 类型。
- 新增 `GFMainThreadDispatchQueue` 与 `GFManualTimerQueue`，提供主线程应用回调队列和手动 tick 驱动的确定性计时队列。
- 新增 `GFDeferredMutationQueue` 与 `GFExecutionRequirement`，提供确定性延迟状态变更 playback 和通用 all / any / none 执行条件报告。
- 新增 `GFConfigProviderAdapter`，可把 Array、Dictionary、自定义对象或懒加载 Callable 表源接入 `GFConfigProvider` 查询协议。
- 新增 `GFByteCursor`，提供带边界检查、显式端序、varuint、`try_read_*()` 结构化读取报告和长度前缀 UTF-8 helper 的 `PackedByteArray` 读写游标。
- 新增 `GFEditorOperationPlan`，可把编辑器工具的预览、dry-run、步骤状态和产物报告汇总为统一操作摘要。
- 新增 `GFBakeDependencyReport`，可记录编辑器烘焙或导入工具的输入、输出、逻辑依赖、失效原因和产物报告摘要。
- 新增 `GFResourceLoadState`，统一表达资源键、路径、加载状态、进度、错误和弱/强引用模式，供资源队列、UI 与诊断面板复用。
- 新增 `GFSpatialQueryIndex2D` 与 `GFSpatialQueryIndex3D`，在统一查询 API 后面封装线性扫描、四叉树和 3D 空间哈希策略；新增 `query_*_into()` / `query_records_*_into()` 输出复用入口，供高频空间查询减少结果数组分配。
- 新增 `GFExecutionBudget`、`GFDataProjection`、`GFTextGenerationContext` 与 `GFSourceTextLoader`，为生成器、导入器和编辑器工具提供显式数据投影、安全文本上下文、执行预算诊断和 root-bound 源码文本加载。
- 新增 `GFCompatibilityProfile`、`GFCompatibilityPreflight`、`GFArtifactFreshnessReport` 与 `GFActivationTransaction`，提供通用环境能力预检、artifact 新鲜度报告和显式激活事务回滚机制；`GFContentPackageExportPlan` 新增 `get_preflight_report()` 用于合并内容包计划、artifact 与 Profile 约束。
- `GFAsyncBatch` 新增 ALL / ANY / EACH 完成策略、结构化 `settled` 报告、失败/取消条目、取消 token 绑定和超时取消。
- `GFArchitecture` 新增 `get_binding_diagnostics()`，可只读输出 Model/System/Utility 注册表、别名、工厂生命周期和父级架构链摘要。
- `GFExtensionSettings` 新增 `get_extension_preset_report()`，可审查扩展 preset 的有效、无效、重复和跳过记录；扩展 manifest 与 preset ID 统一改用严格小写 dotted identifier 校验。
- `GFSeedUtility` 新增 `get_branched_godot_rng()`，显式表示 Godot `RandomNumberGenerator` 分支只承诺同一 Godot 随机算法下的复现。
- `GFOperationDiagnosticsUtility` 新增 `record_async_snapshot()` 与状态轨迹记录，可把异步状态、当前 state、重试次数、进度、用户决策点和最近错误汇入操作诊断与健康快照。
- `GFInputDeviceUtility` 新增设备分配事件历史和 `get_assignment_report()`，可诊断手动映射、自动占位、join 输入、断开移除和活跃设备切换。
- 新增 `GFAsyncTrackerUtility`，提供默认关闭的活动异步句柄追踪、可选堆栈捕获和 `GFDiagnosticsUtility` 工具快照接入。
- 新增 `GFPriorityQueue`，提供稳定优先队列、同级 front 插入、取消、调序和按弹出顺序导出能力。
- 新增 `GFItemListBinder` 与 `GFRepeaterBinder`，支持数组数据写入条目控件、模板重复渲染，并可绑定 `GFReactiveStateStore` 路径。
- 新增 `GFTileMetadataPaintTool`，为 `GFTileMetadataLayer` 提供通用 paint patch、UndoRedo 兼容提交和 schema 驱动 overlay 分段数据。
- 新增 `GFValidationConstraintRule`，为 `GFValidationRule` 提供通用范围、集合、正则和尺寸约束，可被 Dictionary schema、设置定义、导入工具或项目校验套件复用。
- `GFTableDataView` 新增 `describe_row()` 与 `describe_view()`，可导出当前可见视图或完整源行的结构化快照，供自定义表格、虚拟列表、调试面板和导出层复用。
- 新增 `GFNumericModifierMath`，提供按优先级应用 add / multiply / divide 数值修饰的通用计算报告，并对非有限输入、除零和 clamp 配置进行 JSON 友好的诊断。
- 新增 `GFAudioMetadataTools`，提供通用音频元数据标签规范化、ID3v2 文本帧读取、展示摘要和 `GFAudioClip.metadata` 合并写回工具。
- 新增 `GFAudioPitchAnalysisTools`，对调用方提供的 PCM 样本做纯数据音高分析，输出频率、音名、cents、RMS 和置信度报告。
- 新增 `GFObservableArrayResource` 与 `GFObservableDictionaryResource`，提供显式变更方法、单项信号和批量变更报告，便于 UI、编辑器工具或状态同步观察资源化集合。
- 新增 `GFSafeResourceCodec` 与 `GFSafeResourceCodecPolicy`，提供 allowlist 驱动的 Resource/Object 属性图编解码，默认拒绝未授权类、脚本和外部资源路径。
- 新增 `GFTextureSetClassifier`，按通用 PBR 贴图后缀归并纹理集，并可输出 `GFImportPlan` 供导入器或 CI 预检使用。
- `GFSurfaceUtility` 新增 `describe_surface_hit()`，可一次性导出 face 命中的 surface index、base/override/active material 与材质资源摘要，供运行时分发、调试面板或日志使用。
- Feedback 扩展新增 `GFHapticPreset` 与 `GFHapticUtility`，提供弱/强马达曲线采样、channel 强度、玩家/设备目标路由和可测试输出回调。
- Camera、Combat、Content Package 与 Network 扩展分别新增 `clear_active_rig_override()`、`GFSkillTargetingRule.random_seed`、manifest `schema_version`、`GFNetworkUtility.connect_timeout_msec`、`GFNetworkReconnectPolicy.set_jitter_seed()` 和网络调试快照统一脱敏，用于显式退出手动相机覆盖、确定性 RANDOM 索敌、严格 manifest schema 声明、客户端连接超时、可复现重连 jitter，并隐藏凭据类字段与 endpoint 路径、查询、片段。

### 🔄 机制更改 (Changed)

- `GFBindableProperty.value_changed` 改回 Godot 原生 signal 发射语义，`set_block_signals()`、deferred / one-shot 连接和 signal await 由引擎处理；需要每个监听者独立集合 payload 的场景应使用 `subscribe()`。
- `GFDependencyGraphTools.sort_dependency_first()` 现在会报告未知根节点到 `missing_root_ids` / `missing_root_count`，未知请求不再被静默跳过。
- `GFExtensionSettings.set_enabled_extension_ids()` 现在始终只保存当前可发现 manifest 的扩展 ID；`include_dependencies` 只控制是否补齐依赖，不再影响未知 ID 过滤。
- `GF Package Manager` 的原生安装、更新和状态检查收紧 package id、registry / lockfile 读取、HTTP redirect 和 archive 元数据边界；dry-run 只做解析与元数据校验，不再解压到 staging 或写入项目文件。
- `GF Package Manager` 的 status、install / update / uninstall dry-run 结果新增 `plan_entries` 与 `plan_summary`，逐包说明安装、更新、保留、卸载、依赖剪枝或阻断原因，便于编辑器页面和项目工具在执行前审查。
- `GF Package Manager` 的原生 backend 和编辑器 worker 新增协作取消入口，扫描、下载、解包、复制、删除和 lockfile 写入会在关键边界检查取消状态并返回 `cancelled`。
- `GF Package Manager` 现在要求用户侧 lockfile 路径留在项目根目录内；registry source mirrors 必须是非空字符串数组，offline bundle 解包前会执行条目数量、路径、大小、总解压量和压缩比审计。
- `GFGeneratedArtifactReport` 新增产物所有权、生成器 ID、来源 ID、文本内容 hash、旧文件 hash 与 `summarize_reports()` 批量摘要，方便生成器区分可重建产物和用户维护文件。
- `GFTypeEventSystem` 新增监听器诊断和 released-owner compact 入口，事件调试统计现在会报告总监听数量、stale owner、pending owner remove、dispatch cache 和 trace 容量。
- `GF Package Manager` 的 lockfile 现在记录已安装文件的 `sha256` 与 `size_bytes`，更新时只会删除仍匹配旧 lockfile 元数据的过期文件，避免覆盖或删除项目侧手动修改。
- `GF Package Manager` 的 status / uninstall preview 现在会复用同一轮项目引用扫描快照；远程 registry source 带 sha/size 元数据时可复用已校验的本地 registry cache。
- `GFArchitecture.dispose()` 现在是终止性生命周期操作：dispose 后的架构实例不能重新 `init()`、注册模块或继续 `create_instance()`；需要重新启动时应创建新的架构实例。
- `GFBinding` 的 singleton factory 会拒绝递归解析，避免循环依赖把 singleton 缓存写入半初始化实例。
- `GFNodeTreeOps.collect_node_tree()` 与递归查找内部改为显式栈遍历，避免深层节点树依赖 GDScript 调用栈。
- `GFBackgroundWorkUtility` 的等待线程任务队列改为复用 `GFPriorityQueue`，保留既有 priority 与 front 语义，同时减少手写排序逻辑。
- `GFSaveGraphUtility`、`GFTurnFlowSystem` 与 `GFConfigPipeline` 收紧失败边界：存档应用会拒绝未来格式、重复 key 和非确定性顺序并回滚已有 Source 状态；回合流程会拒绝阶段重入、保留 `stop(false)` 未解析行动并过滤失效目标；导表导出会先预检数据库与访问器产物，默认拒绝写入 GF 源码目录并报告重复表来源和无效 XLSX header。
- `GFReplayTimeline.append_timeline()`、`GFTextSearchScorer.rank_candidates()`、`GFGrid3DMath` 路径搜索、`GFManualTimerQueue` 和 `GFDeferredMutationQueue` 优化批量排序与队列热路径，同时保持稳定顺序。
- `GFDictionarySchema`、`GFValidationReportDictionary`、`GFValidationSuite`、`GFTagSet` 与 `GFTagSourceAdapter` 增加内部 lookup / pattern / protocol cache，降低大 schema、大报告和高频标签查询的重复扫描成本。
- `GFAsyncChannel`、`GFAsyncWaitUtility` 与 `GFRequestHandlerRegistry` 的异步结果字典构造收敛到内部 helper，减少 `status`、`ok`、`reason`、`metadata` 等字段分叉风险；Signal 等待控制流统一委托 `GFAsyncWaitSupport`，assets、jobs 与 scene 的 threaded ResourceLoader 访问统一收敛到内部 adapter。
- `GFObjectPoolUtility` 的默认 invalid prune 改为优先清理可用池，显式 debug / prune 入口仍保留全池清理语义。
- `GFVariantJsonCodec` 现在会把 `NaN`、`Infinity` 和 `-Infinity` 编码为可往返的 `Float` 类型标记；`GFHeightfield3D` 采样 fallback 改用 `null` 默认值在内部解析为 `NAN`，避免 Godot LSP 启动时序列化非 JSON 数字。
- `GFValidationRule` 新增 `describe()`，`GFSchemaField.describe()` 会保留规则子类的结构化描述，便于编辑器工具和文档生成读取约束细节。
- `GFImportPlan` 新增 `get_operation_summary()`，预检报告会包含操作摘要，并默认报告多个非 skip 条目写向同一目标路径的冲突。
- `GFTileMapCache` 新增 `transformed()`、`remapped_tiles()` 与 `transformed_and_remapped()`，可复用 `GFGridTransform2D` 对 TileMap 片段做旋转/镜像和 tile identity 重映射。
- `GFTouchJoystick` 新增 active region 与 `OutputMode`，可在保持默认模拟输出的同时选择四方向或八方向离散触控输入；`GFInputVirtualCursorModifier` 新增手动 delta、运行时状态快照和恢复入口，便于确定性输入回放。
- 标签、兼容性预检、激活事务、二进制游标、定点数、空间查询和区域缓存收紧边界契约：UUID 校验改为严格 canonical 小写，黑板校验不再隐式应用默认值，已提交事务再次 `commit()` 不会重复执行步骤，`GFByteCursor` 写入遵循当前游标位置，TileMap 全量采样现在以当前 layer used cells 作为权威快照。
- `GFSpatialHash3D` 与 `GFSpatialQueryIndex3D` 现在拒绝 Array / Dictionary 等可变复合实体键，并用半开最大边界计算 AABB 覆盖格子。
- `GFSeedUtility`、`GFDecimalStringFormatter` / `GFNumberFormatter` 与 `GFBigNumber` 收紧确定性数值边界：完整随机状态事务式严格恢复，分支计数稳定排序，默认 seed 固定为 0；数字格式化拒绝非有限值并钳制小数位；大数指数解析、乘除、幂和科学计数法进位使用 checked exponent。
- `GFInputAction.get_action_id()` 现在只返回显式 `action_id`；`GFDisplaySettingsUtility` 只在窗口模式应用窗口尺寸；`GFSettingsUtility` 无存储后端的 fallback 持久化拒绝原生绝对路径并默认限制在 `user://`。
- 标准库的输入、存储、状态机、音频、调试和空间工具编辑器贡献拆分为独立 `.editor` 子包；运行时包不再声明 editor-only 源码路径，标准编辑器聚合包显式依赖这些 editor 子包。
- `GFAsyncWaitSupport` 与 Action Queue 等待协议支持暂停期间冻结 timeout；`GFWaitAction`、`GFFlashAction`、`GFVisualActionGroup` 和 `GFActionQueueSystem` 的暂停、恢复、取消、立即完成和 linked-node 释放语义收紧为可观测的一致生命周期。
- Camera Director 的 `set_active_rig()` 现在表示显式手动覆盖，直到调用 `clear_active_rig_override()` 才恢复自动选择；Capability 扩展收紧依赖图，禁止移除仍被依赖的能力，基类依赖多实现匹配会失败，外部能力不再被 Utility 抢占释放。
- Combat 扩展收紧 Buff / Skill owner、技能提交回调和确定性 RANDOM 索敌边界；Content Package 目录替换改为事务式，资源解析器同步会先清理上一轮内容包拥有的旧 key。

### 🐛 Bug 修复 (Fixed)

- 修复 Decision、Dialogue、Domain、Feedback、Flow、Interaction、Network 与 Physics 扩展在禁用评分项、对话副作用失败、任务/库存生命周期、反馈输出停止、接收器重绑、流程拓扑、指针生命周期、网络通道校验和重力采样缓存场景下的边界语义不一致问题。
- 修复 `GFBindableProperty` 原先手动派发 `value_changed` 导致无法遵循 Godot 原生信号阻塞、延迟、一次性连接和等待语义的问题；`subscribe()` 仍会隔离每个监听者收到的 `Array` / `Dictionary` payload。
- 修复扩展 manifest 无法打开、JSON 无效或根节点不是对象时会从 `get_manifest_graph_report()` 诊断中消失的问题。
- 修复直接改写 `gf/extensions/external_roots` ProjectSettings 后扩展 manifest 缓存可能继续使用旧 root 的问题。
- 修复 `GFEditorCommandSession` 会把已经交给 Godot UndoRedo 管理的命令加入本地 history，导致 `revert_last()` 绕过 UndoRedo 直接撤销的问题。
- 修复 `GFThumbnailRenderer.render_node3d()` 在渲染完成后会把临时复制节点留到下一次渲染或退出树时才清理的问题。
- 修复 `GFEditorTypeIndex.collect_scene_roots_extending()` 会在 root / used path 过滤前消耗 `max_scanned_scenes` 配额的问题。
- 修复 Package Manager 更新同路径文件时可能覆盖用户已修改安装文件的问题。
- 修复卸载根包时自动剪枝依赖未重新检查项目直接引用，可能删除仍被项目代码引用的依赖包文件的问题。
- 修复架构快照导出时可能把 Model 字典或命令历史快照的可变引用交给调用方的问题；现在快照边界会复制集合值。
- 修复日志上下文中的 `NaN` / `Infinity` 直接进入 `JSON.stringify()` 时被 Godot 替换为 `null` 并输出一次性 warning 的问题。
- 修复渲染预热路径资源未缓存、运行时可调 options 兜底未按 `value_kind` 归一化、纯数据存储同步/异步同文件顺序不一致、音频导入覆盖可能半写入、运行时调试器退出不释放会话页，以及 Debug Overlay 延迟挂载释放后节点的问题。
- 修复异步等待、运行时任务调度、命令序列、Schema/Variant 编解码、Timeline、Budget、集合资源和优先队列在生命周期失效、循环引用、诊断报告或边界数值场景下的状态丢失与递归风险。
- 修复资产元数据在 `null` 目标、多个 metadata key、记录字典重载、source path 规范化和 glTF extras 清空场景下可能误报、覆盖 source 或保留陈旧数据的问题。
- 修复行为树节点接受非法状态整数、ABORTED 状态被组合节点吞掉、组合节点共享外部 child 数组、decorator 可形成循环、Limit 超限后保留 running child，以及 BlackboardScope 暴露嵌套可变引用的问题。
- 修复 `GFTagSourceAdapter` 在对象只实现 `has_tag(tag, minimum_count)` 时无法处理 `minimum_count > 1` 的精确匹配问题。
- 修复 `GFTagExpression.to_dictionary()` 会静默丢弃 `null` 子表达式、无法处理循环表达式序列化，以及 `from_dictionary()` 遇到循环或极深字典输入时可能递归复制或栈溢出的问题；复制循环表达式现在也会保留循环保护语义。
- 修复 `GFCompatibilityPreflight.require_package()` 只要求包存在时错误要求版本号的问题，并按 SemVer 规则将 prerelease 视为低于同版本正式版。
- 修复 `GFFormulaParameter`、`GFTileMapCache.get_value()` 和 `GFTextGenerationContext.replace_tokens()` 在可变集合引用或输出长度边界上的不稳定行为。
- 修复 `GFByteCursor` 截断 varuint、非法 UTF-8、负长度读取、当前位置写入、写入扩容失败、非法 offset、极大读取长度和 var UTF-8 超限场景下的错误码、游标位置或部分写入语义不稳定问题。
- 修复 `GFEditorCommand.add_to_undo_manager()` 难以追踪回调执行失败的问题；命令现在保留最近 execute / revert 错误，debug snapshot 会输出对应错误码。
- 修复 `GFFixedDecimal.multiply()` 在最终结果可表示时仍可能因中间 raw 乘积溢出而提前钳制的问题，并让定点数/定点向量序列化使用归一化后的小数位。
- 修复 `GFBigNumber` 非有限 mantissa、`GFDecimalStringFormatter.trim_trailing_zeroes()` 全零文本、`GFFormula.calculate_float()` / `calculate_int()` 非有限结果，以及 `GFDeterministicRandom.next_float_range()` 非有限跨度等数值边界问题。
- 修复 `GFQuerySignature` encoded value 往返、`GFBudgetLedger.release()` / `clear()`、`GFReplayTimeline.add_event()`、`GFTimedTextEntry` / `GFTimedTextTrack` 字典恢复和 LRC 多时间标签行的状态隔离与规范化问题。
- 修复 `GFPolicyProvider` 状态归一与 identity 防篡改、`GFBlackboardSchema` 重复 key、`GFTagSet` 分层计数缓存签名碰撞等校验与缓存一致性问题。
- 修复 `GFRegionMap2D` 与 `GFRegionMap3D` 清空区域时丢失删除脏标记的问题，并补齐 2D 缺失默认值与区域快照的集合复制语义。
- 修复 `GFSpatialQueryIndex2D` 配置 bounds 小于实际记录范围时 quadtree 可能漏查 bounds 外记录的问题。
- 修复 `GFSpatialHash3D` 超大 AABB / 格子范围插入或查询可能分配海量中间数组、失败更新会移除旧记录，以及零半径查询语义不稳定的问题；`GFSpatialQueryIndex2D/3D` 零半径查询现在按点查询处理，3D int 实体结果按数值排序。
- 修复 `GFTileMapCache.from_dict()` 会丢弃空字典格子记录，并把合法极端坐标误判为解析失败的问题。
- 修复输入运行时在设备移除、重绑检测、录制回放 seek、同时间录制事件、短按/序列触发器、手柄轴正负冲突分析和 BBCode 转义上的边界状态问题；触控按钮/摇杆隐藏或离树时会释放动作，拖拽释放到无落点位置会结束会话，空 active region 会拒绝触摸并只警告一次。
- 修复 `GFSurfaceUtility` 同一 Mesh RID 结构变化后 face count 缓存不失效，以及 UUIDv7 同毫秒生成不严格递增的问题。
- 修复 Camera Rig group 注册、缺失 target 可用性、3D target 缩放污染、parallel `look_at` 和 Orbit 输入捕获问题；修复 Capability 外部能力释放、依赖移除、stale metadata 和 Inspector `process_mode` 恢复语义问题。
- 修复 Combat live Buff 快照恢复、过期最终 tick、释放实体效果清理和失败技能提交回调问题；修复 Content Package export graph 错误传播、archive path 越界、duplicate id 缓存残留和坏 manifest 污染当前 catalog 的问题。

### 📘 升级指南 (Migration Guide)

- 如果项目曾经在 `dispose()` 后复用同一个 `GFArchitecture` 实例，请改为创建新实例并重新注册模块。
- 旧 lockfile 没有文件元数据时，Package Manager 仍可读取已安装包；但如果更新需要删除旧版本遗留文件，为避免误删项目修改，建议先重新安装对应 package 生成新的文件元数据。
- 如果项目依赖宽松 UUID 输入、`validate_values()` 隐式补默认值、重复 `commit()` 重新执行事务步骤、或 `GFByteCursor` 永远 append 的旧行为，需要按新的严格契约调整调用点。
- 如果项目仍调用 `GFSeedUtility.get_branched_rng()`，建议改为 `get_branched_godot_rng()`；需要长期固定序列时改用 `get_branched_deterministic_random()`。
- `GFByteCursor` 变长无符号整数 API 已改名为 `read_var_uint()` / `try_read_var_uint()` / `write_var_uint()`；`GFSeedUtility.set_full_state()` 不再容忍损坏状态的局部恢复，项目存档应保存 `get_full_state()` 原样输出，并在恢复失败时保留当前随机状态或走项目级迁移。
- 如果项目依赖 `set_active_rig()` 后下一帧被自动最高优先级 Rig 覆盖，请改用 `clear_active_rig_override()` 显式恢复自动选择。
- Content Package JSON manifest 需要补 `"schema_version": 1`；缺失、字符串版本或未来版本都会进入诊断错误。
- 如果项目把 `activation_commit_callbacks` 当成“执行前预扣成本”使用，需要迁移到 `activation_checks` 或项目自定义预留阶段；提交回调现在只表示执行成功后的提交。
