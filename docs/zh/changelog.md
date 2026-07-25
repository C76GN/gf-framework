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

每个正式版本只记录相对上一个稳定版本的增量。开发期在当前页维护 `[未发布]`；发布时将其转为目标版本，并从工作树删除旧正式版本。发布态当前页只保留目标正式版本；已发布历史以不可变 Git tag 和 GitHub Release 为准，不另建 Markdown 归档，也不得把旧版本改名伪装成新版本。GitHub Release 只提取当前目标版本自身的段落。

---

## [未发布]

**版本概述**：开发线升级为 `10.0.0-dev.0`，补齐通用 2D 编辑器缩略图、运行时 2D Spatial Canvas、有序资产集合、内容包查询与运行时目录挂载、存储后端故障转移、版本化 Analytics Schema 与专用 Outbox Adapter、惰性诊断采集、配方化运行时会话轨迹、UI 路由预加载规划、轨迹预测数学、有界权威快照同步协调和默认关闭的 Runtime Agent Environment，修正 AI Developer Kit 的项目级资源所有权表达，并更新 CI/Release 基础 Actions；业务策略仍保持在各自调用方边界内。

### 🚀 新增特性 (Added)

- 新增 `GFWeakMethodInvocation` 框架级弱方法调用原语，以及 `GFMainThreadDispatchQueue.post_method()` 和 `GFDeferredMutationQueue.record_method()`：长期记录只保存 owner 的弱引用、初始实例 ID 和方法名，调用参数只在执行时传入；队列安全入口不持久化任意参数或 metadata，并把 owner 释放、方法缺失、预检失败与真实业务返回值明确分离。
- 新增平台 Contract Descriptor、Activation Intent 有界去重队列与 `GFPlatformAdapterConformance`，让外部 SDK Adapter 可以声明请求/结果 Schema、字节预算、能力、并发、取消和敏感字段，并在不调用 SDK 时完成静态覆盖审查。
- Network Lobby 升级为带唯一请求关联、单终态、取消、单调超时和迟到 callback 防护的类型化操作模型；新增可显式接管 owned/borrowed `MultiplayerPeer` 的通用 Backend，以及区分未知值的传输指标快照与有界采样历史。
- AI Developer Kit 新增 Platform Adapter、Lobby Backend、契约测试、兼容性 Profile 和故障矩阵模板，并更新 Network / Platform capability 与 Recipe，使 AI 默认生成 Provider 中立且可验证的 Adapter 边界。
- `GFThumbnailRenderer` 与 `GFThumbnailRenderRequest` 支持 `CanvasItem` 的 `Image` / `ImageTexture` 缩略图请求，统一覆盖 `Node2D` 和 `Control`。调用方可以显式提供内容 `Rect2`，也可以让渲染器保守估算 Sprite、Control、Polygon、Line、AnimatedSprite 和 2D 粒子范围。
- 新增可选包 `gf.standard.spatial.canvas` 与运行时 `Control` `GFSpatialCanvas2D`：提供世界/画布变换、焦点缩放、有界平移、稳定网格吸附、带精确命中 Hook 的候选查询、隔离选择结果和项目校验的放置会话；条目、选择、查询候选与网格绘制均受可降低但不可突破的绝对预算约束，GF 不拥有项目节点、占位规则或最终业务命令。
- 新增 `GFAssetCollection`，用稳定 `collection_id` 和有序 `asset_ids` 描述可序列化资源集合，并通过 `GFValidationReport` 报告空 ID、重复 ID 和目录缺失项。
- 新增 `GFContentPackageQuery`、`GFContentPackageQueryResult` 和 `GFContentPackageAssetCatalogProvider`，提供严格内容包筛选、dependency-first 闭包、类型化失败终态和 qualified 资产 ID 适配。
- 新增 `GFAssetCatalogRuntime` 与 `GFAssetCatalogMount`，提供 owner-scoped 目录快照、严格或显式高优先级冲突政策、原子 revision 提交和幂等卸载。
- 新增 `GFStorageFailoverBackend`，按稳定后端 ID 提供有界顺序尝试、`PRIMARY_ONLY` / `FIRST_SUCCESS` 写删语义、暂时性错误冷却和不含业务载荷的结构化操作报告。
- 新增 `GFAnalyticsEventSchema` 与 `GFAnalyticsSchemaRegistry`，按稳定事件名和 `1..2_147_483_647` 范围内的版本校验 Analytics properties；`GFAnalyticsUtility.track_versioned()` 对缺失版本、非法 Schema 和不匹配属性 fail closed，不执行隐式迁移。
- 新增 `GFAnalyticsOutboxAdapter`，按固定 v1 协议 Schema（`schema_id = "gf.analytics.outbox"`、`protocol_version = 1`）把 Analytics payload 耐久移交给专用 `GFRequestOutboxUtility`；尚可尝试的 pending 幂等复用会重新保存并复核，耗尽 pending 与 failed store 都不会被误报为成功，非敏感逻辑 endpoint 不进入调试快照，同时保留项目 transport、replay filter、PII/consent、鉴权和服务端幂等边界。
- 新增 `GFDiagnosticSnapshotProvider` 与 `GFDiagnosticProviderResult`，提供 owner-bound、仅显式求值的类型化诊断采集，以及重入、时长和结构预算隔离。
- 新增 `GFSessionTraceUtility`、`GFSessionTraceRecipe`、`GFSessionTraceChannelDefinition` 与 `GFSessionTraceCheckpoint`，提供显式通道白名单、事件数与字节双重预算、默认隐私脱敏、配方化故障检查点、结构化支持报告快照和可选 `GFLogSink` journal。
- 新增 `GFUIRoutePreloadUtility`，从 `GFUIRoute.adjacent_route_ids` 做有界、确定性的页面可达性遍历，并生成可直接交给 `GFAssetUtility` 的 `GFAssetPreloadPlan`。
- 新增 `GFUIRouteOperation` 与 `GFUIRouteResult`，把异步路由的输入拒绝、预加载、面板打开、取消、释放和未知结果统一为单终态请求契约。
- 新增 `GFTrajectoryMath`，提供 2D/3D 恒加速度未来状态、恒速发射体对匀速目标的最早拦截解，以及带绝对点数上限的同步公式轨迹采样。
- 新增 `GFNetworkSyncCoordinator`、`GFNetworkSimulationAdapter` 与 `GFNetworkInputFrame`：提供 actual peer、authority、recipient、epoch、sequence 与连续裁决 ack 绑定的全量权威快照流程，以及有界历史、输入窗口、目标 tick 动态授权复核和可选事务式预测纠偏；transport、项目状态 Schema、实体控制权、鉴权与复制语义仍由项目负责。
- 新增可选包 `gf.standard.agent_environment` 与 `GFRuntimeAgentEnvironment`：受信宿主可声明严格 JSON endpoint，为调用方签发精确授权的短期 session，并统一执行创建线程绑定、token 摘要校验、TTL、固定窗口限流、防重放、策略上下文失效、输入输出硬预算和无业务载荷审计；环境默认关闭，不内置网络、模型 SDK、文件/命令执行、截图或任意反射。
- 新增 Save Profile 运行时：`GFSaveProfile`、`GFSaveSectionProvider`、`GFSaveRecoveryPolicy`、`GFSaveProfileUtility`、异步操作句柄和类型化终态结果共同提供多 section 所有权、generation 合并、flush 屏障、迁移校验和事务回滚。
- 新增 `GFStorageAsyncOperation` 与 `GFStorageAsyncResult`，让并发调用方按唯一 request ID 观察单次读写终态；`GFStorageReadResult.FailureKind` 结构化区分非法请求、缺失、IO、损坏、未来格式、迁移失败和不可用。
- AI Developer 项目契约新增可选 `architecture.owned_resources`，用于精确声明 `project.godot`、`export_presets.cfg` 等不属于业务模块的项目级治理文件。
- AI Developer 工具协议新增只读迁移计划入口与目标绑定、原子 compare-and-swap 的交互式 CLI `contract-migrate`；非交互工具不暴露迁移写入，只支持经过显式定义的单步契约迁移。

