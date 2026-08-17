# 更新日志 (Changelog)

## [未发布]

**版本概述**：本轮新增类型化音频播放区间与循环点、共享资源 admission Broker、request-scoped 对象池预热 Operation，以及带解析前硬预算的公共 JSON object 读取器，并让既有编辑器与扩展 JSON reader 通过兼容 adapter 复用同一核心；把 Architecture 启动升级为依赖 DAG 驱动的四阶段激活并增加类型化异步关闭，把 Settings 持久化拆为 Store 端口与可选 Storage adapter，为 Save Profile 增加精确 provider domain、活动身份与显式恢复/对账事务，补充 Headless 服务探针和周期环境表现的项目组合配方，修复并加固 AI Developer 的项目 Adapter 依赖边界、Kernel 资源所有权与路径边界，以及触屏/拖放的重入生命周期和输出租约问题，同时把 Changelog、安全扫描抑制和内部 API section 约束转为可执行维护门禁，并收紧热模块事务、Save Profile 准备、可选依赖、后台回调所有权、按 key 并发、场景邻居稳定帧、渲染预热和音频释放契约；此外加入冻结模块访问策略、Route 请求生命周期、类型化虚拟输入 Pulse，以及有界虚拟列表 Binder、事务式表格谓词和可验证的 Spatial Canvas 输入策略，使生成访问、异步 UI、定时输入和大型交互界面都具备明确的身份、终态、传播与所有权边界；框架只提供可验证的通用机制，不内置项目启动、存档业务、部署协议、领域过滤器、行视觉、环境模型或轮询式音频模拟。

### 🚀 新增特性 (Added)

- 新增 provider-neutral 的 `GFBoundedJsonObjectReader`：文本与路径入口会在 `JSON.parse()` 前执行不可关闭的 1 MiB/64 层硬上限，只接受 object 根节点并返回固定 8 字段 JSON-safe 报告；既有编辑器四字段 reader 与扩展六字段/累计预算 reader 改为兼容 adapter，保留原报告形状和调用入口。编辑器 adapter 的非正预算会恢复公共默认值；扩展 adapter 在累计预算耗尽时于打开文件前失败，并把字节或词法深度超限持久标记为 `budget_exceeded`。
- 新增可选制作期包 `gf.tool.asset_browser`：`GFAssetBrowserModel` 以原子隔离的 `GFAssetCatalog` 快照、稳定选择、有界分页和缩略图任务代际提供 model-first 素材浏览状态；当前不注册 Dock，也不接管目录扫描、Provider、下载、导入或缓存。
- 新增默认关闭的 `gf.layered_sprite`（包 ID `gf.extension.layered_sprite`）：用单一共享时间轴、稳定层和层内变体组合 2D 外观，配置经过有界完整校验后原子替换；扩展不内建角色、装备或素材导入语义。
- 新增第三方原生物理后端 Adapter 组合 Recipe：冻结后端、平台、架构、ABI、依赖、许可证与制品摘要，并分别验证本地、跨目标和完整项目状态的可复现性；本项只增加文档与 AI Developer Recipe，不新增 Runtime 或 package。
- AI Developer 新增显式离线上下文包：调用方逐项选择已保存 UTF-8 文件与项目设置，先取得不含正文的哈希绑定计划，再由交互终端确认并在导出前复核来源；该能力不读取实时 Editor 状态、未保存缓冲区或截图，也不提供无人值守的自动导出入口。
- 新增 `GFViewportSurfaceInputBridge` 与不可伪造的 `GFViewportSurfaceInputCapture` 回执：把调用方已解析的标准化表面坐标同步投递到 `Viewport`，并以 bridge、pointer、capture generation 和 target generation 拒绝迟到 move/release/cancel；独立有界的 pointer timestamp 高水位还能在双击历史关闭或裁剪后拒绝仍受保护 key 的跨代际迟到 press，已捕获 key 的 hover 与不受支持的鼠标 release 均 fail-closed；射线、UV、Mesh、XR 和目标选择仍由外部 Resolver 负责。
- 新增可选制作期包 `gf.tool.lsp_workspace_edit`：把调用方已经取得的闭合 `WorkspaceEdit`、已保存文档版本、来源摘要与工作区代际绑定成一次性计划，再通过 `GFArtifactWriteTransaction` 提交；它不是 LSP client、Rename 引擎或编辑器 UI。
- Behavior Tree 新增有界调试快照选项：`BTNode` / `Runner` 在遍历和黑板键物化前限制节点、深度、子项与键数，末端统一通过报告编码器约束文本、集合和总字节；快照不保留 live Object、Callable 或黑板值。通用 Object 只保证返回值的有界后投影，不承诺约束其方法内部构造成本，也不会向 owner 返回的 Dictionary 注入诊断字段。
- Domain Inventory 新增一次性 `GFInventoryTransferTransaction`、类型化 `GFInventoryTransferResult` 与短生命周期只读 `GFInventoryReadView`：跨两个 `GFSlotInventoryModel` 先有界规划并绑定 identity、revision 和计划摘要，提交时重验后同时替换两边状态，再按来源、目标、事务终态顺序统一通知；普通 mutation 与事务规则都读取同一种逐步候选投影，失败不会先写入或用补偿伪装原子性。
- 新增 Achievement 组合 Recipe：复用 `GFQuestUtility`、Save Profile、项目 `GFPlatformAdapter` 与 Outbox 组合持久化和平台同步；本项只增加文档与 AI Developer Recipe，不新增 Achievement Runtime、package、奖励或通知系统。
- 新增 Environment Query 组合 Recipe：复用 Spatial/Physics、Decision、`GFExecutionBudget` 与只读诊断，把有限候选、预计算评分、generation 和取消组成项目 Pipeline；本项只增加文档与 AI Developer Recipe，不新增平行查询 Runtime、评分器或预算体系。
- 新增纯数学 `GFCivilDate`、类型化日期结果与 `GFCalendarGridTools`：支持 `0001-01-01..9999-12-31` 的 proleptic Gregorian 日期、ISO 周、显式月末策略和 7 列月历网格，不读取系统时钟、时区、locale 或外部服务。
- `GFAnalyticsUtility` 新增 `get_dropped_event_count()`，统一公开普通队列溢出、失败回灌裁剪与最终信封超限造成的累计事件丢弃数。
- `GFConfigAccessGenerator.build_source_with_report()` 新增访问器完整发射报告；`GFConfigPipelineArtifactManifest.make_source_receipt_validation_report()` 新增编译来源收据与当前文件的独立稳定性校验。
- `GFDecisionConsideration` 新增 `get_debug_snapshot_from_score()`，诊断调用方可复用预计算分数而不再次执行项目 scorer；Decision capture diagnostics 新增 `attempted_count`，区分成功捕获与已消费的懒读取尝试。
- `GFContentPackageQuery` 新增 `to_report_dictionary()`，通过统一报告编码器有界处理 Resource、循环集合与非有限浮点；Content Package catalog graph report 新增被拒 manifest 的数量、输入索引、来源与原因摘要。
- `GFOperationDiagnosticsUtility` 新增 `DEFAULT_MAX_PHASES_PER_OPERATION` / `max_phases_per_operation`，单条 operation 的最近 phase 窗口与累计 `dropped_phase_count` 现在可配置、可观察。
- 新增 `GFAudioPlaybackRegion` 与 `GFAudioPlaybackRegionResult`：以类型化资源表达播放起点、自然或显式终点、forward / ping-pong / backward 循环和循环起点，以 `VALID` 区分“结构已验证”和 `APPLIED`“执行者已接受”，严格区分 `INVALID` 与 `UNSUPPORTED`，并按 WAV、Ogg Vorbis、MP3、Playlist 和其他流的 Godot 原生能力返回逐请求结果。
- `GFAudioClip` 新增 `playback_region`；BGM、环境音、普通 SFX 与 2D/3D 空间 SFX 共用请求快照、私有流复制和原生播放准备流程。`GFAudioUtility` 新增拒绝信号、最近拒绝报告与 session 区间调试快照。
- 新增 `GFBgmStartOperation`、`GFBgmStartResult` 与 `GFBgmSessionHandle`；`GFAudioUtility.start_bgm()` / `start_bgm_clip()` 以逐请求终态区分拒绝、失败、取代、取消与真正提交，并在成功后返回不暴露播放器或 backend 的精确 Session capability。
- `GFAudioBackendCapability` 新增播放区间协议发现能力，`GFAudioBackend.evaluate_playback_region()` 提供无副作用的逐片段、逐通道协商；粗粒度能力声明不能替代具体请求评估。
- 新增 Headless 服务健康/探针组合配方：组合惰性诊断 Provider、有界会话字段与类型化传输指标，由项目 Adapter 决定 liveness/readiness、传输协议、鉴权和部署政策；Backend 指标补充使用通用执行预算，并对总指标、自定义指标和 ID 长度设置绝对上限。
- 新增周期环境表现组合配方：组合可注入时钟、项目环境样本、Shader Profile、接口快照与 Binder；周期、天气、天文、时区和持久化策略继续由项目负责。
- AI Developer Capability / Recipe / Evaluation 知识目录升级到 `1.10.0`，加入第三方原生物理后端 Adapter、Achievement 与 Environment Query 三份组合配方，并让目录认识类型化播放区间、虚拟列表 Binder、事务式表格谓词和 Spatial Canvas 输入策略的可搜索组合边界。
- `GFModel`、`GFSystem` 与 `GFUtility` 新增 `begin_activation(scope)` / `begin_quiesce(scope)`；`GFArchitecture` 新增 activation/shutdown deadline、激活与 quiescing 状态查询，以及依赖 DAG 驱动的第四阶段 bootstrap。
- 新增 `GFArchitectureShutdownResult`：类型化区分正常完成、失败、取消、超时、强制释放与幂等重复关闭，并以有界模块条目保存 quiesce 证据；并发 `shutdown_async()` 调用共享同一关闭流程。
- 新增 `GFSettingsStoreUtility` 同步物理端口及 `GFSettingsFileStoreUtility`、`GFSettingsNullStoreUtility`；另在 `gf.standard.settings.storage` package 提供声明 `GFStorageUtility` 生命周期依赖的 `GFStorageSettingsStoreUtility` adapter。
- 新增 Save Profile bootstrap 组合配方：项目 System 声明依赖 `GFSaveProfileUtility`，在 `begin_activation()` 中把 `load_profile()` / `flush_profile()` Operation 桥接到一次性完成源；框架不新增项目存档业务类。
- `GFArchitecture` 新增 `find_model()`、`find_system()` 与 `find_utility()` 静默可选查询：非严格模式复用普通父链和 alias 规则，严格模式停止本地但不报告 required miss。
- `GFAsyncKeyedGate` 新增 `try_request_lease()` 与 `STATUS_BUSY`：无法在当前主线程边界立即提交时，不创建 waiter、请求 ID 或 completion，不发请求生命周期信号，也不改变公平游标。
- 新增 `GFResourceBroker` 与 `GFResourceLease`：为 Asset、Scene 与 BackgroundWork 提供显式共享、无单例的 threaded ResourceLoader admission；不同资源请求使用有界严格 FIFO，同资源身份复用底层请求并保留独立消费者取消，已发起且失去消费者的请求继续 drain 到 Godot 终态。
- 新增 `GFObjectPoolPrewarmOperation` 与 `GFObjectPoolPrewarmResult`；对象池批量/预算预热现在可按请求观察进度、终态有效容量准入和闭合终态，并通过 caller、token、owner 或 parent 生命周期精确取消当前请求尚未创建的单位，不影响其他并发预热的 reservation。运行期容量压力会把未提交单位归为 skipped；非主线程调用同步返回 `INVALID/main_thread_required`，不触碰池状态。
- `GFResourceBroker` 公开默认/绝对活动与等待预算常量，以及活动请求无法追溯满足 type hint / admission 时的稳定失败原因常量；活动请求配置限制为 1..64，等待请求配置限制为 1..4096，队首 exclusive / require-idle 请求和排队中同路径约束升级都不会被后续共享请求绕过。
- Save Profile 新增一次性 opaque `GFSaveProfileRequest`：`take_ownership()` 分别接管 document metadata、Provider context 与 result metadata，不提供 payload getter；合法边界只做 O(1) claim，成功后调用方必须放弃三个输入图的全部嵌套 alias。
- Save Profile 新增 `GFSaveSectionSnapshot` 与 `GFSaveSectionSnapshotOperation`：Provider 通过 `begin_save_snapshot()` / `_begin_save_snapshot()` 在主线程按 work unit 分片生成不可变 section Snapshot；固定且很小的载荷可用 `make_completed_snapshot()`，大型载荷必须实现有界 Operation。
- Storage 新增 `GFStoragePayloadTransfer` 与 `save_payload_request_async()`：以 opaque 单所有者句柄逻辑移交纯 Variant 载荷，并允许同一冻结绑定上的 timeout-detached attempt 与有界重试共享只读 Snapshot。
- `GFStorageUtility` 新增 `has_file(logical_path)`；Storage 内部新增分片 catalog 与 opaque UUID family store，把 portable logical identity、owner 和 committed payload 建立可双向审计的稳定映射。
- Storage 新增 `GFStorageDeleteResult`、`GFStorageAsyncOperation.OPERATION_DELETE` 与 `GFStorageUtility.delete_file_request_async()`：异步删除以逐请求 handle 返回类型化失败分类、有界 family 成员计数和不含物理路径的失败成员分类。
- Storage 新增 `GFStorageAsyncRequestOptions` 与 `GFStorageAsyncCallerResult`：typed 请求可弱绑定 caller owner、只读 cancellation token 和单调 timeout，并通过 Operation 的独立 caller 终态安全停止观察。`GFStorageUtility.get_late_settlement_diagnostics()` 以不含 payload、Storage root 或私有 family 身份的精确 22 字段 schema，有界保留最近 64 条迟到物理终态。
- `GFSaveProfileUtility` 新增全局准备 work budget、单 profile slice budget 和软时间 budget；`GFSaveProfileResult` 新增准备耗时、Storage attempt 累计耗时与准备 work units 诊断。
- 新增 `GFSaveProfileTransactionCoordinator`、`GFSaveProfileTransactionOperation` 与
  `GFSaveProfileTransactionResult`：在单 Profile 原语之上按精确有序 Provider 身份管理
  domain、活动 Profile、严格 activate/switch、显式 bootstrap/adopt、类型化 mutation
  和 reconcile，并以独立不可变终态报告跨 Profile 事务。
- 新增 `GFSaveProfileRecoveryLease`、`GFSaveProfileReconcileLease` 与
  `GFSaveProfileReconcileRequest`：missing/corrupt 只能通过匹配的一次性恢复能力继续，
  写入结果未知时冻结 domain，等待底层证据 settled 后通过显式严格重读收敛。
- 新增 `GFSaveSectionMutation` 与 `GFSaveProfileMutationRequest`：用 move-only 候选 section
  清单替代事务内任意回调，固定 Provider 顺序并在确定失败时逆序恢复。
- `GFSaveSlotStorageAdapter` 新增 `build_slot_file_plan()`：无需配置 Storage 即可返回已校验的数据/元数据文件名和 portable logical target，供同步入口在访问 backend 前复用同一模板安全规则。
- `GFStorageAsyncResult` 新增 `WriteFailureKind` 与隔离的 worker 载荷预检报告，区分非法请求、不可持久化载荷、编码、线程、生命周期和 IO 故障。
- `GFArchitecture` 新增统一的 `resolve_module_access()`、模块类型与查询作用域枚举；Access Generator 可按精确模块脚本路径冻结 inherited/local、required 与 require-ready 策略，生成结果不再依赖运行时隐式选择。
- 新增 `GFUIPanelAsyncOperation`：为每次底层异步 push/replace 冻结单调 serial、路径、层级和操作类型，并以弱面板引用暴露唯一终态；`GFUIRouterUtility` 的异步打开选项新增 owner 与 `GFAsyncScope` 生命周期锚点。
- 新增 `GFVirtualInputPulseOperation` 与 `GFVirtualInputSource.PulseReplacementPolicy`：以类型化句柄表达有界虚拟动作脉冲、OR 生命周期取消、连续 hold 的原子替换、离散激活的真实 release-to-press 重触发、拒绝策略、单调 generation 和匹配释放证明；重触发只保证清除并重写匹配 contribution，其他贡献持续活跃时不会伪造聚合动作边沿。
- 新增 `GFVirtualListBinder` 与 `GFVirtualListSyncResult`：把项目持有的 `ScrollContainer`、绝对布局内容根、行工厂和绑定回调组合为 owner-bound 的有界回收句柄，按稳定 identity 物化 visible + overscan 窗口，统一处理测量回写、单次锚点修正、虚拟焦点交接、重入合并和确定性释放；数据、视觉、选择、激活与输入继续由项目负责。
- 新增 `GFTableRowView`、`GFTableRowPredicate`、`GFTableRowPredicateResult`、`GFTableRowPredicateRegistration` 与 `GFTableViewRebuildResult`：以稳定 ID、启用状态和确定顺序组合项目谓词，并以隔离行视图和类型化结果表达包含、排除或失败。
- 新增 `GFSpatialCanvasInputPolicy` 与 `GFSpatialCanvasSelectionModeBinding`；`GFSpatialCanvas2D.InputDisposition` 显式区分 ignored、handled 和 consumed，使鼠标 chord、选择修饰键、滚轮父级仲裁、可禁用单指行为、独立多指 pan/zoom、系统手势和取消 action 可以在不继承 Canvas 的前提下原子配置。
- `GFHapticUtility` 新增 `get_last_output_report()`：在自动 tick 无法直接消费返回值时，仍可观察最近一次物理输出、停止、停止失败或 provider 拒绝；空刷新不会覆盖最近活动报告。
- `GFInputMappingDock` 新增 `set_remap_config()` / `get_remap_config()`，只读编辑器诊断现在可显式检查玩家或 profile 覆盖后的有效绑定。

### 🔄 机制更改 (Changed)

- **破坏性变更**：`GFGeneratedArtifactReport.save_text()` 的 `allowed_roots` 改为显式物理所有权边界。省略该键继续保留旧路径行为；一旦提供，值必须是非空且全部有效的 `res://` / `user://` 根目录集合，空集合、错误类型或非法根会在零 I/O 前以 `ERR_INVALID_PARAMETER` 失败。受控生成器应始终传入精确根目录；启用后读取、临时写入、替换、清理与回滚会逐边界拒绝符号链接、junction 和其他重解析组件。替换事务另行冻结原件的原始字节身份与实体种类，避免 malformed UTF-8 或 legacy direct symlink 在 backup/rollback 时被误判；最终 rename 后还会确认已消费的 temp 与 backup 身份保持为空，未知重占实体不会被删除。最终 rename 已提交而后验证或 cleanup 失败时，报告可以是 `failed` 且 `written = true`；请求扫描时，任何已发生的文件系统变化都会触发一次扫描。传统生成器 `Error` 入口会把 `written = true` 投影为 `OK` 以阻止自动重试，迁移后的诊断与恢复逻辑必须改用对应的 report 入口并同时检查 `written` 与原始错误。该机制基于可观察复核，不宣称提供跨进程目录句柄固定或原子 CAS。

