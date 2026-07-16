# GFProjectReferenceScanner

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_project_reference_scanner.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

项目资源引用扫描服务。 面向编辑器、CI 和框架诊断流程扫描项目资源与文本源码，按目标根目录和 class_name 输出 verified、strong 与 weak 分级引用，并在文件数量、 目录深度和读取字节预算耗尽时返回 fail-closed 诊断。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`REFERENCE_STRENGTH_VERIFIED`](#member-gfprojectreferencescanner-constants-reference_strength_verified) | `const REFERENCE_STRENGTH_VERIFIED: StringName = &"verified"` |
| 常量 | [`REFERENCE_STRENGTH_STRONG`](#member-gfprojectreferencescanner-constants-reference_strength_strong) | `const REFERENCE_STRENGTH_STRONG: StringName = &"strong"` |
| 常量 | [`REFERENCE_STRENGTH_WEAK`](#member-gfprojectreferencescanner-constants-reference_strength_weak) | `const REFERENCE_STRENGTH_WEAK: StringName = &"weak"` |
| 常量 | [`REFERENCE_SOURCE_GDSCRIPT_LOAD`](#member-gfprojectreferencescanner-constants-reference_source_gdscript_load) | `const REFERENCE_SOURCE_GDSCRIPT_LOAD: StringName = &"gdscript_load"` |
| 常量 | [`REFERENCE_SOURCE_GDSCRIPT_SYMBOL`](#member-gfprojectreferencescanner-constants-reference_source_gdscript_symbol) | `const REFERENCE_SOURCE_GDSCRIPT_SYMBOL: StringName = &"gdscript_symbol"` |
| 常量 | [`REFERENCE_SOURCE_RESOURCE_TEXT`](#member-gfprojectreferencescanner-constants-reference_source_resource_text) | `const REFERENCE_SOURCE_RESOURCE_TEXT: StringName = &"resource_text"` |
| 常量 | [`REFERENCE_SOURCE_GODOT_DEPENDENCY`](#member-gfprojectreferencescanner-constants-reference_source_godot_dependency) | `const REFERENCE_SOURCE_GODOT_DEPENDENCY: StringName = &"godot_dependency"` |
| 常量 | [`REFERENCE_SOURCE_TEXT_FALLBACK`](#member-gfprojectreferencescanner-constants-reference_source_text_fallback) | `const REFERENCE_SOURCE_TEXT_FALLBACK: StringName = &"text_fallback"` |
| 常量 | [`DEFAULT_SCAN_ROOTS`](#member-gfprojectreferencescanner-constants-default_scan_roots) | `const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfprojectreferencescanner-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_SCANNED_FILES`](#member-gfprojectreferencescanner-constants-default_max_scanned_files) | `const DEFAULT_MAX_SCANNED_FILES: int = 10000` |
| 常量 | [`DEFAULT_MAX_FILE_BYTES`](#member-gfprojectreferencescanner-constants-default_max_file_bytes) | `const DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024` |
| 常量 | [`DEFAULT_MAX_TOTAL_BYTES`](#member-gfprojectreferencescanner-constants-default_max_total_bytes) | `const DEFAULT_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024` |
| 常量 | [`DEFAULT_IGNORED_ROOTS`](#member-gfprojectreferencescanner-constants-default_ignored_roots) | `const DEFAULT_IGNORED_ROOTS: Array[String] = [` |
| 常量 | [`TEXT_FILE_EXTENSIONS`](#member-gfprojectreferencescanner-constants-text_file_extensions) | `const TEXT_FILE_EXTENSIONS: Array[String] = [` |
| 方法 | [`scan_references`](#member-gfprojectreferencescanner-methods-scan_references) | `static func scan_references(targets: Array[Dictionary], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`scan_root_references`](#member-gfprojectreferencescanner-methods-scan_root_references) | `static func scan_root_references( root_path: String, class_names: Array[String] = [], options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfprojectreferencescanner-constants-reference_strength_verified"></a>

### `REFERENCE_STRENGTH_VERIFIED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_STRENGTH_VERIFIED: StringName = &"verified"
```

Godot 依赖图确认的资源引用。

<a id="member-gfprojectreferencescanner-constants-reference_strength_strong"></a>

### `REFERENCE_STRENGTH_STRONG`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_STRENGTH_STRONG: StringName = &"strong"
```

静态语义扫描确认的资源或 class_name 引用。

<a id="member-gfprojectreferencescanner-constants-reference_strength_weak"></a>

### `REFERENCE_STRENGTH_WEAK`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_STRENGTH_WEAK: StringName = &"weak"
```

仅文本命中的弱引用提示，不会让扫描报告的引用计数阻断。

<a id="member-gfprojectreferencescanner-constants-reference_source_gdscript_load"></a>

### `REFERENCE_SOURCE_GDSCRIPT_LOAD`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_GDSCRIPT_LOAD: StringName = &"gdscript_load"
```

GDScript load/preload 等加载表达式来源。

<a id="member-gfprojectreferencescanner-constants-reference_source_gdscript_symbol"></a>

### `REFERENCE_SOURCE_GDSCRIPT_SYMBOL`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_GDSCRIPT_SYMBOL: StringName = &"gdscript_symbol"
```

GDScript class_name 标识符来源。

<a id="member-gfprojectreferencescanner-constants-reference_source_resource_text"></a>

### `REFERENCE_SOURCE_RESOURCE_TEXT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_RESOURCE_TEXT: StringName = &"resource_text"
```

Godot 文本资源依赖字段来源。

<a id="member-gfprojectreferencescanner-constants-reference_source_godot_dependency"></a>

### `REFERENCE_SOURCE_GODOT_DEPENDENCY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_GODOT_DEPENDENCY: StringName = &"godot_dependency"
```

Godot ResourceLoader 依赖图来源。

<a id="member-gfprojectreferencescanner-constants-reference_source_text_fallback"></a>

### `REFERENCE_SOURCE_TEXT_FALLBACK`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REFERENCE_SOURCE_TEXT_FALLBACK: StringName = &"text_fallback"
```

无法确认语义的文本命中来源。

<a id="member-gfprojectreferencescanner-constants-default_scan_roots"></a>

### `DEFAULT_SCAN_ROOTS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]
```

默认扫描根目录。

<a id="member-gfprojectreferencescanner-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认最大扫描深度。

<a id="member-gfprojectreferencescanner-constants-default_max_scanned_files"></a>

### `DEFAULT_MAX_SCANNED_FILES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_SCANNED_FILES: int = 10000
```

默认最大候选扫描文件数。

<a id="member-gfprojectreferencescanner-constants-default_max_file_bytes"></a>

### `DEFAULT_MAX_FILE_BYTES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024
```

默认单文件读取字节上限。

<a id="member-gfprojectreferencescanner-constants-default_max_total_bytes"></a>

### `DEFAULT_MAX_TOTAL_BYTES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024
```

默认单次扫描总读取字节上限。

<a id="member-gfprojectreferencescanner-constants-default_ignored_roots"></a>

### `DEFAULT_IGNORED_ROOTS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_IGNORED_ROOTS: Array[String] = [
```

默认忽略的根目录。

<a id="member-gfprojectreferencescanner-constants-text_file_extensions"></a>

### `TEXT_FILE_EXTENSIONS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TEXT_FILE_EXTENSIONS: Array[String] = [
```

作为文本扫描的资源扩展名。

## 方法

<a id="member-gfprojectreferencescanner-methods-scan_references"></a>

### `scan_references`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func scan_references(targets: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
```

扫描项目文件对一组目标根目录或 class_name 的引用。

参数：

| 名称 | 说明 |
|---|---|
| `targets` | 扫描目标列表。 |
| `options` | 可选扫描参数。 |

返回：项目引用扫描报告。

结构：

- `targets`: Array[Dictionary]，每个目标支持 id、root_path 和 class_names；id 为空时使用 root_path。
- `options`: Dictionary，支持 scan_roots、ignored_roots、additional_ignored_roots、max_references_per_target、max_weak_references_per_target、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references、use_resource_dependencies 和 warning_prefix。
- `return`: Dictionary，包含 ok、partial_scan、budget_exceeded、input_target_count、target_count、reference_count、weak_reference_count、targets、weak_targets、references、weak_references、candidate_file_count、scanned_file_count、scanned_bytes、skipped_files 和 scan_warnings。

<a id="member-gfprojectreferencescanner-methods-scan_root_references"></a>

### `scan_root_references`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func scan_root_references( root_path: String, class_names: Array[String] = [], options: Dictionary = {} ) -> Dictionary:
```

扫描项目文件对单个根目录的引用。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 要匹配的根目录。 |
| `class_names` | 同一目标根目录下需要匹配的 class_name 列表。 |
| `options` | 可选扫描参数。 |

返回：单目标项目引用扫描报告。

结构：

- `class_names`: Array[String]，与 root_path 同属一个目标的公开 class_name 列表。
- `options`: Dictionary，支持 scan_references() 的所有 options；默认会把 root_path 加入 additional_ignored_roots，避免扫描目标自身。
- `return`: Dictionary，字段同 scan_references() 返回值。
