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

**版本概述**：本轮新增类型化音频播放区间与循环点和共享资源 admission Broker，补充 Headless 服务探针和周期环境表现的项目组合配方，修复并加固 AI Developer 的项目 Adapter 依赖边界，同时把 Changelog 与安全扫描抑制约束转为可执行维护门禁，并收紧 Save Profile 准备、可选依赖、后台回调所有权、按 key 并发、场景邻居稳定帧、渲染预热和音频释放契约；框架只提供可验证的通用机制，不内置部署协议、环境业务模型或轮询式音频模拟。

### 🚀 新增特性 (Added)

- 新增 `GFAudioPlaybackRegion` 与 `GFAudioPlaybackRegionResult`：以类型化资源表达播放起点、自然或显式终点、forward / ping-pong / backward 循环和循环起点，以 `VALID` 区分“结构已验证”和 `APPLIED`“执行者已接受”，严格区分 `INVALID` 与 `UNSUPPORTED`，并按 WAV、Ogg Vorbis、MP3、Playlist 和其他流的 Godot 原生能力返回逐请求结果。
- `GFAudioClip` 新增 `playback_region`；BGM、环境音、普通 SFX 与 2D/3D 空间 SFX 共用请求快照、私有流复制和原生播放准备流程。`GFAudioUtility` 新增拒绝信号、最近拒绝报告与 session 区间调试快照。
- `GFAudioBackendCapability` 新增播放区间协议发现能力，`GFAudioBackend.evaluate_playback_region()` 提供无副作用的逐片段、逐通道协商；粗粒度能力声明不能替代具体请求评估。
- 新增 Headless 服务健康/探针组合配方：组合惰性诊断 Provider、有界会话字段与类型化传输指标，由项目 Adapter 决定 liveness/readiness、传输协议、鉴权和部署政策；Backend 指标补充使用通用执行预算，并对总指标、自定义指标和 ID 长度设置绝对上限。
- 新增周期环境表现组合配方：组合可注入时钟、项目环境样本、Shader Profile、接口快照与 Binder；周期、天气、天文、时区和持久化策略继续由项目负责。
- AI Developer Capability / Recipe 知识目录升级到 `1.8.0`，加入两份组合配方的可搜索边界，并让音频能力目录认识类型化播放区间与循环点。
- `GFArchitecture` 新增 `find_model()`、`find_system()` 与 `find_utility()` 静默可选查询：非严格模式复用普通父链和 alias 规则，严格模式停止本地但不报告 required miss。
- `GFAsyncKeyedGate` 新增 `try_request_lease()` 与 `STATUS_BUSY`：无法在当前主线程边界立即提交时，不创建 waiter、请求 ID 或 completion，不发请求生命周期信号，也不改变公平游标。
- 新增 `GFResourceBroker` 与 `GFResourceLease`：为 Asset、Scene 与 BackgroundWork 提供显式共享、无单例的 threaded ResourceLoader admission；不同资源请求使用有界严格 FIFO，同资源身份复用底层请求并保留独立消费者取消，已发起且失去消费者的请求继续 drain 到 Godot 终态。
- `GFResourceBroker` 公开默认/绝对活动与等待预算常量；活动请求配置限制为 1..64，等待请求配置限制为 1..4096，队首 exclusive / require-idle 请求和排队中同路径约束升级都不会被后续共享请求绕过。
- Save Profile 新增一次性 opaque `GFSaveProfileRequest`：`take_ownership()` 分别接管 document metadata、Provider context 与 result metadata，不提供 payload getter；合法边界只做 O(1) claim，成功后调用方必须放弃三个输入图的全部嵌套 alias。
- Save Profile 新增 `GFSaveSectionSnapshot` 与 `GFSaveSectionSnapshotOperation`：Provider 通过 `begin_save_snapshot()` / `_begin_save_snapshot()` 在主线程按 work unit 分片生成不可变 section Snapshot；固定且很小的载荷可用 `make_completed_snapshot()`，大型载荷必须实现有界 Operation。
- Storage 新增 `GFStoragePayloadTransfer` 与 `save_payload_request_async()`：以 opaque 单所有者句柄逻辑移交纯 Variant 载荷，并允许同一冻结绑定上的 timeout-detached attempt 与有界重试共享只读 Snapshot。
- `GFSaveProfileUtility` 新增全局准备 work budget、单 profile slice budget 和软时间 budget；`GFSaveProfileResult` 新增准备耗时、Storage attempt 累计耗时与准备 work units 诊断。
- `GFStorageAsyncResult` 新增 `WriteFailureKind` 与隔离的 worker 载荷预检报告，区分非法请求、不可持久化载荷、编码、线程、生命周期和 IO 故障。

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
- `GFNetworkBackend.get_transport_metrics()` 现在把基础计数与 Adapter 补充阶段隔离；补充 Hook 超过执行预算、未为新增指标消费步骤或突破指标容量时，本次调用失败关闭为基础快照，不把不可控工作带入探针路径。
- `GFBackgroundWorkUtility` 在接受任务后强持有 `RefCounted` worker/apply callback target，并分别在线程 join 和任务终态释放，避免排队任务依赖调用方局部变量寿命。
- `GFRenderWarmupUtility` 将清单显式提供的 `entries_per_tick` 在入队时钳制并固定；未覆盖时继续读取当前全局默认值，正常 `tick()` 只消费 FIFO 队首自己的预算，显式 `process_queue()` 继续提供跨清单总预算。
- `GFAssetUtility`、`GFSceneUtility` 与 `GFBackgroundWorkUtility` 改为从 Architecture 解析或由项目显式注入 `GFResourceBroker`；独立使用必须显式创建 Broker，框架不再为每个消费者隐式创建互不协调的私有加载通道。缺少 Broker 的真实请求统一以 `ERR_UNCONFIGURED` 失败关闭，headless Scene 不再绕过 admission；Asset/Scene dispose 会先关闭 admission，阻止同步通知重入遗留 Lease。
- Scene 图谱自动邻居预载改为在目标 `scene_changed` 后等待首个稳定 process/render 边界，再以 exclusive + require-idle 进入共享 Broker；新切换、配置变更、关闭和 dispose 会取消旧 generation，批量登记在每个同步可重入边界重验 generation，手动与自动同路径兴趣使用独立 Lease 所有权。
- `save_profile(profile_id, request)` 先验证 Profile、能力和生命周期，再 O(1) claim Request、分配 generation 和入队；边界拒绝不会消费 Request，未初始化或已 claim 的 Request 返回 `invalid_request`。Save Operation 只持有 result metadata，最新 document metadata/context 由状态直接接管并在开始准备时通过 assignment 移入当前 generation。`load_profile()` 与 `flush_profile()` 继续只在调用栈内完成校验、屏障捕获和入队。
- 保存 Provider 从后续 `tick()` 开始按全局预算公平轮转，软时间预算只阻止启动下一个 slice，不伪装成可抢占执行。准备完成后文档逻辑 move 到 `GFStoragePayloadTransfer`；Storage worker 在本次新写入的编码与 temp、marker、final 事务提交前执行有界纯 Variant 图预检和物化，既有事务 recovery 与目录初始化仍是独立前置生命周期。Save 终态不再保留完整文档副本，完整文档只由 load 结果返回。
- Storage 首次 claim transfer 时冻结 Storage 实例、规范文件名、canonical target file-family identity 和 codec options；每个物理 attempt 取得独立只读 lease，最后一个 lease 结束且 Profile 释放 generation 后才清空载荷，重试不再重新采集 Provider 或复制完整文档。
- Storage worker 载荷预检现在同时限制 128 层深度、1,000,000 个值和 64 MiB 估算原始字节，拒绝 Object/Script typed container 元数据；诊断只保留结构索引、类型与预算计数，Save 通过隔离 Adapter 映射 section，不输出 key/value 或 key 派生摘要。