- **破坏性变更**：`GFInputAction` 新增默认值为 `0.5` 的 `release_threshold`，模拟量动作改为分别在全局与玩家作用域保留聚合后的 raw-active 迟滞状态；轴阈值必须有限、位于 `0.0..1.0` 且 release 不高于 activation，否则对应轴 mapping 会失败关闭并从有效 entry 中排除。精确中立值始终释放，`BOOL` 动作不使用也不诊断轴阈值。既有自定义 `activation_threshold` 轴资源必须显式迁移 `release_threshold`，不能依赖新默认值保持旧单阈值行为。
- **破坏性变更**：`GFSlotInventoryModel` 的 `registry`、`allow_growth` 与 `slot_definitions` 现在通过受保护属性入口推进单调 revision 并拒绝通知期重入；`slot_definitions` 必须与槽位数量精确等长，错长赋值原子拒绝，自动增长只追加 `null` 规则。`acceptance_checker` 的第五个参数及 `GFInventorySlotDefinition.can_accept()` 的 `inventory` 参数统一收紧为 `GFInventoryReadView`，旧的 `GFSlotInventoryModel` / 任意 `Object` 类型不再接受。两类库存规则 Callable 现在必须指向可反射参数元数据的具名 Object 方法；匿名 lambda、不透明 Callable 与不兼容签名会在调用前静默失败关闭，不保留兼容重载。规则 Resource 字段漂移不会冒充模型 revision，但跨库存 commit 会重新规划并按当前配置摘要拒绝陈旧计划。
- **破坏性变更**：`GFArtifactWriteTransaction` 的 `expected_sha256` 现在要求精确 `String`，不再把 `null` 或其他错误类型静默解释为未设置；新增 `preflight_existing_sha256`，用审阅时旧内容 SHA-256 在预检与可观察替换边界拒绝已发生的磁盘漂移。Godot 文件 API 无法把内容比较与路径替换合并为跨进程原子操作，因此该字段不承诺 compare-and-exchange，也不能替代调用方对编辑器或外部写入者的协调。
- `GFSettingsUtility` 收敛为后端中立的内存核心：Architecture 模式启用持久化时必须解析精确 `GFSettingsStoreUtility` alias，并在 Store ready 后执行自动加载；standalone `init()` 继续自动持有 File Store 以兼容既有 `user://` 行为，`persistence_enabled=false` 则完全关闭 Store 与文件 I/O。端口在本阶段仍复用 `GFStorageReadResult`，所以 `gf.standard.settings` 的依赖闭包仍包含 `gf.standard.storage`；可选的 `gf.standard.settings.storage` 只负责提供 `GFStorageUtility` adapter。
- Settings quiesce 会先冻结准入，再按顺序 flush 全部已接纳目标和开放 batch；scope 取消会在下一个 Store write 前停止排空，并保留未尝试记录供显式 `flush_pending_save()` 重试。已成功捕获但物理写入失败的记录保留原始 payload，`tick()` 不会热重试；循环引用等捕获失败只保留 target 与类型化错误，必须提交同 target 的新修正快照覆盖。重复 quiesce 不会隐式重试，`dispose()` 只清理状态，不再承担权威 flush。
- `GFAssetBrowserModel.preview_resolved` 现在只发布闭合、有界的缩略图结果：MeshLibrary 计划会在复制前检查精确 schema 与 `MAX_RESULT_COUNT`，并递归冻结容器；循环、超限或错误类型失败关闭。`Image` / `Texture2D` 仍是引擎对象句柄，listener 必须按只读引用使用。
- `GFStorageUtility` 的所有运行时文件与目录入口统一使用规范相对身份，并在词法上解析到当前 Storage root；同步、异步、payload transfer、目录管理和事务恢复不再存在可动态扩大的绝对路径授权，非法非空 `save_dir_name` 也不再退化到 `user://` 根。需要任意本机路径的可信编辑器或离线迁移工具改由自身 `FileAccess` / `DirAccess` 边界负责；该约束不是宿主 symlink、junction 或挂载点沙箱。
- `GFStorageUtility` 采用 `portable-ascii-v1` logical identity 与 `.gf-storage/v1` 私有布局：输入必须原样满足小写 ASCII segment 规则，不再归一化别名；SHA-256 分片 catalog 与 reciprocal owner record 绑定 domain-separated UUID v8 family，payload、candidate、backup、prepare/commit evidence 和 Resource stage 全部位于 family namespace。同步/异步事务先发布 immutable prepare，再写 candidate，final 切换后发布独立 commit evidence；partial prepare、partial commit、rollback 和证据清理按 exact family 状态恢复，任何歧义失败关闭。首次 activation、显式 `init()` 或首次合法 I/O 尝试会冻结 root，quiesce 排空已接纳工作，`list_files()` 从 catalog 投影并在 drain 后重新恢复 committed view；同一 root 当前要求 single writer。
- Storage 同步与 typed 异步删除现在共享精确 family executor：删除不隐式执行 recovery/repair，只接受 catalog/owner 互证、精确单成员事务证据或由目标 opaque family 独占证明的 markerless sidecar；group、损坏或不一致证据在任何删除前以冲突失败关闭。授权后的成员按 backup、prepare pending、prepare、commit pending、commit、candidate、Resource stage、final 顺序 fail-fast 删除，final 始终最后；已删除/剩余成员可由结果观察且 catalog/owner tombstone 保留。同一 Utility 的同 family 请求继续 FIFO，不同 family 可受 worker 配额并发。本变更不提升 `.gf-storage/v1` layout/catalog schema，也不需要迁移。
- `GFStorageAsyncOperation` 拆成 caller 与物理两条 exactly-once 终态轴；旧 `completed/is_completed/get_result` 保持物理语义。排队请求在接纳前可真实取消，已接纳 load 的 caller 取消为 `CANCELLED`，已接纳 save/delete 为 `OUTCOME_UNKNOWN`；线程槽至少保留到真实线程退出，family 锁与 settling ownership 保留到物理终态写入。调度按 physical-first 与首个 caller 原因获胜；`dispose()` 真实取消排队请求并 join 活动 worker，不提前释放 Utility 状态。
- BGM start 改为 prepare-then-commit：较新的有效请求只取代等待中的候选，当前已提交 Session 会保留到 backend 或本地 standby 候选接受。crossfade 在 incoming 接受时提交逻辑 Session；没有更早 exact terminal intent 时，旧 Session 以 `REPLACED` 终结并仅作为 retiring voice 淡出。本地候选或 backend 接受前失败、取消和迟到回调不再清除当前 BGM、history 或精确控制句柄；backend 已物理接受后身份失效时会 best-effort 补偿停止，无法恢复的旧 backend-owned Session 以 `PLAYBACK_FAILED` 终结。backend 拒绝、本地 fallback、topology 失效和补偿结果都由闭合 disposition 记录。
- AI Developer 的 package 状态只从完整闭合且版本一致的正式 lockfile 产生可信事实；无效 lockfile 不再向 Snapshot/Capability readiness 泄露 package ID。项目路径授权改为保留词法身份并拒绝根内 link/reparse，Agent 规则读入增加单文件与调用级预算，托管块替换保持 marker 外字节并以源 SHA-256 拒绝计划后的普通并发编辑。Platform/Storage 模板共用受控文件读取边界，Storage 正常保存路径不再重复遍历同一 payload 图。
- 维护契约现在区分普通发布、真实冻结与 tag-origin hotfix，并在 tag 前以同一不可变产物 manifest 运行完整 `release` suite；参考工程同步默认只读，明确区分 `--plan` 与 `--apply`，统一遵守路径优先级，并以有界、带 SHA-256 的二进制精确 payload manifest 拒绝源/目标重叠、link/reparse、特殊文件、捕获期漂移和跨平台路径碰撞。Copy 同步改为异常可回滚的完整树替换，Link 同步不再删除未知既有目标，机器输出只暴露逻辑路径及稳定规则 ID。维护 CLI 只自动清理本次命令拥有的成功日志，历史/legacy 清理由显式预览后的 `log-hygiene` 负责；`path-hygiene` 同时强制 GF 自有 GDScript 使用无 BOM 严格 UTF-8、LF、末尾换行与 Tab 缩进。
- 正式 API Catalog 升级到 schema v3，并用独立 AutoLoad owner 收录 `Gf` 及其公开成员；Reference 同步生成 AutoLoad 索引和详情页。生成链仍完整收集多行声明，并在未闭合声明、owner 身份/注册/package 漂移、跨 kind 冲突、错误 section/anchor 或候选坏链接时事务前失败关闭。此次只修复文档和工具的可发现性，`Gf` 的 AutoLoad 名称、注册路径与运行时行为不变。
- 公开 changelog 现在只保留消费者可见的当前版本说明；作者模板与发布维护规则迁入维护者文档，`Affected Files` 与纯内部仓库路径清单由 changelog policy 拒绝。公开文档门禁同时覆盖根 README、商店文案、扩展/package 标识、扩展默认值、FAQ 任务入口与完整卸载旅程。
- Project Layout 的 Validator/Scaffolder 现在在任何扫描或写入前严格拒绝未知选项、错误类型、非字符串执行字段、非规范相对路径和错误 rule 字段；维护器对齐用的既有保留字段仍维持 schema v1 接受行为，但文档明确它们不在 Godot 侧执行。`naming_convention.target` 正确区分 `path`、`name` 与 `stem`，目录扫描改为预算耗尽即全局中止的流式枚举，dry-run/apply 共用阻塞路径预检，诊断 context 不再持有调用方 Object。
- Logging 的内置文件、JSONL sink 与 batched sink 现在统一由 Architecture tick 推进真实空闲 flush；batched shutdown 会在同步交付持续取得进展时逐批排空，默认 JSONL 路径加入 sink 实例身份以保证活动写入者独占。Analytics Header 在请求前执行 HTTP token、控制字符、重复名、数量与 UTF-8 字节预算校验，非 2xx 公共结果不再携带远端响应正文。
- 维护检查的 canonical fingerprint JSON 现在拒绝 `NaN` / `Infinity`，三层 timeout budget 只接受有限非负数；凭据扫描用类型化路径事实隔离分类用 policy path 与输出用脱敏 label，包路径 validator、matcher、compiled index 和维护 owner collector 则统一拒绝非 canonical raw pattern，不再静默 trim、去前缀或改写分隔符。
- 模块化包闭包审计现在同时输出每个 package/preset 的源码文件数、GDScript 数与未压缩字节数，使 package ID 闭包不变时的 payload 增长仍可观察，并为后续建立经审阅的载荷基线提供确定性证据。
- registry v2 现在在 Python 规划器与 Godot 原生后端执行同一闭合字段、类型、package kind、依赖、路径、archive、SHA-256 与 size 契约，畸形条目不会再被默认值补成可规划 package。两侧依赖闭包改为显式迭代栈，深图不再依赖语言调用栈；批量卸载按请求集合的投影最终态计算 `required_by`，集合外 depender 继续阻断，集合内依赖边不再自我阻断原子移除。
- Config Pipeline 的 Reader、Layout、Validation 与 Target 契约升级：Reader 为实际读取字节生成来源收据，XLSX Layout 以该身份打开有界 archive，编译器指纹纳入各 Stage 显式声明的辅助实现依赖，JSON Target 增加不可关闭的深度、节点和输出字节硬上限以及循环检测。
- **破坏性变更**：Config Pipeline 的公开 writer、Profile/Runner preflight、`dry_run` 与真实写入统一只接受 `res://` / `user://` 输出 URI，并把规范化后的同一目标身份传播到报告、manifest 与事务；旧 `allow_absolute_output_path` 选项已移除。`GFConfigPipeline` 的 database/access/manifest 与 Profile/Runner 路由才识别 `allow_parent_output_path` / `allow_gf_source_output`；parent 授权只允许在 resource URI 根内规范化，不能授权主机绝对路径或越过 URI 根。
- **破坏性变更**：`GFExtensionManifest` 与 `gf_extension.json` 不再拥有 `access_generator_extension_paths`、`editor_action_paths`、`editor_dock_paths`、`editor_inspector_paths`、`export_plugin_paths`、`gltf_document_extension_paths` 和 `import_plugin_paths`；七类路径统一由 `editor/gf_tool_contribution.json` schema v2 声明并独立校验，不保留双读。`installer_paths`、`editor_dock_order` 与 `editor_dock_short_label` 继续归 runtime manifest；无效 Tool Contribution 只形成 `partial` 并隔离无效工具路径，不使有效 manifest 图或 Installer 失效。
- Decision 的预计算选择入口改为对任意输入顺序执行完整最大值扫描；候选与考虑项评分冻结本轮数组成员，Utility registry key 成为注册期权威身份并拒绝同实例双 key。上下文对每个不同懒 key 先占用有界账本，miss 负缓存且重绑定时清空；字符串 provider 只有参数个数兼容时才调用。Option authoring validation 直接投影 Consideration 权威报告，不再复制五套数值/来源规则。
- Content Package schema v1 的 canonical/兼容别名同时出现时必须具有相同规范化文本，否则以稳定 `conflicting_alias_fields` 失败关闭；单次 catalog query/Resolver 注册复用同一依赖排序结果，不再在一轮读取中重复构图。
- Combat 的目标排序改为一次性装饰候选快照，Projectile Catalog 对重复导出 ID 采用首项权威并在写入/移除时规范化；Gauge 动作结果固定为本动作自身的提交快照，属性集合清理则先脱离旧状态再发送通知。
- Capability 多条件查询现在把 required/rejected 列表中的 `null` 视为非法配置并整体失败关闭，真正的空列表仍保留无条件语义；只读能力探测不再向未注册 receiver 写空元数据，分组能力交集查询只执行一次失效索引清理。项目能力生成模板不再硬编码 GF `3.17.0` 版本来源。
- Camera 3D Rig/Director 现在把任意有限非退化 Basis 统一提取为不含缩放或反射的右手旋转；镜像层级和奇数负轴缩放按 Godot rotation extraction 约定收敛为 determinant 近似 `+1` 的姿态，再进入 Quaternion blend。
- Behavior Tree 的运行时复制统一校验独立 identity 与动态脚本类型，随机 Selector/Sequence 共用同一顺序生成器；调试快照区分真实递归回边与共享引用，节点 metadata 和 BlackboardScope 初值改用循环安全集合复制。`TimeLimit(0)`、Blackboard live storage 与异步取消边界同步写入正式合同。
- Action Queue 在动作组启动时冻结本轮计划，并在任何子动作副作用前拒绝并行重复实例；拦截器按下一动作开始时的当前 `priority` 与稳定注册序重排，批量替换只发布一次最终状态。文档同步明确 Signal timeout 只解除等待而不自动取消，以及命名子队列在父级批量释放前会持续保留。
- Asset Metadata 归因报告现在一次性规范化覆盖输入，并分别公开原始输入、有效唯一、无效和重复数量；NOTICE 结构字段统一收束为单行，多行 notice 以固定续行缩进输出。`GFAssetMetadataUtility` 的 5 个既有入口恢复为 3.17.0 API Surface 公开基线，状态探测不再为只读 empty/valid 判断深复制完整 payload。
- Safe Resource Codec 在扫描或暂存 Array、Dictionary、Object 的完整形状前按直接子节点基数预检剩余 `max_items`；命令历史反序列化改为候选栈完整构建后原子替换，失败时保留原 undo/redo 栈。Storage Section Cache 的复合 scope identity 现明确为调用时的值语义。
- 纯代码与节点状态机新增显式事务代际和激活周期：守卫及 enter/pause/resume 回调中的嵌套状态操作优先于过时外层计划，状态事件在激活集合变化后立即停止跨周期投递；节点条件组允许共享无环子图，并以 64 层深度和 4096 次评估硬上限失败关闭，校验器同步报告循环与超深图。
- Support Report provider/transport、Runtime Tunable setter 与多项 debug 容量开关已在文档中明确为受信同步边界；编辑器 Diagnostics Dock 与 Runtime Debugger Tab 共享无状态、脱敏的树展示 helper，不再分别维护同一套值分类、摘要和 JSON 编码逻辑。
- operation 终态改为 first-terminal-wins：重复 finish 幂等返回首次终态，后到 phase/state/async terminal 不再改写历史；incident 容量按 `last_sequence` 淘汰。控制台参数补全现在以 parser 对称编码保留空字符串、空白、引号和反斜杠的 token 语义，候选值不再被隐式 trim。
- 下载清单目标现在必须是声明 `target_root` 下的安全相对路径；覆盖提交使用可恢复同目录备份，续传追加传播读写错误并回滚部分追加。源码文本缓存每次命中都会重检当前 `max_bytes`，文件与自定义字节来源执行严格 UTF-8 验证。ACK 账本在全 pending 容量饱和时显式拒绝新记录，不再驱逐未确认旧包。
- 资源句柄用私有不可变 lease identity 释放引用，跨 Utility 释放失败关闭；ownerless 资源路径替换先验证再提交且保留 owner-scoped 贡献。任务队列为取消历史增加独立上限，所有终态都会从等待队列移除；场景 fixed 预加载请求可单调升级缓存/在途合并，越过 `res://` 根的路径失败关闭。
- 运行时任务组现在只接受深度不超过 256、节点不超过 4096 的无环且无重复实例任务树；外层组调度会原子预留整棵后代树并冻结未来子任务配置。调度器为每次 schedule 分配 generation，并在所有用户回调后复核，`GFCallableRuntimeTask.finished_callable` 也收紧为只接受 `bool`。
- 指令序列把 `step_started` 明确定义为 execute 前可否决边界，完整公开 `last_run_report` 闭合字段；`GFWaitSequenceStep` 与 Signal timeout 拒绝非有限配置，命令快照新增覆盖文本和全部 PackedArray 的 16 MiB 保守成本预算。
- 播放区间在请求开始时连同 `GFAudioClip` 一起复制；本地执行始终复制 `AudioStream`，只修改 session 私有副本。异步回调、crossfade 回退和环境音 session 都携带冻结后的规范化区间。
- 本地音频只接受引擎能够精确表达的起点和循环点，不使用 Timer、每帧轮询或近似 seek 模拟非循环有限终点；有效但无法精确执行的组合明确返回 `UNSUPPORTED`。
- WAV 终点按最后有效帧索引写入，原生无法保持初始位置语义的 backward 明确返回 `UNSUPPORTED`；Ogg Vorbis / MP3 私有循环副本清除会改变自然终点的 `beat_count`。后端评估与执行只接收由验证结果重建的规范化 clip/context 快照。
- 环境音停止拒绝和本地淡出等非终态继续保留活动区间；拒绝信号保留调用通道，而持久诊断把非框架通道收敛为 `custom`，避免项目值进入稳定快照。
- 公开音频路径、参数/状态/开关、mix snapshot、effect value、总线文本以及 clip/event probe、区间评估与执行统一经过有界请求快照；图遍历、属性扫描、`String` / `StringName` / Packed Array 载荷字节与 Packed 元素分别受硬预算约束，向量 Packed Array 按双精度构建上限保守计费。单个快照图内的重复引用由 memo 保持，ClassDB 原生 Packed 属性只允许经类型/内容复核的值复制；集合循环、超限、Resource storage schema 漂移、无法安全实例化或脚本/dynamic setter 破坏最终图一致性时均在首次回调或本地副作用前失败关闭。Backend 与本地 effect fallback 使用彼此隔离的副本，拒绝前的参数改写不能污染本地提交。Utility 的 Bank resolver 同时限制活动 ID、全局保留挂载数、候选数、标识长度、分隔符长度和 fallback 层级；容量拒绝保持注册栈原子不变，有限权重求和溢出也在抽样前失败关闭，不能再通过重复挂载或开放式候选遍历绕过门禁。环境音会话保留目标增益，部分淡出被失败替换打断时会恢复区间、播放身份与增益，旧流已自然结束时则提交停止终态并释放播放器流引用。
- 音频 Utility 重复 `init()` 改为幂等，BGM stop fallback 改为 utility-owned 可取消 Timer；池化 SFX 在 acquire/reparent 前恢复完整框架播放器模板，Ambient stopped player 以默认 16 项 idle LRU 管理。混音快照在任何 backend/AudioServer 副作用前严格校验 payload shape。
- 音频素材工具增加总扫描 entry 与深度/结果绝对上限，`0` 不再关闭扫描保护，并默认跳过 DirAccess 可识别的 symbolic link。ID3 路径读取先解析固定 header，再受 1 MiB 默认/8 MiB 绝对上限约束，复杂 header feature 和截断状态改为显式诊断。素材复制正式 open 时复核 source 长度、按实际读取扣减共享预算，并用确定性 temp/backup 在下一次调用恢复中断事务。
- 新增 `changelog_policy` 当前状态检查：`X.Y.Z-dev.N` 只允许唯一的规范 `[未发布]` 段，稳定版本只允许唯一的同版本正式段；共享的严格 Markdown 解析会在标题/分类识别时排除 fenced 与缩进代码和独立 HTML 注释，但仍把候选段开头的代码块视为已经渲染的内容，确保版本概述必须真正排在首位。门禁拒绝原始 HTML、混写注释、非法 backtick info string、非 ASCII 标题分隔、伪装历史标题、作者专用顶层章节、纯内部路径清单及不可读正文，并由发布说明提取器复用；同时验证文档标题、唯一候选段、分类结构、扩展版本对齐和稳定 core 的 API SemVer，在 quick、full 和 release 套件中失败关闭。
- 新增 tracked-only `codeql_suppression_policy`：禁止 Python 源码中的全部内联 suppression，并拒绝 bracketed legacy、通配、多 query，以及 CodeQL 的路径过滤、查询过滤、自定义配置和自定义查询套件；YAML 约束只匹配真实 mapping key，区分规范注释、URL fragment、说明 scalar 与 block scalar，并通过受控 UTF-8 普通文件读取固定完整父目录链和文件身份。该策略与 GF 凭据门禁的豁免保持完全隔离，并进入 quick、full 与 release。
- `public_api_boundary` 现在解析 GDScript API 签名，并拒绝 `@api public` / `@api protected` 方法把顶层私有 `*_SCRIPT` 预加载常量暴露为参数或返回类型；framework-internal、private 方法和方法体局部类型保持可用，避免实现细节进入公开契约。
- API baseline 现在比较公开成员的 `@schema` 契约；已有 free-text schema 的任何文本变化（包括追加、改写、重排或删除）都会 fail-closed 归入 breaking，只有稳定基线此前完全没有 schema、当前首次补充时才归入 compatible，避免 Dictionary 字段迁移绕过 SemVer 主版本门禁。
- `GFArchitecture.init()` 在模块 Hook 前冻结注册快照并从四类 typed required Hook 编译声明依赖 DAG，按依赖优先顺序执行 `init()`、`async_init()`、`ready()` 和 `begin_activation()`；stage4 全部成功前，命令、查询、事件、普通 tick 与外部运行时准入保持关闭。缺失、stale alias、歧义、非法或循环依赖现在无条件使初始化失败，本地 alias/assignable 解析错误不会回退父级。
- READY 后的模块注册、替换与注销改为显式拓扑事务：热注册与热替换的新实例只存在于 staged candidate，stage4 成功后才原子发布 registry 与活动计划；注销则先完成目标 quiesce 再提交。事务期间拒绝普通运行时执行，迟到 continuation 和同 Hook 重入不能覆盖更新 topology。Factory 与 alias 拓扑在首次 activation 后冻结。
- `GFArchitecture.shutdown_async()` 先不可逆关闭新工作准入，再按激活 DAG 严格逆序调用模块 quiesce，并在 deadline、取消或失败后仍执行恰好一次的同步 dispose/release。等待已接纳拓扑事务超时或被取消时，关闭流程按“夺取写权、取消 scope、claim 清理”接管，且不保留长期 tombstone；`unfinished_modules` 同时记录当前 quiesce 失败、取消或超时的模块及其后尚未开始的模块。三个架构生命周期 timeout 属性统一只接受有限 `0..86400`，`0` 禁用 deadline；per-call shutdown timeout 保留 `-1.0` 作为读取属性默认值的唯一负值 sentinel。`dispose()` 明确收敛为 SceneTree 退出等无法等待路径的 forced fallback。
- `Gf.set_architecture()` 只发布完成 stage4 且接纳运行时工作的 candidate；替换旧全局架构时先等待旧架构 typed shutdown 成功。失败 replacement 会清理未发布 candidate，并以 assignment serial/scope ownership 阻止旧协程晚到写回。
- `GFNodeContext.context_ready` 只在 owned/inherited Architecture 完成第四阶段后发出；quiescing 架构不可作为可用 Context，节点离树继续使用同步 forced dispose，项目可控关闭应直接等待 owned Architecture 的 `shutdown_async()`。
- `GFNetworkBackend.get_transport_metrics()` 现在把基础计数与 Adapter 补充阶段隔离；补充 Hook 超过执行预算、未为新增指标消费步骤或突破指标容量时，本次调用失败关闭为基础快照，不把不可控工作带入探针路径。
- `GFBackgroundWorkUtility` 在接受任务后强持有 `RefCounted` worker/apply callback target，并分别在线程 join 和任务终态释放，避免排队任务依赖调用方局部变量寿命。
- `GFRenderWarmupUtility` 将清单显式提供的 `entries_per_tick` 在入队时钳制并固定；未覆盖时继续读取当前全局默认值，正常 `tick()` 只消费 FIFO 队首自己的预算，显式 `process_queue()` 继续提供跨清单总预算。
- `GFAssetUtility`、`GFSceneUtility` 与 `GFBackgroundWorkUtility` 改为从 Architecture 解析或由项目显式注入 `GFResourceBroker`；独立使用必须显式创建 Broker，框架不再为每个消费者隐式创建互不协调的私有加载通道。缺少 Broker 的真实请求统一以 `ERR_UNCONFIGURED` 失败关闭，headless Scene 不再绕过 admission；Asset/Scene dispose 会先关闭 admission，阻止同步通知重入遗留 Lease。
- Scene 图谱自动邻居预载改为在目标 `scene_changed` 后等待首个稳定 process/render 边界；尚未活动的新路径以 exclusive + require-idle 进入共享 Broker，已由其他消费者活动且 type hint 与 `PackedScene` 相同或未指定的同路径则以独立共享 Lease 加入，不追溯升级 admission。新切换、配置变更、关闭和 dispose 会取消旧 generation，批量登记在每个同步可重入边界重验 generation，手动与自动同路径兴趣使用独立 Lease 所有权。
- `save_profile(profile_id, request)` 先验证 Profile、能力和生命周期，再 O(1) claim Request、分配 generation 和入队；边界拒绝不会消费 Request，未初始化或已 claim 的 Request 返回 `invalid_request`。Save Operation 只持有 result metadata，最新 document metadata/context 由状态直接接管并在开始准备时通过 assignment 移入当前 generation。`load_profile()` 与 `flush_profile()` 继续只在调用栈内完成校验、屏障捕获和入队。
- 保存 Provider 从后续 `tick()` 开始按全局预算公平轮转，软时间预算只阻止启动下一个 slice，不伪装成可抢占执行。准备完成后文档逻辑 move 到 `GFStoragePayloadTransfer`；Storage worker 在本次新写入的编码与 temp、marker、final 事务提交前执行有界纯 Variant 图预检和物化，既有事务 recovery 与目录初始化仍是独立前置生命周期。Save 终态不再保留完整文档副本，完整文档只由 load 结果返回。
- Storage 首次 claim transfer 时冻结 Storage 实例、规范文件名、canonical target file-family identity 和 codec options；每个物理 attempt 取得独立只读 lease，最后一个 lease 结束且 Profile 释放 generation 后才清空载荷，重试不再重新采集 Provider 或复制完整文档。
- Storage worker 载荷预检现在同时限制 128 层深度、1,000,000 个值和 64 MiB 估算原始字节，拒绝 Object/Script typed container 元数据；诊断只保留结构索引、类型与预算计数，Save 通过隔离 Adapter 映射 section，不输出 key/value 或 key 派生摘要。
- SaveGraph apply 现在用私有 operation state 持有事务身份、Source snapshot、动态实体和 after-load 队列，并拒绝同 Utility 的同步递归 apply；调用方 context 不再能通过 `_gf_save_graph_*` 同名键改变事务所有权。迁移注册表在执行前冻结 step 快照，运行中对 live registry 的重入修改只影响后续迁移。
- Coordinator 管理的 Profile 只在 domain 稳定且该 Profile 活动时开放直接 save/flush；
  直接 load、非活动 Profile 写入以及事务或 reconcile fence 期间的直接操作均失败关闭。
  activate/switch 始终采用严格读取，不把 `ACTION_USE_CURRENT_STATE` 隐式提升为活动身份；strict load 绑定 manager capability，撤权后的迟到读取不会在事务终态之后应用 Provider。
