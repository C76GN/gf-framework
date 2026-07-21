# 运行时会话轨迹

`GFSessionTraceUtility` 用于记录一段有界、结构化的运行时事件轨迹。它适合回答“玩家在报错前打开了哪些页面、触发了什么输入、存档流程走到了哪一步”，但不会扫描场景树、自动读取节点属性，也不会替项目上传玩家数据。

与逐帧录像或完整状态转储相比，会话轨迹只记录项目显式声明的语义事件。例如，一次 UI 故障可以只保留最近的 `route.opened`、`input.confirmed` 和 `save.completed`，而不是保存每一帧的全部节点状态。这样更容易控制数据体量，也更容易向玩家解释实际采集了什么。

## 建立最小轨迹

工具不会自动注册通道。项目应先声明允许记录的通道，再开始会话；未知通道会 fail closed：

```gdscript
var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
trace.max_events = 256
trace.max_event_buffer_bytes = 512 * 1024
trace.max_event_bytes = 8 * 1024

trace.register_channel(&"input", {
	"max_events": 80,
})
trace.register_channel(&"route", {
	"max_events": 120,
})
trace.register_channel(&"save", {
	"max_events": 24,
})

trace.start_session(&"play_session", {
	"build_channel": "public",
	"game_mode": &"campaign",
})
```

如果多个系统都需要查询同一条轨迹，可以在项目 Installer 中注册这个实例；若只有一个局部调试流程使用，也可以由该流程直接持有。GF 不会因类存在而自动开始采集。

显式 `session_id` 只应使用非敏感、本地、低基数的标识，例如 `play_session` 或自动生成值。它用于事件归组，不会自动识别账号 ID、网络令牌等业务秘密；超长通道、事件和 provider ID 会 fail closed，而不是截断后与既有白名单发生别名。

事件 ID 和载荷 schema 由项目定义。建议记录稳定、低基数的操作结果，不要直接记录玩家输入的自由文本、账号 token 或完整存档：

```gdscript
var result: Dictionary = trace.record_event(
	&"route",
	&"opened",
	{
		"route_id": &"settings",
		"entry": &"pause_menu",
	},
	{
		"simulation_tick": simulation_tick,
	}
)

if not GFVariantData.get_option_bool(result, "ok"):
	var reason: StringName = GFVariantData.get_option_string_name(result, "reason")
	push_warning("Session trace rejected event: %s" % reason)
```

每条成功事件包含会话 ID、单调序号、相对会话时间、可选模拟 tick、通道、事件 ID、载荷和 metadata。载荷和单次记录提供的 metadata 在进入内存轨迹前会经过 `GFReportValueCodec` 编码和当前字节预算约束；默认使用 `privacy` profile。

会话 context、通道 metadata 和 provider metadata 会被工具长期保存，并可能在 profile 改变后重复用于快照或事件。它们因此始终按 `privacy` 安全下限编码，不会因为注册时临时使用 `debug` 或 `support` 而保留对象实例 ID、节点名称或原始路径。确实需要本地调试细节时，应把经过项目字段白名单筛选的数据放进单次事件，而不是依赖长期目录 metadata。

## 在关键点采集状态

有些问题需要同时知道“发生了什么”和“当时的少量状态”。项目可以注册同步 snapshot provider，并只在报错、检查点或用户主动生成支持报告时调用它：

```gdscript
trace.register_snapshot_provider(
	&"player_summary",
	&"save",
	func() -> Dictionary:
		return {
			"checkpoint_id": current_checkpoint_id,
			"health_bucket": current_health_bucket,
			"inventory_count": inventory_count,
		}
)

var capture: Dictionary = trace.capture_snapshot_provider(
	&"player_summary",
	{ "simulation_tick": simulation_tick }
)
```

Provider 必须快速、同步、无参数且没有副作用。读取普通轨迹或构建报告不会自动执行 provider；只有显式调用 `capture_snapshot_provider()` 且当前会话与目标通道允许记录时才会采集。这一边界避免被拒绝的诊断请求仍执行项目回调，也避免任意节点被隐式反射。

## 接入支持报告

`build_snapshot()` 返回普通、JSON-safe 的有界字典，可以作为 `GFSupportReportUtility` 的项目分区。注册分区仍不代表自动进入报告；构建报告时还要显式启用 `include_sections`：

```gdscript
var reports: GFSupportReportUtility = (
	Gf.get_utility(GFSupportReportUtility, true) as GFSupportReportUtility
)
reports.register_section(
	&"session_trace",
	func(_options: Dictionary) -> Dictionary:
		return trace.build_snapshot({
			"limit": 120,
			"include_channel_catalog": false,
			"include_provider_catalog": false,
		})
)

var report: Dictionary = reports.build_report(
	"设置页面无法返回",
	{ "include_sections": true }
)
```

