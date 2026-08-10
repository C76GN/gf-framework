# 更新日志 (Changelog)

## 📝 日志条目结构标准

每个候选版本条目必须包含非空的版本概述，并至少包含一个与本轮变更相关的标准分类。没有相关变动的分类可以省略；出现的分类必须非空、不得重复，并按以下固定顺序排列：

1. **版本号与日期**：开发期固定为 `## [未发布]`；正式版固定为 `## [主版本.次版本.修订号] - YYYY-MM-DD`。
2. **版本概述**：使用非空的 `**版本概述**：...` 简述该版本的核心目标。
3. **🚀 新增特性 (Added)**：新加入的类、方法、系统、扩展组件等。
4. **🔄 机制更改 (Changed)**：对现有功能逻辑的修改、内部重构、性能优化等。
5. **🐛 Bug 修复 (Fixed)**：修复的逻辑错误、内存泄漏、崩溃问题等。
6. **⚠️ 废弃与移除 (Deprecated/Removed)**：标记为废弃（将在未来移除）或本次直接移除的接口、文件。
7. **🔧 API 变动说明 (API Changes)**：详细列出函数签名改变、属性重命名等直接导致旧代码报错的改动。
8. **📘 升级指南 (Migration Guide)**：为使用旧版本框架的开发者提供 Step-by-Step 的升级建议和兼容性处理方案。
9. **📁 核心受影响文件 (Affected Files)**：列出改动最大的核心源码文件，方便开发者进行二次开发比对。

## 维护策略

每个正式版本只记录相对上一个稳定版本的增量。开发态当前页只保留唯一的 `[未发布]`，不得同时保留任何正式版本段；发布时将其转为目标版本，发布态当前页只保留唯一的目标正式版本段。已发布历史以不可变 Git tag 和 GitHub Release 为准，不另建 Markdown 归档，也不得把旧版本改名伪装成新版本。GitHub Release 只提取当前目标版本自身的段落。

`changelog_policy` 会根据 `addons/gf/plugin.cfg` 判定开发态或稳定态，并严格校验顶层标题顺序、编号结构、候选段数量、标题、日期、首条可见版本概述、分类名称、顺序和可读正文；它同时要求内置扩展版本与完整框架身份一致，并把开发身份映射到稳定 core 执行 API baseline SemVer 校验。原始 HTML、注释与可见内容混写、非 ASCII 标题分隔及只含实体或分隔线的正文都失败关闭；该检查属于 docs、quick、full 与 release 门禁。

---

## [未发布]

**版本概述**：本轮新增类型化音频播放区间与循环点和共享资源 admission Broker，把 Architecture 启动升级为依赖 DAG 驱动的四阶段激活并增加类型化异步关闭，为 Save Profile 增加精确 provider domain、活动身份与显式恢复/对账事务，补充 Headless 服务探针和周期环境表现的项目组合配方，修复并加固 AI Developer 的项目 Adapter 依赖边界，同时把 Changelog 与安全扫描抑制约束转为可执行维护门禁，并收紧热模块事务、Save Profile 准备、可选依赖、后台回调所有权、按 key 并发、场景邻居稳定帧、渲染预热和音频释放契约；此外加入冻结模块访问策略、Route 请求生命周期、类型化虚拟输入 Pulse，以及有界虚拟列表 Binder、事务式表格谓词和可验证的 Spatial Canvas 输入策略，使生成访问、异步 UI、定时输入和大型交互界面都具备明确的身份、终态、传播与所有权边界；框架只提供可验证的通用机制，不内置项目启动、存档业务、部署协议、领域过滤器、行视觉、环境模型或轮询式音频模拟。

### 🚀 新增特性 (Added)