### 🔄 机制更改 (Changed)

- `GFPlatformAdapter` 会在派发前验证已描述 Contract 的方法、能力、Schema、请求预算和并发，并在成功回调处验证结果；关闭 Adapter 会统一取消全部活动 Handle，声明不支持取消的方法不会错误调用 Provider cancel。
- `GFNetworkLobbyService` 现在拥有请求 ID、deadline、Backend 替换取消和快照提交；非请求驱动的成员、邀请和 Lobby 更新继续使用事件，请求终态不再依赖无法关联的全局 callback 信号。
- `GFNetworkBackend` 统一累计成功发送与已派发接收的 bytes/packet 指标；ENet、WebSocket 和通用 MultiplayerPeer Backend 共用该统计边界，未支持的 RTT、jitter 或丢包率保持未知。
- `GFStorageBackend.load_data()` 会为没有显式错误码的后端结果补齐 `error_code`，使组合后端能够区分成功、普通读取失败和明确的暂时性故障。
- `GFContentPackageUtility` 的 source root 新增稳定 owner 关系和事务式整组替换；既有便捷入口只操作公开 manual owner scope，不再可能清除其他模块来源。
- `GFStorageUtility` 的异步读写新增请求句柄入口；既有 `save_data_async()`、`load_data_async()` 和全局完成信号保持原行为，并与句柄共用同一调度队列。
- `GFStorageFailoverBackend.configure_backends()` 对策略、失败阈值和冷却窗口执行事务式 fail-closed 校验，非法配置不会部分替换既有后端或静默改变写入语义。
- `GFAnalyticsUtility` 的最终信封 Planner 现在按最大前缀向下有界校验，不假设自定义 `payload_builder` 的大小单调；工作预算耗尽时以 `planner_budget_exceeded` 保留完整队列，只有单事件已证明无法装入时才明确丢弃。
- `GFAnalyticsConfig.batch_size` 与 `max_queue_size` 的 Inspector 和运行时赋值现在分别统一钳制到 `1..500` 与 `1..100_000`；`GFAnalyticsUtility.identify()` 只接受 `1..4096` 字符的 client id，client id 与事件名统一拒绝 C0/DEL 控制字符。`GFAnalyticsOutboxAdapter` v1 只接受精确 `{ events }` payload 与固定事件字段，额外 `payload_builder` 字段会 fail closed。
- `GFRequestOutboxUtility.enqueue_with_report()` 显式区分内存入队与持久化结果；可靠入口会预检 codec 无损往返、复核同步通知后的精确所有权并补偿失效事务，`max_storage_bytes` 同时约束保存与恢复候选。请求信号、transport 和 replay filter 使用隔离副本；Outbox 继续只承诺 at-least-once 尝试。
- `GFSupportReportWorkflow.queue_report()` 现在要求 `report_id` 为 `1..4096` 字符且不含 C0/DEL，要求 Outbox 完成持久化检查点，钳制重试次数到 `1..64`，并在顶层提交失败结果中保留 queue reason 与持久化错误。
- 缩略图渲染改为等待场景树更新后同步强制绘制，避免无持续绘制帧时错过 `frame_post_draw`；dummy 渲染后端现在会安全返回空结果，不再访问无纹理存储的 ViewportTexture。
- Session Trace journal 会校验轨迹与 sink 的脱敏 profile，且对 sink 生命周期、写入与刷新执行重入保护；不安全配置和运行期 profile 降级会 fail closed。
- `GFDiagnosticsUtility.collect_snapshot()` 仅在调用方显式提交 `diagnostic_provider_ids` 时执行项目 Provider，并在回调返回后复核 owner、注册表修订、时长和输出预算；普通快照继续只读取已发布缓存。
- Session Trace 配方首次应用必须早于任何会话历史，并对 Resource 定义、完整通道目录和运行时配置保留独立指纹与单调修订号；未声明的既有通道会阻止应用，应用后新增通道或临时改写预算、脱敏配置都会让配方操作 fail closed。必需与可选 Provider 失败会分别统计，单项失败不阻断后续检查点采集。
- `GFUIRouterUtility` 可从当前已注册路由构建预加载计划；Planner 对目录、候选和边扫描分别设有硬上限，统一规范化路由 ID，只表达资源候选和诊断，不自动执行 IO，也不把相邻关系解释为权限或业务跳转。
- `GFUIRouterUtility.push_route_async()` 与 `replace_route_async()` 现在返回类型化句柄，并支持 `none`、`best_effort`、`required` 三种显式打开前预加载策略；自动计划默认只包含当前页面，临时 owner group 会在面板终态后释放。
- AI Developer 工具协议 4.0.0 将项目契约收敛到 schema v2：`required_capabilities` 被带 decision state、owner、Recipe、验收条件和备注的 `capability_requirements` 取代；必需能力必须显式选择 provider package，迁移占位项保持 `pending_review` 并阻断漂移门禁。
- AI Developer 项目快照升级到 schema v4，新增契约迁移状态和 `capability_readiness`；目录包、安装包、Recipe 的显式 `all_of/any_of` 包表达式、生产/测试源码命中、累计字节预算与扫描完整性分别记录，不再从示例类反推依赖，也不把“未观察到类”误写成“未采用能力”。
- Capability / Recipe 知识目录补齐版本化 Analytics Schema、专用 Outbox Adapter、Save Profile、Content Package Catalog Mount、类型化异步 UI Route、惰性诊断 Provider、Session Trace 与 Network Sync Coordinator 的项目侧采用边界。
- Network Capability / Recipe 知识目录补齐有界权威快照协调、Adapter 纯校验、解码前 raw packet 限制、新 epoch 重同步和项目实体控制权边界。
- AI Developer 项目契约的所有受控项目路径现在统一逐段拒绝符号链接、Windows junction 和其他重解析点；模块根、Adapter 根、project profile、验证必需路径与项目级资源不再允许通过链接别名绕过所有权边界。
- 模块根与 Adapter 根额外采用跨平台规范化校验，并以大小写无关方式拒绝 `res://addons/gf` 及 Windows 尾点、保留名称等别名，避免把 GF 源码误归属为项目模块；普通源码资源引用不受这项契约限制。
- CI 与 Release 工作流统一采用 Node.js 24 世代的 `actions/checkout@v7`、`actions/setup-python@v7`、`actions/upload-artifact@v7` 和 `actions/download-artifact@v8`，维护自检会阻止旧主版本回退。
- 验证链路将 Draft quick gate 与 Ready/main 完整门禁分离，`GF repository policy` 与 `GF merge gate` 共同作为 required checks，并把 framework 检查拆成 GUT、LSP 与静态检查并行分片；Ready/main 另由 `windows-latest` 聚焦任务验证原生 Job Object 清理并汇入 merge gate，非 `main` 手工运行不会生成同名 required context。本地 Full Suite 默认使用 3 个隔离 worker（可显式调整为 2–6 个），按批创建/执行/验收/清理工作区与私有用户目录，Windows 同时约束 clone、staging 和临时目录的投影路径预算并拒绝映射盘与 SUBST 别名，启动前由真实 Godot 验证平台用户目录边界，suite deadline 覆盖准备、源码分块捕获、制品扫描/哈希/复制、执行与复核全链路。每个 shard 由 POSIX process group 或 Windows Job Object 持有至完整后代树清空；单次 suite 的 package smoke 复用一份经源码指纹和哈希封存的构建产物，父进程精确核对 consumer 报告的 manifest 摘要与产物数量，并对报告和失败日志执行有界读取与完整目录链校验，同时保留严格 LSP 硬门禁与 `--jobs 1` 串行诊断退路。
- GUT 新增生命周期感知的 CLI wrapper、自定义 Runner、pre/post run hook、进程级 early/tracked/terminal warning 汇聚和可复用 LIFO cleanup scope；terminal capture 会在 tracker 快照前原子切换，完整测试入口只在 SceneTree 最终化阶段输出一份、至多由 stdout/log 镜像为两份的 `GF_TEST_LIFECYCLE_GATE` closed-schema JSON 证据，失败报告同步设置非零进程退出码。专用 smoke 通过统一进程树监督执行 bootstrap 静态 warning、线程切换 warning、真实 orphan、配置缺失和有界详情等故障注入，并对测试发现期与终态 `push_warning`、新增 orphan Node、GDScript reload warning、非零 GUT Warnings/Orphans 摘要及 Godot 退出泄漏执行 fail-closed 硬门禁。
- `GFTagExpression.expressions` 改为导出 `Array[Resource]`，并在读取、复制、匹配和序列化边界严格收窄到 `GFTagExpression`；这规避 Godot 4.7 对自引用脚本类型数组形成的脚本资源引用环，同时继续把 null 或其他 Resource 按非法子表达式处理。

