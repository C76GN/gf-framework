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

## [9.0.0] - 2026-07-20

**版本概述**：以 9.0 主版本收紧持久化、生成物、平台适配、资源所有权、模块依赖和时间域契约，同时继续完善配置编译、AI 项目上下文、诊断、安全边界与确定性运行能力。

### 🚀 新增特性 (Added)

- 新增可选 `gf.tool.ai_developer` 项目侧 AI 开发套件：以严格 `.gf/project_contract.json` 保存项目意图，以独立观测快照报告已安装 GF、模块根和声明漂移，并提供与当前 GF 版本绑定的完整公开 API 索引、通用能力目录、实现 Recipe、包/模块/类查询入口，以及多种 Agent 宿主的可逆托管适配器。
- AI Developer Kit 新增证据式反馈状态机：候选先经过项目/框架/文档/Adapter 边界分类、严格 Schema、预算与默认/项目脱敏，再生成绑定契约和载荷 SHA-256 的受控草稿；网络默认关闭，Agent 协议不暴露提交，最终 GitHub Issue 必须在交互式终端由用户精确确认并在提交前查重。GitHub 同步新增框架 bug、通用能力、文档缺口和 Adapter 契约 Issue Forms。
- AI Developer Kit 新增有界项目模块依赖分析：以编译后的长根优先 ownership matcher 和 GDScript token 集合识别 class/path 证据，报告跨模块边、禁止或未声明依赖、循环、重复 class、未归属引用与扫描完整性；快照只报告事实，不反向修改项目契约。
- 新增统一 `GFProjectArtifactPaths` 与 JSON 策略镜像，固定 `res://generated/**` 源码产物、`.gf/project_contract.json` 项目意图和 `.gf/ai/**` 可重建观测三类边界。
- 新增 provider-neutral 的 `gf.standard.platform` 包，以及 `GFPlatformRuntime`、`GFPlatformAdapter` 和 `GFPlatformRequestHandle`：提供显式 contract 路由、能力/上下文、生命周期转发、初始化状态、取消、超时和唯一请求终态；供应商 SDK 与业务逻辑继续留在外部 Adapter 或项目层。
- `GFAssetCatalog` 新增稳定 ID 到 `GFAssetPreloadPlan` 的桥接，`GFAssetUtility` 新增 `GFAssetLoadSession` / `GFAssetLoadSessionResult`，通过唯一 staging group 实现成组资源的全成功提交、失败回滚和共享缓存所有权保护。
- Save 扩展新增 `GFSaveDocument`、`GFSaveSection`、`GFSaveDocumentSchema`、`GFSaveMigrationStep`、`GFSaveMigrationRegistry`、`GFSaveMigrationResult` 和 `GFSaveDocumentReadResult`，为项目存档提供精确容器、独立 section 版本、相邻迁移链、隔离执行和无半成品失败结果。
- 新增 `GFClock` 与 `GFManualClock`，明确区分进程内单调时间和可持久化 Unix 时间；`GFTimeProvider` 现在同时提供时钟注入和时间缩放协议。
- 新增 `GFStorageReadResult`，把业务载荷、框架 metadata、完整性状态、错误码、物理文档版本与迁移版本从读取入口开始分离。
- 发布产物新增同版本 `gf-ai-developer-kit-<version>.zip` 确定性 Agent 插件，内含 Skill、项目侧协议服务/CLI、Schema、模板和版本化知识；产物通过独立插件结构审计，并与 Asset Store、registry、offline bundle 和模块包共享一次发布事务。
- Config Pipeline 新增版本化 `GFConfigPipelineTableIR` / `GFConfigPipelineIR`，以及职责独立的 `GFConfigPipelineReaderStage`、`GFConfigPipelineLayoutStage`、`GFConfigPipelineValidationStage`、`GFConfigPipelineTargetStage` 与 `GFConfigPipelineCommitStage`；IR 对输入与读取结果实施副本所有权，数据库 IR 在交给 Target 前必须封存且封存后不可修改，重复表名和损坏契约统一 fail closed。
- 新增可选 `gf.tool.dialogue_text` 制作期包及 `GFDialogueTextCompiler`，以严格 `gf.dialogue` JSON schema 编译 `GFDialogueResource`；未知结构字段、字段类型、缺失跳转和自动循环统一进入结构化报告，失败结果不暴露半成品资源。
- Physics 扩展新增 `GFBuoyancyMath3D` 与 `GFBuoyancyField3D`，提供居中浸没比例、阿基米德浮力、相对流速阻力和可重写表面/流速点采样；框架只返回力结果，不自动接管刚体、探针布局或水体检测。
- `GFNetworkFieldSerializer` 新增显式 Quaternion 字段编码，以归一化 `[x, y, z, w]` 表示旋转，并对零长度或非有限输入使用单位旋转回退。
- `GFObjectCandidateRegistry` 新增候选变化信号和单调 revision，便于交互提示、空间查询、编辑器选择或项目缓存按变更重新查询，而不把最佳候选策略写入注册表。
- 新增 `GFPriorityWorkQueue`，以稳定顺序和无上限等待加成提供防饥饿优先级仲裁；显式时间入口与结构化快照可用于确定性测试和调度诊断，队列不执行任务或解释业务优先级。
- 新增 `GFQuietWindowCoalescer`，按 key 在静默窗口、最大窗口、单批消息上限或待处理 key 上限到达时关闭有界批次，并通过过去时信号 `batch_closed(report)` 交付结果；容量回调重入时会先保留当前提交位置，容量收缩与重入通知按固定跨帧预算交付，项目通过 `merge_callback` 定义合并语义，框架不解释消息载荷。
- `GFFlowRunner.run()` 新增有界、JSON 兼容的结构化运行报告，包含稳定终态、通用节点计数、等待状态和可截断 trace，供任务链、过场、工具流水线或诊断面板复用。

