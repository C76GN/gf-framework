# 更新日志 (Changelog)

## 📝 日志条目结构标准

每次版本更新应包含以下核心模块（若无相关变动可省略该模块）：

1. **版本号与日期**：格式为 `## [主版本.次版本.修订号] - YYYY-MM-DD`
2. **版本概述**：简短描述该版本的核心目标（如：大型特性更新、紧急修复、性能重构等）。
3. **🚀 新增特性 (Added)**：新加入的类、方法、系统、扩展组件等。
4. **🔄 机制更改 (Changed)**：对现有功能逻辑的修改、内部重构、性能优化等。
5. **🐛 Bug 修复 (Fixed)**：修复的逻辑错误、内存泄漏、崩溃问题等。
6. **⚠️ 废弃与移除 (Deprecated/Removed)**：标记为废弃（将在未来移除）或本次直接移除的接口、文件。
7. **🔧 API 变动说明 (API Changes)**：详细列出函数签名改变、属性重命名等直接导致旧代码报错的改动。
8. **📘 升级指南 (Migration Guide)**：为使用旧版本框架的开发者提供 Step-by-Step 的升级建议和兼容性处理方案。
9. **📁 核心受影响文件 (Affected Files)**：列出改动最大的核心源码文件，方便开发者进行二次开发比对。

## 维护策略

每个正式版本只记录相对上一个稳定版本的增量。发布时将本轮 `[未发布]` 转为新版本段，并保留已有正式版本段；禁止通过重命名旧标题把累计变更伪装成新版本说明。正式版本必须唯一、带有效日期，并按 SemVer 严格倒序排列。历史过长时可按 major 归档，但当前文件至少保留目标版本和上一稳定版本；GitHub Release 只提取目标版本自身的段落。

---

## [8.1.0] - 2026-07-17

### 🚀 新增特性 (Added)

- `GFUIUtility` 新增 `GFUILayerDefinition`、运行时逻辑层注册、按显示深度诊断与层级默认遮挡策略；HUD、POPUP、TOP 现在只是默认层。面板 options 新增 `hide_under`，同层可组合常驻 UI、非全屏通知和覆盖式 Modal，并在栈变化后重算完整可见性链。
- 标准 Assets 新增 `GFHttpClientUtility`，提供有界并发、等待队列、`HTTPRequest` worker 复用、请求快照、活动/排队取消、父节点退出终态和池诊断快照；客户端池对继承传输预算的请求默认采用 16 MiB 单响应上限。

### 🔄 机制更改 (Changed)

- `GFUIUtility` 的公开 layer 参数与 `GFUIRoute.layer` 统一使用非负 `int` 逻辑层 ID；旧 `GFUIUtility.Layer` 常量仍可作为默认 ID 使用，逻辑 ID 不再与 `CanvasLayer.layer` 绘制值耦合。
- `gf/project/installers` 编辑器改用 Script 资源路径数组；运行时接受 `res://` 或可解析 `uid://` 并规范化到真实脚本。空项、失效 UID 和错误元素类型不再静默退化为空 Installer 列表。
- 维护套件将纯静态审计收敛为单进程执行并共享单次调用范围内的只读工作区快照，依赖和 package 所有权扫描改用索引；检查结果新增耗时、预算和执行方式，外部超时会清理完整后代进程树，并会绕过 Windows Steam 中可能提前返回的 Godot launcher。`--timeout` 只提高单项最小预算，整套预算改由 `--suite-timeout` 独立表达；CI 与发布门禁按集合等价的 framework、package contract、editor、CLI 和 Godot matrix shard 并行执行。

### 🐛 Bug 修复 (Fixed)

- 修复项目 Installer 配置含空项或错误类型时仅跳过条目，导致项目 Utility 未注册而后续以 `Nil` 调用失败的问题；初始化现在保留明确 `last_initialization_error`。
- `GFUIRouterUtility` 在 route 指向未注册逻辑层时返回稳定 `missing_ui_layer`；`GFHttpClientUtility` 在显式请求父节点退出树时以 `request_worker_lost` 终结活动响应，避免永久 pending。
- `GFUIUtility.init()` 与 `GFHttpClientUtility.init()` 重复调用不再清空活动状态或遗留旧 worker/CanvasLayer。

### 🔧 API 变动说明 (API Changes)

- 新增公开类型 `GFUILayerDefinition` 与 `GFHttpClientUtility`。
- `GFUIUtility` 原先声明为 `Layer` 的方法参数改为 `int`，允许项目自定义逻辑层；新增稳定 `DEFAULT_LAYER_ID`，调用既有枚举常量的代码不需要修改。
- `GFHttpRequestBuilder` 新增 `max_response_bytes` 与 `set_max_response_bytes()`；0 表示继承执行传输预算，-1 表示显式无限制，正数表示明确上限。既有一次性 `execute()` 保留 Godot 的无限制默认行为，新客户端池在继承模式下使用 16 MiB 安全默认值。

### 📘 升级指南 (Migration Guide)

- 在项目 Installer 中显式注册 `GFUIUtility`、`GFUIRouterUtility` 和按需使用的 `GFHttpClientUtility`；调用方必须检查 `await Gf.init()`，再用 `Gf.get_utility(Type, true)` 查询 ready 实例。
- 需要左右独立窗口时注册不同逻辑层；只是不希望小通知遮住常驻 UI 时，在上方面板设置 `hide_under = false`，不要全局关闭所有遮挡。
- 通过客户端池请求且合法响应可能超过 16 MiB 时，应在对应 builder 上显式调用 `set_max_response_bytes(required_bytes)`；只有经过风险评估后才使用 `UNLIMITED_MAX_RESPONSE_BYTES`，未知大小的大文件应改用流式下载边界。

## [8.0.1] - 2026-07-16

### 🚀 新增特性 (Added)

