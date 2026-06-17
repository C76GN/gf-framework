# GFResourceRegistryTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.23.0`

通用资源注册表扫描和生成工具。 面向编辑器工具、构建脚本和项目安装器复用；它只从路径生成 `GFResourceRegistry` / `GFResourceRegistryEntry`，不解释业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`EntryIdMode`](#member-gfresourceregistrytools-enums-entryidmode) | `enum EntryIdMode` |
| 常量 | [`RESOURCE_EXTENSIONS`](#member-gfresourceregistrytools-constants-resource_extensions) | `const RESOURCE_EXTENSIONS: PackedStringArray = [` |
| 常量 | [`DEFAULT_EXCLUDED_PATHS`](#member-gfresourceregistrytools-constants-default_excluded_paths) | `const DEFAULT_EXCLUDED_PATHS: PackedStringArray = ["res://addons"]` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfresourceregistrytools-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_RESOURCE_PATHS`](#member-gfresourceregistrytools-constants-default_max_resource_paths) | `const DEFAULT_MAX_RESOURCE_PATHS: int = 10000` |
| 常量 | [`FIELD_EXTENSION`](#member-gfresourceregistrytools-constants-field_extension) | `const FIELD_EXTENSION: StringName = &"extension"` |
| 常量 | [`FIELD_DIRECTORY`](#member-gfresourceregistrytools-constants-field_directory) | `const FIELD_DIRECTORY: StringName = &"directory"` |
| 常量 | [`FIELD_BASENAME`](#member-gfresourceregistrytools-constants-field_basename) | `const FIELD_BASENAME: StringName = &"basename"` |
| 常量 | [`FIELD_RELATIVE_PATH`](#member-gfresourceregistrytools-constants-field_relative_path) | `const FIELD_RELATIVE_PATH: StringName = &"relative_path"` |
| 常量 | [`FIELD_TAGS`](#member-gfresourceregistrytools-constants-field_tags) | `const FIELD_TAGS: StringName = &"tags"` |
| 常量 | [`FIELD_CATEGORY`](#member-gfresourceregistrytools-constants-field_category) | `const FIELD_CATEGORY: StringName = &"category"` |
| 方法 | [`is_resource_path`](#member-gfresourceregistrytools-methods-is_resource_path) | `static func is_resource_path(path: String, extensions: PackedStringArray = RESOURCE_EXTENSIONS) -> bool:` |
| 方法 | [`scan_resource_paths`](#member-gfresourceregistrytools-methods-scan_resource_paths) | `static func scan_resource_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`create_registry_from_paths`](#member-gfresourceregistrytools-methods-create_registry_from_paths) | `static func create_registry_from_paths(paths: PackedStringArray, options: Dictionary = {}) -> GFResourceRegistry:` |
| 方法 | [`create_registry_from_scan`](#member-gfresourceregistrytools-methods-create_registry_from_scan) | `static func create_registry_from_scan(root_path: String = "res://", options: Dictionary = {}) -> GFResourceRegistry:` |
| 方法 | [`collect_dependency_paths`](#member-gfresourceregistrytools-methods-collect_dependency_paths) | `static func collect_dependency_paths(resource_path: String, options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`build_dependency_report`](#member-gfresourceregistrytools-methods-build_dependency_report) | `static func build_dependency_report(resource_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_paths_to_registry`](#member-gfresourceregistrytools-methods-add_paths_to_registry) | `static func add_paths_to_registry( registry: GFResourceRegistry, paths: PackedStringArray, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`sync_registry_from_scan`](#member-gfresourceregistrytools-methods-sync_registry_from_scan) | `static func sync_registry_from_scan( registry: GFResourceRegistry, root_path: String = "res://", options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`make_entry_id`](#member-gfresourceregistrytools-methods-make_entry_id) | `static func make_entry_id(path: String, options: Dictionary = {}) -> StringName:` |
| 方法 | [`make_type_hint`](#member-gfresourceregistrytools-methods-make_type_hint) | `static func make_type_hint(path: String, options: Dictionary = {}) -> String:` |
| 方法 | [`make_entry_fields`](#member-gfresourceregistrytools-methods-make_entry_fields) | `static func make_entry_fields(path: String, options: Dictionary = {}) -> Dictionary:` |

## 枚举

<a id="member-gfresourceregistrytools-enums-entryidmode"></a>

### `EntryIdMode`

- API：`public`

```gdscript
enum EntryIdMode {
	## 使用文件名，不包含扩展名。
	BASENAME,
	## 使用相对 base_path 的路径，不包含扩展名。
	RELATIVE_PATH,
	## 使用完整资源路径，不包含扩展名。
	FULL_PATH,
}
```

从资源路径生成条目 ID 的方式。

## 常量

<a id="member-gfresourceregistrytools-constants-resource_extensions"></a>

### `RESOURCE_EXTENSIONS`

- API：`public`

```gdscript
const RESOURCE_EXTENSIONS: PackedStringArray = [
```

默认资源扩展名白名单，不包含点号。

<a id="member-gfresourceregistrytools-constants-default_excluded_paths"></a>

### `DEFAULT_EXCLUDED_PATHS`

- API：`public`

```gdscript
const DEFAULT_EXCLUDED_PATHS: PackedStringArray = ["res://addons"]
```

默认排除的扫描路径。

<a id="member-gfresourceregistrytools-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认递归扫描深度上限。

<a id="member-gfresourceregistrytools-constants-default_max_resource_paths"></a>

### `DEFAULT_MAX_RESOURCE_PATHS`

- API：`public`

```gdscript
const DEFAULT_MAX_RESOURCE_PATHS: int = 10000
```

默认单次扫描收集的资源路径数量上限。

<a id="member-gfresourceregistrytools-constants-field_extension"></a>

### `FIELD_EXTENSION`

- API：`public`

```gdscript
const FIELD_EXTENSION: StringName = &"extension"
```

默认路径字段：资源扩展名。

<a id="member-gfresourceregistrytools-constants-field_directory"></a>

### `FIELD_DIRECTORY`

- API：`public`

```gdscript
const FIELD_DIRECTORY: StringName = &"directory"
```

默认路径字段：相对目录。

<a id="member-gfresourceregistrytools-constants-field_basename"></a>

### `FIELD_BASENAME`

- API：`public`

```gdscript
const FIELD_BASENAME: StringName = &"basename"
```

默认路径字段：文件基础名。

<a id="member-gfresourceregistrytools-constants-field_relative_path"></a>

### `FIELD_RELATIVE_PATH`

- API：`public`

```gdscript
const FIELD_RELATIVE_PATH: StringName = &"relative_path"
```

默认路径字段：相对路径。

<a id="member-gfresourceregistrytools-constants-field_tags"></a>

### `FIELD_TAGS`

- API：`public`

```gdscript
const FIELD_TAGS: StringName = &"tags"
```

默认路径字段：由相对目录段推导的标签集合。

<a id="member-gfresourceregistrytools-constants-field_category"></a>

### `FIELD_CATEGORY`

- API：`public`

```gdscript
const FIELD_CATEGORY: StringName = &"category"
```

默认路径字段：相对目录的第一段。

## 方法

<a id="member-gfresourceregistrytools-methods-is_resource_path"></a>

### `is_resource_path`

- API：`public`

```gdscript
static func is_resource_path(path: String, extensions: PackedStringArray = RESOURCE_EXTENSIONS) -> bool:
```

判断路径是否指向受支持的资源扩展名。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或文件名。 |
| `extensions` | 可选扩展名白名单，不包含点号。 |

返回：是受支持资源路径时返回 true。

<a id="member-gfresourceregistrytools-methods-scan_resource_paths"></a>

### `scan_resource_paths`

- API：`public`

```gdscript
static func scan_resource_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
```

递归扫描资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res:// 下的目录。 |
| `options` | 可选项，支持 recursive、include_addons、excluded_paths、extensions、include_hidden、include_import_sidecars、max_scan_depth 与 max_resource_paths。 |

返回：按字典序排序的资源路径。

结构：

- `options`: Dictionary，可包含 recursive、include_addons、excluded_paths、extensions、include_hidden、include_import_sidecars、max_scan_depth 和 max_resource_paths 字段。

<a id="member-gfresourceregistrytools-methods-create_registry_from_paths"></a>

### `create_registry_from_paths`

- API：`public`

```gdscript
static func create_registry_from_paths(paths: PackedStringArray, options: Dictionary = {}) -> GFResourceRegistry:
```

从路径列表创建新的资源注册表。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 资源路径列表。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension、type_hint、default_type_hint、type_hints_by_extension、extra_fields、fields_by_path、fields_by_id、include_path_fields、include_tags、include_category、tag_field 和 category_field。 |

返回：新建的资源注册表。

结构：

- `options`: Dictionary，可包含路径导入、ID 生成、类型提示和字段生成选项。

<a id="member-gfresourceregistrytools-methods-create_registry_from_scan"></a>

### `create_registry_from_scan`

- API：`public`

```gdscript
static func create_registry_from_scan(root_path: String = "res://", options: Dictionary = {}) -> GFResourceRegistry:
```

扫描目录并创建新的资源注册表。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res://assets。 |
| `options` | 可选项，同时传给 scan_resource_paths() 与 create_registry_from_paths()。 |

返回：新建的资源注册表。

结构：

- `options`: Dictionary，可同时包含扫描选项和条目导入选项。

<a id="member-gfresourceregistrytools-methods-collect_dependency_paths"></a>

### `collect_dependency_paths`

- API：`public`

```gdscript
static func collect_dependency_paths(resource_path: String, options: Dictionary = {}) -> PackedStringArray:
```

收集资源的依赖路径。 该方法只读取 Godot `ResourceLoader.get_dependencies()` 暴露的依赖关系， 不打包 PCK、不改写 remap，也不解释资源业务含义。返回结果适合继续交给 `create_registry_from_paths()`、`GFAssetUtility.preload_group_async()` 或渲染预热清单。

参数：

| 名称 | 说明 |
|---|---|
| `resource_path` | 入口资源路径。 |
| `options` | 可选项，支持 recursive、include_root、extensions、excluded_paths、max_scan_depth 与 max_dependency_paths。 |

返回：排序后的依赖路径。

结构：

- `options`: Dictionary，可包含 recursive、include_root、extensions、excluded_paths、max_scan_depth 和 max_dependency_paths 字段。

<a id="member-gfresourceregistrytools-methods-build_dependency_report"></a>

### `build_dependency_report`

- API：`public`

```gdscript
static func build_dependency_report(resource_path: String, options: Dictionary = {}) -> Dictionary:
```

构建资源依赖诊断报告。 报告保留路径闭包、直接依赖、缺失依赖、排除依赖、循环和上限命中信息， 适合编辑器检查、构建预检、资源注册表生成前检查和预热清单诊断。

参数：

| 名称 | 说明 |
|---|---|
| `resource_path` | 入口资源路径。 |
| `options` | 可选项，支持 recursive、include_root、extensions、excluded_paths、max_scan_depth、max_dependency_paths 与 include_direct_dependencies。 |

返回：依赖诊断报告。

结构：

- `options`: Dictionary，可包含 recursive、include_root、extensions、excluded_paths、max_scan_depth、max_dependency_paths 和 include_direct_dependencies 字段。
- `return`: Dictionary，包含 ok、healthy、root_path、paths、resources、missing、excluded、cycles、issues、resource_count、missing_count、excluded_count、cycle_count、limit_reached、depth_limit_reached、error_count、warning_count、issue_count、summary 与 next_action 字段。

<a id="member-gfresourceregistrytools-methods-add_paths_to_registry"></a>

### `add_paths_to_registry`

- API：`public`

```gdscript
static func add_paths_to_registry( registry: GFResourceRegistry, paths: PackedStringArray, options: Dictionary = {} ) -> GFValidationReport:
```

将路径列表加入资源注册表。

参数：

| 名称 | 说明 |
|---|---|
| `registry` | 要写入的资源注册表。 |
| `paths` | 资源路径列表。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension、overwrite、type_hint、default_type_hint、type_hints_by_extension、extra_fields、fields_by_path、fields_by_id、include_path_fields、include_tags、include_category、tag_field 和 category_field。 |

返回：导入报告。

结构：

- `options`: Dictionary，可包含路径导入、ID 生成、类型提示和字段生成选项。

<a id="member-gfresourceregistrytools-methods-sync_registry_from_scan"></a>

### `sync_registry_from_scan`

- API：`public`

```gdscript
static func sync_registry_from_scan( registry: GFResourceRegistry, root_path: String = "res://", options: Dictionary = {} ) -> GFValidationReport:
```

扫描目录并同步到已有资源注册表。

参数：

| 名称 | 说明 |
|---|---|
| `registry` | 要写入的资源注册表。 |
| `root_path` | 扫描起点，通常是 res://assets。 |
| `options` | 可选项，同时传给 scan_resource_paths() 与 add_paths_to_registry()。 |

返回：导入报告。

结构：

- `options`: Dictionary，可同时包含扫描选项和条目导入选项。

<a id="member-gfresourceregistrytools-methods-make_entry_id"></a>

### `make_entry_id`

- API：`public`

```gdscript
static func make_entry_id(path: String, options: Dictionary = {}) -> StringName:
```

按选项从路径生成稳定条目 ID。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension。 |

返回：条目 ID。

结构：

- `options`: Dictionary，可包含 id_mode、base_path、path_separator 和 strip_extension 字段。

<a id="member-gfresourceregistrytools-methods-make_type_hint"></a>

### `make_type_hint`

- API：`public`

```gdscript
static func make_type_hint(path: String, options: Dictionary = {}) -> String:
```

按选项从路径推导资源类型提示。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `options` | 可选项，支持 type_hint、default_type_hint 与 type_hints_by_extension。 |

返回：ResourceLoader 类型提示。

结构：

- `options`: Dictionary，可包含 type_hint、default_type_hint 和 type_hints_by_extension 字段。

<a id="member-gfresourceregistrytools-methods-make_entry_fields"></a>

### `make_entry_fields`

- API：`public`

```gdscript
static func make_entry_fields(path: String, options: Dictionary = {}) -> Dictionary:
```

按选项从路径生成可索引字段。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `options` | 可选项，支持 base_path、extra_fields、fields_by_path、fields_by_id、include_path_fields、include_tags、include_category、tag_field 和 category_field。 |

返回：字段字典。

结构：

- `options`: Dictionary，可包含路径字段、目录标签和调用方附加字段选项。
- `return`: Dictionary keyed by field id with scalar, Array, or PackedStringArray values.
