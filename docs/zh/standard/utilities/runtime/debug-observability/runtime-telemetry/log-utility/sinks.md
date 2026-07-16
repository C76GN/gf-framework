# 日志 Sink

`GFLogSink` 是日志输出 sink 基类。项目可以继承它，把 `log_entry_emitted` 同形态的结构化条目写到 JSONL、本地诊断面板、编辑器工具、远端服务、平台 SDK 或自定义运行时采集器。

通过 `add_sink()`、`remove_sink()` 和 `clear_sinks()` 管理 sink 生命周期。日志工具会在 `init()` 后调用 sink 的 `init()`，在 `flush_sinks()` 或 `dispose()` 时转发刷新和关闭钩子。

## JSONL Sink

需要本地结构化日志文件时，可以直接注册 `GFJsonLineLogSink`。默认路径为空时，它会根据当前 `.log` 文件派生同名 `.jsonl` 文件；每一行都是独立 JSON 对象，适合诊断工具、测试或离线分析读取。

```gdscript
var jsonl_sink := GFJsonLineLogSink.new()
jsonl_sink.omit_formatted_text = true
jsonl_sink.max_jsonl_files = 10
log_util.add_sink(jsonl_sink)
```

`GFJsonLineLogSink` 会把 `StringName`、`NodePath` 和非 JSON 原生值转换成稳定字符串，避免上下文里混入 Godot 对象后破坏 JSONL 文件。默认派生路径使用 `gf_log_*.jsonl`，并由 `max_jsonl_files` 单独控制保留数量；显式设置 `file_path` 时，文件命名和清理策略由项目层负责。需要在诊断面板或测试里检查文件打开、写入或清理失败时，可读取 `get_debug_snapshot()`；快照只暴露路径、打开状态、最近错误和错误计数，不抛出额外错误。

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

批量外发固定使用 privacy profile 清洗 `tag`、`message` 和 `context`，`text` 会从这些已清洗字段重新构建，避免格式化文本保留原始路径。框架提供这一通用报告边界；项目层仍负责用户同意、业务字段分类、采样率、速率限制、持久重试和服务端字段映射。