- GF 项目设置新增编辑器展示元数据、分区展示器与专用 Inspector 适配器：适配项目设置窗口的分区代理，在不改变稳定 `gf/...` 设置键的前提下按工具语言显示左侧分区、设置名、枚举选项和悬浮说明；资源路径属性继续复用专用控件并支持 GDScript 全局 Resource 子类；标准库 data-only 清单和启用扩展的编辑器动作均可贡献严格校验的设置展示记录。
- 配置表、状态机、Combat 和程序生成基础能力新增 `GFConfigTableQuery`、`GFNodeStateConditionGroup`、`GFNodeStateActiveCondition`、`GFNodeStateMachine.restore_state_snapshot()`、`GFProjectileEmissionPolicy` 与 `GFDualMeshTopology2D`，为配置查询、状态守卫组合、状态恢复、发射请求门控和 Delaunay / Voronoi 拓扑派生提供通用机制。
- `GFConfigTableQuery` 新增声明式 `condition()`、`where_filter()`、`where_any()` 与 `where_none()` 条件组，支持工具层保存、复用和描述 OR / NOT 查询；新增 `GFNodeGroupCache`，为频繁读取同一 `SceneTree` group 的相机、交互、物理探针或编辑器工具提供可失效缓存和诊断快照。
- 控制台、视口和桥接诊断增强：`GFConsoleCommandDefinition.argument_suggester`、`GFConsoleUtility.suggest_command_arguments()`、`GFViewportUtility` 窗口像素换算报告、`GFBridgeContractReport` Object / Engine singleton 适配器 helper，以及 `GFCompatibilityPreflight.require_artifact()`。
- 输入层新增 `GFInputDirectionTools`、`GFInputEventIdentity`、`GFInputDetectionResult`、`GFInputFormatterRegistry`、`GFInputProviderRegistration`，并让 `GFInputModifier`、`GFInputMapPresetTools.ensure_input_map_preset()` 复用方向规则、事件身份、结构化检测和局部 provider 注册。
- 图、网格、曲线和空间数学新增 `GFGraphMath.find_connected_components()` / `find_minimum_spanning_tree()`、`GFPlacementSequenceMath`、`GFTransform3DMath`、`GFCurve3DMath`、`GFGridCoordinateMath2D`、`GFGridPathMath2D`、`GFGridGenerationMath2D`、`GFGridConnectionMath2D`、`GFSpatialQueryIdentity` 与 `GFGridTransform2D.transform_cardinal_direction()`。
- Mesh、表面和程序化数据工具新增 `GFSurfaceUtility.describe_mesh()`、`GFNoiseFieldTools`、`GFWaveFunctionCollapse2D`、`GFQuadTreeUtility.can_index_rect()`、`GFGridKey3D.try_position_to_cell()` 预检报告，以及相关 JSON-compatible 报告转换入口。
- `GFGridGenerationMath2D` / `GFGridMath` 新增 `find_cell_regions()` 与 `filter_cell_regions_by_size()`，为细胞自动机、噪声阈值、候选散布和编辑器批处理提供纯数据连通区域分析与小区域剔除报告。
- 文本、标签和源码工具新增 `GFSourceTextPatchTools`、`GFDelimitedTextTools`、`GFSceneContractTools`、`GFTagCatalog`、`GFSourceTextLoader` 自定义 loader 链，以及 `GFTextGenerationContext` 安全循环、空态块、注释指令和 `value_formatter`。
- 配置与导表新增 `GFConfigTableImporter` 二维文本行解析、`GFConfigPipelineCommand` Godot headless 适配器、`GFConfigPipelineArtifactManifest` 和 `gf.tool.project_layout` Feature 内聚式项目结构 profile、脚手架与校验器。
- 异步和执行流新增 `GFAsyncBatch.watch_completion()`、`GFAsyncFlowTools.wait_all_completions_async()` / `wait_any_completion_async()`、`GFAsyncProgressAggregator`、`GFAsyncKeyedGate` 并发清理入口，以及 `GFCommandSequence` rollback outcome 字段。
- 诊断、日志和运行快照新增 `GFOperationDiagnosticsUtility` 命名采样统计、`GFSignalRuntimeProbe` JSON-safe 导出、`GFLogUtility.get_entries_since()`、`GFJsonLineLogSink.get_debug_snapshot()`、`GFFlowContext` 快照恢复，以及 `GFEditorTypeIndex.dispose()`。
- 资源、网络和生成产物新增 `GFAssetAttributionTools`、`GFAssetPreloadPlan` / `GFAssetUtility.preload_plan_async()`、`GFNetworkContract` 版本预检、`GFNetworkContractGenerator` 报告式生成保存、`GFNetworkServiceDiscovery` 与 `GFGeneratedArtifactReport.save_text(allowed_roots)`。
- Network 扩展新增平台中立 lobby 抽象：`GFNetworkLobbyBackend`、`GFNetworkLobbyService`、`GFNetworkLobbyDescriptor`、`GFNetworkLobbyMember`、`GFNetworkLobbyQuery`、`GFNetworkLobbyInvite`、`GFNetworkLobbyJoinResult` 与 `GFNetworkPeerIdentity`，用于外部 Steam、微信、LAN 或自建服务 adapter 映射房间、成员、邀请和平台身份。
- Network 编辑器工具新增 `GFNetworkContractAudit`，并为 `GFNetworkMessageValidator` 增加 contract allowlist、channel allowlist、sender/peer 一致性和 sequence/tick 边界校验，便于项目在运行前或入站边界启用 strict 消息审计。
- 标准平台基础能力新增 `GFPlatformCapabilitySet`、`GFPlatformRuntimeContext`、`GFPlatformLifecycleEvent`、`GFPlatformBridgeRequest`、`GFPlatformBridgeResult` 与 `GFPlatformLocaleMap`，用于外部 Steam、Web、小游戏、主机或自建平台 adapter 描述能力、上下文、生命周期、桥接结果和 locale 映射；`GFCompatibilityPreflight.require_artifact()` 现在可显式检查 artifact kind、本地文件存在性、sha256 和 size。
- JSON 与报告边界新增 `GFVariantJsonCodec.stringify_json_compatible()` / `parse_json_compatible_text()`、`GFReportValueCodec`、`GFVariantKeyCodec`、`GFValidationReport.to_json_compatible_dict()`、`GFRequestHandlerRegistry` JSON-safe 结果/事件/快照入口和 `GFByteCursor.to_json_compatible_read_report()`。
- `GFReportValueCodec.make_collection_summary()` 可输出 count/sample/hash/truncated；`GFGridMath`、`GFSurfaceScatterSampler3D`、`GFWaveFunctionCollapse2D`、`GFOperationDiagnosticsUtility`、`GFAudioBank`、纯状态机和节点状态机都补齐显式 JSON-safe 导出入口。
- `GFStorageUtility` 新增 `save_data_group()` 多文件事务保存；Save 扩展新增 `GFSaveSlotStorageAdapter`，以可配置 data/meta 文件模板承载通用槽位持久化。
- UI 和触控输入新增 `GFControlFocusUtility`、`GFVirtualListFocusModel`、`GFPointerCapture`、`GFTouchControl2D`、`GFVirtualInputBridge` 与 `GFDragDropController`；`GFDropZone.is_stale()` 和 `GFDragDropUtility.prune_stale_zones()` 可显式剪枝失效落点。
- `GFSeedUtility.try_make_stable_seed()`、`GFNumberFormatter.get_default_compact_suffixes()`、`GFGridOccupancy` 稳定快照查询、`GFShaderParameterUtility` 全局 shader 参数管理、`GFExtensionSettings.get_manifest_graph_report(include_cached_load_errors)` 等入口补齐生成、格式化、占用、显示和扩展诊断场景。
- `GFViewportUtility.world_to_screen_3d_report()`、`GFShaderParameterUtility` live/declaration 分层查询、`GFAssetMetadataUtility.get_object_metadata_state()`、Camera Director debug snapshot 和 `GFCameraOrbitInput3D` 缺失输入诊断字段补齐运行时报告入口。
- BehaviorTree 新增 `GFBehaviorTree.BlackboardScope.set_parent()`，Camera 扩展新增 Rig / Director 的 `camera_scope_path`、`camera_channel` 和 `GFCameraRig2D.get_camera_pose_data()`；ActionQueue 新增 `GFWaitAction.get_wait_guard_node()` 扩展点。
- 报告边界继续补齐 `GFReportValueCodec.to_report_dictionary()`、Capability Query / Recipe、Combat Action / HitContext / Result、Content Package Manifest / ExportPlan 和 Decision Evaluation 的 JSON-safe 报告入口；新增 `GFRuntimeCleanupScope` 作为可复用的运行时清理回调 scope。
- 资源解析器新增 owner/token 注册 API：`register_path_for_owner()`、`unregister_registration()` 和 `unregister_owner()`，用于内容包、项目模块或工具批量撤销自身贡献而不影响同 key 的其他来源。
- 标准 Assets 新增 `GFAssetCatalogEntry`、`GFAssetCatalog`、`GFAssetCatalogSourceProvider`、`GFAssetCatalogSourceRegistry` 与 `GFResourceRegistryAssetSourceProvider`，为项目素材库、资产索引、标签/分类查询和多来源 catalog snapshot 提供通用底座。
- Decision 扩展新增 `GFDecisionEvaluation`、`GFDecisionSet.evaluate()`、`GFDecisionSet.select_best_from_scores()` 和 `GFDecisionUtility.evaluate()`，支持单次评分同时返回最佳候选与调试快照。
- Combat 新增 `GFSkillActivationStep` 与 `GFProjectileEmissionTask`，分别为技能成本/预留提供可验证、可逆序回滚的激活事务步骤，为单次发射提供门控、硬数量预算、时间快照和一次性提交句柄。
- Content Package 新增 `GFContentPackageCatalog.duplicate_catalog()`，资源解析器新增 `replace_owner_paths()` 原子 owner 快照替换；Decision 的 Set、Option 与 Consideration 新增作者态校验报告，Context 新增可配置捕获预算与截断诊断。
- 标准公共机制新增 `GFObjectCandidateRegistry`，为交互、空间候选、编辑器选择和项目侧 provider 提供弱引用候选表；Feedback 新增 `GFHapticBackend` 输出后端协议，Save 新增 `GFSaveTransactionParticipant` 事务参与者协议。
- `GFProtocolAckLedger` 新增 packet 尝试记录、retry-ready 查询和入站 packet 去重/顺序报告，用于自定义可靠消息、SDK 包装层或本地进程桥接复用。
- 诊断、存储和编辑器工具新增 `GFSupportReportWorkflow`、`GFStorageSectionCache`、`GFStorageBackend.get_capability_report()`、`GFSaveSlotSyncBridge` 和 `GFScriptPatchUtility`，用于支持报告离线提交、分区脏缓存、后端能力摘要、槽位文件同步和脚本头部注解补丁。
- 核心事件系统新增 `GFEventListener`，用于显式声明事件回调、owner 和派发参数数量，避免 targetless / custom `Callable` 无法可靠 introspection 时形成隐式契约。
- Kernel 新增 `GFCancellationToken`、`GFCancellationSource`、`GFAsyncCompletion` 与 `GFAsyncScope`，为项目 Installer、扩展 Installer、`GFNodeContext` scoped 安装流程、编辑器任务和标准层异步工具提供统一的协作取消、一次性终态和后进先出清理回调边界。
- Kernel 新增 `GFKernelRuntime` 作为 `GFArchitecture` 主生命周期状态机，并新增 `GFArchitecture.register_service()` / `get_service()` / `unregister_service()` / `has_service()` 运行时 capability 注册入口。
- Kernel 新增 `GFSubscriptionToken` / `GFLifetimeSubscription` / `GFSignalSubscriptionToken`，`GFBindableProperty` 补齐 `subscribe_token()`、`subscribe_owned()` 与 `subscribe_method()`，为响应式属性和 Godot Signal 订阅提供显式取消句柄和 owner 生命周期绑定。
- Kernel 新增 `GFProjectReferenceScanner`，为扩展审计、编辑器工具和未来项目引用检查提供统一的项目文本资源扫描、强/弱引用分级和扫描预算报告。
- Kernel Extension 新增 `GFExtensionManifestDiscovery`，在无状态 manifest 读取器之上提供可自动失效的 manifest 发现快照缓存，并在快照中区分读取错误、校验错误和聚合 invalid manifest 报告。
- Kernel Extension 新增 `GFExtensionPresetDiscovery` 与 `GFExtensionSelectionDiscovery`，为 preset 组合、启用选择、依赖补齐、启用/禁用 manifest 和 editor contribution 路径提供可自动失效的分层 snapshot。
- Kernel Extension 新增 `GFExtensionToolContribution`，以版本化白名单 schema 校验扩展编辑器工具贡献；未来版本、未知字段、非法扩展 ID、错误路径类型和越过扩展根的贡献默认拒绝。
- Kernel Editor 新增 `GFEditorCommand.is_sealed()`，用于判断编辑器命令实例是否已进入不可重配置状态。
- Kernel Editor 新增 `GFEditorBackgroundRequestTask` 内部任务句柄，用于统一编辑器后台 worker 的启动、取消、等待和结果归属。
- Kernel Editor 新增 `GFThumbnailRenderRequest` 与 `GFThumbnailRenderTask`，缩略图渲染可按请求排队、等待、取消和读取结构化终态。
- Kernel Editor 新增 `GFResourcePreviewSourceRegistry` 内部预览来源注册表，为 Resource 预览 provider、来源优先级和预览生成预算提供统一边界。
- Kernel Package 新增 `GFPackageTransactionEngine`、共享 transaction schema 与 Godot/Python `recover` 命令，以持久 journal、payload/lockfile 快照和版本化事务报告承载安装、更新、卸载及 metadata-only 提交。
- Kernel Editor 新增 `GFEditorActionDefinition.can_invoke()` / `get_invocation_report()` 和 action snapshot `include_invocation` 选项，用于区分 UI 可用性与严格调用探针。
- Kernel Editor 新增 `GFEditorContributionRegistry` 内部清单读取器，标准库编辑器贡献可通过 data-only manifest 与模板文本注入，并在目标脚本缺失时跳过对应记录。
- `GFAsyncTrackerUtility` 新增 `refresh_snapshot()` / `refresh_snapshots()`，外部快照 provider 改由显式刷新点调用，并以缓存快照、调用预算和稳定错误报告承载观察结果。
- `GFDiagnosticsUtility` 新增 `publish_monitor_sample()`、`publish_snapshot_section()` 和 `publish_tool_snapshot()`，`GFDebugOverlayUtility` 新增 `push_panel_content()`；外部观察值统一在受控刷新点发布，采集与 GUI 刷新只读取有界缓存。

### 🔄 机制更改 (Changed)

- 内置扩展继续采用独立 SemVer：本次按各自契约破坏面将 Asset Metadata、Behavior Tree、Camera、Capability、Combat、Content Package、Decision、Dialogue、Domain、Feedback、Interaction、Network、Save 与 Turn Based 提升主版本；Action Queue、Flow 与 Physics 仅增加兼容能力并提升次版本。扩展清单中的框架 `version` 与扩展 `extension_version` 不再混为同一版本轴。
- `GFPluginProjectSettings.ensure_all()` 改为仅注册进程内默认值、重置值和 Inspector 元数据，不再隐式保存整个 `ProjectSettings`；需要落盘的用户操作继续由扩展管理器或所属工具显式提交。
- `GF Package Manager` 的项目写入边界改由独立 Package Transaction Engine 统一负责；Godot 原生 backend 与 Python 维护工具不再各自维护临时目录回滚和 lockfile-last 写入，而是复用一致的 `preparing` / `prepared` / `payload_applied` / `committed` 阶段语义、自动恢复和 live-owner 并发阻断。
- `GF Package Manager` 新增内核内部 cache policy 与 filesystem artifact store，提供 `project_local`、`external_read_only`、`external_shared_rw` 三种显式模式和 `cache-init` 命令；外部目录必须具备版本化 GF marker，verified registry 与 archive 使用完整 SHA-256 内容寻址，临时下载、registry 派生文件和 offline bundle 解包保持在项目 workspace。
- Package lock 的 installed-state 契约升级为精确文件基线：每个 payload 文件记录 SHA-256 与字节数，`verify-lock` 要求清单和元数据完全对应；更新、卸载及旧文件清理会在同一事务内拒绝覆盖或删除已被项目修改的文件。
- `gf_package_resolver.py` 的 `install-plan` / `update-plan` / `uninstall-plan` 收敛为纯计划入口，不再写入 lockfile；已有依赖进入新安装闭包时会完整保留 `files` 与 `file_metadata`，真实 installed-state 只能由 Package Transaction Engine 提交。
- Package transaction journal、cache root、workspace、registry archive 与目标项目路径统一执行词法路径、现存祖先 realpath 和 symlink / junction 边界校验；恢复采用旧状态、计划状态与当前状态三方冲突判断，不再静默覆盖进程退出后的项目编辑。
- Godot 原生 package staging 使用紧凑的项目内哈希目录，避免较长 Windows 项目路径因内部重复包名和操作名越过路径预算，同时继续执行链接边界与内容摘要校验。
- 维护检查按场景分配默认超时预算：普通检查保持 600 秒，编辑器安装向导烟测使用 1200 秒，24 场景的 Godot 原生包 CLI 烟测按发布实测使用 2400 秒；每次 Godot 子命令仍保留独立 120 秒上限，显式 `check --timeout` 继续精确覆盖全部所选检查，避免把场景总耗时误判为卡死，同时保留单场景主动卡死检测。
- 配置访问器生成器迁入 `gf.tool.config_pipeline`；配置数据库、访问器与 artifact manifest 采用同一产物所有权、摘要校验和失败回滚边界，默认不覆盖无法证明由当前 pipeline 所有的既有文件。
- 项目布局工具使用严格 profile schema、realpath containment 和显式 operation journal；dry-run 区分 `planned_paths`，真实执行记录所有递归创建的父目录，并在失败时按逆序完整回滚。
- API/AI 文档生成改为 staging、校验后整体替换，相关输出目录在任一生成失败时保持旧快照；维护器会读取本次 Godot 日志、拒绝空 GUT 绿灯，并从源码临时构建 API baseline，公开文档链接也必须保持在文档根内。
- `GFReportValueCodec` 的节点、集合、PackedArray 与总字节预算改为硬工作量边界；外发日志 privacy profile 同时覆盖 tag、message、text 与 context，Analytics 按最终 envelope 字节数切批并以显式 draining 状态完成关闭。