### 🔄 机制更改 (Changed)

- 仓库开发态改用 `9.0.0-dev.0` SemVer 预发布身份，准确表达相对 `8.1.1` 已经确认的迁移型公开契约变化，并避免未发布的 `main` 源码继续冒充最新稳定版本；Draft PR 只运行快速反馈门禁，Ready PR 与 `main` push 必须通过稳定汇总检查及完整等价 CI 分片，正式发布仍只由不可变 SemVer tag 与 Release workflow 定义。
- Package Manager 的框架兼容判断改为严格 SemVer，并把稳定 `maximum_framework_version_exclusive` 解释为下一兼容线边界；tag 风格 `v` 前缀、损坏的非空当前版本，以及与上界同 core 的下一线预发布版本都会 fail closed，开发版本默认在线源改用 latest release source，避免请求尚不存在的版本化 registry。
- release artifact manifest schema 升级为 version 2，新增唯一 `ai_developer_kit` 角色和 `ai_developer_kit_build_count = 1`；release job 只能上传同一不可变产物，下载后复核，不得重新构建另一份插件。`quick` 负责 AI Developer Kit 约束、Schema、知识和模板新鲜度，`api`、`framework`、`full` 与 `release` 继续执行完整行为、确定性 ZIP 和反馈安全门禁。
- AI Developer Kit 的 package lockfile、知识目录版本和查询预算改为严格失败语义；项目契约验证命令改为只声明结构化 `argv`、超时、联网和写入边界，由宿主独立审阅执行，项目文件中的文本不能提升为 Agent 指令。
- Access、Config Access 和 Network Contract 生成器的默认输出从 `res://gf/generated/**` 统一迁移到 `res://generated/**`；AI 项目契约从根目录迁移到 `.gf/project_contract.json`，本地快照与反馈继续隔离在 `.gf/ai/**`。
- `GFStorageCodec` 改为严格 version 2 物理文档，业务载荷固定放在独立 `payload`，未知字段、旧/未来 envelope、格式猜测和隐式明文回退全部移除；`GFStorageUtility` 的同步与异步读取统一返回强类型结果，数据 schema 迁移只有完整链成功后才暴露载荷。
- `GFSaveSlotStorageAdapter` 改为只接收经过校验的 `GFSaveDocument`，并在同一事务写入与文档 schema 一致的槽位 metadata；SaveGraph 的文件入口改为持久化固定 schema 文档，不再直接写裸 graph payload。
- 平台请求、执行预算、超时控制器、SaveGraph pipeline 和槽位时间戳改用显式 `GFClock`；耗时与 deadline 使用单调时间，持久化槽位 metadata 使用 Unix 时间，暂停和时间缩放不会改变这些域。
- `GFConfigPipeline` 改为 Reader -> Layout -> Validation -> Target -> Commit 编排器，旧的单文件解析、XLSX、校验、JSON 编码和事务快照重复实现已移除；主类不再重新解释阶段结果，只有通过 Validation 的 IR 才能进入目标物化。Profile 多产物导出现在由独立 Commit 阶段捕获完整路径集合，失败时逆序恢复已有文件并删除新增文件。
- Config Pipeline 编译器指纹契约升级，直接引用每个 Stage 的稳定 ID / 实现版本和两个 IR 的格式版本，并覆盖全部新增实现文件；阶段或 IR 变化会可靠使旧 manifest stale。
- Config Pipeline artifact manifest 新增 Profile Resource 语义依赖和编译器阶段指纹；freshness 现在同时覆盖外置 schema / 校验器脚本、GF 与 Godot 版本、阶段 ID、实现版本和实现文件摘要，并继续受统一文件、累计字节和条目预算约束。
- `GFSupportReportUtility` 改为最小采集默认值：运行时只保留 `MINIMAL` 平台信息，场景、诊断和已注册自定义分区默认关闭；调用方可显式选择 `COARSE` 不可逆分桶、`FULL` 精确运行时信息或完全关闭运行时采集。
- `GFTextureSetClassifier` 新增重复角色与必需角色完整性诊断；同一集合内的 albedo 别名、GL/DX normal 等冲突不再按输入顺序静默覆盖，导入计划只包含通过完整性校验且无歧义的集合，并保留问题摘要。
- 补充 UI 逻辑层与绘制层边界：`layer_id` 只标识独立导航栈，绘制顺序由 `canvas_layer` 决定，`hide_under` / replace 不会跨层清理；文档同时明确 `mode`、`modal` 与 `metadata` 的职责。
- `gdscript_lsp_diagnostics` 纳入 `full`、`framework` 与 `release` suite 的无条件硬门禁；任何 GDScript error / warning、文件诊断超时或项目连接失败都会阻止提交或发布验证通过。
- `GFBackgroundWorkUtility` 的 CPU/IO 等待队列改用 `GFPriorityWorkQueue`，新任务仍按基础优先级响应，长期等待任务则随时间获得无上限加成；调试快照新增脱敏的优先级仲裁摘要。
- `GFRequestOutboxUtility` 的存储 schema 升级为 version 2：重试截止时间改用 Unix 毫秒，空幂等键在入队时由稳定请求 ID 补齐，保存采用校验后的临时文件/备份原子替换，加载可从完整候选恢复，并在每个重放终态后写入检查点；崩溃前已递增到上限但尚未完成终态迁移的 pending 请求会在重启重放时直接修复到 failed store，不会再次发送或永久卡住。

