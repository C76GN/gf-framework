# GFPathEnumerationTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_path_enumeration_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

只读文件路径枚举工具。 统一处理目录递归、隐藏文件、扩展名白名单、排除路径、深度上限和数量上限。 它只返回路径和扫描报告，不读取文件内容、不生成资源注册表，也不规定项目目录结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfpathenumerationtools-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_FILE_COUNT`](#member-gfpathenumerationtools-constants-default_max_file_count) | `const DEFAULT_MAX_FILE_COUNT: int = 10000` |
| 常量 | [`DEFAULT_MAX_ENTRY_COUNT`](#member-gfpathenumerationtools-constants-default_max_entry_count) | `const DEFAULT_MAX_ENTRY_COUNT: int = 10000` |
| 方法 | [`enumerate_files`](#member-gfpathenumerationtools-methods-enumerate_files) | `static func enumerate_files(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`scan_files`](#member-gfpathenumerationtools-methods-scan_files) | `static func scan_files(root_path: String = "res://", options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfpathenumerationtools-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认递归扫描深度上限。

<a id="member-gfpathenumerationtools-constants-default_max_file_count"></a>

### `DEFAULT_MAX_FILE_COUNT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_FILE_COUNT: int = 10000
```

默认单次枚举文件数量上限。

<a id="member-gfpathenumerationtools-constants-default_max_entry_count"></a>

### `DEFAULT_MAX_ENTRY_COUNT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_ENTRY_COUNT: int = 10000
```

默认单次枚举访问的目录项数量上限。

## 方法

<a id="member-gfpathenumerationtools-methods-enumerate_files"></a>

### `enumerate_files`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func enumerate_files(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
```

枚举目录中的文件路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点。 |
| `options` | 可选项，支持 recursive、include_hidden、extensions、excluded_paths、file_filter、max_scan_depth、max_file_count、max_entry_count 和 sort。 |

返回：按配置枚举出的文件路径。

结构：

- `options`: Dictionary with optional recursive, include_hidden, extensions, excluded_paths, file_filter, max_scan_depth, max_file_count, max_entry_count, and sort fields. file_filter receives a normalized file path and returns bool.

<a id="member-gfpathenumerationtools-methods-scan_files"></a>

### `scan_files`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func scan_files(root_path: String = "res://", options: Dictionary = {}) -> Dictionary:
```

枚举目录中的文件路径并返回扫描报告。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点。 |
| `options` | 可选项，支持 recursive、include_hidden、extensions、excluded_paths、file_filter、max_scan_depth、max_file_count、max_entry_count 和 sort。 |

返回：扫描报告。

结构：

- `options`: Dictionary with optional recursive, include_hidden, extensions, excluded_paths, file_filter, max_scan_depth, max_file_count, max_entry_count, and sort fields. file_filter receives a normalized file path and returns bool.
- `return`: Dictionary with ok, root_path, paths, scanned_count, visited_entry_count, truncated, limit_kind, limit_path, and limit_value.