- `GFNumberFormatter` 默认 compact 后缀改为 getter 事实来源；`GFWaveFunctionCollapse2D` 复用 `GFGridTransform2D` 方向变换；`GFInputRecording.add_event()` 按时间二分插入；`GFInputSequenceTrigger.required_action_ids` 兼容路径缓存生成分支并按 action/gap 失效；`GFInputFormatter` 静态 provider API 改为默认 registry 包装层，图标 atlas 复用 `GFInputEventIdentity` 并新增缺失路径 negative cache，冲突分析按事件桶扫描。
- `GFResourceRegistryTools.scan_resource_paths()` 的目录遍历改为复用 `GFPathEnumerationTools`，资源注册表层继续保留 glob、`.import` sidecar 与资源路径数量上限语义；`package-godot-smoke` 现在校验安装 lockfile 文件清单、运行时包写入边界和生成解析脚本的 `@tool` 标记。
- `GFStorageCodec` 的 JSON 格式现在默认复用 `GFVariantJsonCodec`，可保留 Vector、Color、PackedArray、Transform 以及 `NaN` / `INF` / `-INF` 等值，避免存档 JSON stringify 时被替换为 `null`。
- `GFStorageCodec` 的 JSON 字典排序改为类型感知 stable key token，不再用 `str(key)` 比较，避免 `1` 与 `"1"` 等跨类型 key 在 checksum 或序列化文本中出现顺序不稳定。
- `GFStorageUtility` 的路径策略改为严格 fail closed：默认拒绝绝对路径和包含 `..` 的跨目录相对路径，不再收敛到存储根目录下的同名文件。
- `GFConfigLocalizationKeyValidationRule` 默认要求显式 `known_keys` 或 `text_map`；无 key catalog 时报告 `localization_key_source_missing`，`TranslationServer` 只作为显式非严格模式的弱 fallback。
- 公开报告的路径字符串和 Resource 路径经 `GFReportValueCodec` 导出时默认脱敏；开发态需要完整路径时显式传 `path_redaction = "none"`。
- `GFReportValueCodec` 下沉到 `kernel/core`，作为 kernel、standard 与 extensions 共享的唯一报告边界编码器；CLI、编辑器展示和标准模块诊断输出不再各自使用宽松 JSON-compatible sanitizer。
- `GFTypeEventSystem`、`GFArchitecture`、`Gf` 门面、`GFModel` / `GFSystem` / `GFUtility` / `GFController` 以及状态机事件代理统一改为接收 `GFEventListener`；事件系统不再从裸 `Callable` 推断参数契约。
- `GFInstaller` 与 `GFNodeContext` 的 `install()` / `install_bindings()` 钩子现在接收 `GFAsyncScope`；项目 Installer 超时、初始化失败、架构释放和 scoped 节点退出树都会取消对应 scope 并执行登记清理，迟到写入仍由架构失败边界拒绝。
- `GFEditorTypeIndex` 默认不再为短生命周期扫描隐式订阅 `EditorFileSystem`；长期持有的编辑器工具需要调用 `enable_live_invalidation(owner)` 进入 owner-bound live 缓存失效模式。
- `GFArchitecture` 的父级查找统一通过 visited guard：模块查询、工厂查询/创建、时间提供器、命令历史和依赖诊断都会在腐坏父链循环处停止；binding diagnostics 新增 `parent_chain_cycle_detected` / `parent_chain_truncated` 字段，dependency diagnostics 使用 `dependency_parent_chain_cycle` 区分父链循环与普通缺依赖。
- `GFArchitecture` 主生命周期从多布尔组合收敛为 `GFKernelRuntime` 状态机；`init()`、动态注册、热替换和分帧恢复等 public async 边界现在返回 `bool`，调用方可直接判断失败、超时或取消。
- 命令历史快照不再按方法名扫描 Utility；历史工具通过 `GFArchitecture.SERVICE_COMMAND_HISTORY_STORE` 显式注册为 runtime service，避免 duck typing 误匹配。
- 本地 alias 指向缺失目标时不再回退父级同名服务；alias 错误会在本地失败，减少子架构覆盖语义的歧义。
- `GFEditorCommand` 实例成功执行或写入 UndoRedo 后会冻结配置；编辑器工具应为每次独立编辑动作创建新命令，避免历史 redo / undo 被后续重配置污染。
- `GFEditorActionDefinition.is_available()` 明确收敛为轻量 UI 可用性查询；`invoke()`、`create_command()` 和新调用探针统一尊重 `availability_callback`，避免禁用上下文仍能直接执行动作。
- Package Manager Dock 不再直接持有 `Thread` 和 worker；后台请求生命周期改由 `GFEditorBackgroundRequestTask` 归属，退出时先取消任务再等待结果并清空 active task。
- 标准层异步等待、flow、batch、timeout 与 keyed gate 统一复用 Kernel 的 `GFCancellationToken` / `GFCancellationSource` / `GFAsyncCompletion`；`GFAsyncWaitUtility.wait_completion_async()` 成为 completion 等待入口，避免 Kernel 反向依赖标准层等待工具。
- `GFThumbnailRenderer` 的批量预览取消从全局布尔开关收敛为 request/task 句柄语义；直接渲染入口仍返回旧结果类型，需要可取消或可诊断任务时使用 `submit_render_request()`。
- 通用 Resource 预览生成器改为通过 preview source/provider 注册表解析源纹理，并对未知 Resource、超大源纹理和超大目标尺寸采用稳定状态与 fail-closed 预算策略。
- 标准库编辑器贡献从可执行聚合脚本切换为 `gf_editor_contributions.json` 与模板文本；根插件不再加载 standard 脚本来读取记录，partial standard 安装或残留文件不会阻断核心插件启动。
- 节点状态机和节点状态的事件 architecture 缓存改为 `WeakRef`，不再延长外部 `GFArchitecture` 生命周期。
- `GFAsyncTrackerUtility` 不再保存对象型 `snapshot_provider` Callable 本体，而是保存弱目标引用和方法名，避免追踪器强持有 provider 目标。
- `GFDiagnosticsUtility` 的命令、监控和快照贡献改为 owner-bound 所有权；外部 monitor、工具快照和顶层分区在发布时完成 report-safe 编码与宽度、节点、深度、字节预算校验，采集阶段不再同步执行项目回调。无效新采样会保留上一份有效缓存，owner 释放后自动剪枝。
- `GFStorageUtility.load_resource()` 现在必须命中 `allowed_resource_load_type_hints`，并在 `ResourceLoader` 返回后校验实际资源实例匹配 `type_hint`；空类型 allowlist 不再表示放行所有类型提示。
- `GFGeneratedArtifactReport` 的单项 `skipped` 报告不再被 `success` 标记为失败；报告仍保留非 OK `error_code` 和说明，供生成器、导入器或流水线按自身策略决定是否阻断后续步骤。
- `GFGeneratedArtifactReport.save_text()` 现在拒绝绝对文件系统路径和非 `res://` / `user://` 输出路径，并可由 `allowed_roots` 阻断生成物写入手写源码区。
- `GFGeneratedArtifactReport` 和 `GFTemplateGenerationManifest` 的报告 / 摘要返回值现在会把动态 `metadata`、可选 `reports` 与 `manifests` 通过 `GFReportValueCodec` 收束为 JSON-safe 结构，避免 Object、非有限浮点或 PackedArray 泄漏到公开报告边界。
- `GFExtensionManifest` 与 `GFExtensionPreset` 的 JSON 文件报告现在只返回 JSON-safe 的 `manifest_data` / `preset_data`，`from_json_file()` 只在报告 `ok=true` 时返回对象；manifest 资源路径也会在声明来源明确时校验实际存在性。
- `GFExtensionCatalog` 的公开 manifest 扫描入口现在统一规范化 root path，`GFExtensionSettings` 的缓存 manifest 返回值改为副本，避免调用方意外修改内部缓存。
- `GFExtensionSettings` 的 manifest 缓存改由 `GFExtensionManifestDiscovery` 维护；同一扩展 root 内 manifest 文件内容、manifest 路径集合或手动写入快照的来源签名变化时，会自动重新发现而不依赖调用方显式清 cache。可读取但未通过校验的 manifest 会进入 discovery snapshot 的 `manifest_validation_errors` 与 `invalid_manifests`，不再只由图诊断补报。
- `GFExtensionSettings` 的 preset、启用选择和 editor contribution 路径派生改由 Discovery / Snapshot 家族维护；同一路径 preset 或 `editor/gf_tool_contribution.json` 文件内容变化时会自动刷新，manifest/preset/tool contribution JSON 读取和扩展 ID 校验也收敛到单一内核事实来源。
- `GFPluginActions` 的访问器生成、ProjectSettings 读取和扩展菜单动作路径发现改由 `GFPluginActionDependencies` 内部 provider 承接，插件菜单动作不再直接依赖启动期全局 `class_name`。
- `GFExtensionUsageAudit` 现在默认跳过被审计扩展自身根目录，并把引用报告中的 `preview` 改为脱敏摘要和独立 `match` 字段，避免把源码行片段带入 UI、日志或诊断报告；引用扫描升级为格式感知和依赖图辅助的分级报告，只有 GDScript 加载/类型使用、资源依赖字段或 Godot 依赖图确认的 strong / verified 引用会阻断审计，普通字符串命中只进入 weak 报告。底层扫描已迁移到 `GFProjectReferenceScanner`，同一文件会在一次读取后匹配所有禁用根目录，并在 `max_file_bytes` / `max_total_bytes` 超限时返回 `partial_scan` 和 fail-closed 的 `ok=false`。
- `GFRuntimeTask` 不再暴露可直接改写的 `requirements` 数组，任务占用对象必须通过 `set_requirements()`、`add_requirement()`、`remove_requirement()` 和 `get_requirements()` 管理；`GFRuntimeTaskGroup` 调度前会重建子任务占用，并拒绝并行子任务共享同一 requirement。
- `GFDataProjection` 配合 `GFDictionarySchema` 时改用带报告的字段规范化，可转换值继续输出规范化结果，转换失败会写入报告并保留原始输入，不再把坏值降级成类型 fallback。
- `GFModel`、`GFSystem`、`GFUtility` 与 `GFInstaller` 的异步生命周期文档现在明确说明首个 `await` 前仍运行在主线程；`Gf` 会规范化项目 Installer 路径并拒绝非 `res://` `.gd` 安装器。
- `GFArchitecture` 与 `GFArchitectureSnapshotCoordinator` 的快照输出现在收敛为 JSON 兼容值；可序列化 Model 不再以脚本资源路径作为保存键回退，缺少 `class_name` 时应重写 `get_save_key()`。
- `GFReactiveEffect.stop()` 现在会在 owner 已失效时仍通过 source 侧解绑路径清理绑定账本，减少长期运行会话中的无效绑定残留。
- `GFEditorValueField` 与 `GFResourceTableEditor` 的字典/数组展示现在先做 JSON 兼容转换，`GFEditorValueField` 额外支持标签、防抖信号、枚举、向量和自定义控件工厂，`GFSourceBuilder.doc()` 支持多行文档注释输入。
- `GFConfigPipelineRunner.export_profile_path()` 现在支持 `changed_only`、产物 manifest、freshness 报告和 skipped 运行结果；`GFConfigPipelineTableSource` 的解析选项文档同步补充注释行、注释列和条件块指令。
- `GFConfigPipeline` 的 XLSX 行解析复用统一表格行解析入口，补齐 workbook / sheet 条目上限、输出路径 canonical 校验、manifest JSON-safe 导出和 Profile 构建选项白名单。
- `gf.tool.project_layout` 的 validator / scaffolder 收紧 profile schema、规则类型、严重级别、Feature ID、扫描预算和失败回滚，避免未知规则、半成品目录或生成物泄漏被静默放过。
- `GF Package Manager` 的本地 registry archive 现在只接受本地 registry bundle 内的相对文件路径，远程 registry 必须解析到 HTTP(S) archive；archive 审计会覆盖条目数量、解压大小、压缩比、ZIP64、路径长度和路径深度，Godot 原生 CLI JSON 输出会先经过 JSON-compatible sanitizer，卸载时也会在 lockfile 写入成功后再清理空目录。
- GF package manifest 维护 gate 现在会拒绝隐藏在 `metadata` 中的软依赖、下载、registry、preset 和装配覆盖字段，并要求 extension package 的 `gf_extension_id` 与自身拥有的 `gf_extension.json` 对齐。
- GF package manifest 中 extension 绑定字段统一为 `gf_extension_id`；运行时 extension manifest 只描述运行时扩展自身，扩展编辑器工具改由 `editor/gf_tool_contribution.json` 与独立 tool package 贡献。
- 标准 UI、设置、显示和网络编辑器能力进一步拆分为更细 package，`gf.tool.network.editor` 可独立安装到需要网络契约编辑/生成工具的项目；运行时网络 package 不再携带编辑器 action 贡献。
- GF 编辑器插件 helper 的 `setup()` 现在按 helper 维度保持幂等，重复装配前会清理旧实例；Package Manager Dock 退出时会等待活动 worker 收束，避免编辑器关闭后后台事务继续写项目文件。
- `GFDependencyGraphTools` 的依赖遍历改为显式栈迭代，减少长链依赖图的递归深度风险和中间 stack 复制。
- `GFNetworkContractGenerator.generate_many()` 现在会返回 `artifact_summary` / `artifact_reports`，并把 `overwrite_existing=false` 时的已有文件视为 skipped 产物而不是批量生成失败。
- `GFTextGenerationContext` 的 token 数据路径现在支持 Godot `Packed*Array` 数字下标，循环模板也补齐 `PackedByteArray` 与 `PackedVector4Array` 作为输入源。
- `GFNodeTreeOps` 的节点收集内部改为按索引遍历子节点，减少直接子节点、同级节点和深度遍历中的中间数组分配。
- `GFValueIndex`、`GFQuerySignature`、`GFCacheDiagnostics`、`GFAsyncKeyedGate` 和 `GFAsyncProgressAggregator` 现在统一使用 `GFVariantKeyCodec`；非稳定 key 会被拒绝或从签名中忽略，避免 `var_to_str()` 对可变集合、对象和非有限浮点产生不稳定 token。
- `GFAsyncKeyedGate.request_lease()` 的 `max_concurrency` 现在只作为当前请求及其租约存活期的临时约束，不再写入持久 key 配置；等待队列推进保持 FIFO，避免后续请求绕过较早等待请求。
- `GFCommandSequence` 的步骤结果、等待结果和回滚错误报告现在会通过 `GFReportValueCodec` 输出 JSON-safe 结构，异步 rollback 会记录独立 outcome，避免运行时对象、`NaN` 或取消/超时状态混入普通错误字符串。
- `GFExecutionRequirement.evaluate()` 现在保留 `failed_count` 的原始谓词 false 语义，并新增 `raw_failed_count`、`blocking_count` 与 `none_matched_count`，避免 `MODE_NONE` 的通过/阻塞状态被 UI 或日志误读。
- `GFObservableArrayResource` 与 `GFObservableDictionaryResource` 明确 batch 期间不补发 item-level signal，只在 `end_batch()` 发出 aggregate signal。
- `GFBridgeContractReport.report_request_handlers()` 继续保留兼容入口，但 request-handler 专用 contract/adapter 条目构建逻辑已迁回 `GFRequestHandlerRegistry`。
- `GFSourceTextPatchTools` 文档和测试明确其范围是 LSP-shaped、Godot String character 坐标，不承诺 LSP UTF-16 code unit 坐标。
- `GFTextureSetClassifier` 默认后缀规则新增 packed ORM / RMA / MRA / ARM / MRO 贴图角色，导入计划 metadata 会保留 `orm` 纹理映射供项目导入器选择材质写入策略。
- `GFHeightfield3D` 新增 `normal_to_slope()`、`sample_slope_grid()` 与 `sample_slope_world()`，把高度场坡度作为可直接查询的纯数据指标，并让表面散布坡度过滤复用同一语义。
- `GFTransform3DMath` 新增 `ScaleAxisMode`、`apply_scale_axis_mode()` 与 `interpolate_scale()`；`GFSurfaceScatterSampler3D` 的 `scale_min` / `scale_max` 现在可使用 `Vector3`，并支持 `scale_axis_mode` 轴向缩放锁定。
- `GFGridMath` 现在是薄 facade，具体 2D 网格实现归属到坐标、路径、生成和连接四个专门类；`GFSpatialQueryIndex2D`、`GFSpatialQueryIndex3D` 与 `GFSpatialHash3D` 复用 `GFSpatialQueryIdentity`，2D/3D 查询记录都会输出统一 `identity` 快照。
- 输入设备分配报告、输入配置/Profile 自定义数据、重绑定冲突报告、输入录制、TileMap 缓存和拖拽调试快照现在统一收敛到 JSON-compatible 边界，默认可直接用于 `JSON.stringify()`，需要保留 Godot 原始 Variant 时可显式关闭对应 `json_compatible` 参数。
- 触屏按钮和触屏摇杆的 InputMap 桥接改为 owner-aware 聚合，同一动作被多个虚拟触控源按住时，只有最后一个来源释放后才真正释放动作；DPAD 摇杆同方向拖动只刷新手柄位置，不重复触发方向信号或动作写入。
- 运行时任务调度改为原子所有权提交：仲裁期间冻结任务配置，冲突任务在 requirement 所有权切换后才执行中断回调；任务组配置改为私有快照和显式 setter，命令序列也会冻结本次步骤计划，并只按失败步骤显式声明执行补偿。
- Foundation 的报告 key、JSON marker、schema finite policy、排序比较器、二进制读写预算、确定性浮点编码、数值文本预算和主随机流访问进一步收紧；空间哈希、查询 facade、broadphase、物理查询和采样报告统一拒绝非有限几何，并在候选后端构建失败时保持事务式回退。
- 输入运行时改为对象生命周期绑定的虚拟动作 owner；设备替换会独立报告活跃设备变化，重映射配置采用全量校验后提交，录制事件只暴露深快照，循环回放通过显式追赶预算选择无损延后或跳过完整周期。
- `GFDragDropUtility` 查询候选时会先剪枝失效 Control 落点，并在 `only_accepting=true` 时先检查接收规则再执行命中检测，减少无效回调和失效节点残留；`GFSceneUtility` 与 `GFScenePreloadMap` 现在统一规范化 `res://` 场景路径，缓存、后台加载参数、历史、延迟切场和图谱计划不再因 `./`、`..`、反斜杠或首尾空白形成重复状态；`GFAssetUtility` 缓存、`GFResourceResolverUtility` 解析报告、`GFResourceRegistry` 条目/搜索/分组输出和 `GFScenePreloadMap` 图谱遍历统一使用 `GFResourceIdentity.cache_key` 对齐资源身份，避免 `uid://`、canonical `res://` 与注册表路径混用时重复加载或重复计划。
- `GFAssetUtility`、`GFBackgroundWorkUtility` 与 `GFSceneUtility` 现在共享 threaded ResourceLoader operation 协调器，统一建模 cancel、drain、refcount、late result suppression 和 retry 复用语义，避免取消后的迟到资源写入缓存、应用队列或场景预加载缓存。
- `GFSeedUtility` 的确定性随机分支只依赖主 seed 与分支 key，不再受当前 RNG 临时状态影响；完整状态恢复只接受当前 schema 版本，避免旧格式被误当作可恢复状态。
- `GFQuadTreeUtility` 固定边界索引、`GFInputMappingUtility` 结构化运行时 key、节点状态机运行时注册组校验和状态组快照恢复都收紧失败边界；`GFAudioBankTools` / `GFAudioLibraryTools` 改为 `tool_api` 并移入 `gf.standard.audio.editor`，`GFConfigTableEditorTools` 改为 `editor_api` 并移入新增的 `gf.standard.config.editor`；`gf.standard.config` 运行时包改为显式文件清单，避免越界实体、分隔符碰撞、漏校验、失败恢复污染运行态和编辑器 helper 进入运行时闭包。
- `GFSettingsUtility` 持久化统一复用 key-safe / cycle-safe Variant JSON 编码，fallback 文件名改为严格 basename 白名单；`GFDisplaySettingsUtility` 响应外部窗口模式变更时会按窗口模式同步窗口尺寸。
- ActionQueue 的重复执行、命名队列清理、等待动作守卫和瞬时 flash 语义收紧为可取消、可释放、可测试的一致生命周期；`GFTweenActionStep.duplicate_step()` 会深拷贝目标值。
- Asset Metadata 的 schema 校验改为基于原始 metadata，不再用默认值掩盖缺失必填字段；节点树和归因报告默认输出 JSON-safe 结构，并避免把完整原始条目塞入 issue metadata。
- BehaviorTree 收紧运行时节点契约：非法 Action / Condition 返回值进入结构化失败原因，自定义节点默认 `duplicate_runtime()` 不再共享自身，黑板父级、调试快照和 metadata 输出都具备循环保护。
- Camera 分组自动发现按 scope / channel 过滤，Orbit Rig 复用基础 Rig 的 look-at 和旋转偏移语义，非有限相机输入会在姿态边界被规范化。
- 渲染预热默认不再长期 pin 资源；缓存必须显式 opt-in，并支持 cache group、最大缓存数量和按组释放。PackedScene 预热扫描/实例化改为 unsafe opt-in，需要显式 `allow_scene_instantiation`。
- Surface、Viewport、Shader 全局参数、Asset Metadata、Control Focus 和 Camera 诊断契约收紧：公开报告避免运行时对象泄漏，shader global live 与 ProjectSettings declaration 分离，未布线焦点方向默认清理，Camera selection 与 pose application 状态可分别观察。
- Standard 编辑器 dock 记录移入 100+ order 段，避免与 kernel Package Manager / Extension Manager 的内置工作区排序碰撞。
- Combat 的 Buff、Skill、索敌和发射体边界继续收紧：Buff 生命周期输出报告，重复刷新只在状态变化时发事件；技能副作用改由可回滚激活事务管理；索敌 API 明确为 2D 并拒绝非有限配置/位置；发射请求在生成节点前执行硬预算并只提交一次策略状态；追踪发射体忽略已释放目标。`GFObjectPoolUtility` 的 acquire / prewarm 系列新增入树前 `before_add` 回调。
- `GFResourceResolverUtility` 的显式 path 注册改为多记录 owner/token 模型，并支持隔离构建后原子替换 owner 完整快照；`GFContentPackageCatalog` 保有和返回 manifest 深快照，`register_resources()` 不再暴露部分更新或移除项目侧同 key 记录。
- Content Package JSON 读取改为严格字段类型，不再宽松转换字符串、数组、字典和资源项；空 root 不再拥有任意路径，可选传递依赖扫描会对 `data_only` 包 fail closed，多包导出路径按 package ID 隔离。
- `GFDecisionContext` 在赋值时主动捕获有界 subject / target 快照，缺失 key 才通过 provider 懒加载并缓存；所有评分和权重进入有限数值契约，排序只对完全相等分数使用原始顺序，调试快照统一输出 report-safe 数据。
- `GFDecisionUtility.register_decision_set()` 现在拒绝注册 ID 与资源内 `decision_set_id` 不一致的集合；`select_best()` 复用 `evaluate()` 的单次评分结果，`get_debug_snapshot(..., [])` 明确表示完整的预计算空结果，不会再次评分。
- `GFLevelUtility` 的关卡重开清理改为显式 `GFRuntimeCleanupScope`，Domain 扩展不再依赖 `gf.standard.storage` 的命令历史工具；项目需要清理命令历史或其他运行时残留时，应自行注册清理回调。
- Feedback、Flow、Interaction、Network、Physics 与 Save 扩展继续收紧报告、身份和 preflight 边界：Shake / Haptic 查询报告输出 JSON-safe 结构，haptic 保留 stop 失败明细，Flow 运行态可显式导出 JSON-safe 快照，Interaction/Combat 消息报告中的 `receiver` 改为 JSON-safe 摘要，Network service key 改为 endpoint 摘要且拒绝 Object 传输字段，Gravity probe 采样按 World3D 和确定性 tie-break 隔离，Save 载荷校验与 apply preflight 使用一致的 scope/source 结构检查。
- Dialogue 的自动边、守卫、选项与恢复流程统一使用资源指纹和有界深复制；Flow 区分执行边与数据边，并在异步节点期间冻结共享运行态、在恢复失败时回滚完整图状态。
- Network 的消息、发现、快照和 patch 统一进入有深度、节点数与字节预算的 transport value 校验；Save 在 serializer、slot metadata 与最终持久化前统一拒绝 Object、循环集合和非有限数等不稳定值。
- Turn Based 的阶段运行态按 context 隔离，Flow 通过 context lease 复核异步结果；行动实例首次入队后冻结配置，离队后永久 sealed，待处理队列由 Flow 持有并只暴露快照。
- Interaction Sensor 和 Gravity Probe 可从通用候选 provider 采样对象；诊断 core 改为只内置基础采样，资产、下载、远端缓存和扩展诊断通过 provider 主动贡献。
- Save pipeline trace 的 `shared` 与 event `payload` 现在只导出 JSON-safe 值，避免 Object、Resource、循环集合或非有限数进入调试日志、CLI 输出或存档预览。

