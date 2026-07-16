# GFDirectoryWatchUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_directory_watch_utility.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.23.0`

调用方驱动的目录变化检测工具。 通过显式 poll() 对目录快照做差异比较，适合编辑器工具、资产索引器、 构建脚本或项目安装器按自己的节奏刷新资源。它不创建 Autoload， 也不在后台自行扫描。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`changed`](#member-gfdirectorywatchutility-signals-changed) | `signal changed(change_set: GFDirectoryChangeSet)` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfdirectorywatchutility-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_FILE_COUNT`](#member-gfdirectorywatchutility-constants-default_max_file_count) | `const DEFAULT_MAX_FILE_COUNT: int = 10000` |
| 属性 | [`recursive`](#member-gfdirectorywatchutility-properties-recursive) | `var recursive: bool = true` |
| 属性 | [`include_hidden`](#member-gfdirectorywatchutility-properties-include_hidden) | `var include_hidden: bool = false` |
| 属性 | [`extensions`](#member-gfdirectorywatchutility-properties-extensions) | `var extensions: PackedStringArray = PackedStringArray()` |
| 属性 | [`excluded_paths`](#member-gfdirectorywatchutility-properties-excluded_paths) | `var excluded_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`max_scan_depth`](#member-gfdirectorywatchutility-properties-max_scan_depth) | `var max_scan_depth: int = DEFAULT_MAX_SCAN_DEPTH` |
| 属性 | [`max_file_count`](#member-gfdirectorywatchutility-properties-max_file_count) | `var max_file_count: int = DEFAULT_MAX_FILE_COUNT` |
| 属性 | [`report_existing_on_first_scan`](#member-gfdirectorywatchutility-properties-report_existing_on_first_scan) | `var report_existing_on_first_scan: bool = false` |
| 方法 | [`configure`](#member-gfdirectorywatchutility-methods-configure) | `func configure(options: Dictionary = {}) -> GFDirectoryWatchUtility:` |
| 方法 | [`watch_path`](#member-gfdirectorywatchutility-methods-watch_path) | `func watch_path(path: String) -> void:` |
| 方法 | [`unwatch_path`](#member-gfdirectorywatchutility-methods-unwatch_path) | `func unwatch_path(path: String) -> bool:` |
| 方法 | [`clear_watch_paths`](#member-gfdirectorywatchutility-methods-clear_watch_paths) | `func clear_watch_paths() -> void:` |
| 方法 | [`get_watch_paths`](#member-gfdirectorywatchutility-methods-get_watch_paths) | `func get_watch_paths() -> PackedStringArray:` |
| 方法 | [`reset_snapshot`](#member-gfdirectorywatchutility-methods-reset_snapshot) | `func reset_snapshot() -> void:` |
| 方法 | [`poll`](#member-gfdirectorywatchutility-methods-poll) | `func poll() -> GFDirectoryChangeSet:` |
| 方法 | [`get_snapshot`](#member-gfdirectorywatchutility-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfdirectorywatchutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfdirectorywatchutility-signals-changed"></a>

### `changed`

- API：`public`

```gdscript
signal changed(change_set: GFDirectoryChangeSet)
```

poll() 发现文件变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `change_set` | 本次变化集。 |

## 常量

<a id="member-gfdirectorywatchutility-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认递归扫描深度上限。

<a id="member-gfdirectorywatchutility-constants-default_max_file_count"></a>

### `DEFAULT_MAX_FILE_COUNT`

- API：`public`

```gdscript
const DEFAULT_MAX_FILE_COUNT: int = 10000
```

默认单次扫描文件数量上限。

## 属性

<a id="member-gfdirectorywatchutility-properties-recursive"></a>

### `recursive`

- API：`public`

```gdscript
var recursive: bool = true
```

是否递归扫描子目录。

<a id="member-gfdirectorywatchutility-properties-include_hidden"></a>

### `include_hidden`

- API：`public`

```gdscript
var include_hidden: bool = false
```

是否包含隐藏文件和隐藏目录。

<a id="member-gfdirectorywatchutility-properties-extensions"></a>

### `extensions`

- API：`public`

```gdscript
var extensions: PackedStringArray = PackedStringArray()
```

可选扩展名白名单。不包含点号；为空表示包含全部文件。

<a id="member-gfdirectorywatchutility-properties-excluded_paths"></a>

### `excluded_paths`

- API：`public`

```gdscript
var excluded_paths: PackedStringArray = PackedStringArray()
```

排除路径。命中目录或其子路径会被跳过。

<a id="member-gfdirectorywatchutility-properties-max_scan_depth"></a>

### `max_scan_depth`

- API：`public`

```gdscript
var max_scan_depth: int = DEFAULT_MAX_SCAN_DEPTH
```

递归扫描深度上限。0 表示不限制。

<a id="member-gfdirectorywatchutility-properties-max_file_count"></a>

### `max_file_count`

- API：`public`

```gdscript
var max_file_count: int = DEFAULT_MAX_FILE_COUNT
```

单次扫描文件数量上限。0 表示不限制。

<a id="member-gfdirectorywatchutility-properties-report_existing_on_first_scan"></a>

### `report_existing_on_first_scan`

- API：`public`

```gdscript
var report_existing_on_first_scan: bool = false
```

首次 poll() 是否把已存在文件报告为 created。

## 方法

<a id="member-gfdirectorywatchutility-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(options: Dictionary = {}) -> GFDirectoryWatchUtility:
```

按字典选项配置检测器。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项，支持 recursive、include_hidden、extensions、excluded_paths、max_scan_depth、max_file_count 和 report_existing_on_first_scan。 |

返回：当前检测器。

结构：

- `options`: Dictionary controlling scan behavior.

<a id="member-gfdirectorywatchutility-methods-watch_path"></a>

### `watch_path`

- API：`public`

```gdscript
func watch_path(path: String) -> void:
```

添加监听目录。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 要监听的目录路径。 |

<a id="member-gfdirectorywatchutility-methods-unwatch_path"></a>

### `unwatch_path`

- API：`public`

```gdscript
func unwatch_path(path: String) -> bool:
```

移除监听目录。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 要移除的目录路径。 |

返回：成功移除时返回 true。

<a id="member-gfdirectorywatchutility-methods-clear_watch_paths"></a>

### `clear_watch_paths`

- API：`public`

```gdscript
func clear_watch_paths() -> void:
```

清空监听目录。

<a id="member-gfdirectorywatchutility-methods-get_watch_paths"></a>

### `get_watch_paths`

- API：`public`

```gdscript
func get_watch_paths() -> PackedStringArray:
```

获取监听目录副本。

返回：监听目录列表。

<a id="member-gfdirectorywatchutility-methods-reset_snapshot"></a>

### `reset_snapshot`

- API：`public`

```gdscript
func reset_snapshot() -> void:
```

清空已有快照。下一次 poll() 会重新建立基线。

<a id="member-gfdirectorywatchutility-methods-poll"></a>

### `poll`

- API：`public`

```gdscript
func poll() -> GFDirectoryChangeSet:
```

扫描当前监听目录并返回变化集。

返回：本次变化集。

<a id="member-gfdirectorywatchutility-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`3.23.0`

```gdscript
func get_snapshot() -> Dictionary:
```

获取当前快照副本。

返回：当前快照字典。

结构：

- `return`: Dictionary keyed by file path with file metadata dictionaries containing modified_time, size_bytes, and content_sha256.

<a id="member-gfdirectorywatchutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：检测器状态字典。

结构：

- `return`: Dictionary with watch_paths, snapshot_size, has_snapshot, and scan options.