### 🐛 Bug 修复 (Fixed)

- 修复已销毁的 `GFArchitecture` 仍会保留父架构强引用的问题；`dispose()` 现在会在模块、工厂、服务和事件系统完成清理后断开 parent link，并拒绝 dispose 完成信号同步回调或后续调用重新注入 parent，即使内部状态被破坏为父链循环也不会让整组架构残留到进程退出。
- 修复 `GFAsyncWaitSupport` 的 `should_continue` 回调宿主释放后，等待器会把失效 Callable 误当作未配置并继续存活到 timeout、进而在后续测试或场景中迟发 warning 的问题；只要调用方显式提交继续检查，进入等待前或等待期间失效都会立即以 `should_continue_invalid` 取消。
- 修复 `GFTagExpression` 被加载或实例化后会在 Godot 退出时残留一个 `GDScript` 与一个 `GDScriptNativeClass` 的问题；Network 生成器和动态 Model 测试也统一拆除瞬态 GDScript 依赖图，不再把整张脚本资源图保留到测试进程退出。
- 修复 `GFAnalyticsUtility.dispose()` 未释放项目注入的 payload builder、transport callback 和 response parser，以及 flush 终态通知同步回调可在 dispose 期间重新注入自引用回调的问题；最终通知结束后会再次清理注入引用。`GFReactiveStateControlBinder` 也不再在退订后由 binding callback 自引用保留整组状态与控件绑定。
- 修复 `GFHapticUtility.dispose()` 只清空播放状态，却继续持有输入设备工具、震动后端、输出回调和停止回调的问题；这些项目注入依赖现在由工具生命周期统一释放，测试不再承担内部所有权清理。
- 修复长期活动的 `GFRuntimeTask` 所持 `Node` requirement 已释放后，`GFRuntimeTaskScheduler` 的 owner 索引与诊断快照仍可能保留陈旧 ObjectID 的问题；活动任务和 live requirements 现在是唯一事实源，调度边界会先完整校验候选 owner map，再与活动集合一起提交，并在仲裁或释放回调期间拒绝会破坏已提交状态的重入写操作。
- 修复 UI 路由启用资源存在性检查时，脚本或其他现有非场景资源可能被误判为健康 `PackedScene` 候选的问题；新增 `invalid_scene_type_paths`，将“资源存在但类型错误”与 `missing_scene_paths` 的“路径不存在”诊断明确分离。
- 修复 Session Trace 在 `debug` 或 `support` 下注册的长期 context、通道 metadata 与 provider metadata，可能在随后收紧 profile 后继续保留对象实例 ID、节点名称或原始路径的问题；这些长期数据现在统一使用 `privacy` 安全下限。
- 修复同一 journal sink 原位重配时会先刷新并按旧所有权关闭实例、导致未重新初始化的 sink 后续静默失效的问题。
- 修复 sink 回调内使用文档化的 `configure_journal_sink(null)` 无法原子断开并延迟清理当前 sink 的问题；替换 sink 时，旧 sink 清理回调发起的置空请求也不会再被外层配置覆盖。
- 修复模块源码引用根级 Godot 治理文件时只能产生 `unowned_project_resource_reference`、或被迫把文件误填为模块扫描目录并导致分析不完整的问题。
- 修复 `GFTrajectoryMath` 将近似等速目标的非零二次项误降阶而漏掉远期拦截，以及按大尺度相对容差把负判别式钳制成伪命中的问题；等速退化现在按未平方速度判定，判别式只在 Godot `real_t` 的单个机器精度包络内恢复切线根，从而同时保留 `length()` 派生等速、舍入后的有效切线和真实 `no_solution` 边界。
- 修复 `GFStorageUtility` 读取旧版本数据时绕过派生类 `migrate_data()` 覆写的问题；自定义迁移继续经过公开扩展点，未覆写时仍保留注册迁移链的类型化失败结果。
- 修复 Save Profile 持续收到更新保存请求时，generation 屏障已经满足的最老读取仍可能长期饥饿的问题；就绪读取与等待保存现在采用有界轮转，未满足屏障的读取仍会等待覆盖它的保存终态。
- 修复超时写入在重试期间晚到成功后，逻辑保存仍可能被后续重试失败错误翻转的问题；已确认成功的 generation 会立即完成受覆盖请求，尚未终态的物理重试继续保留路径所有权直至结束。
- 修复 Session Trace 的通道、Provider、直接事件与 Provider capture 读取 `metadata` 时依赖原生字典键比较的问题；这些入口现在通过 GF 的 String/StringName 等价键规则读取原引用，并在转发 capture 选项前移除两种键形态，继续保持循环 metadata 的有界处理。
- 修复惰性诊断 Provider 引入后会拒绝历史 `diagnostic_providers` 自定义快照分区的问题；普通快照继续保留既有分区，只有显式提交非空 `diagnostic_provider_ids` 的当次快照由内置批次结果占用该顶层键，且不会注销已发布缓存。
- 修复总快照入口会在结构与循环预检前深复制 `diagnostic_provider_request`、从而可能触发递归上限的问题；请求现在先按原引用 fail closed 校验，失败时不执行任何项目 Provider。
- 修复当前契约已经是 schema v2 时，CLI `contract-migrate` 会把 `up_to_date` 计划当作成功应用并退出 0 的问题；没有待执行迁移时现在返回 `no_pending_contract_migration` 和非零退出码。
- 修复有限 `Projection` 已通过 Network transport 值校验、却无法进入确定性规范指纹而导致同步消息在接收端失败的问题；`GFDeterministicVariantSerializer` 现在以 16 个浮点分量稳定编码 `Projection`。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `GFMainThreadDispatchQueue.post_owned()`、`GFDeferredMutationQueue.record_owned()`，并移除 `post()` / `record()` 的 `options.owner`。旧设计同时保存弱 owner 与完整 Callable，Callable 指向或捕获同一个 `RefCounted` owner 时会破坏弱生命周期语义；动态 options 继续传入 `owner` 会 fail closed，不会静默退化为无条件执行。