### 🐛 Bug 修复 (Fixed)

- 修复 Linux 下 Package Transaction Engine 使用 `OS.is_process_running()` 检查当前进程 PID 时被底层 `waitpid/ECHILD` 误判为失效 owner，导致恢复入口接管仍在活动的事务 journal；当前进程 owner 现在直接判定为存活。离线 bundle 与 sibling package 的跨平台测试归档路径也会在进入 `ZIPPacker` 前完成词法归一化，不再依赖 Windows 对 `..` 路径的宽容行为。
- 修复发布维护套件在干净克隆中因未预导入 GUT `class_name` 缓存和被忽略的本地 AI API 摘要输出不存在而失败的问题；`gut` 检查现在显式展开一次受日志审计的 Godot 导入依赖，AI API 检查在输出缺失时生成、存在时严格校验 stale / missing / extra 文件，使本地与 CI 使用同一可重复质量门槛。
- 修复 Gf AutoLoad 在 `_exit_tree()` 中释放架构时，Console、Debug Overlay、UI 层、对象池、屏幕转场、Analytics 关闭监听和 Capability 运行时节点同步 `remove_child()` / `free()` 重入修改正在拆除的父节点的问题；退出状态现在使用有起止且支持嵌套的作用域，回调结束后不会污染后续正常释放。
- 修复 `maintenance-self-test` 在普通 Windows 账户下依赖符号链接创建特权而直接失败的问题；路径安全夹具在 Windows 使用目录 junction，在 POSIX 使用目录 symlink，仍验证生成目录和命令日志拒绝 reparse/link 穿越；日志卫生扫描会容忍枚举后被并发删除的日志，同时继续拒绝链接、类型与权限异常。
- 修复 GF 项目设置本地化被资源路径 Inspector 注册顺序绕过、GDScript 全局 Resource 子类无法触发资源路径数组控件、左侧 GF 分区仍显示英文，以及 GUT 夹具设置被后续保存流程写入仓库 `project.godot` 的问题。
- 修复 Project Settings 独占窗口中的资源路径控件打开全局 `EditorQuickOpenDialog` 产生独占子窗口冲突；单值和数组资源引用改用当前 Inspector 窗口拥有的 `EditorFileDialog`，代码生成输出路径改用允许目标尚不存在的保存文件语义。
- 修复 `GFDictionarySchema` 等价源 key 静默覆盖、`GFMutationBatch` 失效 Callable 被当作成功或跳过、`GFValueIndex` 可变字段值残留索引、`GFTagCatalog.configure()` 空定义忽略 options、`GFPolicyRegistry` 直接配置 providers 时不按 priority 排序、`GFTagSourceAdapter` 二参数 `get_tag_count()` 无法透传 include-child、`GFReplayTimeline` 非有限时间进入 JSON 输出、`GFVariantJsonCodec` / `GFVariantReferenceCodec` 保留 marker 碰撞、`GFByteCursor` 接受非规范 varuint，以及 `GFUuid` v7 在时钟回拨或极限同毫秒序列下排序倒退的问题。
- 修复架构失败或释放期间 owner 事件清理被 dispose guard 误报、Package Manager update-all 丢失未变更包 `file_metadata` 且把 JSON key 顺序或整数/浮点数字面差异误判为 lockfile 变化，以及 `GFSignalUtility` 断开连接时双重移除内部连接数组的问题。
- 修复 `GFVariantData.duplicate_variant()` 对循环 Dictionary / Array 使用 Godot 深复制时可能输出递归错误的问题；循环集合现在通过 identity 访问表复制并保留内部自引用。
- 修复资产缓存移除后分组路径和 pin 状态残留、目录监听同尺寸快速改写漏报、HTTP JSON body 和请求 outbox 持久化路径越界/非有限值 JSON 化、资源注册表字典 key 不一致，以及音频异步停止、导入计划路径逃逸、节拍和音高分析非有限数值泄漏到报告的问题。
- 修复配置表规则看不到已转换字段、颜色列接受无效文本、配置校验报告 context 泄漏非 JSON 值、资源路径校验缓存过期、Localization identity 回退被误判缺失，以及诊断/支持报告/监控序列/运行时 Inspector 在非有限值、失效目标、命令 metadata 和控制台命令所有权上的边界问题。
- 修复纯状态机重挂父级时活跃路径未先退出、stop 被 exit 阶段排队 transition 截断、节点状态组清理/移除暂停栈状态时退出顺序不稳定，以及 `GFReactiveStateStore` 字符串数组下标路径和 flush change 副本隔离不完整的问题。
- 修复 `GFCommandSequence` 异步 rollback 无法通知当前 undo step 取消、且 rollback 超时/取消缺少一等 outcome 字段的问题。
- 修复 `GFProjectReferenceScanner` 多目标扫描复用聚合数组时触发 GDScript typed array 参数不匹配的问题。
- 修复拖拽开始失败或非法 `drag_parent` 会留下 capture/reparent 状态、终态未断开 source 生命周期回调，以及候选选择重复排序分配的问题；拖拽视觉变更现在按 validate/commit/rollback/cleanup 事务收敛。
- 修复 `GFJobWorker` 等待永不触发的 processor Signal 时无法由 stop/cancel 收束、请求 outbox 损坏文件覆盖活队列、资源目录扫描只截断最终结果、远端缓存空 key 身份碰撞与响应体无上限、下载 sidecar 可由调用方越权指定、场景异步入口吞掉立即错误和 ACK ledger 接受不稳定复合 ID 的问题。
- 修复池化音频 player 被复用后旧 handle/tween 仍能控制新播放会话、自然完成未及时终结 handle、音高分析缺少样本/窗口/lag 预算，以及音频 mix/effect/tween 接受非有限数值的问题；播放控制统一绑定 session generation。
- 修复配置表缓存未复核可变 table key、predicate 可修改内部记录、NaN 排序破坏比较器契约、释放后的 provider Object 仍被调用、Localization miss 复制无界 key catalog、资源存在性校验缺少共享预算，以及 schema 清空遗漏独立注册项的问题。
- 修复控制台 alias 被替换后旧注册可误删新命令、诊断 active operation 与终态历史共用错误容量模型、耗时和 metadata 可污染统计、Diagnostics/Overlay 在刷新热路径同步执行外部 provider，以及编辑器诊断展示绕过统一报告 codec 的问题。
- 修复节点状态路径字符串碰撞、state/group detach 后仍持有旧 machine 引用、恢复 hook 可跨组重入修改注册表且仍报告成功、暂停栈折叠绕过退出守卫，以及编辑器状态详情未使用统一报告编码的问题；机器级恢复现在全组加锁、复核 revision 并在任一失败时整体回滚。
- 修复存储 file-family 别名碰撞、事务 marker 扩大恢复范围、宽松 envelope marker 误拆业务字典、压缩模式阻断 legacy plain JSON、迁移链贪心误选断路、未来 schema 被旧运行时降级，以及异步命令历史把 timeout 误当 cancellation 的问题。
- 修复 UI Router 同步 fallback 泄漏 pending route、旧 async replace 清除更新的 push、shader global 设置可写出 `shader_globals/` 命名空间、设置加载保留上一 profile 残值、虚拟列表接受非有限布局参数或保留失效焦点，以及全屏启动覆盖最后窗口尺寸的问题。
- 修复 `GFExtensionSettings` 启用 manifest 路径改用选择快照后，在 manifest 读取失败或依赖图无效时静默返回空路径、未发出阻断告警的问题。
- 修复 `GFActivationTransaction` 同步回调返回 Signal 或 Godot async 状态时会被当作成功值的问题；现在返回 `async_callback_unsupported` issue。
- 修复 `GFRuntimeTaskGroup` 并行子任务在加入后修改 requirements 时可能绕过组内冲突校验的问题；调度器现在会在占用 requirement 前统一询问任务的调度拒绝原因。
- 修复 `GFBlackboardEntry.coerce_value()` 与 `GFSchemaField.coerce_value()` 在转换失败时返回类型 fallback、掩盖源数据错误的问题；失败时保留输入值副本，带报告入口继续返回失败详情。
- 修复 `GFDecimalStringFormatter` 小数缩放溢出、`GFNumberFormatter` 显式 `+` 号分组丢失、`GFWeightedEntry` 接受 `NaN` / `Infinity` 权重、定点数和定点向量公开 raw setter 可留下非规范值或负零字节、`GFRegionMap2D` / `GFRegionMap3D` 修改区域尺寸后旧索引残留，以及 `GFTileMapCache` 字典快照中 Vector 与 PackedArray 不能安全 JSON 序列化的问题。
- 修复输入预设不拒绝未知版本、未分配物理输入仍触发全局动作、默认重绑定检测误收鼠标移动/触摸拖动、输入录制恢复时 duration 小于最后事件时间、回放 resume 未重建已按住虚拟动作、tap trigger setter 可形成无效点击窗口，以及输入图标 rich text 路径未转义或允许非资源 scheme 的问题。
- 修复输入预设 deadzone 可接受非有限或越界值、legacy 输入事件文本绕过白名单、触屏取消键在检测前清理阶段无法等待 release、同数量序列分支热变更继承旧进度、循环回放跨周期静默丢事件、虚拟光标恢复越界、重映射失败清空原配置和公开录制数组可污染内部顺序的问题。
- 修复 `GFDropZone` 可能命中不可交互 Control、`GFJobWorker` 在异步任务已取消后仍发出 `job_processed`，以及场景预加载缓存与图谱路径未统一规范化导致同一场景出现多份状态的问题。
- 修复 `GFStorageUtility.delete_file()` 只删除正式文件导致遗留 `.tmp` / `.bak` / `.txn` 后续恢复已删除数据、`GFSafeResourceCodec` 解码时接受伪造非存储属性、`GFSafeResourceCodecPolicy` 脚本/资源路径 allowlist 仅 trim 后匹配而可能被 `..` 段或反斜杠绕过、`GFSnapshotHistoryUtility` 裁剪当前快照时外部恢复状态不同步、`GFCommandHistoryUtility` 容量限制不约束 redo/反序列化栈、`GFOperationDiagnosticsUtility.record_async_snapshot()` 把取消终态混入 failed operation 统计，以及 Storage Viewer 直接 `JSON.stringify()` 丢失 Godot Variant / `NaN` 语义的问题。
- 修复 `GFSafeResourceCodec` 外部资源解码先加载后检查脚本依赖的问题；现在会在 `ResourceLoader.load()` 前预检外部资源依赖中的脚本路径。
- 修复 `GFScreenshotUtility.capture_burst()` 的 locale、窗口大小和 pause 状态恢复逻辑分散的问题；批量截图现在通过统一 transaction helper 幂等恢复环境。
- 修复 `GFRuntimeDebuggerPlugin` 在远端停止时直接释放已注册页签，导致后续运行丢失页签，并在编辑器卸载插件时触发 `TabContainer` 父子关系错误的问题；页签现在由 `EditorDebuggerSession` 统一管理并跨运行复用。
- 修复 `GFUIUtility.push_panel_instance()` 重挂父级时可能触发错误关闭处理、`GFUIRouterUtility` 同一目标的异步 route 冲突无法明确拒绝，以及设置 fallback 路径、复杂字典 key、循环值和外部窗口尺寸同步的边界问题。
- 修复 ActionQueue 复合动作或 repeat 动作重复执行时旧等待分支残留、命名队列清理后仍持有子队列、等待 host 离树后仍完成、零时长 flash 未立即应用和 Tween step 复制共享可变目标值的问题。
- 修复 Asset Metadata 必填字段被 schema 默认值掩盖、归因报告泄漏原始对象/路径细节，以及 BehaviorTree 非法返回值、黑板父级循环、调试快照循环和自定义运行态共享的问题。
- 修复 Camera Director 可能选择其他父级下的分组 Rig、无 Rig 时 `process_camera()` 误报已应用姿态、目标丢失时重复发出 active-rig 变更，以及 Orbit 输入在无 Rig 时仍捕获鼠标的问题。
- 修复 ActionQueue Tween `finish()` 依赖 `custom_step(INF)`、启动前 detached target/host 行为未锁定、BehaviorTree `TimeLimit(0)` 首帧仍 tick 子节点、`UntilSuccess` / `UntilFail` 重试前不 reset 子节点、Asset Metadata 空 marker 残留、归因嵌套 source path 丢失、RenderWarmup 缓存无上限和 Viewport 无效 Camera3D 返回 `INF` 坐标的问题。
- 修复 Combat Buff 自定义效果失败后内置 tag / modifier 残留、叠层 Buff 只增加层数不追加内置效果、重复 `IGNORE` Buff 仍发刷新事件、池化发射体入树时提前 auto launch，以及 homing 目标释放后触发脚本错误的问题。
- 修复 Content Package 重新同步资源键时会删除项目侧同 key 注册记录的问题；内容包撤销现在只移除 owner 属于内容包 catalog 的 resolver 记录。
- 修复 Combat 技能提交后执行失败无法补偿、发射策略状态在生成失败时提前消耗、非有限战斗数值污染 Gauge/Modifier/Hit/Projectile/Targeting、HitBox 状态递归遍历无预算，以及 2D 索敌 API 名称误导 3D 调用方的问题。
- 修复 Content Package manifest 宽松类型转换掩盖坏数据、空 root 放行绝对资源、只检查直接文件扩展、catalog 可变引用泄漏、resolver 同步中途失败留下部分记录，以及多包相同相对路径导出冲突和依赖归属错误的问题。
- 修复 Decision 近似比较破坏最高分排序、非有限权重导致聚合异常、显式空评分触发二次 provider 读取、上下文捕获无预算，以及调试快照泄漏 Resource/Object/非有限值的问题。
- 修复内置扩展 manifest 可携带维护用内部标签的问题；维护 gate 现在会拒绝 `externalization-candidate` 这类不应进入正式扩展 manifest 的 tag。
- 修复 Feedback haptic stop 失败报告丢失、同一物理手柄被玩家目标和设备目标重复输出、Flow Dock JSON 预览遇到 NaN/Object/循环结构不安全、Flow 端口缺少 `port_id` 时回退资源路径、`node_started` 中取消仍继续执行当前节点、Interaction 已释放对象快照/保留 pointer payload 覆盖/input_ray_pickable 与 cursor 共享状态、Network 旧 discovery 广告覆盖新记录、WebSocket peer id 与 host 语义冲突、ENet 断开后 peer 残留、Network debug sanitize 循环结构、Physics gravity 跨 World3D 采样/非有限值传播/同帧缓存遗漏字段参数/已释放对象引用崩溃、Save Error int 被当成功和损坏 serializer payload 可部分写入的问题。
- 修复 TurnBased 阶段/行动等待期间 stop、超时、重入和参与者释放后仍可能继续推进的问题；流程现在会清理失效 actor、同步取消等待行动并重建行动排序缓存。
- 修复 Analytics 和批量日志 sink 在部分接收失败时丢失剩余队列、JSONL sink 文件/目录/清理错误不可诊断，以及 Input Mapping Dock 清空上下文后仍残留路径或重复报告空 mapping 的问题。
- 修复 Analytics 超限 envelope 被无限回灌、异步 shutdown 无法继续排空、批量日志按错误结果字段判断成功，以及 Input Mapping Dock 加载失败后路径与已提交 context 分裂的问题。
- 修复 Projectile 未入树命中报告触发 `get_path()` 引擎错误、Decision 调试快照 StringName key 不便普通读取、Pointer 3D 同对象重绑定丢失外部 pickable 基线、Network 诊断快照段名不稳定、AudioStreamPlayer serializer 拒绝 `bus` StringName，以及 Project Layout 失败回滚和 `**/generated/**` glob 排除边界问题。
- 修复 Singleton 工厂跨 binding 循环失败后可能残留部分缓存实例的问题；`GFArchitecture` 现在以解析上下文栈检测循环并在根链路失败时回滚本次创建的 Singleton 缓存，`GFBinding` 拒绝 provider 补偿返回值时也会释放未挂树 `Node` 候选。
- 修复核心生命周期注销重入、安装期 facade 注册目标、字典递归合并、编辑器生成物原子保存、资源表类型提交、扩展 manifest / preset 校验、Extension Manager 手动刷新缓存、包管理 metadata-only 安装、标准异步超时、信号连接缓存、节点组缓存、引用池和计时器非有限 delta 等边界问题。
- 修复 Package Manager 在 payload 已修改、lockfile 被删除或替换、以及 committed journal 尚未清理时遭遇进程退出可能留下 payload 与 lockfile 不一致的问题；未提交事务会恢复旧状态，已提交事务会校验并完成清理。
- 修复 Package Manager 原生卸载未核对逐文件摘要、等内容既有文件被静默纳入 package ownership、伪造 journal 路径可越界清理、Windows 路径别名或链接可映射到根外、崩溃恢复覆盖事后编辑，以及构建器非原子发布或跟随源码链接的问题。
- 修复 Dialogue signal 重入后继续操作旧会话、截断快照参与资源身份计算，Flow 在取得共享节点租约前发信号或执行、运行态 getter 泄漏可变别名，Network 凭据键与复合数值漏检、发现编码未执行预算，Quest 进度整数溢出、Gravity duck provider 参数检查不足、Save 槽位路径别名碰撞，以及 Turn 生命周期信号递归重入的问题。
- 修复已初始化架构热替换期间 `ready()` 触发全局失败时旧实例可能从注册表摘除但未释放的问题；失败链路现在清理新旧实例并保持注册表 fail-closed。
- 修复 `api-since-touched` 把 GDScript 三引号字符串中的项目代码模板误识别为 GF 公开 API 的问题；维护器现在跳过多行字符串声明并以自测固定该边界。

