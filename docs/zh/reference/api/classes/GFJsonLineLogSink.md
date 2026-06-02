# GFJsonLineLogSink

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/logging/gf_json_line_log_sink.gd`
- 模块：`Standard`
- 继承：`GFLogSink`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

把结构化日志条目写入 JSON Lines 文件。 该 sink 只负责把 GFLogUtility 传入的条目序列化为一行一个 JSON 对象， 不规定采集服务、上传时机或业务字段 schema。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`file_path`](#member-gfjsonlinelogsink-properties-file_path) | `var file_path: String = ""` |
| 属性 | [`omit_formatted_text`](#member-gfjsonlinelogsink-properties-omit_formatted_text) | `var omit_formatted_text: bool = false` |
| 属性 | [`flush_interval_msec`](#member-gfjsonlinelogsink-properties-flush_interval_msec) | `var flush_interval_msec: int = 250` |
| 属性 | [`flush_immediately`](#member-gfjsonlinelogsink-properties-flush_immediately) | `var flush_immediately: bool = false` |
| 属性 | [`max_jsonl_files`](#member-gfjsonlinelogsink-properties-max_jsonl_files) | `var max_jsonl_files: int = 10:` |
| 方法 | [`init`](#member-gfjsonlinelogsink-methods-init) | `func init(owner: Object) -> void:` |
| 方法 | [`write`](#member-gfjsonlinelogsink-methods-write) | `func write(entry: Dictionary) -> void:` |
| 方法 | [`flush`](#member-gfjsonlinelogsink-methods-flush) | `func flush() -> void:` |
| 方法 | [`shutdown`](#member-gfjsonlinelogsink-methods-shutdown) | `func shutdown() -> void:` |
| 方法 | [`get_file_path`](#member-gfjsonlinelogsink-methods-get_file_path) | `func get_file_path() -> String:` |

## 属性

<a id="member-gfjsonlinelogsink-properties-file_path"></a>

### `file_path`

- API：`public`

```gdscript
var file_path: String = ""
```

输出文件路径。留空时会根据 GFLogUtility 当前日志文件派生同名 `.jsonl` 文件。

<a id="member-gfjsonlinelogsink-properties-omit_formatted_text"></a>

### `omit_formatted_text`

- API：`public`

```gdscript
var omit_formatted_text: bool = false
```

是否在写入前移除 `text` 字段，减少重复存储。

<a id="member-gfjsonlinelogsink-properties-flush_interval_msec"></a>

### `flush_interval_msec`

- API：`public`

```gdscript
var flush_interval_msec: int = 250
```

文件自动 flush 间隔。设为 0 时每条日志都会立即 flush。

<a id="member-gfjsonlinelogsink-properties-flush_immediately"></a>

### `flush_immediately`

- API：`public`

```gdscript
var flush_immediately: bool = false
```

是否强制每条 JSONL 日志立即 flush。

<a id="member-gfjsonlinelogsink-properties-max_jsonl_files"></a>

### `max_jsonl_files`

- API：`public`

```gdscript
var max_jsonl_files: int = 10:
```

使用默认派生路径时最多保留的 JSONL 文件数量。

## 方法

<a id="member-gfjsonlinelogsink-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init(owner: Object) -> void:
```

初始化 sink 并打开 JSONL 文件。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 持有该 sink 的日志工具。 |

<a id="member-gfjsonlinelogsink-methods-write"></a>

### `write`

- API：`public`

```gdscript
func write(entry: Dictionary) -> void:
```

写入一条结构化日志。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 日志条目字典。 |

结构：

- `entry`: Dictionary log entry produced by GFLogUtility.

<a id="member-gfjsonlinelogsink-methods-flush"></a>

### `flush`

- API：`public`

```gdscript
func flush() -> void:
```

刷新尚未写出的 JSONL 内容。

<a id="member-gfjsonlinelogsink-methods-shutdown"></a>

### `shutdown`

- API：`public`

```gdscript
func shutdown() -> void:
```

关闭文件句柄。

<a id="member-gfjsonlinelogsink-methods-get_file_path"></a>

### `get_file_path`

- API：`public`

```gdscript
func get_file_path() -> String:
```

获取当前实际输出路径。

返回：JSONL 文件路径。
