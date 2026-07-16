# GFLogSink

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/logging/gf_log_sink.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

日志输出 sink 基类。 项目可以继承该类，把 GFLogUtility 的结构化日志条目写入 JSONL、 远端采集、编辑器面板或其他自定义目标。Sink 不拥有日志工具生命周期， 只响应 init/write/flush/shutdown 钩子。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_report_redaction_profile`](#member-gflogsink-methods-get_report_redaction_profile) | `func get_report_redaction_profile() -> String:` |
| 方法 | [`init`](#member-gflogsink-methods-init) | `func init(_owner: Object) -> void:` |
| 方法 | [`write`](#member-gflogsink-methods-write) | `func write(_entry: Dictionary) -> void:` |
| 方法 | [`flush`](#member-gflogsink-methods-flush) | `func flush() -> void:` |
| 方法 | [`shutdown`](#member-gflogsink-methods-shutdown) | `func shutdown() -> void:` |

## 方法

<a id="member-gflogsink-methods-get_report_redaction_profile"></a>

### `get_report_redaction_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_report_redaction_profile() -> String:
```

获取该输出边界使用的报告脱敏 profile。 未知 sink 默认采用 public；仅本地、受控的诊断 sink 应显式覆盖为 debug。

返回：GFReportValueCodec REDACTION_PROFILE_* 常量之一。

结构：

- `return`: String naming one GFReportValueCodec redaction profile.

<a id="member-gflogsink-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init(_owner: Object) -> void:
```

初始化 sink。

参数：

| 名称 | 说明 |
|---|---|
| `_owner` | 持有该 sink 的日志工具。 |

<a id="member-gflogsink-methods-write"></a>

### `write`

- API：`public`

```gdscript
func write(_entry: Dictionary) -> void:
```

写入一条结构化日志。

参数：

| 名称 | 说明 |
|---|---|
| `_entry` | 日志条目字典。 |

结构：

- `_entry`: Dictionary log entry produced by GFLogUtility.

<a id="member-gflogsink-methods-flush"></a>

### `flush`

- API：`public`

```gdscript
func flush() -> void:
```

刷新尚未写出的缓冲。

<a id="member-gflogsink-methods-shutdown"></a>

### `shutdown`

- API：`public`

```gdscript
func shutdown() -> void:
```

关闭 sink 并释放内部资源。
