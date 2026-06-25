# GFImportPlan

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_import_plan.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

通用导入计划与预检报告。 描述一组来源到目标的导入、复制或转换条目，并提供 source trace、预检和修复动作报告。 该类不执行文件复制或格式转换，具体导入器可把它作为编辑器工具和 CI 的共享计划格式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`OPERATION_COPY`](#member-gfimportplan-constants-operation_copy) | `const OPERATION_COPY: StringName = &"copy"` |
| 常量 | [`OPERATION_CONVERT`](#member-gfimportplan-constants-operation_convert) | `const OPERATION_CONVERT: StringName = &"convert"` |
| 常量 | [`OPERATION_SKIP`](#member-gfimportplan-constants-operation_skip) | `const OPERATION_SKIP: StringName = &"skip"` |
| 属性 | [`entries`](#member-gfimportplan-properties-entries) | `var entries: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfimportplan-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_entry`](#member-gfimportplan-methods-add_entry) | `func add_entry( source_path: String, target_path: String, operation: StringName = OPERATION_COPY, options: Dictionary = {} ) -> GFImportPlan:` |
| 方法 | [`clear`](#member-gfimportplan-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_entries`](#member-gfimportplan-methods-get_entries) | `func get_entries() -> Array[Dictionary]:` |
| 方法 | [`get_source_traces`](#member-gfimportplan-methods-get_source_traces) | `func get_source_traces() -> Array[Dictionary]:` |
| 方法 | [`get_validation_report`](#member-gfimportplan-methods-get_validation_report) | `func get_validation_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_repair_report`](#member-gfimportplan-methods-get_repair_report) | `func get_repair_report() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfimportplan-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfimportplan-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfimportplan-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFImportPlan:` |

## 常量

<a id="member-gfimportplan-constants-operation_copy"></a>

### `OPERATION_COPY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_COPY: StringName = &"copy"
```

复制来源文件。

<a id="member-gfimportplan-constants-operation_convert"></a>

### `OPERATION_CONVERT`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_CONVERT: StringName = &"convert"
```

转换来源文件。

<a id="member-gfimportplan-constants-operation_skip"></a>

### `OPERATION_SKIP`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_SKIP: StringName = &"skip"
```

跳过来源文件。

## 属性

<a id="member-gfimportplan-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var entries: Array[Dictionary] = []
```

导入条目列表。

结构：

- `entries`: Array[Dictionary] where each entry contains source_path, target_path, operation, source_trace, repair_actions, and metadata.

<a id="member-gfimportplan-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary for caller-defined import plan metadata.

## 方法

<a id="member-gfimportplan-methods-add_entry"></a>

### `add_entry`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_entry( source_path: String, target_path: String, operation: StringName = OPERATION_COPY, options: Dictionary = {} ) -> GFImportPlan:
```

添加导入条目。

参数：

| 名称 | 说明 |
|---|---|
| `source_path` | 来源路径。 |
| `target_path` | 目标路径。 |
| `operation` | 导入操作。 |
| `options` | 条目选项。 |

返回：当前计划。

结构：

- `options`: Dictionary，可包含 source_format、target_format、type_hint、source_trace、repair_actions 和 metadata。

<a id="member-gfimportplan-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear() -> void:
```

清空导入条目。

<a id="member-gfimportplan-methods-get_entries"></a>

### `get_entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_entries() -> Array[Dictionary]:
```

获取条目副本。

返回：条目副本。

结构：

- `return`: Array[Dictionary] import plan entries.

<a id="member-gfimportplan-methods-get_source_traces"></a>

### `get_source_traces`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_source_traces() -> Array[Dictionary]:
```

获取 source trace 列表。

返回：source trace 字典数组。

结构：

- `return`: Array[Dictionary] where each trace contains source_path, target_path, operation, source_format, target_format, and metadata.

<a id="member-gfimportplan-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_validation_report(options: Dictionary = {}) -> Dictionary:
```

生成导入预检报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 预检选项。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary，可包含 check_source_exists、target_root 和 allow_empty_target。
- `return`: GFValidationReportDictionary.finalize_report() output with entry_count and source_traces.

<a id="member-gfimportplan-methods-get_repair_report"></a>

### `get_repair_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_repair_report() -> Dictionary:
```

生成修复动作报告，不执行修复。

返回：修复动作报告。

结构：

- `return`: Dictionary with action_count, actions, source_traces, and metadata.

<a id="member-gfimportplan-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：导入计划字典。

结构：

- `return`: Dictionary with entries and metadata.

<a id="member-gfimportplan-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 导入计划字典。 |

结构：

- `data`: Dictionary with entries and metadata.

<a id="member-gfimportplan-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFImportPlan:
```

从字典创建导入计划。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 导入计划字典。 |

返回：新导入计划。

结构：

- `data`: Dictionary with entries and metadata.