面向玩家的报告入口应先展示采集预览并取得适当许可。默认脱敏会处理路径、对象和非 JSON 原生类型，但不会理解项目自由文本里的业务秘密；字段白名单、账号数据分类和用户同意仍由项目负责。

## 可选的跨重启本地 journal

内存轨迹会随进程结束消失。需要在崩溃或强退后检查最近事件时，可以显式配置 `GFLogSink`；本地 JSONL 是一种可选实现：

```gdscript
var journal: GFJsonLineLogSink = GFJsonLineLogSink.new()
journal.file_path = "user://diagnostics/session_trace.jsonl"
journal.file_open_mode = GFJsonLineLogSink.FileOpenMode.APPEND
journal.flush_interval_msec = 250

trace.max_journal_events = 1000
if not trace.configure_journal_sink(journal, {
	"initialize": true,
	"shutdown_on_dispose": true,
	"flush_after_write": false,
}):
	push_error("Session Trace journal 配置失败；检查 sink 与脱敏 profile。")
```

`max_journal_events` 限制单次会话写入数量；`stop_session()` 和 `dispose()` 会刷新 journal。需要更强的每事件落盘保证时可启用 `flush_after_write`，但这会增加磁盘同步成本。文件轮换、保留期、加密、上传和玩家删除入口仍是项目策略，不由 Session Trace 自动决定。

Journal 会先按 Session Trace 当前 `redaction_profile` 编码事件，再交给 sink。为了避免已经放宽的数据跨过更严格的输出边界，轨迹 profile 必须至少与 sink 的 `get_report_redaction_profile()` 声明一样严格：基础自定义 `GFLogSink` 默认声明 `public`，`GFJsonLineLogSink` 声明 `debug`，`GFBatchedLogSink` 声明 `privacy`。不安全或未知的组合会让 `configure_journal_sink()` 返回 `false`，且不会部分替换既有配置；每次写入还会重新读取声明，因此配置后无论项目把轨迹 profile 改弱，还是自定义 sink 动态改变输出 profile，后续不安全写入都会 fail closed，并计入 `journal_dropped_event_count`。

Sink 的 `get_report_redaction_profile()`、`init()`、`write()`、`flush()` 和 `shutdown()` 都位于重入保护边界内。回调中触发新的轨迹写入不会递归进入同一 sink；`configure_journal_sink(null)`、清除或释放会先原子断开引用，再完成延迟清理。替换 sink 时，如果旧 sink 的清理回调主动置空配置，置空请求优先且外层替换返回 `false`，调用方可在回调结束后显式重试。同一个 sink 实例再次配置时只原位更新所有权和刷新选项，不会把仍要继续使用的实例提前 `flush()` 或 `shutdown()`；只有新配置再次显式传入 `initialize = true` 时才会调用 `init()`。自定义 sink 仍应保持回调快速、同步，并避免执行项目业务副作用。

## 容量与读取

- `max_events`：内存最多保留的事件数，超限时淘汰最旧事件。
- `max_event_buffer_bytes`：内存事件缓冲的总字节上限；上下文与通道/provider 目录另受各自数量和单份 metadata 预算约束。
- `max_event_bytes`：单事件上限；过大的事件会以稳定原因拒绝，而不是无界写入。
- 通道 `max_events` / `max_event_bytes`：为高频通道设置更严格的局部预算。
- `get_events(limit, filters)`：按通道、事件 ID 或序号范围读取最近事件。
- `get_debug_snapshot()`：只返回计数、容量、拒绝原因和 journal 状态，不包含完整载荷。
- `build_snapshot(options)`：生成可交给支持报告、调试面板或离线分析器的结构化快照。

`dropped_event_count` 表示容量淘汰，`rejected_event_count` 表示事件未进入轨迹。两者应该分别观察：前者通常意味着需要调整采样或预算，后者通常意味着通道未注册、已禁用、会话未开始或单事件过大。

## 使用边界

Session Trace 不是输入录像、确定性重放、崩溃捕获器、性能 profiler 或远程监控 SDK。它只提供通用的事件包络、显式 provider、容量治理、脱敏边界和可选 sink。项目仍负责：

- 决定哪些业务事件值得记录，以及每个事件的最小字段 schema；
- 在主线程或自己的同步点记录事件，并维护模拟 tick 的含义；
- 处理玩家许可、访问控制、保留期、加密和远端传输；
- 把轨迹与构建版本、存档版本、网络会话或崩溃报告关联；
- 若需要真正重放，另行保存确定性输入、随机种子和权威状态。
