# GFExtensionUsageAudit

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_usage_audit.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

检查禁用扩展是否仍被项目文件直接引用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`REFERENCE_STRENGTH_VERIFIED`](#member-gfextensionusageaudit-constants-reference_strength_verified) | `const REFERENCE_STRENGTH_VERIFIED: StringName = &"verified"` |
| 常量 | [`REFERENCE_STRENGTH_STRONG`](#member-gfextensionusageaudit-constants-reference_strength_strong) | `const REFERENCE_STRENGTH_STRONG: StringName = &"strong"` |
| 常量 | [`REFERENCE_STRENGTH_WEAK`](#member-gfextensionusageaudit-constants-reference_strength_weak) | `const REFERENCE_STRENGTH_WEAK: StringName = &"weak"` |
| 常量 | [`REFERENCE_SOURCE_GDSCRIPT_LOAD`](#member-gfextensionusageaudit-constants-reference_source_gdscript_load) | `const REFERENCE_SOURCE_GDSCRIPT_LOAD: StringName = &"gdscript_load"` |
| 常量 | [`REFERENCE_SOURCE_GDSCRIPT_SYMBOL`](#member-gfextensionusageaudit-constants-reference_source_gdscript_symbol) | `const REFERENCE_SOURCE_GDSCRIPT_SYMBOL: StringName = &"gdscript_symbol"` |
| 常量 | [`REFERENCE_SOURCE_RESOURCE_TEXT`](#member-gfextensionusageaudit-constants-reference_source_resource_text) | `const REFERENCE_SOURCE_RESOURCE_TEXT: StringName = &"resource_text"` |
| 常量 | [`REFERENCE_SOURCE_GODOT_DEPENDENCY`](#member-gfextensionusageaudit-constants-reference_source_godot_dependency) | `const REFERENCE_SOURCE_GODOT_DEPENDENCY: StringName = &"godot_dependency"` |
| 常量 | [`REFERENCE_SOURCE_TEXT_FALLBACK`](#member-gfextensionusageaudit-constants-reference_source_text_fallback) | `const REFERENCE_SOURCE_TEXT_FALLBACK: StringName = &"text_fallback"` |
| 常量 | [`DEFAULT_SCAN_ROOTS`](#member-gfextensionusageaudit-constants-default_scan_roots) | `const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfextensionusageaudit-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_SCANNED_FILES`](#member-gfextensionusageaudit-constants-default_max_scanned_files) | `const DEFAULT_MAX_SCANNED_FILES: int = 10000` |
| 常量 | [`DEFAULT_MAX_FILE_BYTES`](#member-gfextensionusageaudit-constants-default_max_file_bytes) | `const DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024` |
| 常量 | [`DEFAULT_MAX_TOTAL_BYTES`](#member-gfextensionusageaudit-constants-default_max_total_bytes) | `const DEFAULT_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024` |
| 常量 | [`DEFAULT_IGNORED_ROOTS`](#member-gfextensionusageaudit-constants-default_ignored_roots) | `const DEFAULT_IGNORED_ROOTS: Array[String] = [ 	"res://.godot", 	"res://.git", 	"res://.gf", 	"res://addons/gf", 	"res://build", 	"res://packages", ]` |
| 常量 | [`TEXT_FILE_EXTENSIONS`](#member-gfextensionusageaudit-constants-text_file_extensions) | `const TEXT_FILE_EXTENSIONS: Array[String] = [ 	"cfg", 	"csv", 	"gd", 	"gdshader", 	"godot", 	"import", 	"json", 	"shader", 	"tscn", 	"tres", ]` |
| 方法 | [`audit_disabled_extensions`](#member-gfextensionusageaudit-methods-audit_disabled_extensions) | `static func audit_disabled_extensions( manifests: Array[GFExtensionManifest], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`find_references_to_root`](#member-gfextensionusageaudit-methods-find_references_to_root) | `static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`find_references_to_root_report`](#member-gfextensionusageaudit-methods-find_references_to_root_report) | `static func find_references_to_root_report( root_path: String, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfextensionusageaudit-constants-reference_strength_verified"></a>

### `REFERENCE_STRENGTH_VERIFIED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_STRENGTH_VERIFIED: StringName = &"verified"
```

Godot 依赖图确认的资源引用。

<a id="member-gfextensionusageaudit-constants-reference_strength_strong"></a>

### `REFERENCE_STRENGTH_STRONG`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_STRENGTH_STRONG: StringName = &"strong"
```

静态语义扫描确认的资源或 class_name 引用。

<a id="member-gfextensionusageaudit-constants-reference_strength_weak"></a>

### `REFERENCE_STRENGTH_WEAK`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_STRENGTH_WEAK: StringName = &"weak"
```

仅文本命中的弱引用提示，不会让禁用扩展审计失败。

<a id="member-gfextensionusageaudit-constants-reference_source_gdscript_load"></a>

### `REFERENCE_SOURCE_GDSCRIPT_LOAD`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_GDSCRIPT_LOAD: StringName = &"gdscript_load"
```

GDScript load/preload 等加载表达式来源。

<a id="member-gfextensionusageaudit-constants-reference_source_gdscript_symbol"></a>

### `REFERENCE_SOURCE_GDSCRIPT_SYMBOL`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_GDSCRIPT_SYMBOL: StringName = &"gdscript_symbol"
```

GDScript class_name 标识符来源。

<a id="member-gfextensionusageaudit-constants-reference_source_resource_text"></a>

### `REFERENCE_SOURCE_RESOURCE_TEXT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_RESOURCE_TEXT: StringName = &"resource_text"
```

Godot 文本资源依赖字段来源。

<a id="member-gfextensionusageaudit-constants-reference_source_godot_dependency"></a>

### `REFERENCE_SOURCE_GODOT_DEPENDENCY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_GODOT_DEPENDENCY: StringName = &"godot_dependency"
```

Godot ResourceLoader 依赖图来源。

<a id="member-gfextensionusageaudit-constants-reference_source_text_fallback"></a>

### `REFERENCE_SOURCE_TEXT_FALLBACK`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_TEXT_FALLBACK: StringName = &"text_fallback"
```

无法确认语义的文本命中来源。

<a id="member-gfextensionusageaudit-constants-default_scan_roots"></a>

### `DEFAULT_SCAN_ROOTS`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]
```

默认扫描根目录。

<a id="member-gfextensionusageaudit-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认最大扫描深度。

<a id="member-gfextensionusageaudit-constants-default_max_scanned_files"></a>

### `DEFAULT_MAX_SCANNED_FILES`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_MAX_SCANNED_FILES: int = 10000
```

默认最大扫描文件数。

<a id="member-gfextensionusageaudit-constants-default_max_file_bytes"></a>

### `DEFAULT_MAX_FILE_BYTES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024
```

默认单文件读取字节上限。

<a id="member-gfextensionusageaudit-constants-default_max_total_bytes"></a>

### `DEFAULT_MAX_TOTAL_BYTES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024
```

默认单次扫描总读取字节上限。

<a id="member-gfextensionusageaudit-constants-default_ignored_roots"></a>

### `DEFAULT_IGNORED_ROOTS`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_IGNORED_ROOTS: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://.gf",
	"res://addons/gf",
	"res://build",
	"res://packages",
]
```

默认忽略的根目录。

<a id="member-gfextensionusageaudit-constants-text_file_extensions"></a>

### `TEXT_FILE_EXTENSIONS`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const TEXT_FILE_EXTENSIONS: Array[String] = [
	"cfg",
	"csv",
	"gd",
	"gdshader",
	"godot",
	"import",
	"json",
	"shader",
	"tscn",
	"tres",
]
```

作为文本扫描的资源扩展名。

## 方法

<a id="member-gfextensionusageaudit-methods-audit_disabled_extensions"></a>

### `audit_disabled_extensions`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func audit_disabled_extensions( manifests: Array[GFExtensionManifest], options: Dictionary = {} ) -> Dictionary:
```

检查一组禁用扩展是否仍被项目文件直接引用。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 要检查的禁用扩展 manifest 列表。 |
| `options` | 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_weak_references_per_extension、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references 和 use_resource_dependencies。 |

返回：引用审计报告。

结构：

- `options`: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, depth, scanned file count, file byte budget, total byte budget, weak text reporting, and Godot dependency graph usage.
- `return`: Dictionary containing ok, partial_scan, budget_exceeded, extension_count, reference_count, weak_reference_count, extensions, weak_extensions, references, weak_references, candidate_file_count, scanned_file_count, scanned_bytes, skipped_files, scan_warnings, issue_count, issues, and class_name_scan. references only contains strong or verified blocking references.

<a id="member-gfextensionusageaudit-methods-find_references_to_root"></a>

### `find_references_to_root`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
```

查找项目文件中对指定扩展根目录的直接路径引用。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扩展根目录。 |
| `options` | 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_weak_references_per_extension、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references 和 use_resource_dependencies。 |

返回：引用列表。

结构：

- `options`: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, depth, scanned file count, file byte budget, total byte budget, weak text reporting, and Godot dependency graph usage.
- `return`: Array of Dictionary file reference records. By default only strong or verified blocking references are returned; include_weak_references appends weak text matches.

<a id="member-gfextensionusageaudit-methods-find_references_to_root_report"></a>

### `find_references_to_root_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func find_references_to_root_report( root_path: String, options: Dictionary = {} ) -> Dictionary:
```

查找项目文件中对指定扩展根目录的直接引用，并返回扫描完整性报告。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扩展根目录。 |
| `options` | 参数同 find_references_to_root()。 |

返回：引用与扫描完整性报告。

结构：

- `options`: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, shared depth, candidate file count, file byte and total byte budgets, weak text reporting, and Godot dependency graph usage.
- `return`: Dictionary containing ok, partial_scan, budget_exceeded, truncated, references, weak_references, candidate_file_count, scanned_file_count, scanned_bytes, skipped_files, scan_warnings, issue_count, issues, and class_name_scan.
