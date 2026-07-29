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

**版本概述**：本轮新增类型化音频播放区间与循环点，补充 Headless 服务探针和周期环境表现的项目组合配方，并把当前 Changelog 状态与条目结构转为可执行维护门禁；框架只提供可验证的通用契约，不内置部署协议、环境业务模型或轮询式音频模拟。

### 🚀 新增特性 (Added)

- 新增 `GFAudioPlaybackRegion` 与 `GFAudioPlaybackRegionResult`：以类型化资源表达播放起点、自然或显式终点、forward / ping-pong / backward 循环和循环起点，以 `VALID` 区分“结构已验证”和 `APPLIED`“执行者已接受”，严格区分 `INVALID` 与 `UNSUPPORTED`，并按 WAV、Ogg Vorbis、MP3、Playlist 和其他流的 Godot 原生能力返回逐请求结果。
- `GFAudioClip` 新增 `playback_region`；BGM、环境音、普通 SFX 与 2D/3D 空间 SFX 共用请求快照、私有流复制和原生播放准备流程。`GFAudioUtility` 新增拒绝信号、最近拒绝报告与 session 区间调试快照。
- `GFAudioBackendCapability` 新增播放区间协议发现能力，`GFAudioBackend.evaluate_playback_region()` 提供无副作用的逐片段、逐通道协商；粗粒度能力声明不能替代具体请求评估。
- 新增 Headless 服务健康/探针组合配方：组合惰性诊断 Provider、有界会话字段与类型化传输指标，由项目 Adapter 决定 liveness/readiness、传输协议、鉴权和部署政策；Backend 指标补充使用通用执行预算，并对总指标、自定义指标和 ID 长度设置绝对上限。
- 新增周期环境表现组合配方：组合可注入时钟、项目环境样本、Shader Profile、接口快照与 Binder；周期、天气、天文、时区和持久化策略继续由项目负责。
- AI Developer Capability / Recipe 知识目录升级到 `1.8.0`，加入两份组合配方的可搜索边界，并让音频能力目录认识类型化播放区间与循环点。

### 🔄 机制更改 (Changed)

- 播放区间在请求开始时连同 `GFAudioClip` 一起复制；本地执行始终复制 `AudioStream`，只修改 session 私有副本。异步回调、crossfade 回退和环境音 session 都携带冻结后的规范化区间。
- 本地音频只接受引擎能够精确表达的起点和循环点，不使用 Timer、每帧轮询或近似 seek 模拟非循环有限终点；有效但无法精确执行的组合明确返回 `UNSUPPORTED`。
- WAV 终点按最后有效帧索引写入，原生无法保持初始位置语义的 backward 明确返回 `UNSUPPORTED`；Ogg Vorbis / MP3 私有循环副本清除会改变自然终点的 `beat_count`。后端评估与执行只接收由验证结果重建的规范化 clip/context 快照。
- 环境音停止拒绝和本地淡出等非终态继续保留活动区间；拒绝信号保留调用通道，而持久诊断把非框架通道收敛为 `custom`，避免项目值进入稳定快照。
- 后端的 clip/event probe、区间评估与执行分别接收一次性参数副本，Dictionary / Array / Resource 使用有界深快照；集合循环、深度或项目数超限、Resource 无法复制时均在回调前失败关闭，不能通过改写回调参数绕过协商、污染调用方权威对象或污染本地回退。环境音会话同时保留目标增益，部分淡出被失败替换打断时会恢复区间、播放身份与增益，旧流已自然结束时则提交停止终态并释放播放器流引用。
- 新增 `changelog_policy` 当前状态检查：`X.Y.Z-dev.N` 只允许唯一的规范 `[未发布]` 段，稳定版本只允许唯一的同版本正式段；共享的严格 Markdown 解析会在标题/分类识别时排除 fenced 与缩进代码和独立 HTML 注释，但仍把候选段开头的代码块视为已经渲染的内容，确保版本概述必须真正排在首位。门禁拒绝原始 HTML、混写注释、非法 backtick info string、非 ASCII 标题分隔、伪装历史标题及不可读正文，并由发布说明提取器复用；同时验证文档标题、日志条目结构标准、维护策略、分类结构、扩展版本对齐和稳定 core 的 API SemVer，在 quick、full 和 release 套件中失败关闭。
- API baseline 现在比较公开成员的 `@schema` 契约；已有 free-text schema 的任何文本变化（包括追加、改写、重排或删除）都会 fail-closed 归入 breaking，只有稳定基线此前完全没有 schema、当前首次补充时才归入 compatible，避免 Dictionary 字段迁移绕过 SemVer 主版本门禁。
- `GFNetworkBackend.get_transport_metrics()` 现在把基础计数与 Adapter 补充阶段隔离；补充 Hook 超过执行预算、未为新增指标消费步骤或突破指标容量时，本次调用失败关闭为基础快照，不把不可控工作带入探针路径。