- Switch 先 flush 调用时源 generation，再快照并加载目标，已知失败逆序恢复且保留源活动
  身份。Bootstrap/Adopt 只消费各自 missing/corrupt Recovery Lease，并在写确认后激活；
  mutation 的已知 Storage 失败已证明未提交，因此恢复内存但不发起扩大风险的补偿保存。
- 事务写入返回 `outcome_unknown` 时，Coordinator 保持 Provider 状态与 domain fence，
  不自动回滚、重试、补偿或猜测迟到终态；Reconcile Lease 等待底层 generation 证据
  settled，随后仍须由项目提交 `GFSaveProfileReconcileRequest`，严格重读 lease 指定
  Profile 并完整应用后才解锁。Request 不接受项目布尔结论或可执行恢复策略。
- Access Generator 在调用扩展或构建源码前事务式验证整批策略，统一 String/StringName 字段键并拒绝等价重复、未知、失配或错误类型配置；失败报告固定为零写入且不会覆盖既有产物。生成的 Model/System/Utility 访问器统一委托 Architecture 共享解析原语。
- `GFUIUtility.push_panel_async*()` / `replace_layer_async*()` 改为返回精确请求句柄并可预绑定完成回调；Router 只关联返回句柄，不再把无请求身份的全局完成信号当作协议。Route 在 UI 提交前接受 owner/scope 任一终止，提交后则保持结果未知边界，不尝试撤销已提交 UI 工作。
- 虚拟输入 Pulse 由 Source 持有操作 generation、Mapping 持有稳定输入键的权威 lease；同键替换和手动写入在单次原子边界交接，不发出中间 inactive 状态，清理、重建与 dispose 只释放仍匹配的当前贡献。
- `GFVirtualListModel` 增加单调布局 revision、`layout_changed` 与不含 overscan 的 viewport range；Binder 先保证真实视口，再在硬预算内补充 overscan，按本地 pool 复用 Control，并按测量前整数锚点合并同一轮全部滚动修正。每轮同步在任何项目回调前冻结 data/layout revision、条目数量、范围、目标 geometry、content extent、布局主轴、交叉轴尺寸/填充策略、活动预算与测量请求 revision；布局/轴/填充/预算变化、显式重测与新焦点意图只进入下一轮。callback 内 `invalidate_items()` 会以非成功 `STATUS_DEFERRED` 中止旧 data generation：绑定副作用前保留旧 active，副作用开始后则按 Control 身份去重、对称解绑并清空不可信 materialization，且不推进 committed revision。callback 内收紧 pool 预算也延迟到候选提交或回滚后裁剪，结果报告最终 pool 数量。公开 reveal 只有在模型、视口、主轴、精确 Control 所有权和最终整数偏移全部保持一致时才成功，否则保留意图并请求下一轮。Binder 只恢复自己实际拥有的内容轴，切轴不会覆盖项目对另一轴的修改；owner、滚动容器、内容根或活动 Control 失效都会进入确定性释放，三类生命周期节点任一退出树都会立即 dispose。`GFVirtualListSyncResult.to_dict()` 只输出 JSON 原生 String、Dictionary、Array、数字和布尔值。数据或 identity 变化必须由项目显式失效，不能伪装成布局变化。
- `GFTableDataView` 的投影管线收敛为“文本过滤 → 启用谓词 AND 短路 → 排序 → 单次候选交换”；注册校验、谓词失败、非法结果和经 `GFTableDataView` API 发起的回调重入都保留上一份 registry、source、projection、revision 与选择。谓词数量先执行 raw admission，超限时不遍历或调用候选；每个谓词接收独占 `GFTableRowView`，框架只经静态入口调用受保护 `_evaluate()`，并直接从继承基类存储归一化结果，候选覆写公开 evaluate/getter 不能参与协议。注册 metadata 同样按 inherited 基类存储隔离为纯 GF 值；查询只返回独立快照，调用方不能绕过 revision 静默修改 ID、顺序、启用态或谓词引用。谓词实例参数变化必须显式 `refresh_view()`。行快照中的 PackedVector 按 double-precision 构建上界计费。单格和批量写入先在可隔离候选行上完成写入与完整投影，再一次提交 source、selection 和 projection；稳定行 ID 变化会同时迁移选择集合与原范围锚点。不可安全复制的行值或带任意 setter 的写入失败关闭，不再留下部分写入，所有外部信号只在一致状态完成后发布。
- `GFSpatialCanvas2D` 不再把“已处理”和“停止传播”混为布尔值；输入策略先逐字段复制到纯 GF 基类实例再校验，不能由 Resource 子类覆写复制或校验绕过。拖动开始时冻结实际按钮与选择模式，普通滚轮可以留给父级 `ScrollContainer`，手工转发不隐式修改 Viewport handled 状态；取消 action 只允许非指针事件，并在每次匹配前重新执行有界检查，InputMap 运行时漂移会失败关闭而不会抢占平移或选择。鼠标与原始触摸现在由唯一物理输入 owner 串行化：冲突来源（含 wheel）和系统手势在匹配 release 或显式 cancel 前保持 `IGNORED` 且不修改 Canvas 状态，输入禁用、策略替换、Control/应用失焦、应用暂停、Canvas 隐藏和生命周期退出会完整释放 owner 与指针追踪。单指 `NONE` 且全部 raw 多指行为关闭时不会建立隐式捕获；多指 pan 与 pinch zoom 分别门控，同一手势只应用明确启用的视图分量。Godot canceled 鼠标/touch 只释放匹配捕获，不再被当作正常 release 提交选择或放置。
- Flow Runner 现在把“所有已调度节点均解析并完成”作为唯一 completed 语义，缺失起点或动态后继会中止；Context 与 Graph 运行态恢复先完整校验再原子提交，Runner 只复制当前节点状态而不再为每一步序列化整个 Context。编辑器视图保留带诊断的空连接，并用与运行时一致的完整结构规则筛选无效连接；连接身份改为无歧义元组编码。
- `GFProjectReferenceScanner` 现在为每个文件只执行一次切行、GDScript 注释剥离和引用标识符预处理，再复用于所有扫描目标；命中顺序、强弱证据、配额和截断 schema 保持不变。
- 通用项目引用扫描器不再隐式排除仓库维护者自定义的临时目录；项目工具若需排除额外目录，必须通过 `ignored_roots` 或 `additional_ignored_roots` 显式声明。GF 自带编辑器流程继续显式排除其维护输出，不改变日常面板与导出行为。
- `GFVariantJsonCodec` 与 `GFVariantData.diff_variant()` 现在共享可配置的深度、节点和集合项遍历预算；codec 超限返回顶层 `TraversalLimit` 标记或调用方 fallback，diff 则用 `complete` / `traversal_truncated` / `traversal_reason` 区分“已检查部分无差异”和“完整相等”。Dictionary diff 同时改用文本键索引和 path push/pop，避免等价 String/StringName 键的二次扫描与逐层路径复制。
- `GFConfigTableQuery.values()` 现在默认深复制可变记录和字段投影；确实需要零复制借用时必须显式传 `duplicate_values=false`。数值排序与范围比较使用精确 int/float 次序，不再把相邻大整数或近邻浮点折叠为近似相等。空 ANY/NONE 条件组继续作为未配置 no-op，并在正式文档中明确不能充当授权策略表达式。
- `GFConfigBuildProfile` 现在对 column 内 validation rules 应用与 record/table rules 相同的 metadata 裁剪；`GFResourceConfigProvider.set_table_resources()` 的 clear-then-register、部分新状态语义和项目 staging 要求已明确文档化。
- `GFTagSourceAdapter` 的 Array / `PackedStringArray` 计数改为一次遍历后稳定排序；`GFSourceTextPatchTools` 对全部合法 edit 改为按原始 offset 单次组装结果，避免随标签数或 edit 数重复扫描、重建完整输入。
- `GFByteCursor.write_var_utf8()` 在可由字符数下界确定超限时先于 UTF-8 buffer 分配拒绝；合法输入完成总预算检查和一次扩容后直接写入 prefix 与 payload，不再构造与完整字段同量级的 combined 副本。`write_utf8()` 同样对可由字符数确定的超限输入提前拒绝。
- `GFActivationTransaction` 新增私有 transition guard：prepared 状态幂等，终态只能在操作之外显式清理，validate/apply/rollback 回调内的嵌套事务操作结构化失败关闭，回调内清理或改写步骤不会破坏外层状态机。
- Observable Array/Dictionary 的单项与 batch aggregate 通知统一走 FIFO 派发；`GFValueIndex` 与 `GFMutationBatch` 在同步 mutation/transition 信号窗口内拒绝同实例重入写入，避免半提交索引和 Callable 重复副作用。重复显式 priority/order 以内部入队序稳定裁决，work queue 的极端 aging 比较改用共同尺度归一化并让诊断值饱和为有限 float。
- `GFObjectCandidateRegistry.max_candidates` 降低为正数时立即按注册顺序淘汰最旧记录，并把整次容量收敛提交为一次 revision/通知；`GFNodeGroupCache` 的强一致性同步改用临时实例 ID 集合，使成员校验随输入规模线性增长。
- Kernel base/core 中 59 个 `framework_internal` 方法已从“公共方法”迁移到“框架内部方法”section；API Surface 校验器对该范围新增 tag/section 一致性门禁，避免内部协作入口再次伪装成公开 API。
- 编辑器 Undo action 现在由命令暴露实际 mutation context 与全部目标；场景 metadata 和属性批处理会进入目标所属 history，跨 history 批次在 action 创建前失败关闭。
- 编辑器贡献与模板 sidecar 在 JSON 解析、记录收集和模板读取前执行字节、嵌套深度、记录数、单模板与累计模板字节预算；贡献清单报告显式区分 `absent`、`valid`、`degraded`、`invalid`，缩略图请求同时限制目标尺寸、像素数和等待队列。
- 节点状态机编辑器模板迁入 `gf.standard.state_machine.editor` 的物理所有权范围；标准库贡献清单继续集中索引记录，`package-source-boundary` 新增文件型贡献 owner 与唯一包所有者一致性门禁。
- `刷新 GF 编辑器贡献` 现在等待已有 EditorFileSystem 扫描，合并连续请求并为最新 generation 启动独立扫描；只有扫描空闲且最新 generation 已应用后才发布成功，超时或插件退出会有界失败并取消回调。
- 扩展 manifest、preset 与 tool contribution 统一执行原始字段类型校验及单文件 1 MiB、发现累计 64 MiB、嵌套深度 64 的 JSON 硬预算；签名改用有界分块 SHA-256，并与随后解析共享累计预算。
- 扩展启用选择新增 `valid` / `partial` / `invalid` 三态以及显式 `paths_allowed`。未知启用 ID 和单个无效工具贡献会形成可诊断的 partial 状态并隔离无效路径；manifest 图无效仍全局阻断。
- 禁用扩展引用审计的 `class_name` 预扫描与项目扫描现在共享深度、候选文件、单文件和累计字节预算；任一阶段截断都会进入统一的 partial 报告、跳过记录和结构化 issue。
- 输入运行时新增显式派发 epoch：同步 action 回调清空、替换上下文或释放 utility 后，当前事件立即停止使用旧 entry；provider registry 在查询时按当前 priority 稳定重排，设备容量缩小时以一次集合变更裁剪越界席位并记录逐席位移除事件。
- 输入检测与回放新增会话代际：detector 的无超时等待也累计完整 elapsed，REPLACED 回调开始的新检测优先于尚未返回的旧 begin；playback 在 `event_applied` 前提交事件索引，并在同步回调 stop/start/reset/seek 或替换 recording/source 后终止旧 tick。player-scoped Chord/Sequence 缺完整玩家查询协议时统一失败关闭，不再逐方法回落全局状态。
- Input Mapping Dock 的预算预扫、正式报告、Tree 和详情现在共用当前有效 remap；Resource.changed 同帧风暴合并为一次最终刷新，页面脱树时立即释放 context/remap 订阅。`GFInputRemapConfig` 的公开 mutation 方法成功提交后会发出 `changed`。
- 拖放 lifecycle signal 现在只观察已提交状态：controller started 在 session/pointer/source lease 完整提交后发布，终态 signal 在旧 lease 清理后发布；Utility drop 以 resolving guard、对象 identity 复核和单一终态提交约束任意项目 Callable，候选查询在回调结束 session 后失败关闭为空，clear/prune 操作同时快照 ID 与对象 identity，并保留回调中对后续同 ID 的替换对象。
- 触屏按钮与摇杆为每次 gesture 冻结 action、虚拟 joypad lane 和 begin-time 定位模式；运行时 export 修改从下一次 gesture 生效。Node process mode 禁用与关闭 button mouse 接收都会先释放当前输出。
- Feedback 的 haptic 输出改为单遍物理目标分组，并在任何 provider callback 前冻结整轮计划；成功 start 绑定原 backend/callback/input owner，partial provider 和未成对 callback 失败关闭。`auto_apply_on_tick` 仅控制 tick，显式 stop/clear 继续立即撤销输出。Shake 的非空 `tracks` 始终选择轨道模式，disabled 或范围外轨道不参与合成，数值零不再冒充“未参与”。
- Interaction 的反射式 `set_interaction_context`、`get_candidate_objects`、`send_to` 与 `receive_interaction` 协议统一在调用前验证参数数量、Variant 类型和 Object 类约束；候选按实例 ID 线性去重，并以 WeakRef 跨越查询到实际分发的时间边界。Pointer 的 pressed 状态改为按 window、device 与 button 独立配对，交错按钮不会互相覆盖。
- Network snapshot patch 生成器与 applicator 现在共享 8 层 path、4096 操作及 transport-safe 内容边界；服务发现把公开记录时间与内部 TTL deadline 分离。Fixed tick 在同步 signal 窗口拒绝同实例递归 `advance()` / `step_once()`，避免无界嵌套推进。
- Network Contract 批量生成现在先构建确定性全批计划：资源加载、定义校验、大小写不敏感目标唯一性、标识符与源码预算全部在写入前完成，dry-run 与真实保存共享 `plan_fingerprint`。审计路径按规范文本去重并保留 `resource_path`、原始 phase 与聚合 phase，known channel 去重改为线性集合并加入同步入口硬上限。
- Network Resource 与生成访问器的版本预检改为委托同一个内部纯值校验器；collection 审计改名为诚实的人工边界复核，不再暗示框架会解释项目自有 metadata。当前批次仍只保证完整预检，逐文件保存遇到不可预期 I/O 故障时不承诺整批自动回滚。
- Physics Probe 现在把一次采样作为入口快照事务：位置、分组、组合模式与 fallback 在 field/provider 回调前冻结，同实例同步递归采样失败关闭为零；同帧缓存加入精确实例身份，不再把同路径替换对象视为旧实例。`STRONGEST` 使用共同尺度比较幅值，SUM 与最高优先级聚合在中间结果失去有限性时失败关闭。
- TurnBased 的 stop 通知幂等性与 action cleanup policy 现在分离：`stop(true)` 在 already-stopped 或 `stop(false)` 恢复后仍会清理并封存队列；phase/action 双通道只有在最后一个 operation 收尾后才释放共享 stop 证据。行动 target 由 `GFTurnAction` 在唯一边界按实例 ID 线性清洗，默认排序和自定义比较器的输入合同也已明确。