### 🐛 Bug 修复 (Fixed)

- 修复 AI Developer 依赖分析只编译 Module roots、导致合法 Module → Adapter 资源引用被误报为未归属的问题；Adapter root 与其中声明的 `class_name` 现在作为目标所有权进入同一有界索引，但 Adapter 仍不作为依赖源或模块循环节点，缺失、不安全、不可读、歧义及预算耗尽继续失败关闭。
- 修复依赖所有权计划允许 Module/Adapter ID 占用 `gf`、`godot` 保留 token，以及目录枚举错误被 `os.walk()` 静默跳过的问题；共享命名空间现在统一拒绝保留与重复 ID，任一后代枚举失败都会使分析不完整。Module 与 Adapter 扫描只允许经路径安全校验的普通 `.gdignore` 文件剪除根或后代子树；链接、损坏或不可验证的同名条目不会再静默隐藏源码，而会计入不安全路径并使分析不完整。
- 修复安全测试把合成夹具命名为真实敏感数据、导致 CodeQL 将边界与脱敏验证误判为明文持久化的问题；无关凭据检测的边界测试改用 opaque canary，需要敏感形状路径的测试在内存中构造 synthetic canary，且不再依赖任何扫描抑制。
- 修复 CodeQL 策略把普通 `LGTM`、步骤说明中的 `paths` / `queries` 和 shell block 行尾反斜杠误判为 suppression/config，以及把 URL fragment 的 `#` 错当注释后漏过禁用默认查询的问题；YAML key lexer 现在同时覆盖 block、flow、quoted、Unicode escape、quoted continuation 与多行显式 key，并在原始输入、线性 Unicode 解码后的原始文本及续行拼接后的逻辑行上累计冒号、引号与标签探测预算。续行改为分块后单次连接，编码或跨行构造的 probe 不能在 normalization 阶段恢复二次复杂度。
- 修复 Utility 的有界 Bank resolver 用最右子串截断多字符 `fallback_separator`、导致结果偏离 `GFAudioBank.resolve_clip()` 的问题；运行时解析现在保留从左到右、非重叠且忽略空片段的既有分隔语义，同时继续限制标识长度、分隔符长度与最多 16 次回退。
- 修复异步等待生命周期测试把 1ms 墙钟预算与 deferred free 调度顺序绑定的竞态；测试现在先用 timeout pause 建立等待已挂起的握手，再同步释放 continuation owner，稳定验证失效检查必须先于同轮已到期 timeout 仲裁。
- 修复后台任务只保存 `Callable`、导致短生命周期 `RefCounted` worker 或 apply target 在线程执行前释放的问题；取消、失败和成功路径现在统一清理 callback 所有权。
- 修复 `GFRenderWarmupUtility.queue_manifest()` 保存但正常帧推进忽略 `entries_per_tick` 的问题，并防止显式零或负清单预算永久停滞。
- 修复 `GFDiagnosticsUtility` 在 strict architecture 中通过 reporting lookup 探测可选 Console、Log 和工具快照贡献者，导致合法缺失被误报为必需依赖的问题。
- 修复场景树先释放 root-owned BGM 播放器后，`GFAudioUtility.dispose()` 在有效性检查前构造 typed array 而触发 freed-instance 转换错误的问题；两条 BGM 清理路径与重复 dispose 都收敛到幂等终态。
- 修复场景切换完成帧立即启动邻居预载时与活动 Asset warmup 重叠，可能导致 `.tscn` 间歇解析失败的问题；邻居请求现在必须经过目标场景确认、稳定帧和共享 Broker idle 边界。
- 修复 `save_profile()` 在提交调用栈内同步遍历大型 Provider、可造成超过 100ms 主线程停顿的问题；请求现在先返回句柄，再由生命周期 tick 在显式预算内推进准备。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `play_bgm_with_options()` 的 `loop` / `playback_region` 通用选项，并保留事件 metadata/options 中的同名键；继续传入会在资源加载和后端派发前失败关闭，类型化区间只能来自 `GFAudioClip.playback_region`。
- 移除框架内部 `gf_threaded_resource_coordinator.gd` 与 `gf_threaded_resource_operation.gd`；不保留双轨协调实现，统一由公开 `GFResourceBroker` / `GFResourceLease` 承担跨 Utility 所有权与 admission。
- 移除 `GFSaveProfileUtility.save_profile(profile_id, metadata, context)` 字典重载；保存调用统一改用一次性 `GFSaveProfileRequest`，不保留隐式复制兼容路径。
- 移除 `GFSaveProfileResult.STATUS_GATHER_FAILED` / `gather_failed`；Snapshot 创建、协作式推进与 worker payload 预检失败统一使用 `STATUS_PREPARATION_FAILED` / `preparation_failed`，不保留 alias。
- 移除 `GFSaveSectionProvider.gather_section()`、`_gather_section()`、`GFSaveProfileUtility.STATE_GATHERING` 及读取回滚对保存采集的隐式回退；保存 Provider 必须采用 Snapshot Operation，启用读取的 Provider 必须显式实现 `_capture_section()`。

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

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/standard/utilities/audio/gf_audio_playback_region.gd`
- `addons/gf/standard/utilities/audio/gf_audio_playback_region_result.gd`
- `addons/gf/standard/utilities/audio/gf_audio_utility.gd`
- `addons/gf/standard/utilities/audio/gf_audio_backend.gd`
- `addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd`
- `addons/gf/standard/utilities/audio/gf_audio_clip.gd`
- `addons/gf/kernel/core/gf_architecture.gd`
- `addons/gf/standard/common/gf_async_keyed_gate.gd`
- `addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd`
- `addons/gf/standard/utilities/display/gf_render_warmup_utility.gd`
- `addons/gf/standard/utilities/jobs/gf_background_work_task.gd`
- `addons/gf/standard/utilities/jobs/gf_background_work_utility.gd`
- `addons/gf/standard/utilities/assets/gf_resource_broker.gd`
- `addons/gf/standard/utilities/assets/gf_resource_lease.gd`
- `addons/gf/standard/utilities/assets/gf_asset_utility.gd`
- `addons/gf/standard/utilities/scene/gf_scene_utility.gd`
- `addons/gf/standard/utilities/storage/gf_storage_payload_transfer.gd`
- `addons/gf/standard/utilities/storage/gf_storage_async_operation.gd`
- `addons/gf/standard/utilities/storage/gf_storage_async_result.gd`
- `addons/gf/standard/utilities/storage/gf_storage_utility.gd`
- `addons/gf/extensions/save/document/gf_save_section.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_request.gd`
- `addons/gf/extensions/save/profile/gf_save_payload_validation_adapter.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_operation.gd`
- `addons/gf/extensions/save/profile/gf_save_section_provider.gd`
- `addons/gf/extensions/save/profile/gf_save_section_snapshot.gd`
- `addons/gf/extensions/save/profile/gf_save_section_snapshot_operation.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_utility.gd`
- `addons/gf/extensions/save/profile/gf_save_profile_result.gd`
- `addons/gf/extensions/save/gf_extension.json`
- `packages/standard/gf.standard.storage.json`
- `addons/gf/extensions/network/backends/gf_network_backend.gd`
- `addons/gf/extensions/network/runtime/gf_network_transport_metrics.gd`
- `addons/gf/extensions/network/gf_extension.json`
- `addons/gf/tools/ai_developer/gf_ai/constants.py`
- `addons/gf/tools/ai_developer/gf_ai/contract.py`
- `addons/gf/tools/ai_developer/gf_ai/dependencies.py`
- `addons/gf/tools/ai_developer/gf_ai/snapshot.py`
- `addons/gf/tools/ai_developer/knowledge/recipes.json`
- `tools/gdscript_api_parser.py`
- `tools/gf_maintenance.py`
- `docs/zh/editor/tools/ai-developer.md`
- `docs/zh/extensions/save-graph/save-profile-runtime.md`
- `docs/zh/extensions/save-graph/save-profile-adr.md`
- `docs/zh/extensions/network-turnbased/network-transport/backend-session.md`
- `docs/zh/standard/utilities/io/storage-snapshot/storage-utility.md`
- `docs/zh/standard/utilities/io/assets-jobs-warmup/resource-broker.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/scene-flow/preload-cache-map.md`
- `docs/zh/standard/utilities/runtime/audio/backend-events.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/shader-parameter-profile.md`
- `tests/gf_core/extensions/network/test_gf_network_extension.gd`
- `tests/gf_core/maintenance/test_api_surface_contract_validation.gd`
- `tests/gf_core/extensions/save/test_gf_save_profile_preparation.gd`
- `tests/gf_core/extensions/save/test_gf_save_profile_scheduler.gd`
- `tests/gf_core/extensions/save/test_gf_save_payload_validation_adapter.gd`
- `tests/gf_core/extensions/save/test_gf_save_profile_utility.gd`
- `tests/gf_core/standard/utilities/storage/test_gf_storage_payload_transfer.gd`
- `tests/gf_core/standard/utilities/assets/test_gf_resource_broker.gd`
- `tests/gf_core/standard/utilities/scene/test_gf_scene_preload_map.gd`
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