### ⚠️ 废弃与移除 (Deprecated/Removed)
- 移除 `GFNumberFormatter.DEFAULT_COMPACT_SUFFIXES` public static var；该变量看似可配置但不会影响默认 compact 路径，已由 `get_default_compact_suffixes()` 和 `format_compact()` 的 `suffixes` 参数替代。
- 移除 `GFSeedUtility.get_rng()`，主随机流只能通过受控生成方法推进；移除 `GFRuntimeTaskGroup.tasks` / `mode` 直接字段和 `GFVirtualInputBridge.make_owner_id()`，避免外部绕过配置锁或手工维护生命周期字符串。
- 移除标准层旧 `GFCancelToken` / `GFCancelSource` 类名与脚本路径；取消契约统一为 Kernel 级 `GFCancellationToken` / `GFCancellationSource`。
- 移除 `GFStorageUtility` 内置 slot facade：`save_slot()`、`load_slot()`、`load_slot_result()`、`load_slot_meta()`、`load_slot_meta_result()`、`has_slot()`、`list_slots()` 和 `delete_slot()`。标准层只保留通用文件、codec 和多文件事务机制，槽位身份与文件模板由项目 adapter 定义。
- 移除维度含糊的 `GFSkillTargetingRule` / `GFSkillTargetingUtility` 类名和旧脚本路径；当前实现明确为 `GFSkillTargetingRule2D` / `GFSkillTargetingUtility2D`，不保留兼容别名。
- 移除 `addons/gf/kernel/editor/gf_config_access_generator.gd` 旧路径；`GFConfigAccessGenerator` 只由 `gf.tool.config_pipeline` 拥有，不保留跨层兼容副本。
- 移除 `GFTurnContext.actions` / `actors`、`GFTurnContext.clear_actions()`、`GFTurnPhase.is_finished` / `reset()` 的直接可变运行态入口；行动队列归属 `GFTurnFlowSystem`，阶段完成状态归属单次 context runtime。