### 🐛 Bug 修复 (Fixed)

- 修复 Config Pipeline 的 resource 数据库 `dry_run` 在 `ResourceSaver` 明确不识别目标扩展名时仍报告成功、直到真实保存才失败的问题；规范化后的 resource 目标现在会在 ownership 与任何产物 I/O 前按当前 saver 声明做大小写不敏感预检，dry-run 与真实路由统一返回 `ERR_FILE_UNRECOGNIZED`，显式 JSON 格式的扩展名策略保持不变。

- 修复 `GFAssetUtility.unload_group(..., true)` 在句柄引用归零时直接执行全局缓存移除、从而清掉其他分组 membership 与 pin 的问题；分组卸载现在只释放本组账本，并仅在句柄、剩余 pin 和其他分组 membership 全部归零时 eager remove。未 pin membership 仍不改变正常 LRU 语义。

- 修复 Architecture activation 静默恢复 Settings 后 Display 仍停留在 ready 阶段默认值，以及多 target quiesce 在首个同步 Store write 取消 scope 后仍启动后续 I/O；Display 只在加载结果实际替换状态且 `apply_on_ready=true` 时重应用完整状态，已开始的 write 如实结算而未尝试记录保留供显式重试。

- 修复 Viewport 表面输入把合法 `UV=1.0` 投到右/下排他边界、端点特判造成接近 `1.0` 时非单调跳变、双击历史预算淘汰错误推进无关 capture dispatch epoch，以及 `cancel_source()` 遗留已释放指针状态或未使同步旧投递失效的问题；同时修复 Layered Sprite 的 `animation_started` 监听器只改变播放态时吞掉已提交通知，以及帧/配置身份 ABA 后外层重复发布陈旧 `frame_changed` 的问题。
- 修复 Audio Utility 在播放器入树、流播放 hook、BGM 终态通知、请求快照与后端回调的同步重入中可能半提交旧代状态的问题；初始化和本地候选现在逐边界复核生命周期、请求身份与实际场景树 parent，流 hook 导致 crossfade 资格失效时也会在发布前补齐备用播放器，校验或终态监听器启动的较新请求优先于仍在外层调用栈中的旧请求，本地 stop 期间提前 EOF 会同步清除物理与逻辑会话，pre-init backend topology 操作也按实际提交结果返回。
- 修复公开 logical 文件名以 `.tmp`、`.bak` 或 `.txn` 结尾时与另一文件事务 sidecar 共享物理路径、可能跨 file key 误读或误删的问题；每个 logical identity 现在映射到独立 opaque family，旧 root 可见文件不会被运行时猜测收养。
- 修复 `GFObjectPoolUtility` 的同步、分批与时间预算预热在并发、回调重入或运行中缩小上限时可共同写穿 `max_available_per_scene` 的问题；同一场景现在共享当前生命周期的在途容量预留，变更上限、归还节点或 dispose/init 会在提交前重新验收并丢弃过期候选。普通 acquire 也会冻结生命周期与 parent authority，并在场景构造、状态 setter 和根/子节点 hook 的每个外部边界复核当前代次；旧调用栈不再继续激活、通知或发布已归还、已释放或跨生命周期的节点树。
- 修复项目 Installer 主动取消并返回后仍保持 running、并发 `Gf.init()` 永久等待且半注册模块未回滚的问题；取消与 timeout 等失败入口现在统一在 Architecture 失败结算中先回滚再恰好一次唤醒等待方，terminal 回调不能重开或提交 Installer，detached 旧 continuation 收尾前继续阻止重试和迟到写入。
- 修复 `GFUIUtility` 在 panel 入树并执行 `_ready()` 后才捕获 previous focus，导致 modal 在 `_ready()` 主动取得焦点时无法恢复外部焦点的问题；现在会从目标 `CanvasLayer` 的 `Viewport` 在入树前捕获。
- 修复同一路径的场景预加载在底层请求 drain 前重复调用 `cancel_scene_preload()`、导致 Lease 取消副作用和 `scene_preload_cancelled` 信号重复发生的问题；首次调用后，同一规范化路径的后续调用会保持幂等，不改变既有的迟到完成清理和共享 path-level 取消边界。
- 修复 AI Developer 模块依赖分析只排除小写 `res://addons/gf/` 后代、导致框架保留根本身及大小写等价路径被误报为未归属项目资源的问题；路径引用现在统一复用框架保留资源边界判定，其他资源形状字符串的现行分类策略保持不变。
- 修复 `GFSceneUtility` 自动邻居预载回调错误接收 `SceneTree.scene_changed` 不会提供的场景根参数，导致真实零参数信号触发时报参数数量错误、邻居预载无法启动的问题；回调现在从发出信号的 `SceneTree.current_scene` 读取目标根。
- 修正根 README 已失效的一参数 `GFInstaller.install()` 示例、未观察的注册/初始化/查询失败，以及 Asset Store 把 Installer 与 `Gf.init()` 写成二选一的问题；扩展安装页现在明确区分 `gf.save`、`gf.extension.save` 与 `gf.preset.save`，维护者文档也与全部内置扩展默认关闭的 manifest 事实一致。

- 修复 Platform 层可提交身份匹配但状态、错误、载荷或单调时间戳互相矛盾的预构造终态并消费唯一 Request Handle，以及 `GFArchitecture` 可在 Installer 事务尚未进入 running 时被提前标记 applied、从而跳过真实项目 Installer 的问题；非法提交现在保持 pending/未开始状态且不发完成信号。
- 修复 Platform 请求的空白 ID 变体绕过契约校验与租约去重、迟到成功不释放 Provider 并发租约、方法及激活意图复合键分隔符碰撞、pending Intent 被去重历史淘汰后可重复入队、负限制静默变成无限制、调试快照泄露原始错误和描述符 metadata，以及极端 deadline 回绕和 Locale 批量导入 first-write-wins 的问题；请求身份、账本、诊断和导入路径现在使用单一规范语义并补充生命周期回归。
- 修复低流量 batched 日志只能由下一次写入触发 interval flush、关闭期只处理一个批次、两个默认 JSONL sink 争用同一文件、普通 Analytics queue overflow 不进入累计丢弃口径、非 2xx body 污染公共错误，以及畸形或巨量自定义 Header 依赖 HTTP 后端偶然拒绝的问题。
- 修复 workspace fingerprint 在未跟踪 symlink 的 `lstat` 与 `readlink` 之间可混合两个对象、Unicode/超长路径脱敏后让 `.env` 文件名规则和 `tests/` suppression 失效，以及 ZIP entry 脱敏名称反向影响敏感文件名分类的问题；符号链接现在执行读后身份复核，所有凭据规则始终基于验证后的原始路径语义，报告仍只暴露安全 fallback label。
- 修复包归属索引忽略 manifest `exclude_paths`、让被排除 editor 文件仍参与所有者/重叠判断的问题；独立 builder 与维护 gate 现在统一以 1 MiB、64 层和 16384 个 JSON 值限制本地 package manifest，并递归拒绝藏在 `metadata` 中的下载、安装、签名、依赖和装载策略字段。
- 修复 Config Pipeline 在生成数据库后重新哈希已变化来源并把错误摘要写入 manifest、阶段 helper 变化不使旧产物 stale、XLSX 的四个语义 XML entry 把非正常终止当作 EOF、Unicode-only 表名被访问器静默跳过，以及循环或超大 JSON 图可绕过 Target 工作预算的问题；写 manifest 的批量导出会在事务完成前复核来源并在漂移时整批回滚。
- 修复 Config Pipeline 的 resource `dry_run`、独立 writer 与 Runner changed-only 早退使用不同输出路径授权的问题；裸相对、主机绝对、未知或畸形 URI 现在都会在零产物 I/O 前一致失败，fresh manifest 也不能绕过校验。
- Dialogue Runner 现在以统一会话租约保护 condition、response、`line_blocked`、`line_reached` 与 mutation 等同步重入边界，旧推进栈不能再覆盖或终止回调中启动的新会话；非展示步数预算不再误计目标 TEXT。Dialogue 资源校验新增空图与非法 `LineKind` 拒绝，并用操作级索引收敛 transition/cycle 校验复杂度；资源身份失败路径不再记录任意字典键，指纹编码改为字典顺序无关且不会把 Variant codec 的遍历截断 marker 当成完整身份。Dialogue 的 `framework_internal` 方法也迁入 canonical 内部 section，并纳入 API Surface 门禁。
- 修复 Dialogue Text 虽声明 strict JSON 却接受 trailing comma、重复 member、原始控制字符、非法 Unicode 与溢出数值，以及大输入、诊断洪泛、语义错误无源码位置和报告 metadata 循环递归的问题；编译器现在在物化前执行严格、有界、带 JSON Pointer provenance 的解析，读取/文本/结构/line/response/诊断均有不可关闭的硬上限，失败结果保持 `resource == null` 与 `line_count == 0`，本地报告则以有界 JSON-safe 投影保留可跳转来源和 owner 提供的 next action。
- 修复 Network Contract 多输入清洗到同一输出或共享 `class_name` 时后项静默覆盖前项、GDScript 关键字字段与 getter 清洗碰撞生成不可解析源码、错类型/非有限默认值被定义校验漏过、Dictionary/Array 默认值静默退化为空集合、`allow_null` 显式 null 被非空默认值吞掉，以及生成版本报告缺少运行时 `contract_id` 的问题。
- 修复 Decision `select_best_from_scores()` 对乱序数组返回首个合格低分、评分回调清空 exported 数组导致越界或漏评、缺失 provider key 绕过调用预算、错误 provider 签名产生脚本错误，以及已注册 DecisionSet 改 ID 后形成双重 registry 身份的问题；Decision 上下文、Score 与 Evaluation 的项目 Variant 副本改为循环安全实现，循环 metadata 不再触发 `Max recursion reached`。
- 修复 Content Package 已解析但缺少 `package_id` 的 manifest 被静默丢弃后仍提交空候选目录、不同 package/resource 二元组的复合 Asset ID 碰撞后覆盖返回部分快照，以及 Query/Provider 对循环 metadata 深复制或调试序列化触发递归上限的问题；失败重建现在保留上一份有效 catalog，Provider 碰撞时拒绝整份候选。
- 修复 Combat 同实例技能同步重入导致事务重复提交、发射策略接受重叠旧报告、Buff predicate 使用失效索引、命中观察信号改写权威结果、属性集合清理遗留幽灵连接、锁向弹道在目标释放后停住，以及 Buff 非有限时间输入污染或不终止等问题；补充 2D/3D 对称回归测试。
- 修复 Capability Node 树超过启停预算时先写 active/meta、仍调用 Hook 和成功信号但未更新节点树，生命周期 Hook 释放 receiver 后遗留注册事务并继续传递 freed Object，Inspector 把多个子类依赖误判为唯一命中，以及 Recipe 编辑器只信声明类型而接受不相关场景根脚本的问题。
- 修复 Camera 允许负行列式 Basis 进入 Quaternion 插值并产生引擎错误或朝向跳变、Orbit 鼠标捕获在运行时改键或窗口失焦后残留，以及有限输入与 scale 的乘积溢出后仍报告已应用的问题；捕获现绑定创建时的设备/按键/Rig/代次，所有派生增量会在写入 Rig 前复核有限性。
- 修复 Behavior Tree 具体内置节点子类被 Runner 静默切片、同一 Runner 同步重入重复推进、Cooldown 从 child tick 前计时、Decorator 替换遗弃旧运行态、无效 Condition 伪装成业务 false，以及循环 Dictionary 深复制触发 `Max recursion reached`；所有路径均增加失败关闭或精确诊断回归。
- 修复 Action Queue、动作组与 RepeatAction 的控制 hook 同步反调时可递归或重复控制，pause/resume hook 内清空或释放队列时跳过当前动作取消并遗留陈旧所有权，parallel/repeat 在 execution generation 失效后仍启动旧工作，以及旧并行 waiter 可移除新一轮活动动作的问题；生命周期取消现在先解除当前所有权，再于外层控制 hook 返回后按 identity 去重、按 FIFO 恰好执行一次，duck-typed 动作把非 `Signal` 结果声明为等待时也会受控拒绝并继续有界推进。
- 修复 Asset Metadata 将矛盾归因别名及嵌套/顶层声明按优先级静默折叠、让空白覆盖路径从审计分母消失，以及未受信文本可用控制字符伪造 NOTICE 分组或同级条目的问题；冲突和无效路径诊断只保留字段名、输入索引与稳定原因，不复制原始值。
- 修复 configured Tween 的 marker callback 改写下一 `parallel` 步骤拓扑，以及 absolute step 只检查属性存在、让不兼容目标值通过预检的问题；标记现在在对应 Tweener 的同组结束点触发，类型不兼容会在追加 PropertyTweener 前由 validation/step preflight 拒绝。
- 修复 Settings fallback 在文件打开后写入失败仍返回 `OK` 并发成功信号、同步 UI route replace 在新面板失败前删除旧历史、异步 Route 被可重入回调修改后失去完成关联，以及 shader copy-on-write 写回失败后继续修改共享原材质的问题；路由请求现在冻结入口快照，Shader Binder 复用已隔离材质并在外部替换后重新隔离。显示音量、Viewport 缩放、Control 窗口矩形和安全区边距同时在引擎副作用前拒绝 `NaN` / `Inf`。
- 修复 Storage `USE_NEWEST` 把 `NaN` / `±Inf` 元数据解释成更新方向并覆盖另一后端，以及命令历史恢复在无效 builder 或中途构建失败时清空、部分替换旧栈的问题。
- 修复响应式状态深层写入失败后仍遗留中间字典、`set_state()` 把不完整 diff 误判为相等或只发布部分路径，以及状态守卫重入继续执行旧切换计划、节点 enter/push 重入追加过时历史或信号、状态事件在切换后继续调用旧候选的问题；遍历不完整时现在会提交新状态并只发布根级 `state_replaced`。
- 修复 Storage JSON 编码把 Variant 遍历预算耗尽产生的 `TraversalLimit` 诊断标记当作完整业务文档落盘的问题；编码、压缩、混淆和校验和路径现在统一失败关闭，同步与异步事务不会创建临时提交，并保留已有最终文件。
- 修复共享资源与存储的取消、替换、恢复和释放边界：Broker 会在 queued Lease 离开后按剩余消费者重算类型与 admission 约束；Asset、Scene 与 BackgroundWork 私有 Broker 在 drain 完成前拒绝替换；Scene 自动邻居可加入外部消费者已活动且 type hint 兼容的同路径请求；BackgroundWork 不会把新任务并入已取消 Lease；Storage 异步单文件入口会按完整多文件事务恢复，并在 dispose 终态回调重入期间持续关闭新 admission。
- 修复 Signal Runtime Probe 的 one-shot 连接断开后遗留幽灵账本和缺少幂等释放入口、Support Report replay 在 dispose/outbox 切换后提交旧 continuation、报告替换吞掉 backup 清理错误、路径附件/输出链接绕过与绝对保存路径泄露、Overlay 非有限采样伪报成功、Screenshot burst 接受非有限延迟、Debug Draw 非有限时间形成永久命令，以及 Runtime Inspector 递归 setter 或注册代际变化后仍报告成功的问题。
- 修复重复 operation 终态与迟到回调可覆盖审计历史、活跃重复 incident 按首次插入顺序被误淘汰、异步 tracker 刷新失败后把 last-good 快照伪装成当前成功，以及非法控制台 tier 降级为 `OBSERVE` 的问题；tracker 现在保留成功时间并显式报告 attempt、error 与 stale，批量刷新也统计已登记后失效的 provider。
- 修复混音快照错误容器仍返回成功、池化 SFX 携带上一 lease 的 Godot 属性、重复 AudioUtility 初始化遗留旧播放器，以及 BGM replacement 不能取消 fallback waiter 的问题。
- 修复素材复制仅按预检长度判断预算、source 在预检后变化仍继续复制、覆盖中断后 canonical target 缺失且随机 backup 无法定位、ID3 声明截断仍报告完整成功，以及 pitch 最小工作量突破 `max_correlation_operations` 的问题。
- 修复 stopped Ambient channel 永久缓存任意数量播放器，以及音频目录中海量非匹配项、`0=无限` 或链接环可绕过原有“只限制匹配结果”预算的问题。
- 修复清单绝对目标绕过批次写入根、下载覆盖在最终 rename 失败前删除旧目标、续传忽略文件读写错误，以及 `expected_size` 被文档误解为完整性校验的问题。
- 修复源码文本缓存绕过后来收紧的字节上限、非法 UTF-8 被替换字符静默接受、可写句柄 path 改写释放身份、resolver 无效替换先删除旧记录、waiting 任务终态仍滞留队列、取消历史无界、fixed 预加载合并丢失升级意图、场景根上方 `..` 被钳制到其他合法路径，以及 ACK 饱和时静默驱逐 pending 的问题。
- 修复任务组允许 self/祖先循环导致 requirement 聚合无界递归、组提交后未来子任务仍可被独立调度或修改 requirement，以及任务在 `end()` 中重调度同一实例后旧代继续推进新代的问题。
- 修复 `step_started` 监听器取消后步骤仍执行、序列 rollback 忽略 `GFUndoableCommand.is_undo_successful()`、取消长等待后专属 `SceneTreeTimer` 继续驻留到原超时点，以及超大 String/PackedArray 快照绕过节点预算的问题。
- 修复 AI Developer 依赖分析只编译 Module roots、导致合法 Module → Adapter 资源引用被误报为未归属的问题；Adapter root 与其中声明的 `class_name` 现在作为目标所有权进入同一有界索引，但 Adapter 仍不作为依赖源或模块循环节点，缺失、不安全、不可读、歧义及预算耗尽继续失败关闭。
- 修复依赖所有权计划允许 Module/Adapter ID 占用 `gf`、`godot` 保留 token，以及目录枚举错误被 `os.walk()` 静默跳过的问题；共享命名空间现在统一拒绝保留与重复 ID，任一后代枚举失败都会使分析不完整。Module 与 Adapter 扫描只允许经路径安全校验的普通 `.gdignore` 文件剪除根或后代子树；链接、损坏或不可验证的同名条目不会再静默隐藏源码，而会计入不安全路径并使分析不完整。
- 修复安全测试把合成夹具命名为真实敏感数据、导致 CodeQL 将边界与脱敏验证误判为明文持久化的问题；无关凭据检测的边界测试改用 opaque canary，需要敏感形状路径的测试在内存中构造 synthetic canary，且不再依赖任何扫描抑制。
- 修复 CodeQL 策略把普通 `LGTM`、步骤说明中的 `paths` / `queries` 和 shell block 行尾反斜杠误判为 suppression/config，以及把 URL fragment 的 `#` 错当注释后漏过禁用默认查询的问题；YAML key lexer 现在同时覆盖 block、flow、quoted、Unicode escape、quoted continuation 与多行显式 key，并在原始输入、线性 Unicode 解码后的原始文本及续行拼接后的逻辑行上累计冒号、引号与标签探测预算。续行改为分块后单次连接，编码或跨行构造的 probe 不能在 normalization 阶段恢复二次复杂度。
- 修复 Utility 的有界 Bank resolver 用最右子串截断多字符 `fallback_separator`、导致结果偏离 `GFAudioBank.resolve_clip()` 的问题；运行时解析现在保留从左到右、非重叠且忽略空片段的既有分隔语义，同时继续限制标识长度、分隔符长度与最多 16 次回退。
- 修复异步等待生命周期测试把 1ms 墙钟预算与 deferred free 调度顺序绑定的竞态；测试现在先用 timeout pause 建立等待已挂起的握手，再同步释放 continuation owner，稳定验证失效检查必须先于同轮已到期 timeout 仲裁。
- 修复仅依赖父级 factory 的活动 child 未保持父链关闭租约，以及 provider/injection 重入关闭架构、嵌套解析失败或待释放对象仍可缓存、交付、重复清理或遗留 child 事件作用域的问题；外部 factory 依赖现在只阻止父链正常关闭而不冻结无关模块拓扑，每次解析固定 owner/requester 的准入与 generation，逐 Hook fail closed，解析栈内拒绝模块拓扑重入，并按缓存释放权与实际注入目标回滚未交付实例。
- 修复独立 `api-baseline-diff` 无法为受治理的 `X.Y.Z-dev.N` 开发身份选择上一稳定 SemVer 基准、并错误拒绝其目标 major/minor 升级的问题；基准选择、breaking/compatible 判定与 Changelog 门禁现在复用同一稳定 core，未知 prerelease 或 build metadata 继续失败关闭。
- 修复后台任务只保存 `Callable`、导致短生命周期 `RefCounted` worker 或 apply target 在线程执行前释放的问题；取消、失败和成功路径现在统一清理 callback 所有权。
- 修复 `GFRenderWarmupUtility.queue_manifest()` 保存但正常帧推进忽略 `entries_per_tick` 的问题，并防止显式零或负清单预算永久停滞。
- 修复 `GFDiagnosticsUtility` 在 strict architecture 中通过 reporting lookup 探测可选 Console、Log 和工具快照贡献者，导致合法缺失被误报为必需依赖的问题。
- 修复场景树先释放 root-owned BGM 播放器后，`GFAudioUtility.dispose()` 在有效性检查前构造 typed array 而触发 freed-instance 转换错误的问题；两条 BGM 清理路径与重复 dispose 都收敛到幂等终态。
- 修复 BGM 的 void start 无法观察 backend 接受、fallback、异步加载失败与被新请求取代的问题；pending cancel、owner 退出、全局 stop、backend 替换和 dispose 现在各自得到 exactly-once 终态。Session stop、自然结束、replacement 和生命周期释放按精确 ID first-wins，所有相关内部状态先冻结再通知，监听器重入不会让旧 continuation 停止或清除新会话。
- 修复场景切换完成帧立即启动邻居预载时与活动 Asset warmup 重叠，可能导致 `.tscn` 间歇解析失败的问题；邻居请求现在必须经过目标场景确认、稳定帧和共享 Broker idle 边界。
- 修复 `save_profile()` 在提交调用栈内同步遍历大型 Provider、可造成超过 100ms 主线程停顿的问题；请求现在先返回句柄，再由生命周期 tick 在显式预算内推进准备。
- 修复共享 Provider 的 Profile 切换由项目拼接 flush/load 时缺少原子活动身份、目标失败后
  可能遗留部分应用状态的问题；新 Coordinator 在精确 domain 锁内完成源屏障、逆序恢复
  与单次身份提交。