### 🐛 Bug 修复 (Fixed)

- 修复 Godot 4.7 导出项目时 `GFExtensionExportPlugin` 未实现必需 `_get_name()` 回调，导致导出器在仍可生成产物并返回成功退出码时持续输出 `EditorExportPlugin` 错误的问题；插件现在提供稳定名称，headless 契约测试会阻止 override 丢失回归。
- 修复 Config Pipeline `changed_only` 未把显式 schema 语义及校验器实现纳入 Profile 摘要，可能在 schema、默认值、索引、引用或验证逻辑变化后仍错误跳过导出的问题；合法旧 manifest 会安全判定为 stale 并在成功导出后升级，损坏或部分指纹仍拒绝覆盖。
- 修复 `GFSafeResourceCodec` 丢失类型化 `Array` / `Dictionary` 约束，以及伪造编号、Variant.Type、集合结构、重复键/属性或属性类型可能被宽松转换和写入对象的问题；脚本路径、原生基类及二者兼容性现在均经过 policy 门禁，失败解码会拆除 Resource 引用环并释放已创建的非 RefCounted 对象，合法的自环、双节点环和共享引用仍可往返。
- 修复 `GFSpringMath` 在较大物理时间步下可能明显过冲，或让正阻尼响应停留在边界二周期的问题；稳定下限现在同时使用严格安全裕量与 `delta_seconds * k1`，30/60/120 Hz 临界阻尼终态/瞬态及 30 Hz 欠阻尼衰减均有回归覆盖。
- 修复 `GFLogUtility` 只限制 context，导致超长 tag/message 放大内存、文件、控制台和诊断快照，且顶层 trace_id 绕过内存、JSONL 与 sink 预算/profile 的问题；这些文本现在复用既有预算，tag/message 在 entry、text、内存缓存与 `log_emitted` 保持一致，trace_id 在结构化条目、context、内存和 sink 中保持有界并按 sink profile 重建，短文本和换行语义不变。
- 修复 `GFDebugOverlayUtility` 在初始化后立即释放时，延迟挂载回调仍携带已释放 GUI 参数并触发 Godot deferred-call 类型转换错误的问题；挂载请求现在以代次失效，并在执行时重新读取当前实例。
- 修复 `GFTextFitter.fit_control()` 的 Label 分派忽略显式测量文本，且无换行短文本只能反复进行候选测量、放大 Godot 退出期 shaped-text RID 残留的问题；新增一次最大字号测量的单行比例路径，默认完整排版行为不变。
- 修复本地包管理网络 smoke 服务器把请求目标直接写入 `Location` 响应头的问题；重定向边界现在拒绝原始 CR/LF 控制字符，避免测试服务产生 HTTP 响应拆分，并保留合法路径与百分号编码字面量。
- 修复 release 级全包 Godot matrix 沿用默认 10 分钟父预算，并在四路并发的大依赖闭包安装超过普通命令预算后因重复 `row_key` 再次抛异常、覆盖原始失败证据的问题；matrix 父检查与并发安装阶段现在分别使用独立 2400 秒和 240 秒预算，单场景解析超时保持不变，断言报告会保留调用方提供的精确包 ID。
- 修复 AI Developer Kit 项目快照未按 Godot `project.godot` 的 `[gf]` section 读取 `extensions/enabled`，且只接受 `PackedStringArray`、遗漏扩展设置实际使用的 `Array[String]` 表示，导致真实项目的启用扩展被错误报告为空的问题；快照现在按精确 section 解析两种字符串数组表示，并拒绝其他 section 的同名键干扰。
- 修复项目模块依赖扫描把注释、普通字符串或资源文本中的弱引用误当成强 class 依赖，以及重复解析 ownership 规则造成大项目扫描成本放大的问题；新分析器只保留可复核 token/path 证据，并在预算、不可读路径或 class 歧义下标记不完整而不是输出伪阴性。
- 修复 `GFRequestEnvelope` 把进程内单调 ticks 持久化为重试截止时间，导致重启后请求可能过早重放或长期跳过的问题；持久化失败现在会阻止重放继续推进，Signal 等待超时也不再让 Flow 节点运行态租约永久占用。