### 🔧 API 变动说明 (API Changes)

- `GFNumberFormatter.DEFAULT_COMPACT_SUFFIXES` 已移除，读取默认后缀改用 `get_default_compact_suffixes()`；`GFSeedUtility.try_make_stable_seed(parts, options)` 返回 `{ ok, seed, error }`，供导入器、生成器和工具链区分失败与合法 `0` seed。
- `GFSeedUtility` 新增 `next_uint32()`、`next_float()`、`next_int_range()` 与 `next_float_range()`；`GFRuntimeTaskGroup` 改用 `set_tasks()`、`set_mode()`、`get_tasks()` 与 `get_mode()`；`GFUndoableCommand.set_snapshot()` 现在校验有界纯 Variant 快照并返回 `bool`。
- `GFVirtualInputBridge.press_action()` / `release_action()` / `release_owner()` 改为接收 `Object owner` 和可选 `channel_id`，并新增 `clear_all_actions()` / `prune_released_owners()`；Node owner 退出树时自动释放持有动作。
- `GFInputRemapConfig.apply_dict()` 现在返回事务报告；`GFInputRecording.events` 改为只读深快照；`GFInputPlayback` 新增 `LoopCatchUpPolicy`、`loop_catch_up_policy`、`max_loop_cycles_per_tick` 与 `loop_catch_up_limited`。
- `GFConsoleUtility.CommandTier` 新增 `INPUT` 分级，用于把输入型调试命令与只读观察、控制和危险命令区分开；依赖枚举数值的项目应改用枚举名。
- `GFDirectoryWatchUtility.get_snapshot()` 的值从单一修改时间扩展为包含 `modified_time`、`size_bytes` 和 `content_sha256` 的文件元数据字典，用于稳定识别同尺寸内容变化。
- `GFResourceRegistryEntry.to_dict()` 现在以 `resource_path` 作为资源路径字段；`from_dict()` 仍可读取旧的 `path` 字段，便于迁移已有数据。
- `GFInputDeviceUtility.get_assignment_events()` / `get_assignment_report()`、`GFInputProfileBank.to_dict()` / `apply_dict()` / `from_dict()`、`GFInputRemapConfig.to_dict()` / `apply_dict()` / `from_dict()`、`GFDragSession.to_dictionary()`、`GFDropZone.to_dictionary()` 和 `GFDragDropUtility.get_debug_snapshot()` 新增或调整 `json_compatible` 参数，默认输出 JSON-safe 结构；项目需要 Godot 原始 Variant 时显式传 `false`。
- `GFStorageUtility.allowed_resource_load_type_hints` 的空列表语义改为“不允许任何 Resource 读取”。需要使用 `load_resource()` 的项目必须显式列出允许的 `type_hint`，并确保文件实际资源类型与该 hint 兼容。
- `GFStorageUtility` 默认不再把绝对路径或跨目录相对路径收敛到同名文件；这些路径会返回 `ERR_INVALID_PARAMETER` 或空路径。需要外部绝对路径的可信编辑器工具必须显式启用 `allow_absolute_paths`。
- `GFConfigLocalizationKeyValidationRule` 新增 `require_explicit_key_source`，默认值为 `true`；依赖 TranslationServer identity fallback 的项目需要提供 `known_keys` / `text_map`，或显式关闭严格模式。
- `GFStorageCodec` JSON 排序策略变化会改变跨类型字典 key 的 canonical 输出和 checksum；依赖旧 digest 的存档迁移工具应在迁移窗口内重写 checksum。
- `GFLevelUtility.register_runtime_cleanup()` 新增 `priority` 与 `metadata` 参数，`unregister_runtime_cleanup()` 改为返回是否实际移除；依赖旧返回值的项目需要改为忽略或检查布尔结果。
- `GFDecisionUtility.register_decision_set()` 不再接受外部注册 ID 与 `GFDecisionSet.decision_set_id` 不一致的资源；需要先修正资源 ID 或用一致的注册 ID。
- `GFSkill.targeting_rule` 类型及 Combat Installer 注册项改为 `GFSkillTargetingRule2D` / `GFSkillTargetingUtility2D`；直接 preload 的路径改为 `gf_skill_targeting_rule_2d.gd` / `gf_skill_targeting_utility_2d.gd`。
- `GFSkill.activation_commit_callbacks` 已由 `activation_steps: Array[GFSkillActivationStep]` 取代；项目步骤必须提供唯一 `step_id`，同步实现验证、应用和需要时的回滚钩子。
- `GFQuadTreeUtility.insert()` / `insert_with_hit_test()` / `update()` 现在返回 `bool`，`GFNodeStateGroup.restore_state_snapshot()` 返回恢复报告；`GFSpatialQueryIndex2D` 的实体参数改为 `Variant entity`，查询返回实体值数组，int 身份记录仍会额外保留 `entity_id` 字段。
- `GFBehaviorTree.BTNode.duplicate_runtime()` 默认实现现在返回显式失败节点并记录错误，不再返回 `self`；自定义节点如果要在 `Runner(root, true)` 中使用，必须实现自己的运行态复制。
- `GFCameraDirector2D.process_camera()` / `GFCameraDirector3D.process_camera()` 现在只在真实应用相机姿态时返回 `true`；`keep_camera_when_no_rig` 已移除，无可用 Rig 时会自然保留相机当前状态并返回 `false`。
- Camera Rig / Director 新增 `camera_scope_path` 与 `camera_channel` 过滤字段；自动分组收集会按 scope / channel 隔离，显式 `rig_paths` 仍由调用方负责选择。
- `GFRenderWarmupUtility.keep_resources_cached` 默认值改为 `false`；需要保留资源引用时传 `keep_cached=true` 或设置工具属性，并按需配置 `cache_group` / `max_cached_resources`。`build_manifest_from_scene()` / `build_manifest_from_scene_path()` 默认不实例化 PackedScene，必须显式传 `allow_scene_instantiation=true`。
- `GFShaderParameterUtility.has_global_parameter()` 现在只表示当前会话 live 参数；ProjectSettings declaration 请改用 `has_global_parameter_declaration()`，live 查询请使用 `has_global_parameter_live()`。
- `GFSurfaceUtility.describe_surface_hit()` / `describe_mesh()` 的资源字段改为 JSON-safe 资源摘要，不再返回 `Mesh` / `Material` 对象引用；需要运行时对象时继续使用 `get_active_material()`、`get_base_material()` 等 getter。
- `GFBuff.on_apply()` / `on_remove()` / `on_refresh()` / `refresh_from()` 现在返回生命周期报告；`GFObjectPoolUtility.acquire()`、`prewarm()`、`prewarm_async()` 和 `prewarm_async_budget()` 新增可选 `before_add` 参数。
- `GFViewportUtility.world_to_screen_3d()` 对无效 Camera3D 返回 `Vector2.ZERO`；`GFControlFocusUtility.apply_focus_order()` 默认清理未布线方向邻居；`GFAssetMetadataUtility.write_object_metadata({})` 默认清除旧 metadata marker。
- Interaction 与 Combat 的消息结果报告不再在 `receiver` 字段返回 live `Object`；该字段现在是 `GFReportValueCodec` 生成的 JSON-safe 摘要。需要 live receiver 的调用方应使用 signal 的 `receiver` 参数、`GFInteractionContext.target` 或 `GFCombatHitContext.target`。
- `GFReportValueCodec` 的源码路径从 `addons/gf/standard/foundation/variant/gf_report_value_codec.gd` 改为 `addons/gf/kernel/core/gf_report_value_codec.gd`；依赖直接 `preload()` 旧路径的代码必须更新路径，按 `class_name GFReportValueCodec` 调用的代码无需改名。
- `GFAsyncCompletion` 的源码路径从 `addons/gf/standard/common/gf_async_completion.gd` 改为 `addons/gf/kernel/core/gf_async_completion.gd`；直接 `preload()` 旧路径的项目需要更新路径。completion 等待改用 `GFAsyncWaitUtility.wait_completion_async(completion, options)`。
- `GFCancelToken` / `GFCancelSource` 已更名并下沉为 `GFCancellationToken` / `GFCancellationSource`；token 只读检查使用 `is_cancel_requested()`，取消信号为 `cancel_requested(reason)`。
- `GFThumbnailRenderer.cancel_preview_generation` 已移除；需要中断缩略图渲染时使用 `submit_render_request()` 返回的 `GFThumbnailRenderTask.cancel()`，或调用 `cancel_render_task(task, reason)`。
- 事件监听注册 API 不再接受裸 `Callable`：`GFTypeEventSystem.register*()` / `register_simple*()`、`GFArchitecture.register_*event*()`、`Gf.listen*()`、`GFSystem` / `GFUtility` / `GFController` 和状态机代理的事件注册/注销入口都改为接收 `GFEventListener`。
- `GFInstaller.install(architecture)` / `install_bindings(binder)` 和 `GFNodeContext.install(architecture)` / `install_bindings(binder)` 的重写签名改为 `install(architecture, scope: GFAsyncScope)` 与 `install_bindings(binder, scope: GFAsyncScope)`；自定义 Installer、扩展 Installer 和场景级上下文必须同步更新签名。
- `GFModel.async_init()`、`GFSystem.async_init()` 和 `GFUtility.async_init()` 的重写签名改为 `async_init(scope: GFAsyncScope)`；模块应在每次 `await` 后检查 `scope.is_cancel_requested()`，并用 `scope.register_cleanup()` 管理临时清理。
- `Gf.init()`、`Gf.set_architecture()`、`Gf.register_*()`、`Gf.replace_*()`、`Gf.register_*_as()`、`Gf.register_factory*()`、`Gf.replace_factory*()`、`Gf.unregister_factory()`、`GFArchitecture.init()`、`GFArchitecture.register_*()`、`GFArchitecture.replace_*()`、`GFArchitecture.register_*_instance*()`、`GFArchitecture.register_factory*()`、`GFArchitecture.replace_factory*()`、`GFArchitecture.unregister_factory()`、`restore_all_models_state_async()`、`restore_global_snapshot_async()`、`GFBindBuilder.as_singleton()` 和 `as_transient()` 现在返回 `bool`，依赖旧 `void` 签名的调用方应接收或显式忽略返回值。
- `GFFlowNode.serialize_runtime_state()`、`GFFlowGraph.serialize_runtime_state()` 与 `GFFlowContext.serialize_runtime_state()` 新增默认参数 `json_compatible=false`；`GFFlowContext.create_runtime_snapshot()` 新增 `json_compatible` 选项，用于诊断/CLI 边界输出 JSON-safe 快照。
- `GFShakeUtility.get_shake_info()`、`GFShakeUtility.get_debug_snapshot()`、`GFHapticUtility.apply_current_outputs()`、`GFHapticUtility.get_haptic_info()` 与 `GFHapticUtility.get_debug_snapshot()` 的公开报告会清洗为 JSON-safe 值；`GFHapticUtility.apply_current_outputs()` 的返回报告新增 `failed_stop_count` 与 `failed_stops`。`auto_apply_on_tick=false` 时，调用方仍负责在 tick 后显式调用 `apply_current_outputs()` 以刷新 stop。
- Save 图载荷的 `validate_payload_for_scope()` 与 `apply_scope()` 现在都会拒绝非 Dictionary 的 scope descriptor、source entry、source descriptor 和 source data；工厂创建的 Source 会对齐并校验 payload source key，无法对齐时立即释放并失败。
- `GFNetworkContractField.ValueType.OBJECT` 不再允许通过网络契约定义校验；需要传输对象时应先转换为稳定 ID、资源键或项目自定义 DTO。
- 本地 package manifest 中 extension package 的 `enable_extension` 字段已改为 `gf_extension_id`；该字段只绑定 package 内拥有的 `gf_extension.json.id`，不表示安装后自动启用扩展。
- `GFHapticUtility.haptic_backend` 接受任意 `Object` 后端；长期平台适配应实现 `GFHapticBackend`，临时桥接仍可使用 `output_handler` / `stop_handler`。
- `GFConsoleUtility.register_command()` / `register_command_definition()` 现在要求显式 `owner` 并返回 `GFLifetimeSubscription`；取消旧 token 只能移除自身 registration generation，不会误删同名替换命令。
- `GFDiagnosticsUtility.register_command()` 现在要求显式 `owner`；`register_monitor()` 不再接收 provider，而是配合 `publish_monitor_sample()` 使用。旧 snapshot/tool provider 注册入口已由 `publish_snapshot_section()` / `publish_tool_snapshot()` 和对应 remove 入口替代。
- `GFDebugOverlayUtility.watch_value()` / `register_panel()` 已移除；观察值改用 `push_watch_value()`，结构化面板改用 `push_panel_content()`，文本面板继续使用 `push_panel_text()`。
- `GFRuntimeTunableProperty.with_range()` / `normalize_value()` 已由返回校验结果的 `configure_range()` / `try_normalize_value()` 替代；非法类型和非有限范围不再静默归零或写入目标。
- `GFOperationDiagnosticsUtility.max_operations` 拆分为 `max_active_operations` 与 `max_completed_operations`；`GFCommandHistoryUtility.async_timeout_seconds` 改为只告警、不伪造取消的 `async_stall_warning_seconds`。
- `GFSettingsUtility.from_dict()` 拆分为明确的 `replace_from_dict()` 与 `merge_from_dict()`，`load_settings()` 使用 replace 语义；`GFSceneUtility.load_scene_async()` 现在返回同步发起阶段的 Godot `Error`。
- `GFDownloadUtility.enqueue_download()` 不再接受 `temp_path` / `segment_path`，sidecar 由目标路径独占派生；`GFProtocolAckLedger` packet ID 只接受非空 `String` / `StringName` 或 `int`。
- `GFNodeStateGroup.transition_to()` 与机器代理入口新增 `StackExitPolicy`，默认 `REQUIRE_GUARDS`；状态机恢复报告 schema 升级，新增 blocked operations、registry revision/stability 和整体 rollback 字段。
- `GFStorageCodec` envelope 新增精确版本字段并采用严格保留字段集合；无版本旧 envelope 不再自动拆包。`GFStorageUtility` 的整数 slot facade 已直接移除。
- `GFConfigAccessGenerator` 的源码路径改为 `addons/gf/tools/config_pipeline/gf_config_access_generator.gd`；`class_name` 保持不变，但直接 preload 旧 kernel 路径的代码必须更新。
- `GFTurnAction` 的配置属性在首次入队后只读，`is_cancelled` 改为只读并新增 `is_sealed()`；`GFTurnFlowSystem` 新增 `get_actions()` / `get_action_count()` / `clear_actions()`，`context` / `phases` 返回受控值或快照；`GFTurnContext` 通过 `get_actors()` 暴露参与者快照；`GFTurnPhase.finish()` 可接收所属 context，并以 `is_finished_for(context)` 查询单次运行态。
- `.gf/packages.lock.json` 的有文件 package 现在必须同时提供精确 `files` 与逐文件 `file_metadata`。旧的仅路径 lock 不能通过严格 verify，也不能作为安全更新或卸载基线。
- `GFBatchedLogSink` callback 结果统一为 `{ "ok": bool, ... }`；缺失 `ok`、非 Dictionary 或 `ok=false` 都按失败处理并保留未确认批次，不再接受 `success` 作为并行契约。
- Input Mapping Dock 的 context 文件只接受 `res://` / `user://` 下不超过 4 MiB 的 `.tres`；`GFJsonLineLogSink` 自定义路径与 Analytics client ID 路径只接受受控 `user://` 位置，不再收敛绝对路径或父级越界路径。
- Package lock、transaction journal 和 cache marker 必须满足当前完整 schema 与内容摘要；缺字段、未知字段、路径别名、链接目标或无法证明 ownership 的状态会 fail closed，不再按旧格式推断。
- `GFCapabilityUtility.add_capability()` / `add_required_capability()` 不再接收通用 provider 参数；默认构造、外部实例、所有权转移和 PackedScene 实例化改为彼此独立的显式入口。
- `GFSaveSlotWorkflow.build_cards_from_storage()` 已由接收 `GFSaveSlotStorageAdapter` 的 `build_cards_from_slot_store()` 取代，槽位业务契约不再反向依赖通用存储工具。
- `GFPriorityQueue.push()` 的 priority 从 `int` 扩展为有限 `float`，返回值从 `void` 改为 `bool`；NaN 和 Infinity 会被拒绝。
- `GFDialogueRunner` 运行快照 schema 从 2 升级为 4，旧快照不会被隐式猜测或恢复。
- 继承 `GFNodeSerializer` 的自定义序列化器需要处理 `_apply_property_specs()` 返回的 `Array[String]`；该方法不再以 `void` 静默忽略非法载荷。