- 修复 `GFSaveProfileTransactionCoordinator.unregister_profile()` 因 domain 存在任意活动身份而拒绝注销空闲非活动 Profile 的问题；活动目标、进行中的事务和 reconcile fence 仍失败关闭。
- 修复 section 修改与保存分离时，已知写入失败、未知提交和生命周期关闭之间没有统一
  所有权的问题；类型化 mutation 现在区分可逆确定失败与必须 fence 的未知结果。
- 修复异步 UI 的全局完成遥测缺少请求身份，可能被同键重入或旧生命周期迟到回调误关联的问题；Router 现在在发出可重入信号前原子移除旧 pending，并以单调 request ID 与精确底层句柄双重校验终态。
- 修复旧虚拟输入定时器、同 `source_id` 的不同 Source 实例或手动覆盖可能清除后续输入贡献的问题；lease 同时校验操作对象、generation 与单调 lease ID，迟到回调无法释放新脉冲。Pulse 计时改用 owner-bound timer，并通过内部 handle + owner 精确存活契约识别 `GFTimerUtility` dispose/reinit 后的排程丢失，以 `FAILED / timer_schedule_lost` 补偿释放，避免 handle ABA 误取消或动作粘住。
- 修复 Save Profile 的三项事务边界：flush 在调用时捕获的 generation 已持久化后立即
  进入唯一成功终态，不再等待或继承更晚 generation 的失败；Bootstrap/Adopt 只在底层
  保存实际 claim Request 后消费 Recovery Lease 并推进 domain epoch，瞬时准入拒绝可用
  同一 Lease/Request 重试；底层超长错误进入事务 stage evidence 前限制为 2048 字符，
  missing/corrupt 激活仍可靠返回 `recovery_required` 与可用恢复能力。
- 修复 SaveGraph 在 Source/Scope/Pipeline 已记录采集错误后仍生成并覆盖健康存档、内层格式版本接受缺失/旧版/字符串值、调用方 context 可伪造事务根、同步 apply 重入无界递归，以及 participant 或 Source snapshot 回滚失败只存在于可选 trace 的问题；默认 apply 结果现在始终公开 `rollback_failures` 与 `atomicity_restored`。
- 修复 Graph 与 Slot 读取入口接受 `ok=true` 但 integrity 为 `INVALID` 的内容、PersistProperties 的 local/registry 同 ID Serializer 发生编码/解码实现漂移、Slot Sync 绕过 Adapter 模板与规范路径碰撞检查、Document parser 静默丢弃空白/非字符串/trim alias section key，以及 Section/Document 在有界持久化验收前深复制循环或超深容器的问题。
- 修复 `GFSignalSubscriptionToken` 会隐式接管既有同一 `Signal + Callable` 连接、并在取消时断开其他创建方资源的问题；重复连接现在返回非活动 token，原连接继续由原创建方持有。
- 修复 queued-for-deletion 的 Singleton 在同帧重建时只释放依赖作用域、未同步撤销旧实例 owner 事件的问题；缓存身份与框架副作用现在原子切换。
- 修复 `res://`、`user://`、`uid://` 根参与相对化、包含和排除判断时被拼成三斜杠前缀的问题，并统一 scheme 与普通目录的后代边界代数。
- 修复 GDScript 布局门禁把“框架内部方法（类型收窄）”中的“类型”误判为“内部类”的问题；canonical 内部方法、层内方法、私有方法和内部类现在按明确等级排序。
- 修复拾取操作 begin/apply/deactivate 状态不同步的问题；失败 begin 不再被工具持有，失败 apply 保持 READY 可重试，停用工具会取消操作并禁止后续 mutation。
- 修复脚本补丁可用陈旧读取快照覆盖外部修改的问题；保存报告新增 expected baseline 与结构化 conflict，菜单模板创建也改用受控 create-only writer 并验证完整写入。
- 修复空白模板记录无诊断消失、renderer 退出留下未完成 active task，以及 ProjectSettings 分区文案在 cleanup 后残留的问题。
- 修复菜单模板允许非法文件名或 `base_class` 经占位符生成不可解析 GDScript 的问题；派生 `class_name` 与基类现在都在任何文件写入前校验，非法输入保持零输出。
- 修复根插件把可选标准库清单缺席、局部目标缺失和清单损坏都静默折叠为记录数组的问题；降级或无效状态现在输出有界、稳定且不泄露原始值的诊断。
- 修复编辑器贡献刷新在 EditorFileSystem 扫描尚未完成时立即重建 helper 并打印成功、且连续请求可能混用不同文件 generation 的问题。
- 修复扩展选择 cache 的 manifest 身份遗漏展示、版本、类型、默认启用和其他派生字段，导致合法 manifest 仅修改未投影字段后仍复用旧路径授权的问题；cache token 现在覆盖完整规范化语义与校验错误。
- 修复已存在但无效的 tool contribution 只留在内部错误数组、公共选择报告仍显示成功的问题；标准报告现在投影状态与逐贡献诊断。
- 修复 package transaction 允许 lockfile 与 payload/cleanup 路径别名、prepare 后无条件覆盖并发修改，以及旧 target 删除后中断无法自动恢复的问题；已有 target 现在以 transaction-owned sidecar 证明所有权，原先不存在的 target 只在仍精确匹配 planned identity 时回滚，提交前复核当前快照，恢复只补偿本事务拥有的状态。事务 journal 不再为每个 payload 复制冗余原件，preset CLI 烟测按实际场景使用 240 秒有界预算。
- 修复带 integrity 的共享 registry cache 在 lookup 校验后仍按可变路径直接解析，以及 CLI human 输出遗漏嵌套事务 cleanup warning/recovery obligation 的问题；registry 先进入项目私有消费快照并复验，human/JSON 输出保留同一事务结论。
- 修复 Asset Store 构建器枚举后按可变路径读取、可能跟随 filesystem link 或打包与校验时不同字节，以及分发 README 保留指向 ZIP 外部文件的本地链接；构建和发行源文件现在通过稳定普通文件句柄读取，产物审计要求本地链接闭合于 `addons/gf`，失败会清理未完成 ZIP。Release workflow 的 `contents: write` 收紧到唯一发布 job，仓库策略同时精确校验 Draft/Full 聚合门禁的结果映射与每个失败分支，不能再用保留步骤名但把 `exit 1` 改成成功来绕过必需检查。
- 修复 `GFRequestHandlerRegistry` 在 handler 自注销或自替换后仍把旧调用统计写回记录的问题；回调后的写回现在以 registration sequence 复核，回调中的最新注册表状态优先。
- 修复节点池与 `GFRefCountedPool` 在 before-add/acquire/release/reset hook 重入时可能重复借出、重复归还或覆盖新生命周期状态的问题；过渡所有权与 generation 复核使每个实例始终只有一个权威位置。
- 修复 `GFManualTimerQueue` 嵌套推进绕过回调预算以及 callback 中 `clear()` 后旧推进覆盖新状态的问题；同一队列只允许一个 drain，生命周期重置会终止旧轮次。
- 修复 `GFTimeUtility` 接受非有限配置或传播非有限/溢出 delta 的问题；无效配置保留上次有效值，无效本轮输入归零，极端有限物理步长按最大子步数饱和。
- 修复 `GFTimerUtility` 同 tick 到期快照无法被较早回调按句柄、owner 或生命周期取消，以及非有限延迟形成永久 pending 的问题；未开始的 ready callback 现在仍受取消和 generation 约束。
- 修复 `GFRuntimeAgentEnvironment` 审计监听者同步重入导致递归通知栈无界增长的问题；审计先提交，再通过有界迭代队列通知，预算耗尽只影响实时通知。
- 修复 `GFAsyncKeyedGate` 极端正数 timeout 换算毫秒 deadline 时 `int64` 回绕的问题；deadline 现在在最大可表达值饱和。
- 修复 typed Dictionary 解码重置循环状态、schema 默认构造向 non-nullable/no-default 字段注入非法 null、校验 issue 保存外部 mutable key 别名、range 规则把 64 位 int 有损缩窄为 float、对象/字典报告自合并或共享 issues 数组时无界放大，以及稳定 issue 指纹写入运行时实例身份的问题。
- 修复 Standard Config 的 CSV multiline 后诊断物理行漂移、裸 `#if` 缺 symbol 时 fail-open、Adapter 缓存返回已释放 Object、Callable 表源循环依赖假成功/递归、Resolver cache 分隔符碰撞、positional `row_key` 绕过 JSON-safe codec、Size Rule 漏掉 `PackedVector4Array`，以及 Query 路径读取已释放 Object 触发引擎错误的问题。
- 修复值索引替换信号重入留下幽灵二级索引、MutationBatch 重入重复执行当前 Callable、float 预算成功消费却不降低余额，以及字典/aggregate 通知递归倒插的问题。
- 修复文本评分对循环/深 Array 递归失败并允许非有限权重污染排序、ReplayTimeline self-append 无界增长、TimedText direct export 绕过时间归一化、优先工作队列有限输入派生 Infinity，以及缓存诊断 int64 计数回绕为负数的问题。
- 修复 Tag `NONE` / `ANY` 把 null、foreign Resource、循环、过深图或未知 operator 当作普通未命中后失败开放的问题；匹配报告现在区分结构有效性与逻辑命中。
- 修复 activation 终态可被 `prepare()` 重开、同步回调可重入并重复执行副作用，以及回调内 `clear()` 可破坏外层步骤集合的问题。
- 修复 compatibility preflight 把合法超 int64 SemVer prerelease 数字转换为固定宽度整数后误序、artifact include 展示选项静默跳过显式 expected hash/time 校验，以及未闭合模板尾部绕过累计输出上限的问题。
- 修复 `GFByteCursor.try_read_var_utf8()` 分别校验 varuint 前缀与 UTF-8 payload、导致一次公开读取可突破 `max_read_byte_count` 的问题；组合预算超限现在以 `ERR_INVALID_PARAMETER` 原子回滚。
- 修复不同 touch index 共用来源键、mouse 与 touch index 0 共用指针槽、pointer capture 接受 inactive sentinel、虚拟源重配置遗留旧身份贡献、非有限虚拟值污染聚合、虚拟源快照字段与玩家作用域漂移、单项 assignment getter 泄漏内部 Resource，以及非有限输入阈值绕过诊断的问题。
- 修复 `GFInputPlayback.event_applied` 回调 stop 后继续写 source、restart 后旧栈推进新录制索引或 source 置空后解引用的问题；同时修复默认 detector 等待时间恒为 0、finish 回调重入 begin 被旧栈覆盖、检测 JSON 快照泄漏 NaN/Infinity、Deadzone 上下阈值相等时全归零，以及 Pulse 非有限 delta 永久污染 elapsed 的问题。
- 修复 Input Mapping Dock 固定忽略 remap 配置、等价资源路径使用不同缓存身份、失败加载后隐藏旧诊断却无标记复制旧报告，以及工作区页面脱树后继续执行资源刷新等问题。
- 修复 controller `drag_started` 暴露半提交事务、终态 signal 在旧 source/pointer 清理前允许下一会话覆盖字段、候选回调取消后仍返回旧落点或继续发布 moved、drop Callable 取消后仍提交第二终态、clear 回调新建对象被无通知删除，以及有效 parentless source 无法恢复的问题。
- 修复触屏控件活动期间修改 action/device/button/axis/emit 或摇杆 position mode 后向错误 lane 释放、关闭 mouse 接收或禁用 process mode 后动作粘住，以及 touch/controller 接受 `-1` inactive sentinel 的问题。
- 修复 drag session/zone/controller 的 JSON snapshot 在 bounded codec 前执行原生深复制、循环 metadata 触发引擎递归错误并可能回退 raw Variant 的问题；循环和超深输入现在稳定输出 typed marker。
- 修复 Domain 库存按堆叠键误删非键实例数据、物品定义改 ID 后遗留旧注册键、非正数量可构造成功结果、受限槽位交换/排序绕过接收规则，以及 validation 文档 schema 与运行时字段不一致的问题；任务开始/接取会在 `quest_started` 前提交事件订阅，并在所有项目条件、阻塞器和信号回调后复核任务身份与状态，避免事件丢失、监听器泄漏和互斥终态双提交。严格关卡重开现在先解析下一状态再执行运行时清理，Domain Installer 也会在每次异步注册后检查取消并传播注册失败。
- 修复 Feedback 播放中的 shake preset 退化为零时长后永久占用槽位、非有限/零 haptic duration 进入硬件无限模式、全 disabled 或范围外 shake track 错误回落/覆盖、provider 替换把 stop 发给错误 owner、dispose 丢失失败停止的终止证据、自动 haptic 拒绝不可观察、同路径 2D/3D receiver 重建后不恢复，以及 Installer 忽略取消或第二次注册失败的问题。
- 修复 Flow 的公开 `is_running` 可被外部改写而伪造并发锁、缺失节点仍报告 completed、坏 Context 快照先清空现态、Graph 在活动节点租约下部分恢复、非有限 Signal timeout 形成永久等待、空连接被编辑器静默丢弃、视图过滤漏掉方向/类型/重复/单连接约束、含分隔符 ID 发生身份碰撞，以及粘贴重复线性扫描已占用节点 ID 的问题。
- 修复 Interaction 的 Pointer 与 Receiver-to-Receiver 转发对已编码报告再次编码、Area2D/3D 自定义 sender 的空或非 Dictionary 结果产生残缺报告或被静默丢弃、候选回调释放后续 receiver 后访问 previously freed Object、失效 `validation_callback` 静默恢复默认允许，以及同名不兼容项目方法触发脚本错误的问题；每次实际 Area 分发现在都返回并发布完整 JSON-safe 报告。
- 修复 Network snapshot 生成 `ok=true` 但同版本 applicator 因深度、操作数或非法内容静默拒绝，service discovery 的自定义 `now_seconds` 与内部 elapsed clock 混用而延长 TTL，以及 fixed-tick signal 回调递归推进导致 stack overflow 的问题。
- 修复 Physics 同路径 field 替换命中陈旧缓存、最高优先级的 32 位哨兵丢弃合法 int64、Vector3 聚合与平方范数溢出、浮力总力携带 Infinity、平方反比与超大浸没半径发生可避免中间溢出，以及 field 回调改写 Probe 后形成混合时点或错误缓存的问题。
- 修复 TurnBased 在 lifecycle 已 stopped 时让 `stop(true)` 静默跳过清理、`stop(false)` 的在途 restore policy 无法升级、phase/action 双通道先结束者过早清除 stop 证据，以及 `get_actor_value()` 对同名错误 arity/type 方法直接产生脚本错误的问题；action target 的重复 O(n²) 清洗收敛为单次 O(n)。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `GFStorageUtility.allow_absolute_paths`；运行时 Storage 不再提供重新启用任意绝对路径的开关，也不保留 deprecated alias。
- 移除 `GFStorageUtility.get_storage_directory_path()`、`ensure_directory()` 与 `create_directories_for_nested_paths`；runtime Storage 不再暴露或让调用方管理物理目录，目录只保留为 logical catalog selector。
- 移除 `play_bgm_with_options()` 的 `loop` / `playback_region` 通用选项，并保留事件 metadata/options 中的同名键；继续传入会在资源加载和后端派发前失败关闭，类型化区间只能来自 `GFAudioClip.playback_region`。
- 移除框架内部 `gf_threaded_resource_coordinator.gd` 与 `gf_threaded_resource_operation.gd`；不保留双轨协调实现，统一由公开 `GFResourceBroker` / `GFResourceLease` 承担跨 Utility 所有权与 admission。
- 移除 `GFSaveProfileUtility.save_profile(profile_id, metadata, context)` 字典重载；保存调用统一改用一次性 `GFSaveProfileRequest`，不保留隐式复制兼容路径。
- 移除 `GFSaveProfileResult.STATUS_GATHER_FAILED` / `gather_failed`；Snapshot 创建、协作式推进与 worker payload 预检失败统一使用 `STATUS_PREPARATION_FAILED` / `preparation_failed`，不保留 alias。
- 移除 `GFSaveSectionProvider.gather_section()`、`_gather_section()`、`GFSaveProfileUtility.STATE_GATHERING` 及读取回滚对保存采集的隐式回退；保存 Provider 必须采用 Snapshot Operation，启用读取的 Provider 必须显式实现 `_capture_section()`。
- 移除 `GFArchitecture.fail_on_missing_declared_dependencies` 与 `module_lifecycle_max_stage_passes`；声明依赖现在始终是强契约，生命周期计划只编译一个确定性候选 DAG，不保留 warning-only 或初始化期多轮补注册路径。
- 移除 `GFArchitecture.HOOK_GET_REQUIRED_DEPENDENCIES`、`HOOK_GET_REQUIRED_MODELS`、`HOOK_GET_REQUIRED_SYSTEMS`、`HOOK_GET_REQUIRED_UTILITIES` 与 `HOOK_GET_REQUIRED_FACTORIES`；依赖声明只通过 `GFModel`、`GFSystem`、`GFUtility` 的类型化虚方法表达，不再暴露字符串 Hook 常量。
- 移除 `GFSpatialCanvas2D.handle_input_event()` / `handle_screen_input_event()` 的 `bool` 返回契约，以及内置 raw Escape、中键、左键和固定 modifier 判断；调用方改用 `InputDisposition` 与显式 `GFSpatialCanvasInputPolicy`，不保留双轨解释路径。

### 🔧 API 变动说明 (API Changes)