### 🔧 API 变动说明 (API Changes)

- 新增公开类型 `GFWeakMethodInvocation`，提供 `invoked`、`owner_released`、`method_missing`、`failed` 四种稳定调用状态；`GFMainThreadDispatchQueue` 新增 `post_method()`，`GFDeferredMutationQueue` 新增 `record_method()`，均标记为 `@since unreleased`。两个旧式 `*_owned()` 入口及 `post()` / `record()` 的 `options.owner` 已直接移除。
- 新增公开类型 `GFPlatformContractDescriptor`、`GFPlatformContractMethodDescriptor`、`GFPlatformActivationIntent`、`GFPlatformAdapterConformance`、`GFNetworkLobbyOperationRequest`、`GFNetworkLobbyOperationHandle`、`GFNetworkLobbyOperationResult`、`GFMultiplayerPeerNetworkBackend` 和 `GFNetworkTransportMetrics`，均标记为 `@since unreleased`。
- `GFPlatformAdapter.configure()` 现在要求 `contract_ids` 与 `contract_descriptors` 一一对应，并新增 `activation_intent`、Contract Descriptor 查询和受保护发布入口；`GFPlatformRuntime` 新增 Activation Intent 接收、丢弃、按 Adapter 作用域消费、确认和容量配置 API。
- `GFNetworkLobbyBackend` 移除旧的同步 accepted `Dictionary` 操作与请求完成信号，改为 `invoke_operation()` 和受保护 `_dispatch_operation()`；Network 扩展版本升至 `5.0.0`。`GFNetworkLobbyService` 的 create/query/join/leave/metadata 入口改为返回 `GFNetworkLobbyOperationHandle`，`set_backend()` 从 `void` 改为 `bool`，`lobby_created`、`lobbies_queried`、`lobby_joined`、`lobby_left` 的参数统一改为 `GFNetworkLobbyOperationResult`，并移除 `GFNetworkLobbyJoinResult`。
- `GFNetworkBackend` 新增 `get_transport_metrics()` 与受保护指标扩展点；`GFNetworkUtility` 新增传输指标采集信号、采样配置、手动采集和有界历史查询 API。
- `GFThumbnailRenderRequest.Kind` 末尾新增 `CANVAS_ITEM_IMAGE` 和 `CANVAS_ITEM_TEXTURE`，既有枚举值保持不变。
- 新增 `GFThumbnailRenderRequest.for_canvas_item_image()`、`for_canvas_item_texture()` 及相应来源、边界和留白读取入口。
- 新增 `GFThumbnailRenderer.render_canvas_item()` 与 `render_canvas_item_texture()`。
- 新增公开类型 `GFSpatialCanvas2D`，以及视图、坐标变换、网格、条目查询、选择和放置会话入口；均标记为 `@since unreleased`。它是项目显式挂载内容与提交输入的运行时 `Control`，不是编辑器、项目实体仓库或业务命令执行器。
- 新增公开类型 `GFAnalyticsEventSchema`、`GFAnalyticsSchemaRegistry` 和 `GFAnalyticsOutboxAdapter`；`GFAnalyticsUtility` 新增永不为空的 `schema_registry` 与 `track_versioned(event_name, schema_version, properties)`，`GFRequestOutboxUtility` 新增 `enqueue_with_report(envelope, require_persistence)` 与 `max_storage_bytes`，`GFSupportReportWorkflow` 新增固定信封分类入口 `handles_request(envelope)`；均标记为 `@since unreleased`。
- 新增公开类型 `GFAssetCollection` 和 `GFStorageFailoverBackend`；均标记为 `@since unreleased`，不改变既有调用入口默认行为。
- 新增公开类型 `GFContentPackageQuery`、`GFContentPackageQueryResult`、`GFContentPackageAssetCatalogProvider`、`GFAssetCatalogRuntime` 和 `GFAssetCatalogMount`；`GFContentPackageCatalog` 新增 `query_packages()`，Content Package Utility 新增 owner-scoped root API，Asset Catalog Runtime 支持原子 `replace_mount_catalog()`。
- 新增公开类型 `GFDiagnosticProviderResult`、`GFDiagnosticSnapshotProvider`、`GFSessionTraceUtility`、`GFSessionTraceRecipe`、`GFSessionTraceChannelDefinition`、`GFSessionTraceCheckpoint` 与 `GFUIRoutePreloadUtility`，以及 `GFDiagnosticsUtility` 的惰性 Provider 注册/采集 API、`GFUIRoute.adjacent_route_ids`、`get_adjacent_route_ids()` 和 `GFUIRouterUtility.build_preload_plan()`；均标记为 `@since unreleased`。
- 新增公开类型 `GFUIRouteOperation`、`GFUIRouteResult`、`GFUIRouterUtility.route_operation_completed` 和 `PRELOAD_*` 常量；`push_route_async()`、`replace_route_async()` 新增 `async_options` 并从 `void` 改为返回句柄。
- 新增公开类型 `GFTrajectoryMath`，以及运动预测、恒速拦截和有界公式采样入口；均标记为 `@since unreleased`，不改变既有 Steering 行为。
- 新增公开类型 `GFNetworkInputFrame`、`GFNetworkSimulationAdapter` 与 `GFNetworkSyncCoordinator`，以及显式配置、peer 注册、本地输入、权威/预测 tick、recipient-bound 消息、重同步状态和有界调试快照入口；均标记为 `@since unreleased`。既有 Network transport、snapshot、delta/patch 与 lobby API 不变。
- 新增公开类型 `GFRuntimeAgentEnvironment`，以及 endpoint 注册/目录、session 签发/撤销、`invalidate_policy_context()`、版本化请求执行、安全审计和调试快照入口；均标记为 `@since unreleased`。该类型绑定创建线程，只保护不可信请求进入受信同步 handler 的协议边界，不是 OS sandbox。
- 新增公开类型 `GFSaveProfile`、`GFSaveSectionProvider`、`GFSaveRecoveryPolicy`、`GFSaveProfileOperation`、`GFSaveProfileResult`、`GFSaveRollbackFailure` 和 `GFSaveProfileUtility`；Save 扩展安装器会自动注册 Profile Utility，既有 Save Graph 和 Slot API 不变。
- 新增公开类型 `GFStorageAsyncOperation`、`GFStorageAsyncResult`，以及 `GFStorageUtility.save_data_request_async()`、`load_data_request_async()`、`canonicalize_data_file_name()`；`GFStorageReadResult` 新增只追加的 `FailureKind` 与 `failure_kind`。
- `GFTagExpression.expressions` 的公开存储类型从 `Array[GFTagExpression]` 改为 `Array[Resource]`；元素语义仍严格限定为 `GFTagExpression` 或 null，方法参数和返回值不变。
- `GFUIRoute.get_route_id()` 以及 Router 的注册、查询、打开信号和异步 pending 身份统一去除 route ID 首尾空白。
- AI Developer 项目契约从 schema v1 升为 v2，项目快照从 schema v3 升为 v4，AI Developer Kit 工具协议同步升为 4.0.0；旧契约不保留双轨解析，旧 Snapshot 不进入迁移路径。
- GF 开发身份从 `9.1.0-dev.0` 升为 `10.0.0-dev.0`，用于明确承载项目契约 v2、项目快照 v4 与相关破坏性工具协议变化；本条只切换开发线，不创建正式版本或发布标签。

