# GFAudioLibraryTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_library_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`5.0.0`

音频素材库扫描、搜索和导入计划工具。 面向编辑器 Workspace、Inspector 和构建脚本复用；它只处理音频候选 文件、目标路径规划和文件复制，不接管运行时播放、事件命名或混音策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_SEARCH_FIELDS`](#member-gfaudiolibrarytools-constants-default_search_fields) | `const DEFAULT_SEARCH_FIELDS: PackedStringArray = ["clip_id", "relative_path", "file_name", "source_path"]` |
| 常量 | [`DEFAULT_MAX_COPY_FILES`](#member-gfaudiolibrarytools-constants-default_max_copy_files) | `const DEFAULT_MAX_COPY_FILES: int = 10000` |
| 常量 | [`DEFAULT_MAX_COPY_BYTES`](#member-gfaudiolibrarytools-constants-default_max_copy_bytes) | `const DEFAULT_MAX_COPY_BYTES: int = 512 * 1024 * 1024` |
| 方法 | [`scan_library`](#member-gfaudiolibrarytools-methods-scan_library) | `static func scan_library(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`build_entries`](#member-gfaudiolibrarytools-methods-build_entries) | `static func build_entries( paths: PackedStringArray, library_root: String, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`filter_entries`](#member-gfaudiolibrarytools-methods-filter_entries) | `static func filter_entries( entries: Array[Dictionary], query: String, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`make_import_plan`](#member-gfaudiolibrarytools-methods-make_import_plan) | `static func make_import_plan( entries: Array[Dictionary], target_root: String, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`copy_import_plan`](#member-gfaudiolibrarytools-methods-copy_import_plan) | `static func copy_import_plan(plan: Array[Dictionary], options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`get_plan_target_paths`](#member-gfaudiolibrarytools-methods-get_plan_target_paths) | `static func get_plan_target_paths(plan: Array[Dictionary], only_copyable: bool = false) -> PackedStringArray:` |

## 常量

<a id="member-gfaudiolibrarytools-constants-default_search_fields"></a>

### `DEFAULT_SEARCH_FIELDS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_SEARCH_FIELDS: PackedStringArray = ["clip_id", "relative_path", "file_name", "source_path"]
```

默认搜索字段。

<a id="member-gfaudiolibrarytools-constants-default_max_copy_files"></a>

### `DEFAULT_MAX_COPY_FILES`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_COPY_FILES: int = 10000
```

默认单次复制计划可执行的文件数量上限。传入 0 表示不限制。

<a id="member-gfaudiolibrarytools-constants-default_max_copy_bytes"></a>

### `DEFAULT_MAX_COPY_BYTES`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_COPY_BYTES: int = 512 * 1024 * 1024
```

默认单次复制计划可执行的总字节上限。传入 0 表示不限制。

## 方法

<a id="member-gfaudiolibrarytools-methods-scan_library"></a>

### `scan_library`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func scan_library(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
```

扫描音频素材库并返回结构化候选条目。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，可为 res://、user:// 或本地绝对目录。 |
| `options` | 可选项，支持 GFAudioBankTools.scan_audio_paths() 的扫描选项，以及 id_mode、base_path、path_separator、strip_extension。 |

返回：音频候选条目数组。

结构：

- `options`: Dictionary，可包含扫描选项和片段 ID 生成选项。
- `return`: Array[Dictionary]，元素包含 source_path、library_root、relative_path、directory、file_name、basename、extension 和 clip_id 字段。

<a id="member-gfaudiolibrarytools-methods-build_entries"></a>

### `build_entries`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func build_entries( paths: PackedStringArray, library_root: String, options: Dictionary = {} ) -> Array[Dictionary]:
```

从已有路径列表构建音频素材库候选条目。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 音频文件路径列表。 |
| `library_root` | 候选条目的素材库根目录。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension。 |

返回：音频候选条目数组。

结构：

- `options`: Dictionary，可包含片段 ID 生成选项。
- `return`: Array[Dictionary]，元素包含 source_path、library_root、relative_path、directory、file_name、basename、extension 和 clip_id 字段。

<a id="member-gfaudiolibrarytools-methods-filter_entries"></a>

### `filter_entries`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func filter_entries( entries: Array[Dictionary], query: String, options: Dictionary = {} ) -> Array[Dictionary]:
```

按关键字过滤音频素材库候选条目。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | scan_library() 或 build_entries() 返回的候选条目。 |
| `query` | 空格分隔的搜索词。 |
| `options` | 可选项，支持 fields、match_all 和 case_sensitive。 |

返回：过滤后的候选条目副本。

结构：

- `entries`: Array[Dictionary]，元素包含可搜索字段。
- `options`: Dictionary，可包含 fields: PackedStringArray、match_all: bool 和 case_sensitive: bool。
- `return`: Array[Dictionary]，元素为匹配的候选条目副本。

<a id="member-gfaudiolibrarytools-methods-make_import_plan"></a>

### `make_import_plan`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func make_import_plan( entries: Array[Dictionary], target_root: String, options: Dictionary = {} ) -> Array[Dictionary]:
```

为素材库候选生成导入计划。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | scan_library() 或 build_entries() 返回的候选条目。 |
| `target_root` | 目标根目录，通常为 res://audio 下的目录。 |
| `options` | 可选项，支持 preserve_structure、overwrite 和 check_source_exists。 |

返回：导入计划条目数组。

结构：

- `entries`: Array[Dictionary]，元素包含 source_path、relative_path 和 clip_id 字段。
- `options`: Dictionary，可包含 preserve_structure: bool、overwrite: bool 和 check_source_exists: bool。
- `return`: Array[Dictionary]，元素包含 source_path、target_path、relative_path、clip_id、extension、source_exists、target_exists、will_copy 和 reason 字段。

<a id="member-gfaudiolibrarytools-methods-copy_import_plan"></a>

### `copy_import_plan`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func copy_import_plan(plan: Array[Dictionary], options: Dictionary = {}) -> GFValidationReport:
```

按导入计划复制音频文件。 当前纯 GDScript 实现仅适用于调用方独占的可信单写者目录； 每个 target 对应的 `.gf-copy.tmp` 与 `.gf-copy.backup` 名称属于事务保留命名空间。

参数：

| 名称 | 说明 |
|---|---|
| `plan` | make_import_plan() 返回的导入计划。 |
| `options` | 可选项，支持 overwrite、max_copy_files 与 max_copy_bytes。 |

返回：复制报告。

结构：

- `plan`: Array[Dictionary]，元素包含 source_path、target_path、will_copy 和 reason 字段。
- `options`: Dictionary，可包含 overwrite: bool、max_copy_files: int 与 max_copy_bytes: int；上限为 0 时表示不限制。
- `return`: GFValidationReport；metadata 包含 planned_copy_count、planned_copy_bytes、copy_preflight_complete、copied_count、skipped_count、error_count、copied_paths、consumed_copy_bytes 和 committed_copy_bytes；恢复或清理失败通过结构化 issue metadata 暴露 deterministic temp/backup path 与 recovery state。

<a id="member-gfaudiolibrarytools-methods-get_plan_target_paths"></a>

### `get_plan_target_paths`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func get_plan_target_paths(plan: Array[Dictionary], only_copyable: bool = false) -> PackedStringArray:
```

从导入计划收集目标路径。

参数：

| 名称 | 说明 |
|---|---|
| `plan` | make_import_plan() 返回的导入计划。 |
| `only_copyable` | 为 true 时只返回 will_copy 为 true 的条目。 |

返回：去重后的目标路径列表。

结构：

- `plan`: Array[Dictionary]，元素包含 target_path 和 will_copy 字段。