- 新增公开 `GFBoundedJsonObjectReader`，提供 `parse_object(text, max_bytes, max_depth)`、`read_object(path, max_bytes, max_depth)`，以及 1 MiB/64 层的默认与绝对上限常量。两个入口的预算只能收紧；报告固定包含 `ok`、`data`、`source_path`、`size_bytes`、`error_kind`、`error`、`max_bytes` 和 `max_depth`。框架内部 `GFBoundedJsonReader` 与 `GFExtensionJsonFileReader` 现委托该 primitive，同时分别保留既有四字段报告和六字段累计预算报告。
- `GFStorageUtility.allow_absolute_paths`、`get_storage_directory_path()`、`ensure_directory()` 与 `create_directories_for_nested_paths` 已移除；新增 `has_file()`。`list_files()` 只接受 portable logical directory 与不带点号的 lowercase extension token，并只返回 catalog 中存在 committed payload 的规范相对 logical identity；`canonicalize_data_file_name()` 只接受已经 canonical 的输入，不再改写分隔符、大小写或路径别名；`GFStorageAsyncOperation.get_file_name()` 与 `GFStorageAsyncResult.get_file_name()` 同样只暴露 logical identity，不再产生绝对路径身份。`save_dir_name` 必须在 activation、`init()` 或首次 I/O 前配置，Storage root 一经加载即冻结；切换 root 必须创建新的 Utility。
- `GFStorageAsyncOperation` 的操作类型新增 `OPERATION_DELETE`；`GFStorageUtility.delete_file_request_async(logical_path)` 返回 `GFStorageAsyncOperation`，终态由 `GFStorageAsyncResult.get_delete_result()` 读取。新 `GFStorageDeleteResult` 公开 `FailureKind`、`FamilyMember`、`is_successful()`、`get_error_code()`、`get_failure_kind()`、三个成员计数 getter、`get_failed_member()`、`duplicate_result()` 与 `to_dict()`；非 delete 结果的 delete 字段为空，delete 结果不会同时携带 read/write 终态。
- `GFStorageUtility.save_data_request_async()`、`save_payload_request_async()`、`load_data_request_async()` 与 `delete_file_request_async()` 新增尾部可选 `GFStorageAsyncRequestOptions`；`GFStorageAsyncOperation` 新增 `caller_completed`、consumer ID、caller 状态查询、`get_caller_result()` 与 `cancel_observation()`，`GFStorageUtility` 新增 `get_late_settlement_diagnostics()`。不传 options 的既有调用保持物理终态兼容。
- `GFStorageAsyncResult` 新增 `SettlementKind`、`get_settlement_kind()` 与 `is_cancelled()`；worker 接纳前取消固定为 `SettlementKind.CANCELLED` / `ERR_SKIP`。`to_dict()` 的 exact schema 在 11.0 主版本迁移线新增必需 `settlement_kind` 字段，严格 Dictionary 消费者必须同步升级 schema。
- `GFSettingsStoreUtility.is_persistence_enabled()`、`read_settings(file_name)` 与 `write_settings(file_name, data)` 构成新的同步持久化端口；`GFSettingsFileStoreUtility`、`GFSettingsNullStoreUtility` 与可选 package `gf.standard.settings.storage` 中的 `GFStorageSettingsStoreUtility` 是新的公开实现。`GFSettingsUtility` 新增 `persistence_enabled`，并通过 `get_required_utilities()`、`ready()`、`begin_activation()` 与 `begin_quiesce()` 接入 Architecture 生命周期；现有 standalone `init()` 调用形状保持兼容。
- `GFSaveSlotStorageAdapter.list_slots()` 的 `modified_time` 不再读取物理文件系统 mtime，改为 metadata 中的领域时间 `updated_at_unix`；字段缺失时固定为 `0`。`build_slot_file_plan()` 现在按同一 portable logical identity 规则预检模板，不会静默规范化别名。
- `GFAssetBrowserModel` 是 `gf.tool.asset_browser` 新增的公开 model-first API；它消费 Standard Assets 的 `GFAssetCatalog` 与 Kernel 缩略图协议，不新增 Dock、Provider 注册表或 Runtime 所有权。
- `GFLayeredSpriteDefinition`、`GFLayeredSpriteLayerDefinition`、`GFLayeredSpriteVariant` 与 `GFLayeredSprite2D` 构成默认关闭的 `gf.layered_sprite` 新公开 API。
- `GFInputAction.release_threshold` 是新的公开属性；`GFViewportSurfaceInputBridge` 与 `GFViewportSurfaceInputCapture` 是新的 provider-neutral 表面输入投递与回执 API。
- `GFLspWorkspaceEditAdapter` 与一次性 `GFLspWorkspaceEditPlan` 是 `gf.tool.lsp_workspace_edit` 新公开 API，只接受版本绑定、已保存的项目内 GDScript 文本修改。
- `GFArtifactWriteTransaction.make_text_entry()`、`make_bytes_entry()` 与 `make_file_entry()` 的 options/entry schema 新增精确 String `preflight_existing_sha256`；`expected_sha256` 与新字段的错误类型现在都会预检失败，旧候选名 `expected_existing_sha256` 会显式拒绝，避免调用方误把可观察复核理解成原子 compare-and-exchange。
- `GFBehaviorTree.build_debug_snapshot(node, options = {})` 新增遍历、黑板键与最终报告编码预算；节点和 Runner 调试快照新增截断与 `debug_budget` 诊断字段。
- `GFInventoryTransferTransaction`、`GFInventoryTransferResult`、`GFInventoryReadView` 与 `GFSlotInventoryModel.get_revision()` / `set_allow_growth()` 是新的 Domain Inventory 公开 API；`GFInventorySlotDefinition.can_accept()` 的 `inventory` 参数从通用 `Object` 收紧为 `GFInventoryReadView`，这是有意的破坏性 API 变更，不保留兼容重载。模型协调锁、候选替换与事件 flush 入口以及 `GFInventoryTransferPlanner` 仅为 `framework_internal` 原子提交协议。
- `GFCivilDate`、`GFCivilDateResult`、`GFCivilDateDifferenceResult`、`GFCalendarGrid` 与 `GFCalendarGridTools` 是新的纯数学日期与网格 API。
- `GFLogSink.tick(delta)`、`GFLogUtility.tick(delta)` 及内置 timed sink 覆写是新的 11.0.0 公开时间推进契约；`GFAnalyticsUtility.get_dropped_event_count()` 是新的 11.0.0 聚合丢弃观察 API。Analytics 内置 HTTP 非 2xx 失败报告新增 `response_code`，`error` 收紧为不含正文的稳定 `HTTP {status}`。
- `GFConfigAccessGenerator.build_source_with_report()` 与 `GFConfigPipelineArtifactManifest.make_source_receipt_validation_report()` 是新的 11.0.0 公开 API。Reader/Layout/Validation Stage 的内置契约版本和实现版本已升级；Stage descriptor 新增 `implementation_dependencies`。`build_table()` / `build_database()` 的表结果新增 `source_receipt`，`export_profile()` 新增 `source_validation_report`，访问器生成结果新增 input/emitted/skipped 计数与 `issues`，JSON 导出 options 新增 `max_nodes` / `max_output_bytes` 并收紧 `max_depth` 到绝对上限。
- `GFExtensionManifest` 移除七个编辑器路径公开成员；`GFExtensionSettings` 现有七个 `get_enabled_*_paths()` 签名保持不变，但只读取已验证的 Tool Contribution。内部的路径归属记录只用于让 Dock / Inspector 组合所属 manifest 的展示名、短标签与排序，不扩张公开 selection snapshot schema。
- 本轮有意移除 10.x 已公开的通用 `loop` 输入与 `current_bgm_loop` 快照字段，开发身份进入 `11.0.0-dev.0` 主版本迁移线；不提供双轨兼容分支。
- `GFAudioClip.playback_region: GFAudioPlaybackRegion` 为新的可选公开属性。
- `GFAudioBackendCapability.supports_playback_region_contract`、`GFAudioBackend.evaluate_playback_region()`、`GFAudioUtility.playback_region_rejected` 与 `GFAudioUtility.get_last_playback_region_rejection()` 为新的公开 API。
- `GFAudioUtility.start_bgm(path, options, owner)` 与 `start_bgm_clip(clip, crossfade_seconds, owner)` 返回新的 `GFBgmStartOperation`；其 `completed/get_result()` 产出闭合 `GFBgmStartResult`。只有 `STARTED` 携带规范 `GFBgmSessionHandle`；该句柄用 `stop()` 精确控制一个逻辑 Session，并以 `ended` / `EndKind` 报告唯一结束原因。既有 `play_bgm*()` 保持 void wrapper，legacy 空路径 stop 仍保留，而 typed 空路径固定拒绝。
- `GFAudioUtility.get_debug_snapshot()` 用 `current_bgm_region` 和 `last_playback_region_rejection` 描述播放区间状态，不再提供 `current_bgm_loop`。
- `GFNetworkBackend._enrich_transport_metrics()` 现在接收 `GFExecutionBudget`，属于有意的 protected 签名升级；新增 `MAX_TRANSPORT_METRICS_ENRICHMENT_MSEC`，`GFNetworkTransportMetrics` 新增总指标、自定义指标和 ID 长度绝对上限常量。`gf.network` 的 `extension_version` 因此提升到 `6.0.0`。
- `GFNetworkContractGenerator.generate_many()` 的 options 新增 `allowed_roots`、`max_contracts`、`max_messages_per_contract`、`max_fields_per_message`、`max_identifier_length`、`max_source_bytes` 与 `max_total_source_bytes`，报告新增 `plan_fingerprint`；输入定义或 canonical 输出预检失败时整个批次零写入。`GFNetworkContractAudit` 用 `warn_collection_bounds_review` 替代 `warn_unbounded_collections`，并新增 `max_contract_paths`、`max_known_channel_ids`、`max_channel_id_length`。`GFNetworkContractField.default_value` 收紧为非 null 时精确类型且 transport-safe，`allow_null=true` 的显式 null 现在优先于默认值。
- `GFArchitecture.find_model()`、`find_system()` 和 `find_utility()` 是新的公开可选解析入口。
- `GFAsyncKeyedGate.try_request_lease()`、`STATUS_BUSY` 与调试快照中的 `busy_count` 是新的公开 fail-fast 并发契约。
- `GFResourceBroker.request()` / `poll_lease()` / `pump()` / `cancel_all()` 与 `GFResourceLease` 状态、取消和释放接口是新的公开资源 admission API；`GFAssetUtility`、`GFSceneUtility`、`GFBackgroundWorkUtility` 各自新增 `set_resource_broker()`、`setup_standalone_resource_broker()` 与 `get_resource_broker()`。
- `GFObjectPoolUtility.prewarm_request_async()` 与 `prewarm_budget_request_async()` 返回新的 request-scoped `GFObjectPoolPrewarmOperation`；其 `progressed` / `completed`、精确计数和 `GFObjectPoolPrewarmResult` 公开容量部分接纳、拒绝、取消、Utility 生命周期终结、无效输入与执行失败。旧 `prewarm_async()` / `prewarm_async_budget()` 的签名、默认值和等待行为保持兼容。
- Asset、Scene 与 BackgroundWork 调试快照以 `resource_broker` 替代旧 `threaded_resource_operations` 字段；这是有意的诊断 schema 迁移，不保留 alias。
- `GFSaveProfileRequest.take_ownership(document_metadata, context, result_metadata)` 是新的公开 move-only 请求入口；`GFSaveProfileUtility.save_profile()` 现在接收 `GFSaveProfileRequest` 或 `null`，`GFSaveProfileResult.STATUS_INVALID_REQUEST` 明确表示未初始化、结构无效或重复 claim。
- `GFSaveSectionProvider.begin_save_snapshot()` / `_begin_save_snapshot()`、`make_snapshot()` 与 `make_completed_snapshot()` 替代旧同步 gather 契约；这是有意的 Provider 破坏性升级，不提供旧 gather fallback。
- `GFSaveProfileUtility.STATE_PREPARING` 替代 `STATE_GATHERING`，`GFSaveProfileResult.STATUS_PREPARATION_FAILED` 替代 `STATUS_GATHER_FAILED`，并新增 `save_preparation_work_budget_per_tick`、`save_preparation_slice_budget` 与 `save_preparation_time_budget_usec`。
- `GFSaveProfileResult.get_preparation_duration_msec()`、`get_storage_duration_msec()` 与 `get_preparation_work_units()` 分开暴露阶段诊断；Save 结果的 `get_document()` 固定返回 `null`，只有 load 结果携带文档。
- `GFStoragePayloadTransfer.take_ownership()`、`release()`、`GFStorageUtility.save_payload_request_async()`、`GFStorageAsyncOperation.reclaim_failed_payload()`、`GFStorageAsyncResult.get_write_failure_kind()` 与 `get_write_validation_report()` 构成新的显式 move / retry 契约。`gf.save` 的 `extension_version` 因此提升到 `6.0.0`。
- `GFSaveProfileTransactionCoordinator.register_profile()` / `unregister_profile()`、
  `activate_profile()`、`switch_profile()`、`bootstrap_profile()`、`adopt_profile()`、
  `mutate_and_persist()`、`reconcile_profile()`、`get_active_profile_id()` 与
  `get_domain_state_snapshot()` 是新的活动 Profile 事务 API。
- `GFSaveProfileTransactionOperation` / `GFSaveProfileTransactionResult`、
  `GFSaveProfileRecoveryLease`、`GFSaveProfileReconcileLease` /
  `GFSaveProfileReconcileRequest`、`GFSaveSectionMutation` 与
  `GFSaveProfileMutationRequest` 是新的公开 operation、result、lease 和 move-only request
  类型；它们不与普通 `GFSaveProfileOperation` / `GFSaveProfileResult` 混用。`gf.save` 因新增可选活动身份事务层并收紧受管 Profile 准入，`extension_version` 从 `6.0.0` 提升到 `6.1.0`。
- Save 扩展 Installer 现在先确保 `GFStorageUtility` 存在，再装配 Save Graph、Profile 与 Profile Transaction Coordinator；项目 Installer 不再重复拥有 Storage 注册。
- `GFSaveGraphUtility.apply_scope()`、`apply_section()`、`apply_document()` 与 `load_scope()` 的结果 schema 新增稳定字段 `rollback_failures` 与 `atomicity_restored`；`GFSaveSlotStorageAdapter.build_slot_file_plan()` 是新的公开预检 API。SaveGraph 内层版本、读取完整性、Serializer ID 与 Slot 模板的准入语义同步收紧，`gf.save` 的 `extension_version` 从 `6.1.0` 提升到 `6.2.0`。
- `GFModel`、`GFSystem`、`GFUtility` 新增 `begin_activation(GFAsyncScope) -> GFAsyncCompletion` 与 `begin_quiesce(GFAsyncScope) -> GFAsyncCompletion`。
- `GFArchitecture.init(cancellation_token = null)` 保留无参数调用形状并新增显式取消输入；新增 `activation_timeout_seconds`、`shutdown_timeout_seconds`、`is_activating()`、`is_quiescing()`、`is_accepting_runtime_work()`、`is_module_active()`、`shutdown_async()`、`get_last_shutdown_result()` 与 `shutdown_finished`。`module_async_init_timeout_seconds` 与两个新增 timeout 属性统一为有限 `0..86400` 契约，`0` 禁用 deadline；并发 init/shutdown 都由首个调用拥有共享流程策略，后续 init token 只取消自身等待，后续 shutdown 调用只复制同一终态。父级 required module/factory 由 child generation 弱租约保护；模块租约冻结相关父级模块拓扑，任一外部依赖租约都使父级正常关闭以 `ERR_BUSY` 失败。`create_instance()` 现在属于 READY 运行时准入，在 activation、热拓扑事务或 quiesce 期间不会调用 provider。依赖诊断固定复用四类 typed Hook 与真实父级解析语义，不再提供 `include_parent_lookup` / `include_factories` 行为开关。
- `GFArchitecture.unregister_model()`、`unregister_system()`、`unregister_utility()` 及 classless Autoload facade `Gf.unregister_*()` 均改为必须 `await` 且返回 `bool` 的拓扑事务；旧同步 fire-and-forget 调用不再受支持。
- 新增公开值对象 `GFArchitectureShutdownResult`；`GFNodeContext.context_ready` 的既有信号形状不变，但成功语义从第三阶段准备完成收紧为第四阶段 activation 已提交。
- `GFArchitecture.ModuleKind`、`ModuleLookupScope` 与 `resolve_module_access(module_kind, script_cls, lookup_scope, required, require_ready)` 是新的公开共享模块解析 API；`GFAccessGenerator.ACCESS_SCOPE_*`、`ACCESS_POLICIES_SETTING` 和 `gf/codegen/access_policies` 是新的生成期策略契约。
- `GFUIUtility.push_panel_async()`、`push_panel_async_with_options()`、`replace_layer_async()` 与 `replace_layer_async_with_options()` 现在返回 `GFUIPanelAsyncOperation`，并在末尾接收可选完成回调；`GFUIRouterUtility.push_route_async()` / `replace_route_async()` 的 `async_options` 支持 `owner` 与 `scope`，`GFUIRouteResult` 新增 `STATUS_INVALID_LIFECYCLE`。
- `GFVirtualInputSource.configure()` 新增可选 `GFTimerUtility`，并新增 `set_timer_utility()`、`get_timer_utility()`、`pulse_action()` 与不可逆 `dispose()`；`PulseReplacementPolicy` 在保持默认 `REPLACE` 与既有 `REJECT_NEW` 数值不变的前提下追加 `RETRIGGER`，先实际释放旧 lease 的匹配贡献再写入新 generation；`GFVirtualInputPulseOperation` 公开冻结身份、状态、取消、调试快照和匹配释放计数。
- `GFVirtualListModel.layout_changed(revision)`、`get_revision()` 与 `get_viewport_range()` 是新的公开布局观察 API；`GFVirtualListBinder.bind()` / `sync_now()` / `invalidate_items()` / `request_measurement()` / `scroll_to_item()`、生命周期入口和 `GFVirtualListSyncResult` 构成新的可回收 Control 组合契约；`GFVirtualListSyncResult.to_dict()` 的范围编码为 `{start, end_exclusive}`，物化索引编码为 `Array[int]`。
- `GFTableDataView.view_changed` 从单个 `visible_count` 参数改为 `(view_revision, visible_count)`；`set_columns()`、`set_rows()`、`set_filter_query()` 与 `refresh_view()` 现在返回 `GFTableViewRebuildResult`。移除可绕过事务的 `row_id_column`、`case_sensitive_filter` 与 `selection_model` 公共字段，改为类型化 setter/getter；新增命名谓词注册、启停、排序、查询和 revision/result API。`GFTableSelectionModel` 新增原子替换选择集合与锚点的入口；`commit_cell_value()` 与两种批量提交改为候选行事务，不再允许不可隔离行或任意 `value_setter` 走先写后刷新的部分提交路径。命名谓词不保留 Callable-only 或裸 Dictionary 入口。
- `GFSpatialCanvas2D.handle_input_event()` 与 `handle_screen_input_event()` 的返回类型从 `bool` 改为命名的 `InputDisposition` 枚举；新增 `set_input_policy()` / `get_input_policy()`、`GFSpatialCanvasInputPolicy` 与 `GFSpatialCanvasSelectionModeBinding`。滚轮轴、滚轮路由、触摸主行为分别使用各自的命名枚举；`TouchPrimaryBehavior.NONE` 显式关闭单指行为，`touch_multi_pan_enabled` 与 `touch_multi_zoom_enabled` 独立控制 raw 多指视图分量。策略默认选择、嵌套 modifier binding、公开选择入口和捕获状态共同使用唯一的 `GFSpatialCanvas2D.SelectionMode` 类型。
- `GFEditorCommand` 新增 protected `_get_undo_context()` / `_get_undo_targets()`；`GFGeneratedArtifactReport` 报告新增 `conflict` 与 `expected_previous_sha256`，`save_text()` 新增同名基线选项。
- `GFTemplateGenerationManifest` 新增 `MAX_JSON_BYTES` / `MAX_JSON_DEPTH`，`GFThumbnailRenderer` 新增 `MAX_TARGET_DIMENSION` / `MAX_TARGET_PIXELS` / `MAX_PENDING_TASKS`。
- `GFExtensionSelectionDiscovery` 新增 `STATUS_VALID`、`STATUS_PARTIAL`、`STATUS_INVALID`；selection snapshot 与 `GFExtensionSettings.get_extension_selection_report()` 新增 `status`、`partial`、`paths_allowed` 和 `tool_contribution_errors`。
- `GFExtensionUsageAudit` 新增 `find_references_to_root_report()`；审计报告新增 `candidate_file_count`、`issues` 与 `class_name_scan`，原 `find_references_to_root()` 保留为只返回引用数组的便利入口。
- `GFExtensionCatalog.load_extension_manifests()`、`load_all_manifests()` 与 `load_manifests_in()` 新增可选 JSON 预算参数；`GFExtensionSelectionDiscovery` 的 snapshot/signature options 同步支持这些预算。
- `GFVariantJsonCodec` 编解码 options 新增 `max_depth`、`max_nodes`、`max_collection_items`，解码另新增 `traversal_limit`；`GFVariantData.diff_variant()` options 新增同名遍历预算，返回报告新增 `complete`、`traversal_truncated`、`traversal_reason`、访问计数与预算字段。
- `GFConfigTableQuery.values(path = "", duplicate_values = true)` 新增可选 `duplicate_values` 参数；默认返回隔离副本，传 `false` 才保留内部值别名。
- `GFMutationBatch.get_debug_snapshot()` 新增 `transition_state`；重入 commit/rollback 的失败摘要新增 `error` 与 `transition_state`。`GFCacheDiagnostics.get_debug_snapshot()` 新增 `counter_saturated`。
- `GFTagExpression.get_match_report()` 新增 `valid`、`matched` 与 `invalid_indices`；显式未知 operator 和超过 32 层的直接表达式图不再按默认查询继续匹配。
- `GFActivationTransaction` 报告新增 `transition_state`；终态 prepare 返回 `transaction_not_reusable`，in-flight 嵌套操作返回 `transition_in_progress`，这些临时拒绝不会污染事务已提交的持久报告。
- `GFInputMappingUtility` 新增 `get_virtual_source_snapshot_for_player()`；`GFInputDeviceUtility.get_assignment()` 现在与复数/active getter 一致返回隔离副本。`GFVirtualInputSource.source_id`、`player_index` 与 `configure()` 在身份迁移前释放该 handle 追踪的旧贡献。
- `GFInputDetector` 现在保证 begin-to-finish 的有限 elapsed 与重入时 latest-started-wins；`GFInputPlayback.event_applied` 改为 commit-before-notify，生命周期回调会使旧 tick 失效。`GFInputDeadzoneModifier` 的 equal-threshold 定义为阶跃，player-scoped Chord/Sequence 缺玩家协议时不再回落全局查询。
- `GFInputMappingDock` 新增 `set_remap_config(config: GFInputRemapConfig)` 与 `get_remap_config()`；诊断报告新增 `remap_configured`。`GFInputRemapConfig` 的公开 mutation 方法现在发出 `Resource.changed`。
- `GFDragDropUtility.drop()` 新增稳定拒绝原因 `session_resolving`、`session_cancelled` 与 `drop_zone_changed`；callback `ok=false` 仍保留活动会话，`no_drop_zone` 仍为终态。候选查询在 callback 结束 session 时返回空数组/null；`GFDragDropController.start_drag()` 在 started 回调同步结束会话时返回 `-1`。
- `GFDragDropController` 的 started/terminal signal 可观察顺序已收紧为 post-commit / post-cleanup；没有修改 signal 或方法签名。`GFTouchButton` / `GFTouchJoystick` 的公开 export 签名不变，但活动手势不再读取中途改写后的 output identity。
- `GFJobQueueUtility` 新增 `max_cancelled_jobs`，`get_debug_snapshot()` 新增 `cancelled_count`；`GFAssetHandle` 新增框架内部不可变 lease identity 查询，`setup_from_utility()` 增加内部 cache key 参数。
- `GFAudioUtility` 新增 `max_idle_ambient_players`，调试快照新增 cached/idle/max Ambient cache 计数；池化 SFX 的公开签名不变，但复用前恢复的框架基线更完整。
- `GFAudioMetadataTools` 新增 `DEFAULT_MAX_ID3_BYTES` / `ABSOLUTE_MAX_ID3_BYTES`；ID3 report 新增 partial、flags、unsupported features、requested/effective/absolute limit、clamp 与读取/处理字节字段。
- `GFAudioBankTools` 新增 `DEFAULT_MAX_SCANNED_ENTRIES`、`ABSOLUTE_MAX_SCAN_DEPTH`、`ABSOLUTE_MAX_AUDIO_PATHS`、`ABSOLUTE_MAX_SCANNED_ENTRIES`，扫描 options 新增 `max_scanned_entries`；三个扫描预算的 0/负数语义已明确。
- `GFAudioPitchAnalysisTools` 在预算不足时新增 `insufficient_operation_budget`，报告新增 caller budget 与 minimum required operations；`GFAudioLibraryTools.copy_import_plan()` 报告新增执行期 consumed/committed byte 与 recovery 状态。
- `GFInventoryOperationResult.success()` 现在只把正数量标记为成功；`GFSlotInventoryModel.swap_slots()` / `sort_slots()` 会对规划后的目标布局执行槽位接收校验并可能原子返回 `false`。`GFQuestUtility.quest_started` 明确为状态与正目标事件订阅均已提交后的信号；`GFLevelUtility.complete_current_level(..., unlock_next=false)` 只关闭目录顺序相邻解锁，不关闭 `GFLevelEntry.unlocks_on_complete`。
- `GFHapticUtility.get_last_output_report()` 是新的公开 API；输出报告新增 `rejected_count` / `rejected`。`play_haptic*()` 的正 ID 明确表示逻辑排程而非物理接受；`haptic_backend` 必须同时提供 start/stop，`output_handler` 与 `stop_handler` 必须成对配置。输出持续时间现在始终为有限正数，0、负数或非有限显式值回退到有限 refresh。`gf.feedback` 的 `extension_version` 因此提升到 `4.0.0`。
- `GFFlowRunner.is_running` 变为只读观察状态，写入会产生稳定错误；`signal_timeout_seconds` 只接受有限配置，非有限值回退到 30 秒。缺失节点从“计数后继续并可能 completed”收紧为 `aborted / missing_node`。`GFFlowContext.restore_runtime_snapshot()` / `deserialize_runtime_state()` 和 `GFFlowGraph.deserialize_runtime_state()` 采用完整预检与原子失败语义；新增框架内部 `get_node_runtime_state_snapshot()` / `replace_node_runtime_state()`。`GFFlowGraphEditorModel.include_invalid_connections` 现在按完整结构校验定义。`gf.flow` 的 `extension_version` 因此提升到 `3.0.0`。
- `GFInteractions.is_method_call_compatible_for_framework()` 是新的框架内部动态协议预检入口。Interaction 的公开方法和信号签名不变，但失效 validator、非法 sender/provider/receiver 协议、Area 非法返回和 Pointer 多按钮的运行时语义均已收紧；`gf.interaction` 的 `extension_version` 因此提升到 `3.0.0`。
- `GFNetworkSnapshot.make_patch_to()` 会把 `max_depth` 限制到 8，并以 `patch_operation_budget_exceeded` / `generated_patch_not_applicable` 显式拒绝 applicator 无法接受的成功候选。`GFNetworkServiceDiscovery.now_seconds` 只影响记录时间；`GFFixedTickClock.advance()` / `step_once()` 在同实例 signal 重入时无副作用返回。公开签名不变，`gf.network` 的 `extension_version` 提升到 `7.0.0`。
- Physics 公开签名不变；`GFGravityProbe3D.sample()` / `sample_fields()` / `sample_field_provider()` 现在冻结入口查询状态并在同实例同步重入时返回零，全部重力/浮力公开向量保持有限。该运行语义收紧使 `gf.physics` 的 `extension_version` 提升到 `2.0.0`。
- TurnBased 公开签名不变；`GFTurnFlowSystem.stop(true)` 现在对 stopped/恢复中队列执行幂等且可升级的清理，`GFTurnContext.get_actor_value()` 只调用接受两个兼容实参的 duck method。默认 non-finite 排序与自定义 comparator 的合同已写明，`gf.turn_based` 的 `extension_version` 从 `2.0.0` 提升到 `2.0.1`。