### 🔧 API 变动说明 (API Changes)

- 新增公开 tool package `gf.tool.ai_developer`，以及版本化项目契约、快照和反馈 candidate JSON Schema；新增 `gf_ai_project.py` 的 `init-contract`、`validate`、`context`、`snapshot`、能力、package、API module/class/member 与 Recipe 查询、Agent 安装状态与卸载、反馈分析/起草/准备/查重/交互提交命令。项目契约未知字段 fail closed，`.gf/ai/**` 只作为可重建本地输出，不属于项目意图契约。
- 新增公开 package `gf.standard.platform` 和公开类型 `GFPlatformRuntime`、`GFPlatformAdapter`、`GFPlatformRequestHandle`；现有 `GFPlatformRuntimeContext`、`GFPlatformCapabilitySet`、`GFPlatformBridgeRequest`、`GFPlatformBridgeResult` 与 `GFPlatformLifecycleEvent` 作为其平台无关数据契约。
- 新增公开类型 `GFStorageReadResult`。`GFStorageCodec.decode()` 和 `GFStorageUtility.load_data()` 的返回类型由 `Dictionary` 改为 `GFStorageReadResult`，`last_load_result` 与 `load_completed` 的结果类型同步变更；移除重复的 `load_data_result()`、两层 `allow_legacy_plain_json_fallback`、旧 envelope 常量、`verify_integrity()`、`get_metadata()` 和 `has_integrity_checksum()`。
- `GFVariantData` 新增 `is_exact_integer()` 与 `to_exact_int()`，用于严格接受 int 或 JSON 解析产生的安全整数 Number，同时拒绝 bool、文本、非有限值和小数；版本、schema 与其它持久化整数边界不应再使用宽松 `to_int()`。
- 新增公开类型 `GFSaveDocument`、`GFSaveSection`、`GFSaveDocumentSchema`、`GFSaveMigrationStep`、`GFSaveMigrationRegistry`、`GFSaveMigrationResult` 与 `GFSaveDocumentReadResult`。`GFSaveSlotStorageAdapter.save_slot()` 的数据参数由裸 `Dictionary` 改为 `GFSaveDocument`，`load_slot()` 现在接收目标 schema / migration registry 并返回 `GFSaveDocumentReadResult`；`gf.save` extension version 升为 `5.0.0`。
- `GFSaveGraphUtility` 新增 `gather_section()`、`apply_section()`、`gather_document()`、`apply_document()`、`create_document_schema()` 和时钟注入；`save_scope()` / `load_scope()` 的磁盘格式改为固定 `gf.save_graph` 文档及 `save_graph` section。
- `GFAssetCatalog` 新增 `make_preload_plan()`；`GFAssetUtility` 新增事务会话信号、`start_preload_session()` 和 `get_active_preload_session_count()`，并新增公开 `GFAssetLoadSession` / `GFAssetLoadSessionResult`。
- 新增公开 `GFClock` 与 `GFManualClock`；`GFTimeProvider` 新增 `set_clock()`、`get_clock()`、单调时间和 Unix 时间读取，`GFExecutionBudget`、`GFTimeoutController`、`GFSaveGraphUtility`、`GFSaveSlotWorkflow` 与 `GFSaveSlotStorageAdapter` 新增时钟注入入口。`GFSaveSlotMetadata.from_values()` 新增尾部 `unix_time_seconds`，省略时不再隐式读取系统时间；`GFPlatformBridgeResult` 与 `GFPlatformLifecycleEvent` 的零时间戳也不再触发隐藏时钟读取。
- `GFAccessGenerator.DEFAULT_OUTPUT_PATH`、`DEFAULT_PROJECT_OUTPUT_PATH`、`GFConfigAccessGenerator.DEFAULT_OUTPUT_PATH` 与 `GFNetworkContractGenerator.DEFAULT_OUTPUT_DIR` 改为 `res://generated/**`。
- 新增公开类型 `GFConfigPipelineTableIR`、`GFConfigPipelineIR`、`GFConfigPipelineReaderStage`、`GFConfigPipelineLayoutStage`、`GFConfigPipelineValidationStage`、`GFConfigPipelineTargetStage` 和 `GFConfigPipelineCommitStage`。各 Stage 暴露稳定 `STAGE_ID`、`IMPLEMENTATION_VERSION` 与 `get_stage_descriptor()`；`GFConfigPipeline` 新增 `configure_stages()` 和 `get_stage_descriptors()`。
- `GFConfigPipeline.build_table()`、`build_table_from_text()` 与 `build_database()` 的结果新增 `ir`；成功单表结果为 `GFConfigPipelineTableIR`，数据库结果为仅包含通过单表校验项的 `GFConfigPipelineIR`。既有 `table` / `database` / `report` 字段保留。
- `GFConfigPipelineTableSource.describe()` 新增 `schema` 与 `schema_path`；`GFConfigPipelineArtifactManifest` 的 manifest 新增 `profile_entries`、`compiler_fingerprint` 和 `compiler_digest`。这些字段是附加契约，缺少它们的合法旧 manifest 会自动触发一次重建。
- `GFSupportReportUtility` 新增 `RuntimeDetail`、`include_runtime_by_default`、`runtime_detail_by_default`、`include_sections_by_default` 和 `collect_runtime_snapshot()`；`build_report()` 新增 `include_runtime` / `runtime_detail` 选项，full 运行时内存字段使用语义明确的 `static_memory_bytes`。
- `include_diagnostics_by_default` 与 `include_scene_by_default` 从 `true` 改为 `false`，已注册分区也不再默认采集。这是有意的数据最小化行为变更，不保留旧默认兼容分支。
- 新增公开类型 `GFDialogueTextCompiler`、`GFBuoyancyMath3D`、`GFBuoyancyField3D` 和独立 package `gf.tool.dialogue_text`。
- `GFNetworkFieldSerializer.ValueType` 追加 `QUATERNION`；`GFObjectCandidateRegistry` 新增 `candidates_changed(revision)` 与 `get_revision()`。
- bundled 扩展版本随新增公开能力递增：`gf.network` 为 `4.1.0`，`gf.physics` 为 `1.4.0`，含破坏性 Runner 契约变更的 `gf.flow` 为 `2.0.0`。
- `GFTextureSetClassifier.classify_files()` 的 options 新增 `required_roles`，报告新增集合有效性、`duplicate_roles`、`missing_roles`、问题列表及汇总计数；`build_material_import_plan()` 的 metadata 新增对应诊断摘要。
- `GFTextFitter` 新增 `MeasurementMode`；`fit_control()`、`fit_label()`、`fit_rich_text_label()` 和测量入口的 options 新增 `measurement_mode`，其中 `SINGLE_LINE` 提供无换行短文本的一次测量路径，`MULTILINE` 可强制完整多行排版。
- 新增公开类型 `GFPriorityWorkQueue` 与 `GFQuietWindowCoalescer`；后者以 `batch_closed(report)` 发出批次。`GFBackgroundWorkUtility` 新增 `priority_aging_interval_msec`、`priority_aging_step` 和 `queued_priority_entries` 诊断。
- `GFRequestEnvelope.retry_after_msec` 已移除，替换为 `next_attempt_at_unix_msec`；`can_attempt()` 与 `mark_failure()` 的显式当前时间参数现在都是 Unix 毫秒。`GFRequestOutboxUtility` 新增 `persistence_failed(operation, error, path)`，`replay()` 报告新增 `persistence_error` 与 `recovered_exhausted`。
- `GFFlowRunner.run()` 现在返回报告，`flow_completed` 与 `flow_cancelled` 信号现在都携带 `report: Dictionary`；新增 `max_report_trace_entries`、`get_last_run_report()` 和公开 outcome 常量。该签名变更不保留无参数兼容信号。