- 新增 `GFAudioPlaybackRegion` 与 `GFAudioPlaybackRegionResult`：以类型化资源表达播放起点、自然或显式终点、forward / ping-pong / backward 循环和循环起点，以 `VALID` 区分“结构已验证”和 `APPLIED`“执行者已接受”，严格区分 `INVALID` 与 `UNSUPPORTED`，并按 WAV、Ogg Vorbis、MP3、Playlist 和其他流的 Godot 原生能力返回逐请求结果。
- `GFAudioClip` 新增 `playback_region`；BGM、环境音、普通 SFX 与 2D/3D 空间 SFX 共用请求快照、私有流复制和原生播放准备流程。`GFAudioUtility` 新增拒绝信号、最近拒绝报告与 session 区间调试快照。
- `GFAudioBackendCapability` 新增播放区间协议发现能力，`GFAudioBackend.evaluate_playback_region()` 提供无副作用的逐片段、逐通道协商；粗粒度能力声明不能替代具体请求评估。
- 新增 Headless 服务健康/探针组合配方：组合惰性诊断 Provider、有界会话字段与类型化传输指标，由项目 Adapter 决定 liveness/readiness、传输协议、鉴权和部署政策；Backend 指标补充使用通用执行预算，并对总指标、自定义指标和 ID 长度设置绝对上限。
- 新增周期环境表现组合配方：组合可注入时钟、项目环境样本、Shader Profile、接口快照与 Binder；周期、天气、天文、时区和持久化策略继续由项目负责。
- AI Developer Capability / Recipe 知识目录升级到 `1.9.0`，加入两份环境组合配方，并让目录认识类型化播放区间、虚拟列表 Binder、事务式表格谓词和 Spatial Canvas 输入策略的可搜索组合边界。
- `GFModel`、`GFSystem` 与 `GFUtility` 新增 `begin_activation(scope)` / `begin_quiesce(scope)`；`GFArchitecture` 新增 activation/shutdown deadline、激活与 quiescing 状态查询，以及依赖 DAG 驱动的第四阶段 bootstrap。
- 新增 `GFArchitectureShutdownResult`：类型化区分正常完成、失败、取消、超时、强制释放与幂等重复关闭，并以有界模块条目保存 quiesce 证据；并发 `shutdown_async()` 调用共享同一关闭流程。
- 新增 Save Profile bootstrap 组合配方：项目 System 声明依赖 `GFSaveProfileUtility`，在 `begin_activation()` 中把 `load_profile()` / `flush_profile()` Operation 桥接到一次性完成源；框架不新增项目存档业务类。
- `GFArchitecture` 新增 `find_model()`、`find_system()` 与 `find_utility()` 静默可选查询：非严格模式复用普通父链和 alias 规则，严格模式停止本地但不报告 required miss。
- `GFAsyncKeyedGate` 新增 `try_request_lease()` 与 `STATUS_BUSY`：无法在当前主线程边界立即提交时，不创建 waiter、请求 ID 或 completion，不发请求生命周期信号，也不改变公平游标。
- 新增 `GFResourceBroker` 与 `GFResourceLease`：为 Asset、Scene 与 BackgroundWork 提供显式共享、无单例的 threaded ResourceLoader admission；不同资源请求使用有界严格 FIFO，同资源身份复用底层请求并保留独立消费者取消，已发起且失去消费者的请求继续 drain 到 Godot 终态。
- `GFResourceBroker` 公开默认/绝对活动与等待预算常量，以及活动请求无法追溯满足 type hint / admission 时的稳定失败原因常量；活动请求配置限制为 1..64，等待请求配置限制为 1..4096，队首 exclusive / require-idle 请求和排队中同路径约束升级都不会被后续共享请求绕过。
- Save Profile 新增一次性 opaque `GFSaveProfileRequest`：`take_ownership()` 分别接管 document metadata、Provider context 与 result metadata，不提供 payload getter；合法边界只做 O(1) claim，成功后调用方必须放弃三个输入图的全部嵌套 alias。
- Save Profile 新增 `GFSaveSectionSnapshot` 与 `GFSaveSectionSnapshotOperation`：Provider 通过 `begin_save_snapshot()` / `_begin_save_snapshot()` 在主线程按 work unit 分片生成不可变 section Snapshot；固定且很小的载荷可用 `make_completed_snapshot()`，大型载荷必须实现有界 Operation。
- Storage 新增 `GFStoragePayloadTransfer` 与 `save_payload_request_async()`：以 opaque 单所有者句柄逻辑移交纯 Variant 载荷，并允许同一冻结绑定上的 timeout-detached attempt 与有界重试共享只读 Snapshot。
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
- `GFStorageAsyncResult` 新增 `WriteFailureKind` 与隔离的 worker 载荷预检报告，区分非法请求、不可持久化载荷、编码、线程、生命周期和 IO 故障。
- `GFArchitecture` 新增统一的 `resolve_module_access()`、模块类型与查询作用域枚举；Access Generator 可按精确模块脚本路径冻结 inherited/local、required 与 require-ready 策略，生成结果不再依赖运行时隐式选择。
- 新增 `GFUIPanelAsyncOperation`：为每次底层异步 push/replace 冻结单调 serial、路径、层级和操作类型，并以弱面板引用暴露唯一终态；`GFUIRouterUtility` 的异步打开选项新增 owner 与 `GFAsyncScope` 生命周期锚点。
- 新增 `GFVirtualInputPulseOperation` 与 `GFVirtualInputSource.PulseReplacementPolicy`：以类型化句柄表达有界虚拟动作脉冲、OR 生命周期取消、原子替换/拒绝策略、单调 generation 和匹配释放证明。
- 新增 `GFVirtualListBinder` 与 `GFVirtualListSyncResult`：把项目持有的 `ScrollContainer`、绝对布局内容根、行工厂和绑定回调组合为 owner-bound 的有界回收句柄，按稳定 identity 物化 visible + overscan 窗口，统一处理测量回写、单次锚点修正、虚拟焦点交接、重入合并和确定性释放；数据、视觉、选择、激活与输入继续由项目负责。
- 新增 `GFTableRowView`、`GFTableRowPredicate`、`GFTableRowPredicateResult`、`GFTableRowPredicateRegistration` 与 `GFTableViewRebuildResult`：以稳定 ID、启用状态和确定顺序组合项目谓词，并以隔离行视图和类型化结果表达包含、排除或失败。
- 新增 `GFSpatialCanvasInputPolicy` 与 `GFSpatialCanvasSelectionModeBinding`；`GFSpatialCanvas2D.InputDisposition` 显式区分 ignored、handled 和 consumed，使鼠标 chord、选择修饰键、滚轮父级仲裁、可禁用单指行为、独立多指 pan/zoom、系统手势和取消 action 可以在不继承 Canvas 的前提下原子配置。