### 📘 升级指南 (Migration Guide)

1. 删除传给 `play_bgm_with_options()` 或事件 metadata/options 的 `loop` / `playback_region` 字段。
2. 创建 `GFAudioPlaybackRegion`，按需填写 `start_seconds`、`end_seconds`、`loop_mode` 和 `loop_start_seconds`，再赋给 `GFAudioClip.playback_region` 并调用对应 `play_*_clip()`。
3. 自定义后端若要接管任何带 `playback_region` 的片段，应声明 `supports_playback_region_contract`，并以无副作用方式实现逐请求 `evaluate_playback_region()`；不能精确执行时返回 `UNSUPPORTED`。
4. 将调试面板中的 `current_bgm_loop` 读取迁移到 `current_bgm_region`。
5. 自定义 `GFNetworkBackend` 将 `_enrich_transport_metrics(metrics)` 改为 `_enrich_transport_metrics(metrics, budget)`；每次尝试新增可选指标前调用 `budget.consume_steps()`，并在预算或 `metrics.set_metric()` 返回 false 时立即停止。Hook 只能读取有界内存状态，不得执行网络、磁盘、锁等待或项目业务 I/O。
6. 把 `save_profile(profile_id, metadata, context)` 改为 `save_profile(profile_id, GFSaveProfileRequest.take_ownership(document_metadata, context, result_metadata))`；Request 创建成功后立即放弃三个输入字典及全部嵌套 alias。无参数保存继续传 `null` 或省略第二个参数。
7. 将 `STATUS_GATHER_FAILED` 判断替换为 `STATUS_PREPARATION_FAILED`；旧常量与字符串值均已移除。
8. 将 Save Provider 的 `_gather_section()` 改为 `_begin_save_snapshot()`：固定且很小的独占载荷可返回 `make_completed_snapshot()`；大型载荷应返回自定义 `GFSaveSectionSnapshotOperation`，并在每次 `_advance_snapshot(step_budget)` 中只消费有界 work units。
9. 启用读取的 Save Provider 必须单独实现 `_capture_section()`，不能再依赖保存采集回退；将状态检查中的 `STATE_GATHERING` 替换为 `STATE_PREPARING`。
10. Snapshot 或 `GFStoragePayloadTransfer` 完成逻辑 move 后，立即放弃源 payload、metadata 及全部嵌套集合 alias。自定义重试只复用 `reclaim_failed_payload()` 返回的同一个 transfer，并在整个 generation 结束后调用 `release()`。
11. 不再从 Save 的 `GFSaveProfileResult.get_document()` 读取文档；Save 诊断改用 generation、request IDs、准备/Storage 耗时、work units 和校验报告。需要完整文档时只读取 load 结果。
12. Architecture 项目在 Asset、Scene 或 BackgroundWork Utility 之前注册一个共享 `GFResourceBroker`；独立 Utility 调用 `setup_standalone_resource_broker()`，多个独立消费者则创建同一个 Broker 并分别调用 `set_resource_broker()`。
13. 将诊断面板中的 `threaded_resource_operations` 读取迁移到 `resource_broker`，并按 active、pending、draining 与 admission 预算字段展示共享状态。
14. 将过去在 `ready()` 中启动异步运行期工作的模块迁移到 `begin_activation(scope)`，立即返回非空 `GFAsyncCompletion`，并把 callback、Signal 或 Operation 的唯一终态桥接为 succeed/fail/cancel；不要手动 pump Architecture tick。
15. 为模块补全 `get_required_models()`、`get_required_systems()`、`get_required_utilities()`、`get_required_factories()` 声明并消除本地依赖环；删除聚合依赖 Hook、诊断 include 开关以及对 `fail_on_missing_declared_dependencies` 与 `module_lifecycle_max_stage_passes` 的赋值，把初始化 Hook 中的固定模块注册移回 Installer。修复 stale alias 或用显式 alias 消除本地 assignable 歧义，不能依赖父级结果掩盖错误装配。
16. 先启动父 Architecture、再初始化 child，并在关闭时反序执行以保证 parent outlive child；父级 required module 只有在父 Architecture 已 READY 且模块 ACTIVE 时才满足。活动 child 的外部模块依赖租约会冻结相关父级模块拓扑，任一外部依赖租约都会使父级正常关闭返回失败；先关闭 child 再重试。不要用同步 `dispose()` 绕过该顺序，除非正在执行无法等待的灾难收敛。正常应用退出、主运行域替换和数据关键的局部 Context 关闭改为 `await architecture.shutdown_async()` 并检查 typed result；只在无法等待的 SceneTree teardown 保留同步 `dispose()`。将三个 lifecycle timeout 属性迁移为有限 `0..86400`，用 `0` 禁用 deadline；per-call shutdown 仅用 `-1.0` 表示读取属性默认值。shutdown deadline 约束 cooperative quiesce 与异步等待，最终同步释放不能强杀 Godot Thread，因此不承诺墙钟硬上限。
17. READY 后需要改变模块集合时 `await` 对应 register/replace/unregister 事务并检查 `bool`；register/replace 候选在 stage4 成功和原子提交前不可见，失败后不得复用。需要改变 factory 或 alias 拓扑时构建新的 candidate Architecture，不在活动架构上维护兼容分支。
18. 将 `Gf.unregister_model()`、`Gf.unregister_system()` 与 `Gf.unregister_utility()` 的调用改为 `await` 并检查 `bool`；不要依赖旧的同步注销时序。
19. 启用 Save 扩展的项目删除项目 Installer 中重复的 `GFStorageUtility` 注册；需要调整参数时取回扩展已安装实例并配置，需要替换实现时显式调用 `replace_utility()`。
20. 不再在 Installer、`init()`、`ready()` 或 activation 中调用 `create_instance()` 触发工厂副作用；装配期改用 `has_factory()` / `get_required_factories()` 校验，只有 Architecture 提交 READY 且无热拓扑事务后才创建运行时对象。
21. 需要活动槽位或账号身份的项目，把 Profile 注册从 `GFSaveProfileUtility` 迁移到
    `GFSaveProfileTransactionCoordinator.register_profile()`；只让完全相同且顺序一致的
    Provider 实例共享一个 domain，消除部分重叠和重排拓扑。
22. 把 activation 中直接 `load_profile()` 的恢复改为 `activate_profile()`。收到 missing
    Recovery Lease 后由项目确认再调用 `bootstrap_profile()`；收到 corrupt Lease 后先执行
    项目备份/确认政策，再调用 `adopt_profile()`。不要用 `ACTION_USE_CURRENT_STATE` 发布身份。
23. 把项目手写的 flush-source/load-target 切换改为 `switch_profile()`，并以
    `GFSaveProfileTransactionResult` 判断 source flush、target load、rollback 和活动身份终态。
24. 需要“修改后必须持久化”的 section 流程改为构造 `GFSaveSectionMutation` 清单，通过
    `GFSaveProfileMutationRequest` 提交 `mutate_and_persist()`；成功 claim 后放弃请求与候选
    payload 的全部 alias，不再在写失败后自行追加补偿保存。
25. 事务返回 `outcome_unknown` 时停止该 domain 的后续工作，并以结果中的
    `GFSaveProfileReconcileLease` 调用 `reconcile_profile()`；waiting 状态会返回
    `reconcile_pending` 且不 claim Request。lease ready 后用同一 lease 与
    `GFSaveProfileReconcileRequest` 重试，等待严格重读和应用成功；不要用直接 load/save
    绕过 fence，也不要把迟到成功当成原 switch 会自动继续目标。
