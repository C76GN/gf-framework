# GFAccessGenerator

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_access_generator.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

生成强类型 GF 访问器脚本。 生成结果用于减少 `Gf.get_model(Type) as Type` 这类重复样板， 并为 Model / System / Utility / Command / Query 提供稳定的 IDE 补全入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`TargetKind`](#member-gfaccessgenerator-enums-targetkind) | `enum TargetKind` |
| 常量 | [`DEFAULT_OUTPUT_PATH`](#member-gfaccessgenerator-constants-default_output_path) | `const DEFAULT_OUTPUT_PATH: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.ACCESS_OUTPUT_PATH` |
| 常量 | [`DEFAULT_PROJECT_OUTPUT_PATH`](#member-gfaccessgenerator-constants-default_project_output_path) | `const DEFAULT_PROJECT_OUTPUT_PATH: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.PROJECT_ACCESS_OUTPUT_PATH` |
| 方法 | [`generate`](#member-gfaccessgenerator-methods-generate) | `func generate(output_path: String = DEFAULT_OUTPUT_PATH, overwrite_existing: bool = true) -> Error:` |
| 方法 | [`generate_with_report`](#member-gfaccessgenerator-methods-generate_with_report) | `func generate_with_report(output_path: String = DEFAULT_OUTPUT_PATH, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`generate_project_access`](#member-gfaccessgenerator-methods-generate_project_access) | `func generate_project_access(output_path: String = DEFAULT_PROJECT_OUTPUT_PATH, overwrite_existing: bool = true) -> Error:` |
| 方法 | [`generate_project_access_with_report`](#member-gfaccessgenerator-methods-generate_project_access_with_report) | `func generate_project_access_with_report( output_path: String = DEFAULT_PROJECT_OUTPUT_PATH, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`collect_records`](#member-gfaccessgenerator-methods-collect_records) | `func collect_records() -> Array[Dictionary]:` |
| 方法 | [`collect_project_records`](#member-gfaccessgenerator-methods-collect_project_records) | `func collect_project_records() -> Dictionary:` |
| 方法 | [`build_source`](#member-gfaccessgenerator-methods-build_source) | `func build_source(records: Array) -> String:` |
| 方法 | [`build_project_source`](#member-gfaccessgenerator-methods-build_project_source) | `func build_project_source(records: Dictionary) -> String:` |
| 方法 | [`save_source`](#member-gfaccessgenerator-methods-save_source) | `func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:` |
| 方法 | [`save_source_with_report`](#member-gfaccessgenerator-methods-save_source_with_report) | `func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:` |

## 枚举

<a id="member-gfaccessgenerator-enums-targetkind"></a>

### `TargetKind`

- API：`public`

```gdscript
enum TargetKind {
	## Model 访问器目标。
	MODEL,
	## System 访问器目标。
	SYSTEM,
	## Utility 访问器目标。
	UTILITY,
	## Command 访问器目标。
	COMMAND,
	## Query 访问器目标。
	QUERY,
	## Capability 访问器目标。
	CAPABILITY,
}
```

访问器目标类型。

## 常量

<a id="member-gfaccessgenerator-constants-default_output_path"></a>

### `DEFAULT_OUTPUT_PATH`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DEFAULT_OUTPUT_PATH: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.ACCESS_OUTPUT_PATH
```

默认强类型访问器输出路径。

<a id="member-gfaccessgenerator-constants-default_project_output_path"></a>

### `DEFAULT_PROJECT_OUTPUT_PATH`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DEFAULT_PROJECT_OUTPUT_PATH: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.PROJECT_ACCESS_OUTPUT_PATH
```

默认项目常量访问器输出路径。

## 方法

<a id="member-gfaccessgenerator-methods-generate"></a>

### `generate`

- API：`public`

```gdscript
func generate(output_path: String = DEFAULT_OUTPUT_PATH, overwrite_existing: bool = true) -> Error:
```

扫描项目 class_name 脚本并生成访问器。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |

返回：写入结果错误码。

<a id="member-gfaccessgenerator-methods-generate_with_report"></a>

### `generate_with_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func generate_with_report(output_path: String = DEFAULT_OUTPUT_PATH, options: Dictionary = {}) -> Dictionary:
```

扫描项目 class_name 脚本并生成访问器报告。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `options` | 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `options`: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。

<a id="member-gfaccessgenerator-methods-generate_project_access"></a>

### `generate_project_access`

- API：`public`

```gdscript
func generate_project_access(output_path: String = DEFAULT_PROJECT_OUTPUT_PATH, overwrite_existing: bool = true) -> Error:
```

生成项目常量访问器。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |

返回：写入结果错误码。

<a id="member-gfaccessgenerator-methods-generate_project_access_with_report"></a>

### `generate_project_access_with_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func generate_project_access_with_report( output_path: String = DEFAULT_PROJECT_OUTPUT_PATH, options: Dictionary = {} ) -> Dictionary:
```

生成项目常量访问器报告。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `options` | 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `options`: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。

<a id="member-gfaccessgenerator-methods-collect_records"></a>

### `collect_records`

- API：`public`

```gdscript
func collect_records() -> Array[Dictionary]:
```

收集当前项目中可生成访问器的 GF 类型记录。

返回：类型记录列表。

结构：

- `return`: Array of Dictionary type records with class_name, path, script, kind, and access metadata.

<a id="member-gfaccessgenerator-methods-collect_project_records"></a>

### `collect_project_records`

- API：`public`

```gdscript
func collect_project_records() -> Dictionary:
```

收集项目层常量记录，包括命名层、InputMap 动作和 GF ProjectSettings。

返回：项目常量记录。

结构：

- `return`: Dictionary with layers, input_actions, and settings arrays.

<a id="member-gfaccessgenerator-methods-build_source"></a>

### `build_source`

- API：`public`

```gdscript
func build_source(records: Array) -> String:
```

根据记录生成访问器源码。测试可直接调用该方法验证输出。

参数：

| 名称 | 说明 |
|---|---|
| `records` | 生成访问器时使用的类型记录列表。 |

返回：GDScript 源码。

结构：

- `records`: Array of Dictionary type records containing class_name, path, and kind.

<a id="member-gfaccessgenerator-methods-build_project_source"></a>

### `build_project_source`

- API：`public`

```gdscript
func build_project_source(records: Dictionary) -> String:
```

根据项目常量记录生成访问器源码。

参数：

| 名称 | 说明 |
|---|---|
| `records` | 生成访问器时使用的类型记录列表。 |

返回：GDScript 源码。

结构：

- `records`: Dictionary with layers, input_actions, and settings arrays.

<a id="member-gfaccessgenerator-methods-save_source"></a>

### `save_source`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:
```

保存生成源码到指定路径。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `source` | GDScript 源码。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |

返回：写入结果错误码。

<a id="member-gfaccessgenerator-methods-save_source_with_report"></a>

### `save_source_with_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:
```

保存生成源码到指定路径并返回生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `source` | GDScript 源码。 |
| `options` | 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `options`: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
