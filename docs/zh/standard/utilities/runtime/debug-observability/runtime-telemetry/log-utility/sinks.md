# 日志 Sink

`GFLogSink` 是日志输出 sink 基类。项目可以继承它，把 `log_entry_emitted` 同形态的结构化条目写到 JSONL、本地诊断面板、编辑器工具、远端服务、平台 SDK 或自定义运行时采集器。

通过 `add_sink()`、`remove_sink()` 和 `clear_sinks()` 管理 sink 生命周期。日志工具会在 `init()` 后调用 sink 的 `init()`，在架构每帧推进 `GFLogUtility.tick(delta)` 时转发 sink 的 `tick(delta)`，并在 `flush_sinks()` 或 `dispose()` 时转发刷新和关闭钩子。脱离 Architecture 单独使用 `GFLogUtility` 时，调用方必须自行持续调用 `tick(delta)`；无效、非有限或非正数 delta 不会推进时间状态。

## JSONL Sink

需要本地结构化日志文件时，可以直接注册 `GFJsonLineLogSink`。默认路径为空时，它会根据当前 `.log` 文件派生同名 `.jsonl` 文件；每一行都是独立 JSON 对象，适合诊断工具、测试或离线分析读取。

```gdscript
var jsonl_sink := GFJsonLineLogSink.new()
jsonl_sink.omit_formatted_text = true
jsonl_sink.max_jsonl_files = 10
log_util.add_sink(jsonl_sink)
```

`GFJsonLineLogSink` 会把 `StringName`、`NodePath` 和非 JSON 原生值转换成稳定字符串，避免上下文里混入 Godot 对象后破坏 JSONL 文件。默认派生路径使用 `gf_log_*_sink_<instance_id>.jsonl`，每个活动 sink 都拥有独立文件，避免多个默认实例截断或交错写入同一目标；实际路径应通过 `get_file_path()` 读取，不要从主日志路径自行拼接。默认文件由 `max_jsonl_files` 单独控制保留数量；显式设置 `file_path` 时，文件命名、唯一写入者和清理策略由项目层负责。需要在诊断面板或测试里检查文件打开、写入或清理失败时，可读取 `get_debug_snapshot()`；快照只暴露路径、打开状态、最近错误和错误计数，不抛出额外错误。

内置 `.log` 文件和 `GFJsonLineLogSink` 的非零 `flush_interval_msec` 都由 `GFLogUtility.tick(delta)` 推进，因此最后一次低流量写入即使没有后续日志也会在累计间隔后 flush。`flush_immediately = true` 或间隔为 `0` 时仍在每次写入后立即 flush。

自定义 `file_path` 可以通过 `file_open_mode` 选择重复初始化时的文件策略：`TRUNCATE` 覆盖旧内容，`APPEND` 追加到旧文件末尾，`FAIL_IF_EXISTS` 在目标已存在时拒绝打开。需要保留多轮运行日志或防止测试覆盖上一轮产物时，应显式设置该策略，而不是依赖外部先删文件。

## 批量 Sink

需要把日志交给远端服务、平台 SDK、编辑器桥接或测试采集器时，可以使用 `GFBatchedLogSink`。它只负责清洗、排队、按 `batch_size` 分批和触发 `sender_callback` / `batch_ready`，不内置 HTTP 端点、鉴权或服务端字段。

```gdscript
var batch_sink := GFBatchedLogSink.new()
batch_sink.batch_size = 20
batch_sink.sender_callback = func(payload: Dictionary) -> Dictionary:
	# 项目层自行发送 payload["logs"]。
	return { "ok": true }
log_util.add_sink(batch_sink)
```

`sender_callback` 只有一个确认契约：必须返回包含 `ok: bool` 的 `Dictionary`，可选返回 `accepted: int` 和 `error: String`。缺少 `ok`、类型错误或 `ok == false` 都会 fail-closed，并把当前批次放回队列；不再接受 `success` 作为别名。

非零 `flush_interval_msec` 同样由 `GFLogUtility.tick(delta)` 推进，未满 `batch_size` 的最后一批不再依赖下一条日志触发。`shutdown()` 会在同步发送持续缩小队列时逐批排空；一旦 sender 失败、零确认或不再取得进展就立即停止，剩余条目仍保留在 sink 中，并可在释放最后引用前通过 `get_pending_count()` / `get_debug_snapshot()` 检查。该行为不等于耐久交付：需要退出后重放时，项目仍应实现持久队列和幂等接收。

批量外发固定使用 privacy profile 清洗顶层 `trace_id`、`tag`、`message` 和 `context`，`text` 会从这些已清洗字段重新构建，避免格式化文本保留原始路径。框架提供这一通用报告边界；项目层仍负责用户同意、业务字段分类、采样率、速率限制、持久重试和服务端字段映射。