26. 若项目依赖生成访问器的本地/父级、必需性或 ready 语义，在 `gf/codegen/access_policies` 中按精确 `res://` 模块脚本路径声明策略并重新生成；删除未知、重复或已失配路径，生成器会整批失败关闭而不保留部分源码。
27. 把依赖全局 `panel_async_load_finished` 识别单次请求的代码迁移到异步 UI 方法返回的 `GFUIPanelAsyncOperation` 或完成回调；全局信号只用于无身份遥测。Route 调用若需要生命周期绑定，在 options 中传有效 owner 和/或未完成的 `GFAsyncScope`。
28. 需要短时虚拟动作时，为 `GFVirtualInputSource` 注入共享 `GFTimerUtility` 并调用 `pulse_action()`；用返回句柄观察终态，不自行安排延迟 `clear_action()`。既有调用仍默认使用 `REPLACE`：连续 hold 选择 `REPLACE`，重复离散激活选择 `RETRIGGER`，需要保留当前脉冲时选择 `REJECT_NEW`。原先手工组合 `clear_action()` 与 `pulse_action()` 的适配器可迁移到 `RETRIGGER`；若业务要求新的聚合 `just_started`，必须确保没有其他 source、设备或绑定让同一动作持续活跃。Source 与 Mapping 关闭后不得复用。
29. 大型列表把项目 `ScrollContainer` 的直接子内容根、行工厂、bind/unbind、稳定 identity 和 owner 交给 `GFVirtualListBinder`；内容根不能是接管子节点位置的 `Container`。排序、过滤或数据内容提交后显式调用 `invalidate_items()`，只使用稳定且有界的标量 identity；若在 Binder callback 内失效，当前结果会是非成功 `STATUS_DEFERRED`，副作用已开始时 active 可被安全清空，调用方应以结果索引为准等待下一轮重建。需要切换 `layout_axis`、`fill_cross_axis`、`auto_measure` 或 callback 内的预算时，先更新配置并调用 `request_sync()`，当前同步轮仍使用入口快照，下一轮才采用新值。`scroll_to_item()` 返回 `false` 表示操作快照或最终整数偏移未能完整提交，调用方不要把它当作部分成功。Binder 会按每段轴所有权恢复接管前的最小尺寸。owner 退出前让 Binder 自动或显式 `dispose()`，不得重挂载或释放 Binder-owned Control。
30. 表格结构化过滤改为继承 `GFTableRowPredicate`，返回 `GFTableRowPredicateResult`，再用 `GFTableRowPredicateRegistration.create()` 批量事务注册。将 `row_id_column`、`case_sensitive_filter` 与 `selection_model` 直接赋值迁移到 `set_row_id_column()`、`set_filter_case_sensitive()` 与 `set_selection_model()`，并通过 getter 读取已提交配置。更新所有 `view_changed` 连接以接收 revision 与 visible count；只有 rebuild result 成功且 committed，或收到 `view_changed` 时，才更新 VirtualList count 与 Binder identity，失败时继续展示上一份已提交投影。谓词实例的项目参数改变后显式调用 `refresh_view()`，不要依赖框架观察任意成员写入。经 `GFTableDataView.commit_cell_value()` 或批量入口写入的行必须可安全隔离；把带任意副作用的 `value_setter` 移到项目事务层，提交完成后再用新的 source 行调用 `set_rows()`。
31. Spatial Canvas 输入转发改为检查 `InputDisposition`：只有 `CONSUMED` 才停止项目路由。创建并校验 `GFSpatialCanvasInputPolicy` 来替代硬编码按键；嵌套滚动界面用 modifier-gated 或 parent-only wheel，让未匹配滚轮继续 GUI 冒泡。需要禁用单指时使用 `TouchPrimaryBehavior.NONE`，并分别决定 raw 多指 pan 与 pinch zoom；若二者也都关闭，首触点不会被 Canvas 捕获。取消行为使用只含非指针事件的项目 InputMap action，不得与鼠标、触摸或位置手势复用；项目运行时修改 InputMap 后，超出事件预算或变成指针映射的取消 action 会失败关闭。
32. 删除对 `GFStorageUtility.allow_absolute_paths`、`create_directories_for_nested_paths`、`get_storage_directory_path()` 与 `ensure_directory()` 的使用。把文件名改为原样 canonical 的小写 ASCII logical path；不要传反斜杠、大写、Unicode、空段、`.` / `..`、设备名或 `.json` 形式的扩展过滤器。项目维护的编辑器或离线迁移工具若需要任意外部路径，直接在工具层使用 `FileAccess` / `DirAccess`，不要向 runtime Utility 重新注入绝对路径能力。存在性检查改用 `has_file()`，枚举改用 catalog-backed `list_files()`。在 activation、`init()` 或首次 I/O 前完成 `save_dir_name` 配置；root 冻结后需要切换时创建新的 Utility。把槽位 UI 对 `list_slots().modified_time` 的解释改为 metadata `updated_at_unix` 的领域更新时间，缺失值按 `0` 处理。旧 root 可见文件不能自动迁移；先用版本锁定的离线/编辑器工具验证旧 final 与 sidecar 所有权，再通过新 Storage API 重写。每个 Storage root 只保留一个活动 writer Utility/进程；当前没有跨 Utility/进程 lease。私有 namespace 是 GF 公共寻址与所有权边界，不是抵御同进程 `FileAccess`、symlink、junction 或 mount 重定向的安全沙箱。
33. 读取扩展选择诊断的项目工具改为检查 `status` 与 `paths_allowed`；如需展示工具贡献错误，同时读取 `tool_contribution_errors`。
34. 依赖“未发现禁用扩展引用”作安全判断的工具改用 `GFExtensionUsageAudit.find_references_to_root_report()`，并在 `ok=false` 或 `partial_scan=true` 时失败关闭。
35. 检查传给 `GFTimeUtility`、`GFTimerUtility` 和相关调度入口的秒数来源；`NaN` 与无穷不再进入状态或形成 pending timer，应在项目输入边界修正数据并处理返回 `0`。
36. 如果对象池 hook 会重入同一对象池，不要在 hook 返回后继续假定对象仍由外层调用持有；以 acquire/release 的最终返回值和对象池快照为准。
37. 如果依赖延后修改 `GFObjectCandidateRegistry.max_candidates` 而不立即淘汰，请在写入前迁移候选或调整调用顺序；新行为会同步保留最新注册记录并移除最旧记录。
38. 不要在 `GFValueIndex` mutation signal 或 `GFMutationBatch` commit/rollback transition 内同步修改同一实例；检查布尔/摘要失败结果，并在当前调用返回后或 deferred 阶段开始下一次 mutation。
39. 对 `GFBudgetLedger.consume()` 处理新增的 `precision_loss` 拒绝；离散配额应统一为足以在目标容量量级表达的最小单位。
40. 若消费 `GFTagExpression` 的详细报告，把 `valid=false` 与合法的 `matched=false` 分开处理；修正含未知 operator、非法子 Resource、循环或超过 32 层嵌套的项目数据。
41. 不要在 `GFActivationTransaction` 回调内同步 prepare/commit/rollback/clear 同一实例；在外层调用返回后开启下一次事务。apply 可能在返回失败前产生部分副作用时，当前仍由 callback 自行恢复。
42. 将 `GFByteCursor.max_read_byte_count` / `max_write_byte_count` 视为一次公开字段操作的 prefix + payload 总预算，而不是整条消息容量。调用 void 写入方法后若需要判断失败，应在任何后续游标操作前立即读取 `get_last_error()`；后续成功会按“最近操作”语义将其重置为 `OK`。
43. 不要通过 `get_assignment()` 返回的 Resource 原地修改设备归属，改用 `set_assignment()`；运行时降低 `max_players` 会立即撤销越界席位。虚拟源身份改写现在会释放旧贡献，若项目需要同时保留两组身份，应创建两个独立 source handle。
44. `GFInputPlayback.event_applied` handler 可以同步 stop/start/reset/seek，但不要在 handler 返回后继续假定旧 tick 会处理同时间的剩余事件；切换 recording/source 应调用 `start()`。如果项目曾把 equal Deadzone 当作“禁用全部输入”，请改用显式禁用逻辑；相等阈值现在表示达到边界即满幅。
45. 拖放 signal handler 可以同步取消或开始下一会话，但应按 post-commit / post-cleanup 状态读取 controller；处理 `drop()` 结果时接受新增的 resolving/cancelled/zone-changed reason。若直接调用 `get_utility()` 返回的 live backend，需自行承担绕过 pointer façade 的 authority 风险。
46. 活动触屏 gesture 中修改 action、joypad device/control 或 position mode 时，不要期待当前 gesture 迁移到新配置；先 `release()` 再修改可立即切换，否则新配置从下一次 gesture 生效。调用 Godot 原生 `set_process_input(false)` 前必须显式 `release()`。
47. 多个虚拟触屏玩家必须给每套控件配置不同的负 joypad device ID，并用 `GFInputDeviceUtility.set_assignment()` 显式绑定席位；默认 `-2` 只代表一个共享虚拟设备。
48. 下载清单把绝对 `target_path` 改为相对 `target_root`；把 `expected_size` 只用于进度，完整性要求改用 SHA-256。若依赖无限取消历史，显式提高 `max_cancelled_jobs`，但生产配置仍应保持有界。
49. 若音频扫描曾用 `max_scan_depth=0` 或 `max_audio_paths=0` 表示真正无限，现在它们表示请求框架绝对上限；需要控制高扇出目录时同时设置 `max_scanned_entries`。symbolic-link 素材应在受信预处理阶段展开，默认扫描不再跟随 DirAccess 可识别链接。
50. 将 `max_correlation_operations` 当作严格预算并处理 `insufficient_operation_budget`；窗口不足一个完整 lag 时应降低 sample window 或提高预算，而不是期待框架静默超额。
51. 检查依赖复杂 ID3 header feature 或大于 8 MiB tag 的导入流程；通用 metadata 工具现在显式返回 unsupported/partial，应改用专门解析器。素材导入目录仍必须是可信单写者目录，词法 `target_root` 与应用级 sidecar recovery 不构成抗 junction/TOCTOU 的 OS sandbox；每个 target 的 `.gf-copy.tmp` / `.gf-copy.backup` 精确名称现在属于事务保留命名空间，外部 writer 不得复用。
52. 若旧代码有意通过修改 `GFConfigTableQuery.values()` 返回的 Dictionary/Array 来改写 Query 内部记录，请改为显式 `values(path, false)`，或更推荐在进入 Query 前修改权威记录并重新构建查询。直接 `GFConfigTableImporter` 与递归 Config merge 当前只接受已完成项目容量预检的有限输入；Config Pipeline 的 64 MiB 文件预算不等于行/单元格/节点工作预算。
53. 检查 Domain 调用方：不要用 `success()` 表达零数量 no-op；处理 `swap_slots()` / `sort_slots()` 的 `false` 结果；把 `quest_started` 监听器按 post-commit 语义编写。若要关闭条目声明的关卡解锁，修改 `GFLevelEntry.unlocks_on_complete`，不要把 `unlock_next=false` 当作关闭全部解锁规则。Domain 裸 Dictionary 快照是当前版本的 Godot Variant 数据图；跨版本或 JSON 持久化应在项目层增加版本 envelope、迁移与目标编码校验。
54. 检查 Feedback 集成：为自定义 haptic backend 同时实现 start/stop，或成对设置 output/stop handler；用 `apply_current_outputs()` / `get_last_output_report()` 的 `rejected` 判断物理接受，不再把正播放 ID 当作设备成功。若旧配置用 0 表示无限震动，改为项目拥有的显式 session 与 stop policy；`auto_apply_on_tick=false` 仍会让 stop/clear 立即撤销输出。非空但全部 disabled 的 shake tracks 现在输出零，只有清空 tracks 才使用 legacy 字段。多个 receiver 不要共享同一 transform 的完整基准恢复权。
55. 检查 Flow 集成：不要写入 `GFFlowRunner.is_running`，取消改用 `cancel()`；把缺失起点/动态后继按 `aborted / missing_node` 处理；只向 Context 恢复入口传完整原始 Variant 快照，不要直接回灌 JSON-safe 诊断 marker；在恢复或清空 Graph 运行态前等待全部节点执行租约释放。若项目依赖编辑器隐藏某类无效连接，显式读取 `valid` / `invalid_reasons`，不要把 `include_invalid_connections` 当作仅过滤缺失节点的开关。
56. 检查 Interaction 集成：让 `set_interaction_context(context)`、`get_candidate_objects(options)`、`send_to(receiver, payload_override, interaction_id_override)` 和 `receive_interaction(context, interaction_id)` 的参数数量与类型精确匹配公开协议；同名不兼容方法现在会被拒绝或安全回退。若要撤销 Receiver 校验器，显式赋值 `Callable()`；不要依赖 validator owner 释放恢复默认允许。自定义 sender 必须返回非空 Dictionary，但调用方也应处理框架生成的 `invalid_report`。Pointer 项目若同时使用多个按钮、设备或窗口，应按每个 click signal 独立处理，不再依赖单 active button 的旧隐式行为。
57. 检查 Network 集成：调用 `make_patch_to()` 后先检查 `ok`，并处理 `patch_operation_budget_exceeded` / `generated_patch_not_applicable`；不要依赖大于 8 的 path 深度生成不可应用 patch。`now_seconds` 只用于服务记录时间，TTL 必须由持续 `tick(delta)` 推进。Fixed-tick listener 不要重入同一 clock 的推进，也不要在同步 tick signal 中直接 reset/configure/恢复或写状态；把变更意图延后到外层推进返回后。
58. 检查 Physics 自定义 field/provider：回调中修改 Probe 的位置、组合模式、fallback 或分组只会影响下一次采样；不要依赖同步重入同一 Probe 获取中间结果。duck provider 同帧修改私有状态后调用 `invalidate_cache()` 或关闭缓存。处理 SUM/HIGHEST_PRIORITY 的零向量失败关闭结果，不要把它解释为可继续施力的溢出值；如需 lockstep，项目应先固定候选顺序并使用自己的确定性数值方案。
59. 检查所有 SaveGraph apply/load 调用：失败时除 `ok` / `errors` 外读取 `atomicity_restored`；为 `false` 时停止使用可能部分提交的场景状态，并按项目恢复策略消费 `rollback_failures`。不要依赖 `include_pipeline_trace` 才发现回滚失败，也不要在 Source callback 内同步重入同一个 Utility。
60. 修正自定义 SaveGraph payload 的 `format_version` 为精确当前整数，并保证同一 `GFPersistPropertiesSource` 的 property、local 与 registry Serializer ID 唯一；已记录 pipeline error 的采集现在整体失败，调用方不得把空 payload 当作成功快照。
61. 自定义槽位模板在保存或同步前调用 `build_slot_file_plan()` 并处理失败；两个模板都必须含 `{index}`、原样满足 portable logical identity 规则，且 data/metadata target 不能相同。自定义 Storage 若返回 `ok=true` 与 `IntegrityStatus.INVALID`，Graph/Slot 读取入口现在仍会拒绝该结果。
62. TurnBased teardown 可重复调用 `stop(true)` 清理并封存队列，不必在 stopped 状态另调 `clear_actions()`；自定义 action comparator 改为无副作用的确定严格弱序，并显式处理 non-finite/平局。为 phase 的 timer/动画/网络 completion 在 stop/timeout 时断开旧回调，不要让 context-only `finish(context)` 跨同 Context restart；同一可变 Context 也不要同时交给两个 Flow System。
63. 自定义 Config Pipeline Stage 在 descriptor 中列出所有会影响输出的 `implementation_dependencies`，并把 Reader/Layout 输入输出契约迁移到 `reader_result@2` / `layout_result@2`。消费访问器报告时改用 `emitted_schema_count` 判断实际发射数并处理 `issues`；消费导出报告时检查 `source_validation_report`。JSON 导出的项目上限改用 `max_depth`、`max_nodes`、`max_output_bytes` 收紧框架默认值，不要再用零或负数表达无界。批量产物路径统一改为显式 `res://` 或 `user://`。
64. 自定义 `GFLogSink` 若有依赖时间的缓冲行为，覆写 `tick(delta)`；脱离 Architecture 单独使用 `GFLogUtility` 时，由项目每帧显式调用 `tick(delta)`。不要再依赖“下一条日志”触发非零 interval。
65. 若项目从主 `.log` 路径自行推导默认 JSONL 文件名，改为调用 `GFJsonLineLogSink.get_file_path()`；需要跨实例稳定路径时显式设置 `file_path`，并保证目标只有一个活动写入者。
66. 清理自定义 Analytics Header 中的非法 token 名、控制字符、首尾空白、大小写重复名和超预算字段；不要依赖不同 HTTP 后端替框架做不一致的兜底校验。
67. 非 2xx 处理改为读取结构化 `response_code`，不要从 `error` 解析或展示服务端正文；用 `get_dropped_event_count()` 监控队列裁剪，并注意 `max_queue_size` 只限制事件条数。
68. 需要在编辑器中核对玩家/profile 覆盖时，把对应 `GFInputRemapConfig` 传给 `GFInputMappingDock.set_remap_config()`；直接修改其嵌套 Dictionary 后应显式调用 `emit_changed()`，优先使用公开 mutation 方法。context/remap 的自动刷新延迟到同帧末尾合并；需要立即结果时显式调用 `refresh()`。失败路径加载后的复制 schema 现在是带 `current_attempt` 与 `last_successful_report` 的 envelope。
69. 检查 Project Layout 调用：修正拼错或类型错误的 options，把所有由 Godot 执行的 `roots`、`include`、`exclude`、`allowed_files` 和 Feature 子目录字段改为字符串数组。相对路径统一为无前导 `/`、反斜杠、协议、盘符或 `..` 的规范形式；zone 扩展名字段及 rule `paths` / `any` / `extensions` 当前只在维护侧有语义，不要把 Godot 接受它们误判为约束已执行。
70. 检查团队维护的自定义 registry v2：删除未知字段，为每个具体 package 补齐非空 `archive`、完整 SHA-256 和正整数 `size_bytes`；preset 只保留闭合的 preset 字段并让 `dependencies` / `paths` 为空。批量卸载如果要同时移除 depender 与手动 pin 的 dependency，应在同一条 `uninstall` 命令中列出；任何未包含在请求集合中的 depender 仍会阻止 dependency 移除。
71. 检查 Network Contract 工具链：把 `warn_unbounded_collections` 改为 `warn_collection_bounds_review`，并在项目 schema、serializer 或入站 validator 中真正执行集合限制；修正所有与 `value_type` 不精确匹配或非 transport-safe 的非空默认值。批量生成先比较 dry-run/commit 的 `plan_fingerprint`，处理 `duplicate_output_path`、`generation_budget_exceeded` 与 `invalid_contract_definition`；要求不可预期 I/O 失败也整批回滚的流水线暂时应在外层提供事务边界，不要把当前逐文件提交误当作 batch atomic。
72. 迁移参考工程同步命令：删除固定 source 参数，把 `--project` 改为 `--project-root`、`--dry-run` 改为 `--plan`，并移除 `--no-clean`；无操作参数现在等价于只读 `--check`，任何写入都必须显式使用 `--apply`。机器消费者同时迁移到 JSON schema v2：用 `operation` 取代 `dry_run`，用 `planned_actions` / `applied_actions` 取代 `cleaned` / `linked`，用 `file_count` / `directory_count` / `total_bytes` 取代旧复数计数字段，用 `skipped_count` 取代 `skipped`，并以 `payload_sha256` 绑定本次同步输入；检查结果另用 `target_mode`、`mismatch_count` 与 `mismatches` 判断目标状态。
73. 只需要物理完成的 Storage 调用可以继续等待 `completed` 并读取 `get_result()`；需要 owner、取消或 timeout 边界时，改为用 `GFStorageAsyncRequestOptions.create()` 构造选项并等待 `caller_completed` 或查询 `get_caller_result()`。不要把 caller 的 `OUTCOME_UNKNOWN` 当作磁盘取消，也不要在该终态提前结束 payload transfer attempt；继续通过同一 Operation 收集物理终态并按项目策略对账。严格解析 `GFStorageAsyncResult.to_dict()` 的代码必须在 11.0 schema 中加入 `settlement_kind`，并把 `CANCELLED` / `ERR_SKIP` 视为未接纳物理工作，而不是 read/write/delete 领域失败。
74. 既有 fire-and-forget BGM 调用可以继续使用 `play_bgm*()`；需要可靠终态时迁移到 `start_bgm()` / `start_bgm_clip()`，先查询 Operation 是否同步完成，再连接一次性 `completed`。只有 `STARTED` 才读取 `get_session_handle()`；后续停止该精确会话时使用 handle，不要缓存或推断内部播放器。把“发起请求即视为成功”的逻辑改为检查 status、reason 与 backend disposition。本地 standby 或 backend 接受前的候选失败/取消会保留旧 Session；backend 已接受后的身份失效只能 best-effort 补偿，调用方还应处理旧 backend-owned Session 的 `PLAYBACK_FAILED`。
75. 检查全部既有模拟量 `GFInputAction` 资源：若要保留旧单阈值语义，把两个正阈值设为相同值；若要采用迟滞，则把 `release_threshold` 设为更低的有限 `0.0..1.0` 值。`release_threshold = 0` 仍会在精确中立值释放。尤其是 `activation_threshold < 0.5` 的旧轴资源，若保留新字段默认值 `0.5` 会形成非法阈值顺序并让对应 mapping 失败关闭；`BOOL` 动作无需迁移这两个轴字段。
76. 检查直接改写 `GFSlotInventoryModel.slot_definitions` getter 返回数组的代码：先用 `set_slot_count()` 建立最终槽位数，单槽改用 `set_slot_definition()`，批量数组必须与当前槽位数精确等长；自动增长的新槽规则始终为 `null`。把 `acceptance_checker` 第五参数与手工 `can_accept()` 的 `inventory` 实参从 `GFSlotInventoryModel` / 任意 `Object` 改为短生命周期 `GFInventoryReadView`，仅在同步回调内查询；把 `acceptance_checker` 与 `compatibility_checker` 的匿名 lambda 改为 `Callable(object, &"method_name")` 指向签名可反射的具名方法。接收与兼容性回调可能调用零次或多次，必须同步、确定、只读、有界、无 I/O/外部副作用且不依赖调用次数。若项目缓存了跨库存 prepared transaction，规则或定义资源字段变化后应丢弃旧句柄并重新 prepare，不要把 `stale_plan` 当成可强制提交的警告。
77. 检查所有 `GFArtifactWriteTransaction` entry builder 和直接 entry：`expected_sha256` / `preflight_existing_sha256` 只能传精确 `String`，不再用 `null` 表示关闭校验；无需对应约束时省略字段或传空字符串。覆盖已审阅既有文件时可把旧内容摘要传给 `preflight_existing_sha256`，把新内容摘要传给 `expected_sha256`。前者只拒绝预检与替换边界能够观察到的漂移；需要跨进程原子 compare-and-exchange 的调用方必须使用平台原生协调机制，不能依赖本事务字段。
78. 检查依赖完整 Behavior Tree 调试快照的工具：`BTNode.get_debug_snapshot()` 与 `Runner.get_debug_snapshot()` 现在使用框架默认预算，调用方必须读取顶层 `debug_budget.truncated` / `truncation_reasons` 以及节点级截断字段，不能再假设返回整棵树。需要不同预算时改用 `GFBehaviorTree.build_debug_snapshot(node, options)`，并在框架硬上限内显式设置 `max_nodes`、`max_depth`、`max_children`、`max_total_bytes`、`max_text_length` 与 `max_blackboard_keys`。
79. Architecture 中原先只注册 `GFSettingsUtility` 的项目应按旧后端分流：依赖隐式 `user://` fallback 时，把 `GFSettingsFileStoreUtility` 注册为精确 `GFSettingsStoreUtility` alias；原先已复用 `GFStorageUtility` 时，安装 `gf.standard.settings.storage` 并把 `GFStorageSettingsStoreUtility` 注册为精确 base alias；不需要持久化时，在初始化前设置 `persistence_enabled=false`。自定义后端应从覆写 Settings 物理读写迁移为独立 `GFSettingsStoreUtility` 派生实现。正常关闭必须等待 Architecture `shutdown_async()` 或先检查 Settings `begin_quiesce()`；取消 quiesce 会在下一个 target I/O 前停止并保留未尝试记录。物理写入失败只在实例仍存活时可用 `flush_pending_save()` 重试同一冻结 payload，捕获失败则必须修正值并提交同 target 新快照；两者都不会由 `tick()` 热重试，也不能再依赖 `dispose()` 做退出保存。
80. 既有只需等待完成的对象池预热调用无需迁移；需要逐请求取消、进度或错误分类时，在主线程改用 `prewarm_request_async()` / `prewarm_budget_request_async()` 并保存返回 Operation。先检查同步终态，再等待 `completed`；prepare 回调改为返回 `Error`，并按 `GFObjectPoolPrewarmResult` 的 status、reason 和终态有效计数处理容量部分接纳或生命周期终结，不要把取消理解为回滚已经创建的节点。
81. 将 Config Pipeline 的裸相对输出路径（例如 `build/config.tres`）改为显式 `res://build/config.tres`，用户数据输出改为 `user://...`；删除 `allow_absolute_output_path`。需要折叠 resource URI 内父级片段的 `GFConfigPipeline` database/access/manifest 或 Profile/Runner 调用，可以继续按单个产物设置 `allow_parent_output_path: true`，但越过 URI 根、主机绝对路径与未知 scheme 不再有兼容绕过；直接 `GFConfigAccessGenerator` 不识别该路由选项。读取成功结果时应使用返回的规范化 `path` / `output_path` / `manifest_path` 作为产物身份，不再依赖原始空白、反斜杠或 `.` 文本。
82. 将扩展 `gf_extension.json` 中的七个编辑器路径字段移入同扩展的 `editor/gf_tool_contribution.json`；文件必须声明 `schema_version: 2` 和与 manifest 一致的 `extension_id`。保留 `installer_paths`、`editor_dock_order` 与 `editor_dock_short_label` 在 manifest，删除旧七字段而不做双写；否则 11.0 会返回指向 Tool Contribution 的迁移错误。直接消费 `GFExtensionSelectionDiscovery.get_snapshot()` 的工具应从 `contribution_paths` 读取这七个字段，或改用对应的 `GFExtensionSettings.get_enabled_*_paths()`；`manifest_paths` 现在只包含 `installer_paths`。项目工具应以 selection report 的 `status` / `tool_contribution_errors` 展示局部问题，不得因 `partial` 状态禁用已验证的 runtime Installer。
83. 新的项目运行时或工具读取不可信 JSON object 时，先调用 `GFBoundedJsonObjectReader.parse_object()` / `read_object()`，检查 `ok`、`error_kind` 与报告中的实际预算，再消费 `data`；需要恢复 GF typed marker 时，随后调用 `GFVariantJsonCodec.json_compatible_to_variant()` 并保留其遍历预算。不要把 Codec 在 `JSON.parse()` 之后执行的 `max_depth` / `max_nodes` / `max_collection_items` 当作字节或词法深度准入。既有编辑器贡献和扩展发现调用不需要改签名，其兼容 adapter 会保留原报告 schema。
84. 直接消费生成目录的工具应把 XML Catalog 从 schema v2 迁移到 v3，并接受独立的 class / autoload owner；既有 `classCount` / `methodCount` 仍只统计类，新增的 `autoloadCount` / `autoloadMethodCount` 统计 AutoLoad。直接消费 AI Developer `knowledge/api_index.json` 的工具应把 schema v1 迁移到 v2、catalog version `2.0.0`，保留 `classes` / `class_count` 的原语义并额外读取 `autoloads` / `autoload_count`。不要把两个集合按裸名称无条件覆盖合并，也不要把 `Gf` 伪装成 `class_name`。只调用运行时 `Gf.*` 的项目代码无需迁移。