### 📘 升级指南 (Migration Guide)

- 通过 `post_owned(owner, Callable(owner, method))`、`record_owned(owner, Callable(owner, method))`、`post/record(options.owner)` 或捕获 owner 的 lambda 延迟调用 owner 自身方法时，必须改用零参数 `post_method(owner, method_name)` / `record_method(owner, method_name)`。无 owner 的独立 Callable 继续使用 `post()` / `record()`。需要携带参数的自定义容器应保存 `GFWeakMethodInvocation`，只在实际执行点调用 `invoke(arguments)`；不要把 owner、Callable、Signal 或对象图重新塞进长期 options/metadata 绕过弱生命周期。
- 旧 Lobby Backend 应把 create/query/join/leave/metadata 覆写合并到 `_dispatch_operation(request, handle)`，在 Provider callback 中调用 `_succeed_operation()` / `_fail_operation()`；项目调用方保存返回 Handle 并读取 `GFNetworkLobbyOperationResult`，不再等待无法按请求关联的旧完成信号。
- 新 Platform Adapter 应为正式 Contract 提供 Descriptor 并运行 `GFPlatformAdapterConformance.inspect()`；启动、邀请和 Join 回调转换为稳定 ID 的 `GFPlatformActivationIntent`。SDK 已提供 `MultiplayerPeer` 时采用通用 Backend 并明确所有权，不要在 GF 内新增 Provider 命名 Manager。
- 读取传输指标前先调用 `has_metric()`；缺少 RTT 等指标表示 Backend 不支持或当前未知，不能把 `get_metric()` 的默认零值解释为观测结果。长时间会话应设置有界采样容量。
- 既有 3D 缩略图、资产目录、存储后端与同步代码无需迁移。需要 2D 预览、有序资产集合或故障转移时显式采用新入口即可。
- 既有项目画布与关卡编辑器无需迁移。只有需要通用运行时视图、稳定选择或受控放置会话时才安装 `gf.standard.spatial.canvas`（`gf.preset.2d_toolkit` 现已包含它），把项目可视节点显式挂到 `get_content_root()`，并由项目 Adapter 负责同步边界、占位校验、历史、权限和最终模型提交；不要把同步回调用于 IO、异步业务或回调重入。
- 既有单调用方 Content Package root 入口继续使用公开 manual owner scope；多模块、热插拔内容或场景生命周期应迁移到 `register_source_root_for_owner()` / `replace_owner_source_roots()`，并在模块退出时调用 `clear_owner_source_roots()`。
- 既有 `GFAnalyticsUtility.track()`、自定义 transport 和 `GFRequestOutboxUtility.enqueue()` 无需改签名；但依赖 `batch_size <= 0`、`max_queue_size <= 0`、超过 4096 字符的 client id，或在 client id / 事件名中保留 C0/DEL 的配置和数据应先迁移为有效稳定值。只有需要稳定事件契约时才注册 `1..2_147_483_647` 范围内的精确 `(event_name, schema_version)` 并调用 `track_versioned()`；需要离线移交时为 Analytics 配置专用 Outbox。Adapter v1 不保留自定义 payload 顶层字段，项目协议若依赖这些字段应继续使用自定义 transport；Schema 不自动迁移旧事件。相同身份已经进入 failed store 时 Adapter 返回 `already_failed`，项目应显式审查或清理；Outbox 不提供 exactly-once，PII、consent、鉴权和远端幂等仍须由项目显式处理。
- 自定义 Support Report 若自行提供 `report_id`，应迁移为 `1..4096` 字符且不含 C0/DEL 的稳定 String/StringName；共享 Outbox 的项目 transport 应使用 `GFSupportReportWorkflow.handles_request()` 路由，自动装配不会覆盖已有 transport，非匹配请求会失败关闭。
- 运行时资产目录默认拒绝重复 `asset_id`。只有明确设计了覆盖层时，才在首个 Mount 前配置 `CONFLICT_KEEP_HIGH_PRIORITY`；不要依赖 Provider 注册时序决定胜者。
- 自定义 `_draw()` 或无法可靠推断范围的 2D 节点应传入显式 `content_bounds`；多后端复制与冲突处理继续使用 `GFStorageSyncUtility`，不要把故障转移当作原子双写。
- 既有 UI 路由无需迁移；只有需要候选页面预热时才声明 `adjacent_route_ids` 并显式执行生成的资产计划。需要发布后问题轨迹时，应由项目定义最小事件 schema、玩家许可和保留策略，再显式采用 `GFSessionTraceUtility`。
- 既有诊断快照无需迁移。只有无法安全长期缓存的状态才实现 `GFDiagnosticSnapshotProvider`，并由故障点或支持报告入口显式请求；需要跨系统固定轨迹预算和检查点时，在首次会话前应用 `GFSessionTraceRecipe`，不要把上传、许可或业务恢复逻辑写进配方。
- 历史代码通过 `publish_snapshot_section()` 使用 `diagnostic_providers` 分区 ID 时无需迁移：普通快照继续返回该缓存；只有当次显式请求惰性 Provider 时，同名顶层键才由内置批次结果确定性覆盖，后续普通快照仍恢复既有分区。
- 既有曲线、Steering、发射体和节点移动逻辑无需迁移。只有需要结构化未来状态、拦截时间或公式点集时才显式采用 `GFTrajectoryMath`；绘制、物理推进、速度继承、重力拦截和业务命中规则继续由项目负责。
- 既有自定义网络同步无需迁移。采用 `GFNetworkSyncCoordinator` 时，先为 `gf.sync` 注册可靠且有限的 raw packet 通道，保留 `GFNetworkUtility.validator`，由受信 session 签发不可复用 epoch 并显式注册 replica；项目 Adapter 必须实现纯校验、状态回滚和基于 actual peer 的控制权判断，并允许协调器在收包与目标 authority tick 各执行一次授权校验。`RESYNC_REQUIRED` 使用全新 epoch 重建状态，`FAULTED` 必须重建 coordinator 与 Adapter。
- 既有诊断命令、开发者控制台与 AI Developer 工具无需迁移，也不得直接当作 Runtime Agent 权限入口。只有明确需要运行时自动化时才安装 `gf.standard.agent_environment`，在禁用态注册最小 endpoint 与 closed Schema，由项目策略负责业务授权/批准，并由外层传输负责身份认证和凭据保护。
- 既有 Save Graph、Slot 和直接 Storage 调用无需迁移。需要跨模块自动保存时，为每个稳定数据边界实现一个可回滚 `GFSaveSectionProvider`，注册 Profile 和完整迁移链；不要把缺失、损坏或未来版本统一重置为空存档。
- 历史配置若有意使用带首尾空白的 route ID，需迁移为去除空白后的稳定 ID；规范化后重复的 ID 会指向同一注册身份，不应再依赖空白区分页面。
- 直接读取 `GFTagExpression.expressions` 时，应把元素先用 `is GFTagExpression` 收窄再使用；项目若依赖变量的静态 `Array[GFTagExpression]` 类型，应改为通过 `configure_all()`、`configure_any()`、`configure_none()` 提交强类型输入，或显式构造经过校验的 `Array[Resource]`。
- 严格 warning 项目必须接收 `push_route_async()` / `replace_route_async()` 的新返回值；需要结果时保存 `GFUIRouteOperation`，只需 fire-and-observe 全局信号时也应赋给带下划线的局部变量。打开前预加载必须显式选择策略，默认仍为 `PRELOAD_NONE`。
- AI Developer 工具协议 3.x 的 schema v1 契约必须先运行 `contract-migration-plan`，审阅 `pending_review`、`owner: project` 默认值和完整候选，再由用户在交互终端用计划返回的 `plan_sha256` 执行 `contract-migrate` 并输入完整确认短语；随后确认 owner、Recipe 与验收条件并运行 `validate`。
- Snapshot v4 是有意的破坏性生成协议升级：消费方应先升级到 AI Developer 工具协议 4.x，再重新生成快照；不要迁移 v3、复制字段或把观测结果反写为项目意图。独立 Kit ZIP 版本仍与 GF Framework 版本一致。
- 从 `9.x` 开发线升级时，应同步更新 GF 插件与扩展清单到 `10.0.0-dev.0`，并重新生成 AI Developer Kit catalog；稳定版发布时间与版本号仍由后续独立发布流程决定。
- 旧契约若把模块、Adapter、profile 或验证路径放在符号链接/junction 后方，应改为项目根内不经过链接的真实相对路径；工具不会为链接别名保留兼容分支。
- 模块和 Adapter 所有权根若包含尾点/空格、Windows 保留名称、通配字符或大小写变体的 `addons/gf`，应迁移为跨平台规范目录；这些别名不再保留兼容解析。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/kernel/core/gf_weak_method_invocation.gd`
- `addons/gf/standard/common/gf_main_thread_dispatch_queue.gd`
- `addons/gf/standard/common/gf_deferred_mutation_queue.gd`
- `docs/zh/standard/utilities/runtime/time-signal-pool/async-primitives.md`
- `addons/gf/standard/foundation/platform/`
- `addons/gf/standard/platform/gf_platform_adapter.gd`
- `addons/gf/standard/platform/gf_platform_runtime.gd`
- `addons/gf/standard/platform/gf_platform_adapter_conformance.gd`
- `addons/gf/extensions/network/backends/`
- `addons/gf/extensions/network/runtime/gf_network_transport_metrics.gd`
- `addons/gf/extensions/network/session/gf_network_lobby_*.gd`
- `addons/gf/tools/ai_developer/templates/adapters/platform/`
- `addons/gf/kernel/editor/gf_thumbnail_render_request.gd`
- `addons/gf/kernel/editor/gf_thumbnail_renderer.gd`
- `addons/gf/standard/utilities/spatial_canvas/`
- `packages/standard/gf.standard.spatial.canvas.json`
- `docs/zh/standard/input-flow/spatial-canvas-2d.md`
- `addons/gf/standard/foundation/tags/gf_tag_expression.gd`
- `addons/gf/standard/common/gf_async_wait_support.gd`
- `tests/gf_core/support/gf_gut_*.gd`
- `addons/gf/standard/utilities/assets/gf_asset_collection.gd`
- `addons/gf/standard/utilities/assets/gf_asset_catalog_runtime.gd`
- `addons/gf/standard/utilities/assets/gf_asset_catalog_mount.gd`
- `addons/gf/extensions/content_package/resources/gf_content_package_query.gd`
- `addons/gf/extensions/content_package/runtime/gf_content_package_query_result.gd`
- `addons/gf/extensions/content_package/runtime/gf_content_package_asset_catalog_provider.gd`
- `addons/gf/standard/utilities/storage/gf_storage_backend.gd`
- `addons/gf/standard/utilities/storage/gf_storage_failover_backend.gd`
- `addons/gf/standard/utilities/storage/gf_storage_utility.gd`
- `addons/gf/standard/utilities/storage/gf_storage_async_operation.gd`
- `addons/gf/standard/utilities/analytics/gf_analytics_config.gd`
- `addons/gf/standard/utilities/analytics/gf_analytics_event_schema.gd`
- `addons/gf/standard/utilities/analytics/gf_analytics_schema_registry.gd`
- `addons/gf/standard/utilities/analytics/gf_analytics_utility.gd`
- `addons/gf/standard/utilities/io/gf_analytics_outbox_adapter.gd`
- `addons/gf/standard/utilities/io/gf_request_outbox_utility.gd`
- `addons/gf/standard/utilities/debug/gf_support_report_workflow.gd`
- `docs/zh/standard/utilities/io/config-remote-outbox/analytics-events.md`
- `docs/zh/standard/utilities/io/config-remote-outbox/request-outbox.md`
- `docs/zh/standard/utilities/runtime/debug-observability/support-notifications/support-report.md`
- `addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd`
- `addons/gf/standard/utilities/debug/gf_session_trace_utility.gd`
- `addons/gf/standard/utilities/debug/gf_diagnostic_snapshot_provider.gd`
- `addons/gf/standard/utilities/debug/gf_diagnostic_provider_result.gd`
- `addons/gf/standard/utilities/debug/gf_session_trace_recipe.gd`
- `addons/gf/standard/utilities/debug/gf_session_trace_channel_definition.gd`
- `addons/gf/standard/utilities/debug/gf_session_trace_checkpoint.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route_preload_utility.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route_operation.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route_result.gd`
- `addons/gf/standard/utilities/ui/gf_ui_router_utility.gd`
- `addons/gf/standard/foundation/math/gf_trajectory_math.gd`
- `addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd`
- `addons/gf/extensions/network/simulation/gf_network_input_frame.gd`
- `addons/gf/extensions/network/simulation/gf_network_simulation_adapter.gd`
- `addons/gf/extensions/network/simulation/gf_network_sync_coordinator.gd`
- `docs/zh/extensions/network-turnbased/network-sync-coordinator.md`
- `addons/gf/standard/utilities/agent/gf_runtime_agent_environment.gd`
- `docs/zh/standard/utilities/runtime/agent-environment.md`
- `addons/gf/extensions/save/profile/`
- `docs/zh/extensions/save-graph/save-profile-runtime.md`
- `docs/zh/extensions/save-graph/save-profile-adr.md`
- `addons/gf/tools/ai_developer/gf_ai/cli.py`
- `addons/gf/tools/ai_developer/gf_ai/dependencies.py`
- `addons/gf/tools/ai_developer/knowledge/capabilities.json`
- `addons/gf/tools/ai_developer/knowledge/recipes.json`
- `addons/gf/tools/ai_developer/schemas/project_contract.schema.json`
- `addons/gf/tools/ai_developer/schemas/project_snapshot.schema.json`
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `tools/gf_maintenance.py`
- `tools/gf_parallel_validation.py`
- `tools/gf_package_artifact_set.py`
- `tools/gf_process_supervisor.py`
- `tools/gf_repository_policy.py`