### 📘 升级指南 (Migration Guide)

- 如果项目读写 `GFNumberFormatter.DEFAULT_COMPACT_SUFFIXES`，改为读取 `get_default_compact_suffixes()` 或在 `format_compact()` 传入自定义 `suffixes`；如果 `make_stable_seed()` 用作导入缓存、程序化生成或工具链增量 key 且必须区分无效输入，请迁移到 `try_make_stable_seed()` 并处理 `ok=false`。
- 如果项目直接取得 `GFSeedUtility.get_rng()`，改为受控 `next_*()` 方法或按用途创建 branched RNG；如果直接改写任务组 `tasks` / `mode`，改为在调度前调用显式 setter，并处理失败返回值。
- 虚拟输入桥调用方应传入真实 owner 对象和稳定 `channel_id`，不要缓存实例 ID 字符串；重映射加载应检查 `apply_dict()` 的 `ok` / `committed`，录制数据修改应通过 `add_event()`、`clear()` 或 `apply_dict()` 完成。
- 如果项目维护自定义 GF package manifest，把 extension package 的 `enable_extension` 改为 `gf_extension_id`，并确保值与该 package 拥有的 `gf_extension.json.id` 一致。编辑器工具贡献应放入 tool package，不应写回运行时 extension manifest。
- 如果项目直接读写 `GFRuntimeTask.requirements`，需要迁移到 `set_requirements()`、`add_requirement()`、`remove_requirement()` 和 `get_requirements()`；任务调度后不能继续修改占用对象。
- 如果项目把 `Dictionary`、`Array`、Object/Resource 或非有限浮点作为 `GFValueIndex` 字段值，需要先转换成稳定文本、数值或显式 ID 后再建立索引。
- 如果项目启用了 `GFStorageUtility.allow_resource_loads`，需要同时配置 `allowed_resource_load_type_hints`，例如 `PackedStringArray(["PackedScene", "NoiseTexture2D"])`；不要把空列表当作“允许所有类型”。
- 如果项目仍直接使用 `GFStorageUtility.save_slot()` 等旧 slot API，创建项目自己的 slot adapter：用受控模板生成 data/meta 文件名，通过 `save_data_group()` 原子写入，通过 `load_data_result()`、`list_files()` 和 `delete_file()` 组合读取、枚举与删除。不要把业务槽位编号、预览字段或 UI 语义重新下沉到标准存储层。
- 如果项目的存储路径依赖旧的绝对路径/`..` 收敛行为，先清理调用方传入的路径，或在可信编辑器迁移脚本中显式打开 `allow_absolute_paths`；不要把用户输入路径直接传入 storage。
- 如果项目的本地化 key 校验未提供 key catalog，补齐 `known_keys` 或 `text_map`；只有接受弱检查时才关闭 `require_explicit_key_source`。
- 如果项目把 `Dictionary`、`Array`、Object/Resource、Callable 或非有限浮点作为 `GFAsyncKeyedGate`、`GFAsyncProgressAggregator`、`GFQuerySignature` 或空间查询实体 key，需要先转换为稳定 ID、资源路径、坐标、枚举值或有限标量；`GFSpatialQueryIndex2D.query_*()` 结果类型应从 `Array[int]` 迁移到 `Array[Variant]` 或无类型 `Array`。
- 如果项目依赖上述输入或拖拽报告中的原始 `Vector2`、`PackedStringArray`、`StringName` 等 Godot 类型，应在读取端恢复 GF JSON marker，或调用对应方法时传 `json_compatible=false` 取得旧形态数据。
- 自定义 BehaviorTree 节点需要实现 `duplicate_runtime()` 并复制自身运行态；若确实要共享同一节点实例，应显式使用 `GFBehaviorTree.Runner.new(root, false)` 并由项目承担状态隔离。
- 依赖 Camera 自动分组全局选 Rig 的项目，需要把相关 Rig / Director 放入同一父 scope，或显式设置一致的 `camera_scope_path` / `camera_channel`；跨 scope 选择请改用 `rig_paths`。
- 如果调用方把 `process_camera()` 的返回值当作“相机仍保持有效”，需要改为检查返回值是否表示“本帧实际应用了 Rig 姿态”，无 Rig 保持现状的分支应单独处理。
- 如果依赖 RenderWarmup 预热后保留资源引用，显式开启 `keep_cached` 并设置合理的缓存上限；如果从 PackedScene 构建预热清单，只有确认实例化不会触发项目副作用时才传 `allow_scene_instantiation=true`。
- 如果项目把 Surface/Asset Metadata/Viewport/Camera 调试报告直接传给 `JSON.stringify()`，优先使用新报告字段或 JSON-safe 摘要；如果旧代码从报告里读取 `Material` / `Mesh` 对象，应改用对应 runtime getter。
- 如果项目把 shader global 的 ProjectSettings 声明当作 live 参数存在性，需要迁移到 declaration/live 分层 API，并在实际写值前确保当前会话已注册 live 参数。
- 如果项目或扩展重写了 Installer / NodeContext 装配钩子，把签名更新为带 `GFAsyncScope` 的版本；异步装配应在每次 `await` 后检查 `scope.is_cancel_requested()`，并用 `scope.register_cleanup()` 释放临时连接、后台请求或外部句柄。
- 如果项目或扩展重写了 `GFModel` / `GFSystem` / `GFUtility` 的 `async_init()`，把签名更新为 `async_init(scope: GFAsyncScope)`。模块超时、架构失败或 dispose 后，scope 会进入取消状态。
- 如果项目调用 `Gf.init()`、`Gf.set_architecture()`、动态注册/替换、Binder 完成入口或分帧恢复入口，建议接收返回的 `bool` 并在 `false` 时停止后续依赖流程；只做 best-effort 装配时也应显式用 `_result` 变量忽略。
- 如果项目 UI 依赖 `apply_focus_order(axis=horizontal/vertical)` 保留另一轴手工邻居，需要显式传 `preserve_unwired_directional_neighbors=true`。
- 如果项目向 `add_capability()` / `add_required_capability()` 传 provider：默认构造直接删除第三个参数；外部自管实例改用 `add_capability_instance()`；把实例所有权转移给 Utility 时使用 `adopt_capability_instance()` 并确认返回值就是传入实例；PackedScene 改用 `add_scene_capability()`。
- 如果项目用空 metadata 作为扫描标记，需要显式传 `mark_scanned_empty=true`；如果项目重写 `GFBuff` 生命周期方法，应返回 `{ "ok": true }` 或完整生命周期报告；如果项目依赖 `activation_commit_callbacks` 在技能执行后才运行，应迁移到 `activation_committed` 信号或自定义执行成功 hook。
- 如果项目使用 Combat 自动索敌，把类名、类型标注、Installer 查询和 preload 路径迁移到 `GFSkillTargetingRule2D` / `GFSkillTargetingUtility2D`；3D 目标选择应实现独立项目策略，不要把 Node3D 传入 2D 服务。
- 如果项目通过 `activation_commit_callbacks` 扣除成本，把每项副作用迁移为 `GFSkillActivationStep`，在验证阶段保持无副作用，在应用阶段记录本次预留，并实现幂等回滚；只需要成功后通知的逻辑改为监听 `activation_committed`。
- 外部或用户内容包应启用 `check_resource_dependencies` 并设置扫描预算；手工构造 manifest 时必须提供非空受控 root。owner 全量刷新应使用 `replace_owner_paths()`，不要先清空再逐条注册。
- 如果项目从 Interaction/Combat 报告的 `receiver` 字段直接取 Object，改为读取 signal 的 `receiver` 参数或上下文 target；报告字典只用于日志、诊断和可序列化输出。
- 如果项目注册事件监听仍传 `Callable`，迁移为 `GFEventListener.from_callable(callback, 1)`；对象方法优先使用 `GFEventListener.from_method(owner, &"method_name", 1)`。类型事件和简单事件当前都会主动传入 1 个派发参数，owner 绑定继续通过 `register_*_owned()`、`listen_*_owned()` 或模块基类代理表达。
- 如果项目直接使用旧取消类，改为创建 `GFCancellationSource` 并把 `get_token()` 传给只读等待方；等待 completion 时不要调用 completion 自身的等待方法，改用 `GFAsyncWaitUtility.wait_completion_async()` 以统一 timeout、guard node 和取消 token 语义。
- 如果项目把 Flow runtime_state 直接用于调试 JSON，改用 `serialize_runtime_state(true)` 或 `create_runtime_snapshot({ "json_compatible": true })`；原始运行态仍用于内存恢复，不应直接写入 JSON。
- 如果项目构造 Save payload，请确保每个 source entry 至少包含 Dictionary 类型的 `descriptor` 和 `data`；如果数据需要迁移，应先在项目迁移层转换为当前 schema，再调用 `validate_payload_for_scope()` 或 `apply_scope()`。
- 如果项目调用 `GFSaveSlotWorkflow.build_cards_from_storage()`，先用项目的 `GFSaveSlotStorageAdapter` 封装槽位枚举与摘要读取，再调用 `build_cards_from_slot_store()`；不要把 UI 槽位语义重新写回 `GFStorageUtility`。
- 如果项目调用 `GFPriorityQueue.push()`，应检查布尔返回值并拒绝或修正非有限 priority；依赖整数优先级的代码无需转换，但不要继续假设该方法返回 `void`。
- 如果项目持久化了 `GFDialogueRunner` schema 2 快照，必须在项目迁移层重新建立 schema 4 所需的资源指纹与上下文数据，或从业务存档重新开始该段对话；运行时不会直接接受旧 schema。
- 如果自定义 `GFNodeSerializer` 调用 `_apply_property_specs()`，应把返回错误并入反序列化报告并停止提交当前对象；空数组才表示属性校验和应用成功。
- 如果项目注册自定义控制台或诊断命令，把生命周期 `owner` 作为首个参数，并保留控制台返回的 subscription token。monitor 先调用 `register_monitor(owner, id, options)`，再在项目自己的刷新点调用 `publish_monitor_sample()`；工具与分区快照改用 `publish_tool_snapshot()` / `publish_snapshot_section()`。采集阶段不会再调用 provider。
- 如果项目使用旧 Overlay provider，改为在状态变化、定时采样或项目帧循环中调用 `push_watch_value()` / `push_panel_content()`；不要把业务副作用放进诊断刷新路径。
- 如果项目使用 `with_range()` / `normalize_value()`，迁移到 `configure_range()` / `try_normalize_value()` 并处理失败报告；操作诊断容量改为分别配置 active/history，命令历史的 stall 阈值不再作为取消依据。
- 如果项目加载设置时需要保留未出现字段，显式调用 `merge_from_dict()`；恢复完整 profile 或磁盘文件时使用 `replace_from_dict()`。调用 `load_scene_async()` / `load_scene_with_transition()` 时接收立即返回的 `Error`，仅在 `OK` 后等待异步终态信号。
- 如果项目传入下载 `temp_path` / `segment_path`，删除这些选项；如果 ACK packet ID 使用 Array、Dictionary、Object 或其他复合 Variant，先转换为稳定字符串或整数协议 ID。
- 如果项目依赖切换状态时强制清空暂停栈，显式传 `StackExitPolicy.FORCE`；普通切换保留默认守卫语义。读取状态恢复报告时按新 schema 检查 `ok`、`rolled_back`、`blocked_operations` 和 `registry_stable`。
- 如果项目存在旧版无 `__gf_storage_envelope_version` 的 envelope 文件，升级前先用旧版 codec 读出并以当前格式重写；当前运行时不会恢复宽松 marker 识别。旧整数 slot facade 需要迁移到项目 adapter。
- 如果项目直接 preload 旧的 Kernel 配置访问器生成器路径，改为安装 `gf.tool.config_pipeline` 并引用 `addons/gf/tools/config_pipeline/gf_config_access_generator.gd`；运行时配置读取不应依赖该制作期 tool package。
- 如果项目直接修改 `GFTurnContext.actions` / `actors` 或阶段 `is_finished`，改用 `GFTurnFlowSystem.enqueue_action()`、`get_actions()`、`clear_actions()`、`GFTurnContext.add_actor()` / `remove_actor()` / `get_actors()` 和 `GFTurnPhase.finish(context)`；每个 `GFTurnAction` 只能入队一次，需要重试时创建新实例。
- 旧 package lock 缺少逐文件摘要时，不要手工补造基线；从项目选定且摘要校验通过的 registry 重新安装对应 package 以生成完整 lock。若已修改 package 文件，先把项目改动迁出 package ownership，再执行更新或卸载。
- 如果维护脚本曾调用 `gf_package_resolver.py ... --write-lock`，改为只读取返回结果中的 `planned_lockfile` 做预览；需要安装、更新或卸载时调用 `gf_package_installer.py` 对应事务命令。计划结果不能作为已安装事实写入 `.gf/packages.lock.json`。
- 自定义 `GFBatchedLogSink` sender 必须返回包含布尔 `ok` 的结果；失败时可附带稳定错误信息，但不要返回旧 `success` 字段。Input Mapping 编辑器上下文应保存为受控 `.tres`；JSONL 日志与 Analytics client ID 需要外部位置时，应由项目侧 adapter 显式管理并在进入 GF 前映射到受控 `user://` 路径。
- 旧 package transaction journal、宽松 cache marker 或不完整 lock 不具备安全恢复依据，应删除对应未完成事务并从已校验 registry 重新安装；不要手工补造摘要。与 package 内容相同但原本由项目拥有的既有文件也不会被自动接管，安装前应移动该文件或显式调整 package 边界。

---