### 🐛 Bug 修复 (Fixed)

- 修复异步等待生命周期测试把 1ms 墙钟预算与 deferred free 调度顺序绑定的竞态；测试现在先用 timeout pause 建立等待已挂起的握手，再同步释放 continuation owner，稳定验证失效检查必须先于同轮已到期 timeout 仲裁。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `play_bgm_with_options()` 的 `loop` / `playback_region` 通用选项，并保留事件 metadata/options 中的同名键；继续传入会在资源加载和后端派发前失败关闭，类型化区间只能来自 `GFAudioClip.playback_region`。

### 🔧 API 变动说明 (API Changes)

- 本轮有意移除 10.x 已公开的通用 `loop` 输入与 `current_bgm_loop` 快照字段，开发身份进入 `11.0.0-dev.0` 主版本迁移线；不提供双轨兼容分支。
- `GFAudioClip.playback_region: GFAudioPlaybackRegion` 为新的可选公开属性。
- `GFAudioBackendCapability.supports_playback_region_contract`、`GFAudioBackend.evaluate_playback_region()`、`GFAudioUtility.playback_region_rejected` 与 `GFAudioUtility.get_last_playback_region_rejection()` 为新的公开 API。
- `GFAudioUtility.get_debug_snapshot()` 用 `current_bgm_region` 和 `last_playback_region_rejection` 描述播放区间状态，不再提供 `current_bgm_loop`。
- `GFNetworkBackend._enrich_transport_metrics()` 现在接收 `GFExecutionBudget`，属于有意的 protected 签名升级；新增 `MAX_TRANSPORT_METRICS_ENRICHMENT_MSEC`，`GFNetworkTransportMetrics` 新增总指标、自定义指标和 ID 长度绝对上限常量。`gf.network` 的 `extension_version` 因此提升到 `6.0.0`。

### 📘 升级指南 (Migration Guide)

1. 删除传给 `play_bgm_with_options()` 或事件 metadata/options 的 `loop` / `playback_region` 字段。
2. 创建 `GFAudioPlaybackRegion`，按需填写 `start_seconds`、`end_seconds`、`loop_mode` 和 `loop_start_seconds`，再赋给 `GFAudioClip.playback_region` 并调用对应 `play_*_clip()`。
3. 自定义后端若要接管任何带 `playback_region` 的片段，应声明 `supports_playback_region_contract`，并以无副作用方式实现逐请求 `evaluate_playback_region()`；不能精确执行时返回 `UNSUPPORTED`。
4. 将调试面板中的 `current_bgm_loop` 读取迁移到 `current_bgm_region`。
5. 自定义 `GFNetworkBackend` 将 `_enrich_transport_metrics(metrics)` 改为 `_enrich_transport_metrics(metrics, budget)`；每次尝试新增可选指标前调用 `budget.consume_steps()`，并在预算或 `metrics.set_metric()` 返回 false 时立即停止。Hook 只能读取有界内存状态，不得执行网络、磁盘、锁等待或项目业务 I/O。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/standard/utilities/audio/gf_audio_playback_region.gd`
- `addons/gf/standard/utilities/audio/gf_audio_playback_region_result.gd`
- `addons/gf/standard/utilities/audio/gf_audio_utility.gd`
- `addons/gf/standard/utilities/audio/gf_audio_backend.gd`
- `addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd`
- `addons/gf/standard/utilities/audio/gf_audio_clip.gd`
- `addons/gf/extensions/network/backends/gf_network_backend.gd`
- `addons/gf/extensions/network/runtime/gf_network_transport_metrics.gd`
- `addons/gf/extensions/network/gf_extension.json`
- `addons/gf/tools/ai_developer/knowledge/recipes.json`
- `docs/zh/extensions/network-turnbased/network-transport/backend-session.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/shader-parameter-profile.md`
- `tests/gf_core/extensions/network/test_gf_network_extension.gd`
- `tools/gf_changelog.py`
- `tools/gf_maintenance.py`
- `tools/gf_maintenance_rendering.py`
- `tools/extract_release_notes.py`
- `tests/gf_core/standard/utilities/signals/test_gf_async_wait_support.gd`
