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

**版本概述**：开发线升级为 `10.0.0-dev.0`，补齐通用 2D 编辑器缩略图、有序资产集合、存储后端故障转移、运行时会话轨迹和 UI 路由预加载规划，修正 AI Developer Kit 的项目级资源所有权表达，并更新 CI/Release 基础 Actions；业务策略仍保持在各自调用方边界内。

### 🚀 新增特性 (Added)

- `GFThumbnailRenderer` 与 `GFThumbnailRenderRequest` 支持 `CanvasItem` 的 `Image` / `ImageTexture` 缩略图请求，统一覆盖 `Node2D` 和 `Control`。调用方可以显式提供内容 `Rect2`，也可以让渲染器保守估算 Sprite、Control、Polygon、Line、AnimatedSprite 和 2D 粒子范围。
- 新增 `GFAssetCollection`，用稳定 `collection_id` 和有序 `asset_ids` 描述可序列化资源集合，并通过 `GFValidationReport` 报告空 ID、重复 ID 和目录缺失项。
- 新增 `GFStorageFailoverBackend`，按稳定后端 ID 提供有界顺序尝试、`PRIMARY_ONLY` / `FIRST_SUCCESS` 写删语义、暂时性错误冷却和不含业务载荷的结构化操作报告。
- 新增 `GFSessionTraceUtility`，提供显式通道白名单、事件数与字节双重预算、默认隐私脱敏、同步快照 provider、结构化支持报告快照和可选 `GFLogSink` journal。
- 新增 `GFUIRoutePreloadUtility`，从 `GFUIRoute.adjacent_route_ids` 做有界、确定性的页面可达性遍历，并生成可直接交给 `GFAssetUtility` 的 `GFAssetPreloadPlan`。
- AI Developer 项目契约新增可选 `architecture.owned_resources`，用于精确声明 `project.godot`、`export_presets.cfg` 等不属于业务模块的项目级治理文件。

### 🔄 机制更改 (Changed)

- `GFStorageBackend.load_data()` 会为没有显式错误码的后端结果补齐 `error_code`，使组合后端能够区分成功、普通读取失败和明确的暂时性故障。
- `GFStorageFailoverBackend.configure_backends()` 对策略、失败阈值和冷却窗口执行事务式 fail-closed 校验，非法配置不会部分替换既有后端或静默改变写入语义。
- 缩略图渲染改为等待场景树更新后同步强制绘制，避免无持续绘制帧时错过 `frame_post_draw`；dummy 渲染后端现在会安全返回空结果，不再访问无纹理存储的 ViewportTexture。
- Session Trace journal 会校验轨迹与 sink 的脱敏 profile，且对 sink 生命周期、写入与刷新执行重入保护；不安全配置和运行期 profile 降级会 fail closed。
- `GFUIRouterUtility` 可从当前已注册路由构建预加载计划；Planner 对目录、候选和边扫描分别设有硬上限，统一规范化路由 ID，只表达资源候选和诊断，不自动执行 IO，也不把相邻关系解释为权限或业务跳转。
- AI Developer Kit 3.0.0 将项目快照升级到 schema v3；依赖报告现在区分项目级资源状态、命中证据和未归属引用，缺失文件、目录或不安全路径继续 fail closed。
- AI Developer 项目契约的所有受控项目路径现在统一逐段拒绝符号链接、Windows junction 和其他重解析点；模块根、Adapter 根、project profile、验证必需路径与项目级资源不再允许通过链接别名绕过所有权边界。
- 模块根与 Adapter 根额外采用跨平台规范化校验，并以大小写无关方式拒绝 `res://addons/gf` 及 Windows 尾点、保留名称等别名，避免把 GF 源码误归属为项目模块；普通源码资源引用不受这项契约限制。
- CI 与 Release 工作流统一采用 Node.js 24 世代的 `actions/checkout@v7`、`actions/setup-python@v7`、`actions/upload-artifact@v7` 和 `actions/download-artifact@v8`，维护自检会阻止旧主版本回退。

### 🐛 Bug 修复 (Fixed)

- 修复 UI 路由启用资源存在性检查时，脚本或其他现有非场景资源可能被误判为健康 `PackedScene` 候选的问题；新增 `invalid_scene_type_paths`，将“资源存在但类型错误”与 `missing_scene_paths` 的“路径不存在”诊断明确分离。
- 修复 Session Trace 在 `debug` 或 `support` 下注册的长期 context、通道 metadata 与 provider metadata，可能在随后收紧 profile 后继续保留对象实例 ID、节点名称或原始路径的问题；这些长期数据现在统一使用 `privacy` 安全下限。
- 修复同一 journal sink 原位重配时会先刷新并按旧所有权关闭实例、导致未重新初始化的 sink 后续静默失效的问题。
- 修复 sink 回调内使用文档化的 `configure_journal_sink(null)` 无法原子断开并延迟清理当前 sink 的问题；替换 sink 时，旧 sink 清理回调发起的置空请求也不会再被外层配置覆盖。
- 修复模块源码引用根级 Godot 治理文件时只能产生 `unowned_project_resource_reference`、或被迫把文件误填为模块扫描目录并导致分析不完整的问题。

### 🔧 API 变动说明 (API Changes)