### 📘 升级指南 (Migration Guide)

- AI Developer Kit 完全可选，现有项目无需迁移。需要接入时先运行 `init-contract` 并由项目负责人补全会影响当前决策的约束，再按目标 Agent 执行 `agent-install`；不要把模板默认值或生成快照直接当成已批准架构。启用官方反馈网络提交后必须重新生成草稿，使其绑定最新契约哈希，最终提交由用户在交互式终端完成。
- 把既有项目的 `gf_project_contract.json` 移到 `.gf/project_contract.json` 并提交该文件；忽略 `.gf/ai/**` 而不是整个 `.gf/`。停止旧生成器并清理 `res://gf/generated/**`，然后用当前 Access、Config 与 Network 生成器重建 `res://generated/**`，避免同一 class_name 同时存在两份。
- 所有 `load_data()` / `decode()` 调用先检查 `result.ok`，再读取 `result.payload`；完整性、迁移或解析诊断从结果对象读取。需要保留 9.0 之前物理存储文件的项目应在升级发布前运行版本锁定的一次性导入器并重写当前文档，不要在主读取路径保留格式猜测。
- 把项目存档聚合改为 `GFSaveDocument`：为每个长期模块分配稳定 section ID 和独立版本，定义一个 `GFSaveDocumentSchema`，再把槽位 `save_slot()` / `load_slot()` 调用迁移到强类型文档和读取结果。旧裸 payload 必须显式确定初始 schema 版本；迁移逻辑拆成可审计的相邻 `N -> N + 1` 步骤。
- 平台项目代码以 contract/capability 为边界实现独立 `GFPlatformAdapter`，通过 `GFPlatformRuntime` 注册和显式路由；不要把 Steam、微信或商店 SDK 写入 GF Standard，也不要把好友 UI、奖励和活动规则放入 Adapter。
- 场景或模式切换需要“全部资源就绪后再生效”时，把 catalog ID 转为 preload plan 并使用 `start_preload_session()`；不要在回滚时直接 `remove_cache()`，也不要复制 `GFAssetUtility` 的引用计数与 group 所有权。
- 计算 deadline、请求耗时或运行排序的代码改用 `GFClock` 单调方法；写槽位 metadata 或跨进程时间时显式传 Unix 时间。依赖 `GFSaveSlotMetadata.from_values()` 自动填当前时间的调用方必须从架构 `GFTimeProvider` 传入 `get_unix_time_seconds()`。
- 继续只消费 `table` / `database` 的调用方无需改动；需要在落盘前检查规范化数据、实现多个输出目标或做编译诊断时读取新增 `ir`。自定义来源或目标应继承单个 Stage 并用 `configure_stages()` 注入，不要复制 `GFConfigPipeline` 编排器，也不要把项目业务字段写入通用 Stage。
- Config Pipeline 使用方无需手工迁移旧 manifest；下一次 `changed_only` 执行会验证旧摘要、正常重建并写入新指纹。自定义 freshness 读取器应把 `compiler_digest` 作为产物失效条件，并将新增字段按只读诊断信息处理。
- 既有反馈入口如果确实需要场景、诊断或项目分区，构建报告时显式传入 `include_scene = true`、`include_diagnostics = true`、`include_sections = true`；依赖旧精确 runtime 字段时显式选择 `RuntimeDetail.FULL`，并把 `static_memory` 读取迁移为 `static_memory_bytes`。面向玩家的入口优先保留默认 `MINIMAL`，或在预览和授权后选择 `COARSE`。
- 文本制作流程按需安装 `gf.tool.dialogue_text`，输入根对象声明 `format: "gf.dialogue"` 与 `schema_version: 1`；项目字段放入 metadata / payload。运行时安装只需要 `gf.extension.dialogue`，不要从运行时包反向调用编译器。
- 浮力接入时为对象分配一个或多个排水点，把总体排水体积合理拆分，再由项目在物理阶段应用 `sample_point()` 返回的力；有限水体、Area 筛选、刚体所有权和网络策略继续由项目负责。
- 依赖纹理角色“最后一个路径获胜”的导入器应改为读取 `issues` / 集合 `ok`，由制作工具显式解决重复贴图；需要强制材质最低组成时传入 `required_roles`，没有配置时仍允许部分集合。
- 为旋转字段选择 `QUATERNION` 后，发送端会输出四元素组且接收端恢复 Quaternion；双方 schema 必须一致。候选使用方如需响应变化，可监听 `candidates_changed` 并按 revision 去重，再用原有筛选条件重新查询。
- 棋盘数字、分数或短计数器可把本地一次测量 workaround 迁移为 `measurement_mode = GFTextFitter.MeasurementMode.SINGLE_LINE`；正文和自动换行 Label 保持默认 `AUTO`。登录、认证与主页等互斥页面应使用同一逻辑层并调用 replace，跨层切换需要项目显式清理旧层。
- 读取 Outbox 重试时间的代码改用 `next_attempt_at_unix_msec`，写入显式时间时传 Unix 毫秒；原先的 `envelope.can_attempt(Time.get_ticks_msec())` 必须改为 `envelope.can_attempt(int(Time.get_unix_time_from_system() * 1000.0))`，或直接省略参数让 Envelope 读取系统时间。version 1 队列含有无法可靠转换的进程 ticks，升级前应先完成重放或由项目按原业务数据重建请求，不要把旧文件直接改版本号。服务端或 SDK 适配器应转发 `idempotency_key` 并按键去重。
- 调用 Flow 时改为 `var report := await runner.run(graph, context)`；原无参数 `flow_completed` / `flow_cancelled` 回调增加一个 Dictionary 参数，并根据 `outcome` / `reason` 处理终态。只需汇总、不需要节点明细时可把 `max_report_trace_entries` 设为 `0`。