### 🔄 机制更改 (Changed)

- 播放区间在请求开始时连同 `GFAudioClip` 一起复制；本地执行始终复制 `AudioStream`，只修改 session 私有副本。异步回调、crossfade 回退和环境音 session 都携带冻结后的规范化区间。
- 本地音频只接受引擎能够精确表达的起点和循环点，不使用 Timer、每帧轮询或近似 seek 模拟非循环有限终点；有效但无法精确执行的组合明确返回 `UNSUPPORTED`。
- WAV 终点按最后有效帧索引写入，原生无法保持初始位置语义的 backward 明确返回 `UNSUPPORTED`；Ogg Vorbis / MP3 私有循环副本清除会改变自然终点的 `beat_count`。后端评估与执行只接收由验证结果重建的规范化 clip/context 快照。
- 环境音停止拒绝和本地淡出等非终态继续保留活动区间；拒绝信号保留调用通道，而持久诊断把非框架通道收敛为 `custom`，避免项目值进入稳定快照。
- 公开音频路径、参数/状态/开关、mix snapshot、effect value、总线文本以及 clip/event probe、区间评估与执行统一经过有界请求快照；图遍历、属性扫描、`String` / `StringName` / Packed Array 载荷字节与 Packed 元素分别受硬预算约束，向量 Packed Array 按双精度构建上限保守计费。单个快照图内的重复引用由 memo 保持，ClassDB 原生 Packed 属性只允许经类型/内容复核的值复制；集合循环、超限、Resource storage schema 漂移、无法安全实例化或脚本/dynamic setter 破坏最终图一致性时均在首次回调或本地副作用前失败关闭。Backend 与本地 effect fallback 使用彼此隔离的副本，拒绝前的参数改写不能污染本地提交。Utility 的 Bank resolver 同时限制活动 ID、全局保留挂载数、候选数、标识长度、分隔符长度和 fallback 层级；容量拒绝保持注册栈原子不变，有限权重求和溢出也在抽样前失败关闭，不能再通过重复挂载或开放式候选遍历绕过门禁。环境音会话保留目标增益，部分淡出被失败替换打断时会恢复区间、播放身份与增益，旧流已自然结束时则提交停止终态并释放播放器流引用。
- 新增 `changelog_policy` 当前状态检查：`X.Y.Z-dev.N` 只允许唯一的规范 `[未发布]` 段，稳定版本只允许唯一的同版本正式段；共享的严格 Markdown 解析会在标题/分类识别时排除 fenced 与缩进代码和独立 HTML 注释，但仍把候选段开头的代码块视为已经渲染的内容，确保版本概述必须真正排在首位。门禁拒绝原始 HTML、混写注释、非法 backtick info string、非 ASCII 标题分隔、伪装历史标题及不可读正文，并由发布说明提取器复用；同时验证文档标题、日志条目结构标准、维护策略、分类结构、扩展版本对齐和稳定 core 的 API SemVer，在 quick、full 和 release 套件中失败关闭。
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

### 🐛 Bug 修复 (Fixed)