- `GFThumbnailRenderRequest.Kind` 末尾新增 `CANVAS_ITEM_IMAGE` 和 `CANVAS_ITEM_TEXTURE`，既有枚举值保持不变。
- 新增 `GFThumbnailRenderRequest.for_canvas_item_image()`、`for_canvas_item_texture()` 及相应来源、边界和留白读取入口。
- 新增 `GFThumbnailRenderer.render_canvas_item()` 与 `render_canvas_item_texture()`。
- 新增公开类型 `GFAssetCollection` 和 `GFStorageFailoverBackend`；均标记为 `@since unreleased`，不改变既有调用入口默认行为。
- 新增公开类型 `GFSessionTraceUtility`、`GFUIRoutePreloadUtility`，以及 `GFUIRoute.adjacent_route_ids`、`get_adjacent_route_ids()` 和 `GFUIRouterUtility.build_preload_plan()`；均标记为 `@since unreleased`。
- `GFUIRoute.get_route_id()` 以及 Router 的注册、查询、打开信号和异步 pending 身份统一去除 route ID 首尾空白。
- AI Developer 项目契约 schema v1 向后兼容地新增可选 `architecture.owned_resources`；项目快照 schema 从 v2 升为 v3，因此 AI Developer Kit 工具协议同步升为 3.0.0。
- GF 开发身份从 `9.1.0-dev.0` 升为 `10.0.0-dev.0`，用于明确承载项目快照 v3 这一破坏性输出协议变化；本条只切换开发线，不创建正式版本或发布标签。

### 📘 升级指南 (Migration Guide)

- 既有 3D 缩略图、资产目录、存储后端与同步代码无需迁移。需要 2D 预览、有序资产集合或故障转移时显式采用新入口即可。
- 自定义 `_draw()` 或无法可靠推断范围的 2D 节点应传入显式 `content_bounds`；多后端复制与冲突处理继续使用 `GFStorageSyncUtility`，不要把故障转移当作原子双写。
- 既有 UI 路由无需迁移；只有需要候选页面预热时才声明 `adjacent_route_ids` 并显式执行生成的资产计划。需要发布后问题轨迹时，应由项目定义最小事件 schema、玩家许可和保留策略，再显式采用 `GFSessionTraceUtility`。
- 历史配置若有意使用带首尾空白的 route ID，需迁移为去除空白后的稳定 ID；规范化后重复的 ID 会指向同一注册身份，不应再依赖空白区分页面。
- 既有项目契约无需修改。只有源码确实引用模块外项目治理文件时才添加精确 `res://` 文件路径；禁止填写裸 `res://`、目录、通配范围或模块根内文件。快照 v3 是有意的破坏性输出协议升级：消费方应先升级到 AI Developer Kit 3.x，再重新生成快照；不要把 v2 快照补字段后继续使用。
- 从 `9.x` 开发线升级时，应同步更新 GF 插件与扩展清单到 `10.0.0-dev.0`，并重新生成 AI Developer Kit catalog；稳定版发布时间与版本号仍由后续独立发布流程决定。
- 旧契约若把模块、Adapter、profile 或验证路径放在符号链接/junction 后方，应改为项目根内不经过链接的真实相对路径；工具不会为链接别名保留兼容分支。
- 模块和 Adapter 所有权根若包含尾点/空格、Windows 保留名称、通配字符或大小写变体的 `addons/gf`，应迁移为跨平台规范目录；这些别名不再保留兼容解析。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/kernel/editor/gf_thumbnail_render_request.gd`
- `addons/gf/kernel/editor/gf_thumbnail_renderer.gd`
- `addons/gf/standard/utilities/assets/gf_asset_collection.gd`
- `addons/gf/standard/utilities/storage/gf_storage_backend.gd`
- `addons/gf/standard/utilities/storage/gf_storage_failover_backend.gd`
- `addons/gf/standard/utilities/debug/gf_session_trace_utility.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route.gd`
- `addons/gf/standard/utilities/ui/gf_ui_route_preload_utility.gd`
- `addons/gf/standard/utilities/ui/gf_ui_router_utility.gd`
- `addons/gf/tools/ai_developer/gf_ai/dependencies.py`
- `addons/gf/tools/ai_developer/schemas/project_contract.schema.json`
- `addons/gf/tools/ai_developer/schemas/project_snapshot.schema.json`
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`

## [9.0.1] - 2026-07-20

**版本概述**：修复 Godot 原生 Package Manager 在 Linux 等平台安装含隐藏文件的合法包后无法完整清理事务暂存目录的问题，并保持隐藏链接审计继续 fail closed。

### 🔄 机制更改 (Changed)

- Package Transaction Engine 的树清理与链接审计、Package Manager Backend 的兜底清理现在都会显式枚举隐藏目录项。该行为适用于所有合法 package 载荷，不为特定文件名或业务包增加例外。

### 🐛 Bug 修复 (Fixed)

- 修复合法 package 包含 `.gdignore` 等点号文件时，Linux 上的 `DirAccess` 默认隐藏文件过滤会让 `.gf/t` 保留 staging 副本的问题。该残留此前会被 release 全包 Godot matrix 判定为意外运行时写入，并阻止 GitHub Release 创建。
- 修复事务树链接审计可能遗漏隐藏目录项的问题；隐藏符号链接或目录链接现在与普通目录项使用同一拒绝策略。

### 🔧 API 变动说明 (API Changes)

- 无公开 API、package schema、lockfile schema、持久化格式、协议或默认配置变化。

### 📘 升级指南 (Migration Guide)

- `9.0.0` 使用方可直接替换为 `9.0.1`。已安装的 package 文件和 `.gf/packages.lock.json` 无需迁移；如果项目残留旧 `.gf/t` 暂存目录，可在确认没有正在运行的 package 操作后删除该临时目录。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/kernel/package/gf_package_transaction_engine.gd`
- `addons/gf/kernel/package/gf_package_manager_backend.gd`
- `tests/gf_core/kernel/package/test_gf_package_manager_backend.gd`
- `tests/gf_core/maintenance/test_package_transaction_boundary_validation.gd`
