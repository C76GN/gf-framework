# 文件、缓存与上下文

`GFLogUtility` 初始化时会在 `user://logs/` 下创建按日期时间命名的日志文件，并自动清理超出保留数量的旧日志。每条日志会同时生成结构化条目，进入内存环形缓存，写入本地文件，并转发给已注册的 sink。

## 文件保留与 Flush

```gdscript
var log_util := Gf.get_utility(GFLogUtility) as GFLogUtility
if log_util == null:
	return

log_util.max_log_files = 20

print(log_util.get_log_file_path())
```

文件默认按 `flush_interval_msec` 批量 flush。`flush_immediately = true` 或 `flush_interval_msec <= 0` 时，每条日志立即 flush；`ERROR` / `FATAL` 会强制尽快写盘。当前日志文件路径可通过 `get_log_file_path()` 读取，便于测试、诊断界面或导出工具定位文件。

## 内存缓存

内存缓存由 `max_memory_entries` 控制，超出后按环形缓冲覆盖最旧条目。项目可通过 `get_recent_entries()` 读取最近日志，并通过 `get_dropped_memory_entry_count()` 观察已丢弃条目数量。

需要诊断面板、编辑器窗口或远端采集器定期轮询时，优先使用 `get_memory_sequence()` 保存当前游标，再用 `get_entries_since()` 读取新增条目：

```gdscript
var cursor := log_util.get_memory_sequence()

# 后续某一帧或某次刷新
var result := log_util.get_entries_since(cursor, 100)
cursor = result["next_sequence"]
for entry in result["entries"]:
	print(entry["text"])
```

返回报告会包含 `oldest_sequence`、`current_sequence`、`next_sequence`、`truncated`、`has_more` 和 `missed_count`。如果调用方太久没有读取，旧日志可能已经被环形缓存覆盖，此时 `truncated = true`，应把 UI 标记为“部分日志已丢失”，而不是假设日志流完整。`clear_memory_entries()` 只清空缓存和丢弃计数，不重置序列游标，便于轮询方继续从清空之后的新增日志读起。

## 全局上下文

`trace_id` 是每次运行的轻量关联字段。项目可以显式设置，也可以使用默认生成值；全局上下文会合并到后续结构化日志条目中。

```gdscript
log_util.set_trace_id("session-20260509-001")
log_util.set_global_context({
	"scene": "battle",
	"profile": "debug",
})
```

结构化上下文会经过 `sanitize_log_value()` 清洗。过深嵌套、超长字符串和非 JSON 原生对象会被转换为可写入日志的稳定值，避免调试数据破坏日志文件或 sink。

## 崩溃标记

`crash_marker_enabled` 开启时，日志工具会在初始化时检查上一次运行是否留下未清理标记，并通过 `previous_crash_detected` 发出报告。该信号只提示“上次可能异常退出”，不替项目判断崩溃原因、上传策略或恢复流程。