- 修复 `GFUIUtility` 在 panel 入树并执行 `_ready()` 后才捕获 previous focus，导致 modal 在 `_ready()` 主动取得焦点时无法恢复外部焦点的问题；现在会从目标 `CanvasLayer` 的 `Viewport` 在入树前捕获。
- 修复共享资源与存储的取消、替换、恢复和释放边界：Broker 会在 queued Lease 离开后按剩余消费者重算类型与 admission 约束；Asset、Scene 与 BackgroundWork 私有 Broker 在 drain 完成前拒绝替换；Scene 自动邻居可加入外部消费者已活动且 type hint 兼容的同路径请求；BackgroundWork 不会把新任务并入已取消 Lease；Storage 异步单文件入口会按完整多文件事务恢复，并在 dispose 终态回调重入期间持续关闭新 admission。
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
- 修复场景切换完成帧立即启动邻居预载时与活动 Asset warmup 重叠，可能导致 `.tscn` 间歇解析失败的问题；邻居请求现在必须经过目标场景确认、稳定帧和共享 Broker idle 边界。
- 修复 `GFSceneUtility` 自动邻居预载回调错误接收 `SceneTree.scene_changed` 不会提供的场景根参数，导致真实零参数信号触发时报参数数量错误、邻居预载无法启动的问题；回调现在从发出信号的 `SceneTree.current_scene` 读取目标根。
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

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `play_bgm_with_options()` 的 `loop` / `playback_region` 通用选项，并保留事件 metadata/options 中的同名键；继续传入会在资源加载和后端派发前失败关闭，类型化区间只能来自 `GFAudioClip.playback_region`。
- 移除框架内部 `gf_threaded_resource_coordinator.gd` 与 `gf_threaded_resource_operation.gd`；不保留双轨协调实现，统一由公开 `GFResourceBroker` / `GFResourceLease` 承担跨 Utility 所有权与 admission。
- 移除 `GFSaveProfileUtility.save_profile(profile_id, metadata, context)` 字典重载；保存调用统一改用一次性 `GFSaveProfileRequest`，不保留隐式复制兼容路径。
- 移除 `GFSaveProfileResult.STATUS_GATHER_FAILED` / `gather_failed`；Snapshot 创建、协作式推进与 worker payload 预检失败统一使用 `STATUS_PREPARATION_FAILED` / `preparation_failed`，不保留 alias。
- 移除 `GFSaveSectionProvider.gather_section()`、`_gather_section()`、`GFSaveProfileUtility.STATE_GATHERING` 及读取回滚对保存采集的隐式回退；保存 Provider 必须采用 Snapshot Operation，启用读取的 Provider 必须显式实现 `_capture_section()`。
- 移除 `GFArchitecture.fail_on_missing_declared_dependencies` 与 `module_lifecycle_max_stage_passes`；声明依赖现在始终是强契约，生命周期计划只编译一个确定性候选 DAG，不保留 warning-only 或初始化期多轮补注册路径。
- 移除 `GFArchitecture.HOOK_GET_REQUIRED_DEPENDENCIES`、`HOOK_GET_REQUIRED_MODELS`、`HOOK_GET_REQUIRED_SYSTEMS`、`HOOK_GET_REQUIRED_UTILITIES` 与 `HOOK_GET_REQUIRED_FACTORIES`；依赖声明只通过 `GFModel`、`GFSystem`、`GFUtility` 的类型化虚方法表达，不再暴露字符串 Hook 常量。
- 移除 `GFSpatialCanvas2D.handle_input_event()` / `handle_screen_input_event()` 的 `bool` 返回契约，以及内置 raw Escape、中键、左键和固定 modifier 判断；调用方改用 `InputDisposition` 与显式 `GFSpatialCanvasInputPolicy`，不保留双轨解释路径。

### 🔧 API 变动说明 (API Changes)

- 本轮有意移除 10.x 已公开的通用 `loop` 输入与 `current_bgm_loop` 快照字段，开发身份进入 `11.0.0-dev.0` 主版本迁移线；不提供双轨兼容分支。
- `GFAudioClip.playback_region: GFAudioPlaybackRegion` 为新的可选公开属性。
- `GFAudioBackendCapability.supports_playback_region_contract`、`GFAudioBackend.evaluate_playback_region()`、`GFAudioUtility.playback_region_rejected` 与 `GFAudioUtility.get_last_playback_region_rejection()` 为新的公开 API。
- `GFAudioUtility.get_debug_snapshot()` 用 `current_bgm_region` 和 `last_playback_region_rejection` 描述播放区间状态，不再提供 `current_bgm_loop`。
- `GFNetworkBackend._enrich_transport_metrics()` 现在接收 `GFExecutionBudget`，属于有意的 protected 签名升级；新增 `MAX_TRANSPORT_METRICS_ENRICHMENT_MSEC`，`GFNetworkTransportMetrics` 新增总指标、自定义指标和 ID 长度绝对上限常量。`gf.network` 的 `extension_version` 因此提升到 `6.0.0`。
- `GFArchitecture.find_model()`、`find_system()` 和 `find_utility()` 是新的公开可选解析入口。
- `GFAsyncKeyedGate.try_request_lease()`、`STATUS_BUSY` 与调试快照中的 `busy_count` 是新的公开 fail-fast 并发契约。
- `GFResourceBroker.request()` / `poll_lease()` / `pump()` / `cancel_all()` 与 `GFResourceLease` 状态、取消和释放接口是新的公开资源 admission API；`GFAssetUtility`、`GFSceneUtility`、`GFBackgroundWorkUtility` 各自新增 `set_resource_broker()`、`setup_standalone_resource_broker()` 与 `get_resource_broker()`。
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
- `GFModel`、`GFSystem`、`GFUtility` 新增 `begin_activation(GFAsyncScope) -> GFAsyncCompletion` 与 `begin_quiesce(GFAsyncScope) -> GFAsyncCompletion`。
- `GFArchitecture.init(cancellation_token = null)` 保留无参数调用形状并新增显式取消输入；新增 `activation_timeout_seconds`、`shutdown_timeout_seconds`、`is_activating()`、`is_quiescing()`、`is_accepting_runtime_work()`、`is_module_active()`、`shutdown_async()`、`get_last_shutdown_result()` 与 `shutdown_finished`。`module_async_init_timeout_seconds` 与两个新增 timeout 属性统一为有限 `0..86400` 契约，`0` 禁用 deadline；并发 init/shutdown 都由首个调用拥有共享流程策略，后续 init token 只取消自身等待，后续 shutdown 调用只复制同一终态。父级 required module/factory 由 child generation 弱租约保护；模块租约冻结相关父级模块拓扑，任一外部依赖租约都使父级正常关闭以 `ERR_BUSY` 失败。`create_instance()` 现在属于 READY 运行时准入，在 activation、热拓扑事务或 quiesce 期间不会调用 provider。依赖诊断固定复用四类 typed Hook 与真实父级解析语义，不再提供 `include_parent_lookup` / `include_factories` 行为开关。
- `GFArchitecture.unregister_model()`、`unregister_system()`、`unregister_utility()` 及 classless Autoload facade `Gf.unregister_*()` 均改为必须 `await` 且返回 `bool` 的拓扑事务；旧同步 fire-and-forget 调用不再受支持。
- 新增公开值对象 `GFArchitectureShutdownResult`；`GFNodeContext.context_ready` 的既有信号形状不变，但成功语义从第三阶段准备完成收紧为第四阶段 activation 已提交。
- `GFArchitecture.ModuleKind`、`ModuleLookupScope` 与 `resolve_module_access(module_kind, script_cls, lookup_scope, required, require_ready)` 是新的公开共享模块解析 API；`GFAccessGenerator.ACCESS_SCOPE_*`、`ACCESS_POLICIES_SETTING` 和 `gf/codegen/access_policies` 是新的生成期策略契约。
- `GFUIUtility.push_panel_async()`、`push_panel_async_with_options()`、`replace_layer_async()` 与 `replace_layer_async_with_options()` 现在返回 `GFUIPanelAsyncOperation`，并在末尾接收可选完成回调；`GFUIRouterUtility.push_route_async()` / `replace_route_async()` 的 `async_options` 支持 `owner` 与 `scope`，`GFUIRouteResult` 新增 `STATUS_INVALID_LIFECYCLE`。
- `GFVirtualInputSource.configure()` 新增可选 `GFTimerUtility`，并新增 `set_timer_utility()`、`get_timer_utility()`、`pulse_action()` 与不可逆 `dispose()`；`GFVirtualInputPulseOperation` 公开冻结身份、状态、取消、调试快照和匹配释放计数。
- `GFVirtualListModel.layout_changed(revision)`、`get_revision()` 与 `get_viewport_range()` 是新的公开布局观察 API；`GFVirtualListBinder.bind()` / `sync_now()` / `invalidate_items()` / `request_measurement()` / `scroll_to_item()`、生命周期入口和 `GFVirtualListSyncResult` 构成新的可回收 Control 组合契约；`GFVirtualListSyncResult.to_dict()` 的范围编码为 `{start, end_exclusive}`，物化索引编码为 `Array[int]`。
- `GFTableDataView.view_changed` 从单个 `visible_count` 参数改为 `(view_revision, visible_count)`；`set_columns()`、`set_rows()`、`set_filter_query()` 与 `refresh_view()` 现在返回 `GFTableViewRebuildResult`。移除可绕过事务的 `row_id_column`、`case_sensitive_filter` 与 `selection_model` 公共字段，改为类型化 setter/getter；新增命名谓词注册、启停、排序、查询和 revision/result API。`GFTableSelectionModel` 新增原子替换选择集合与锚点的入口；`commit_cell_value()` 与两种批量提交改为候选行事务，不再允许不可隔离行或任意 `value_setter` 走先写后刷新的部分提交路径。命名谓词不保留 Callable-only 或裸 Dictionary 入口。
- `GFSpatialCanvas2D.handle_input_event()` 与 `handle_screen_input_event()` 的返回类型从 `bool` 改为命名的 `InputDisposition` 枚举；新增 `set_input_policy()` / `get_input_policy()`、`GFSpatialCanvasInputPolicy` 与 `GFSpatialCanvasSelectionModeBinding`。滚轮轴、滚轮路由、触摸主行为分别使用各自的命名枚举；`TouchPrimaryBehavior.NONE` 显式关闭单指行为，`touch_multi_pan_enabled` 与 `touch_multi_zoom_enabled` 独立控制 raw 多指视图分量。策略默认选择、嵌套 modifier binding、公开选择入口和捕获状态共同使用唯一的 `GFSpatialCanvas2D.SelectionMode` 类型。

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
28. 需要短时虚拟动作时，为 `GFVirtualInputSource` 注入共享 `GFTimerUtility` 并调用 `pulse_action()`；用返回句柄观察终态，不自行安排延迟 `clear_action()`。同键覆盖语义应显式选择 REPLACE 或 REJECT_NEW，Source 与 Mapping 关闭后不得复用。
29. 大型列表把项目 `ScrollContainer` 的直接子内容根、行工厂、bind/unbind、稳定 identity 和 owner 交给 `GFVirtualListBinder`；内容根不能是接管子节点位置的 `Container`。排序、过滤或数据内容提交后显式调用 `invalidate_items()`，只使用稳定且有界的标量 identity；若在 Binder callback 内失效，当前结果会是非成功 `STATUS_DEFERRED`，副作用已开始时 active 可被安全清空，调用方应以结果索引为准等待下一轮重建。需要切换 `layout_axis`、`fill_cross_axis`、`auto_measure` 或 callback 内的预算时，先更新配置并调用 `request_sync()`，当前同步轮仍使用入口快照，下一轮才采用新值。`scroll_to_item()` 返回 `false` 表示操作快照或最终整数偏移未能完整提交，调用方不要把它当作部分成功。Binder 会按每段轴所有权恢复接管前的最小尺寸。owner 退出前让 Binder 自动或显式 `dispose()`，不得重挂载或释放 Binder-owned Control。
30. 表格结构化过滤改为继承 `GFTableRowPredicate`，返回 `GFTableRowPredicateResult`，再用 `GFTableRowPredicateRegistration.create()` 批量事务注册。将 `row_id_column`、`case_sensitive_filter` 与 `selection_model` 直接赋值迁移到 `set_row_id_column()`、`set_filter_case_sensitive()` 与 `set_selection_model()`，并通过 getter 读取已提交配置。更新所有 `view_changed` 连接以接收 revision 与 visible count；只有 rebuild result 成功且 committed，或收到 `view_changed` 时，才更新 VirtualList count 与 Binder identity，失败时继续展示上一份已提交投影。谓词实例的项目参数改变后显式调用 `refresh_view()`，不要依赖框架观察任意成员写入。经 `GFTableDataView.commit_cell_value()` 或批量入口写入的行必须可安全隔离；把带任意副作用的 `value_setter` 移到项目事务层，提交完成后再用新的 source 行调用 `set_rows()`。
31. Spatial Canvas 输入转发改为检查 `InputDisposition`：只有 `CONSUMED` 才停止项目路由。创建并校验 `GFSpatialCanvasInputPolicy` 来替代硬编码按键；嵌套滚动界面用 modifier-gated 或 parent-only wheel，让未匹配滚轮继续 GUI 冒泡。需要禁用单指时使用 `TouchPrimaryBehavior.NONE`，并分别决定 raw 多指 pan 与 pinch zoom；若二者也都关闭，首触点不会被 Canvas 捕获。取消行为使用只含非指针事件的项目 InputMap action，不得与鼠标、触摸或位置手势复用；项目运行时修改 InputMap 后，超出事件预算或变成指针映射的取消 action 会失败关闭。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/standard/utilities/audio/gf_audio_playback_region.gd`
- `addons/gf/standard/utilities/audio/gf_audio_playback_region_result.gd`
- `addons/gf/standard/utilities/audio/gf_audio_utility.gd`
- `addons/gf/standard/utilities/audio/gf_audio_backend.gd`
- `addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd`
- `addons/gf/standard/utilities/audio/gf_audio_clip.gd`
- `addons/gf/kernel/editor/gf_access_generator.gd`
- `addons/gf/kernel/core/gf_architecture.gd`
- `addons/gf/kernel/core/gf_binding.gd`
- `addons/gf/kernel/core/gf_architecture_lifecycle_plan.gd`
- `addons/gf/kernel/core/gf_architecture_shutdown_result.gd`
- `addons/gf/kernel/core/gf_kernel_runtime.gd`
- `addons/gf/kernel/core/gf.gd`
- `addons/gf/kernel/core/gf_architecture_tick_scheduler.gd`
- `addons/gf/kernel/core/gf_node_context.gd`
- `addons/gf/kernel/base/gf_model.gd`
- `addons/gf/kernel/base/gf_system.gd`
- `addons/gf/kernel/base/gf_utility.gd`
- `addons/gf/standard/common/gf_async_keyed_gate.gd`
- `addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd`
- `addons/gf/standard/utilities/display/gf_render_warmup_utility.gd`
- `addons/gf/standard/utilities/jobs/gf_background_work_task.gd`
- `addons/gf/standard/utilities/jobs/gf_background_work_utility.gd`
- `addons/gf/standard/utilities/assets/gf_resource_broker.gd`
- `addons/gf/standard/utilities/assets/gf_resource_lease.gd`
- `addons/gf/standard/utilities/assets/gf_asset_utility.gd`
- `addons/gf/standard/utilities/scene/gf_scene_utility.gd`
- `addons/gf/standard/utilities/time/gf_timer_utility.gd`
- `addons/gf/standard/utilities/ui/gf_ui_panel_async_operation.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route_result.gd`
- `addons/gf/standard/utilities/ui/gf_ui_router_utility.gd`
- `addons/gf/standard/utilities/ui/gf_ui_utility.gd`
- `addons/gf/standard/utilities/ui/gf_virtual_list_model.gd`
- `addons/gf/standard/utilities/ui/gf_virtual_list_binder.gd`
- `addons/gf/standard/utilities/ui/gf_virtual_list_sync_result.gd`
- `addons/gf/standard/utilities/ui/gf_table_data_view.gd`
- `addons/gf/standard/utilities/ui/gf_table_row_predicate.gd`
- `addons/gf/standard/utilities/ui/gf_table_row_predicate_registration.gd`
- `addons/gf/standard/utilities/ui/gf_table_row_predicate_result.gd`
- `addons/gf/standard/utilities/ui/gf_table_row_view.gd`
- `addons/gf/standard/utilities/ui/gf_table_view_rebuild_result.gd`
- `addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_2d.gd`
- `addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_input_policy.gd`
- `addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_selection_mode_binding.gd`
- `addons/gf/standard/input/sources/gf_virtual_input_pulse_operation.gd`
- `addons/gf/standard/input/sources/gf_virtual_input_source.gd`
- `addons/gf/standard/input/runtime/gf_input_mapping_utility.gd`
- `addons/gf/standard/utilities/storage/gf_storage_payload_transfer.gd`
- `addons/gf/standard/utilities/storage/gf_storage_async_operation.gd`
- `addons/gf/standard/utilities/storage/gf_storage_async_result.gd`
- `addons/gf/standard/utilities/storage/gf_storage_utility.gd`
- `addons/gf/extensions/save/document/gf_save_section.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_request.gd`
- `addons/gf/extensions/save/extension.gd`
- `addons/gf/extensions/save/profile/gf_save_payload_validation_adapter.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_operation.gd`
- `addons/gf/extensions/save/profile/gf_save_section_provider.gd`
- `addons/gf/extensions/save/profile/gf_save_section_snapshot.gd`
- `addons/gf/extensions/save/profile/gf_save_section_snapshot_operation.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_utility.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_result.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_transaction_coordinator.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_transaction_operation.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_transaction_result.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_recovery_lease.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_reconcile_lease.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_reconcile_request.gd`
- `addons/gf/extensions/save/profile/gf_save_section_mutation.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_mutation_request.gd`
- `addons/gf/extensions/save/gf_extension.json`
- `packages/standard/gf.standard.storage.json`
- `packages/standard/gf.standard.ui.json`
- `packages/standard/gf.standard.spatial.canvas.json`
- `addons/gf/extensions/network/backends/gf_network_backend.gd`
- `addons/gf/extensions/network/runtime/gf_network_transport_metrics.gd`
- `addons/gf/extensions/network/gf_extension.json`
- `addons/gf/tools/ai_developer/gf_ai/constants.py`
- `addons/gf/tools/ai_developer/gf_ai/contract.py`
- `addons/gf/tools/ai_developer/gf_ai/dependencies.py`
- `addons/gf/tools/ai_developer/gf_ai/snapshot.py`
- `addons/gf/tools/ai_developer/knowledge/capabilities.json`
- `addons/gf/tools/ai_developer/knowledge/recipes.json`
- `tools/gdscript_api_parser.py`
- `tools/gf_maintenance.py`
- `docs/zh/editor/tools/ai-developer.md`
- `docs/zh/extensions/save-graph/save-profile-runtime.md`
- `docs/zh/kernel/lifecycle/module-lifecycle/init-stages.md`
- `docs/zh/kernel/lifecycle/module-lifecycle/async-ready.md`
- `docs/zh/kernel/lifecycle/module-lifecycle/dynamic-registration.md`
- `docs/zh/kernel/architecture/assembly-diagnostics/dependency-diagnostics.md`
- `docs/zh/extensions/save-graph/save-profile-adr.md`
- `docs/zh/extensions/save-graph/save-profile-transactions.md`
- `docs/zh/extensions/network-turnbased/network-transport/backend-session.md`
- `docs/zh/standard/utilities/io/storage-snapshot/storage-utility.md`
- `docs/zh/standard/utilities/io/assets-jobs-warmup/resource-broker.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/scene-flow/preload-cache-map.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/ui-stack-routing/viewport-text-node-tools/virtual-list-model.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/ui-stack-routing/viewport-text-node-tools/table-data-view.md`
- `docs/zh/standard/input-flow/spatial-canvas-2d.md`
- `docs/zh/standard/utilities/runtime/audio/backend-events.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/shader-parameter-profile.md`
- `tests/gf_core/extensions/network/test_gf_network_extension.gd`
- `tests/gf_core/kernel/core/test_gf_architecture_activation_shutdown.gd`
- `tests/gf_core/kernel/core/test_gf_architecture_lifecycle_transactions.gd`
- `tests/gf_core/kernel/core/test_gf_architecture_lifecycle_plan.gd`
- `tests/gf_core/kernel/core/test_gf_assignment_lifecycle.gd`
- `tests/gf_core/kernel/core/test_gf_node_context_lifecycle.gd`
- `tests/gf_core/maintenance/test_api_surface_contract_validation.gd`
- `tests/gf_core/extensions/save/test_gf_save_profile_preparation.gd`
- `tests/gf_core/extensions/save/test_gf_save_profile_scheduler.gd`
- `tests/gf_core/extensions/save/test_gf_save_payload_validation_adapter.gd`
- `tests/gf_core/extensions/save/test_gf_save_profile_utility.gd`
- `tests/gf_core/standard/utilities/storage/test_gf_storage_payload_transfer.gd`
- `tests/gf_core/standard/utilities/assets/test_gf_resource_broker.gd`
- `tests/gf_core/standard/utilities/scene/test_gf_scene_preload_map.gd`
- `tests/gf_core/standard/utilities/ui/test_gf_virtual_list_binder.gd`
- `tests/gf_core/standard/utilities/ui/test_gf_table_row_predicates.gd`
- `tests/gf_core/standard/utilities/spatial_canvas/test_gf_spatial_canvas_2d.gd`
- `tests/gf_core/package_focused_gut_mapping.json`
- `tests/gf_core/standard/utilities/audio/test_gf_audio_utility.gd`
- `tests/gf_core/tools/ai_developer/test_gf_ai_project_tool.py`
- `tests/gf_core/tools/test_gf_codeql_suppression_policy.py`
- `tests/gf_core/tools/test_gf_credential_gate.py`
- `tools/gf_changelog.py`
- `tools/gf_codeql_suppression_policy.py`
- `tools/gf_maintenance.py`
- `tools/gf_maintenance_rendering.py`
- `tools/gf_path_security.py`
- `tools/gf_workspace_snapshot.py`
- `tools/extract_release_notes.py`
- `tests/gf_core/standard/utilities/signals/test_gf_async_wait_support.gd`
