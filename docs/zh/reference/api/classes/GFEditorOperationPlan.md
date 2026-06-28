# GFEditorOperationPlan

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_operation_plan.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`7.0.0`

编辑器工具操作计划报告。 用于把预览、dry-run、执行步骤和产物报告统一成可展示、可测试的结构化结果。 它只描述编辑器操作计划和结果，不直接修改节点、资源或文件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_PLANNED`](#member-gfeditoroperationplan-constants-status_planned) | `const STATUS_PLANNED: StringName = &"planned"` |
| 常量 | [`STATUS_PREVIEWED`](#member-gfeditoroperationplan-constants-status_previewed) | `const STATUS_PREVIEWED: StringName = &"previewed"` |
| 常量 | [`STATUS_APPLIED`](#member-gfeditoroperationplan-constants-status_applied) | `const STATUS_APPLIED: StringName = &"applied"` |
| 常量 | [`STATUS_SKIPPED`](#member-gfeditoroperationplan-constants-status_skipped) | `const STATUS_SKIPPED: StringName = &"skipped"` |
| 常量 | [`STATUS_FAILED`](#member-gfeditoroperationplan-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 属性 | [`operation_id`](#member-gfeditoroperationplan-properties-operation_id) | `var operation_id: StringName = &""` |
| 属性 | [`label`](#member-gfeditoroperationplan-properties-label) | `var label: String = ""` |
| 属性 | [`dry_run`](#member-gfeditoroperationplan-properties-dry_run) | `var dry_run: bool = false` |
| 属性 | [`metadata`](#member-gfeditoroperationplan-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfeditoroperationplan-methods-configure) | `func configure( p_operation_id: StringName, p_label: String = "", p_dry_run: bool = false, p_metadata: Dictionary = {} ) -> GFEditorOperationPlan:` |
| 方法 | [`add_step`](#member-gfeditoroperationplan-methods-add_step) | `func add_step(step_id: StringName, step_label: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`mark_step`](#member-gfeditoroperationplan-methods-mark_step) | `func mark_step( step_id: StringName, status: StringName, error_code: Error = OK, error: String = "", extra_metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`add_artifact_report`](#member-gfeditoroperationplan-methods-add_artifact_report) | `func add_artifact_report(report: Dictionary) -> void:` |
| 方法 | [`get_steps`](#member-gfeditoroperationplan-methods-get_steps) | `func get_steps() -> Array[Dictionary]:` |
| 方法 | [`get_artifact_reports`](#member-gfeditoroperationplan-methods-get_artifact_reports) | `func get_artifact_reports() -> Array[Dictionary]:` |
| 方法 | [`clear`](#member-gfeditoroperationplan-methods-clear) | `func clear() -> void:` |
| 方法 | [`summarize`](#member-gfeditoroperationplan-methods-summarize) | `func summarize(options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfeditoroperationplan-constants-status_planned"></a>

### `STATUS_PLANNED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_PLANNED: StringName = &"planned"
```

步骤已计划但尚未执行。

<a id="member-gfeditoroperationplan-constants-status_previewed"></a>

### `STATUS_PREVIEWED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_PREVIEWED: StringName = &"previewed"
```

步骤已预览。

<a id="member-gfeditoroperationplan-constants-status_applied"></a>

### `STATUS_APPLIED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_APPLIED: StringName = &"applied"
```

步骤已应用。

<a id="member-gfeditoroperationplan-constants-status_skipped"></a>

### `STATUS_SKIPPED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_SKIPPED: StringName = &"skipped"
```

步骤已跳过。

<a id="member-gfeditoroperationplan-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

步骤失败。

## 属性

<a id="member-gfeditoroperationplan-properties-operation_id"></a>

### `operation_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var operation_id: StringName = &""
```

操作稳定标识。

<a id="member-gfeditoroperationplan-properties-label"></a>

### `label`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var label: String = ""
```

操作显示名称。

<a id="member-gfeditoroperationplan-properties-dry_run"></a>

### `dry_run`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var dry_run: bool = false
```

是否为 dry-run 预览。

<a id="member-gfeditoroperationplan-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary for caller-defined editor operation metadata.

## 方法

<a id="member-gfeditoroperationplan-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_operation_id: StringName, p_label: String = "", p_dry_run: bool = false, p_metadata: Dictionary = {} ) -> GFEditorOperationPlan:
```

配置操作计划。

参数：

| 名称 | 说明 |
|---|---|
| `p_operation_id` | 操作稳定标识。 |
| `p_label` | 操作显示名称。 |
| `p_dry_run` | 是否为 dry-run。 |
| `p_metadata` | 调用方元数据。 |

返回：当前计划。

结构：

- `p_metadata`: Dictionary copied into metadata.

<a id="member-gfeditoroperationplan-methods-add_step"></a>

### `add_step`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_step(step_id: StringName, step_label: String = "", options: Dictionary = {}) -> Dictionary:
```

添加一个操作步骤。

参数：

| 名称 | 说明 |
|---|---|
| `step_id` | 步骤稳定标识。 |
| `step_label` | 步骤显示名称。 |
| `options` | 步骤选项。 |

返回：步骤记录副本。

结构：

- `options`: Dictionary，可包含 status、target、kind、metadata、error_code 和 error。
- `return`: Dictionary，包含 step_id、label、status、target、kind、error_code、error 和 metadata。

<a id="member-gfeditoroperationplan-methods-mark_step"></a>

### `mark_step`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_step( step_id: StringName, status: StringName, error_code: Error = OK, error: String = "", extra_metadata: Dictionary = {} ) -> bool:
```

标记一个步骤状态。

参数：

| 名称 | 说明 |
|---|---|
| `step_id` | 步骤稳定标识。 |
| `status` | 新状态。 |
| `error_code` | Godot Error 错误码。 |
| `error` | 错误说明。 |
| `extra_metadata` | 要合并到步骤 metadata 的额外元数据。 |

返回：找到并更新时返回 true。

结构：

- `extra_metadata`: Dictionary merged into step metadata.

<a id="member-gfeditoroperationplan-methods-add_artifact_report"></a>

### `add_artifact_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_artifact_report(report: Dictionary) -> void:
```

添加生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `report` | GFGeneratedArtifactReport 兼容报告。 |

结构：

- `report`: Dictionary，包含 status、path、error_code、dry_run 等字段。

<a id="member-gfeditoroperationplan-methods-get_steps"></a>

### `get_steps`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_steps() -> Array[Dictionary]:
```

获取步骤记录副本。

返回：步骤数组。

结构：

- `return`: Array[Dictionary]，每个元素是 add_step() 返回结构。

<a id="member-gfeditoroperationplan-methods-get_artifact_reports"></a>

### `get_artifact_reports`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_artifact_reports() -> Array[Dictionary]:
```

获取产物报告副本。

返回：产物报告数组。

结构：

- `return`: Array[Dictionary]，每个元素是 GFGeneratedArtifactReport 兼容报告。

<a id="member-gfeditoroperationplan-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空步骤和产物报告。

<a id="member-gfeditoroperationplan-methods-summarize"></a>

### `summarize`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func summarize(options: Dictionary = {}) -> Dictionary:
```

汇总操作计划。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 汇总选项，支持 include_steps、include_artifacts 和 metadata。 |

返回：操作摘要。

结构：

- `options`: Dictionary，可包含 include_steps、include_artifacts 和 metadata。
- `return`: Dictionary，包含 success、operation_id、label、dry_run、step_count、status_counts、failed_count、skipped_count、artifact_summary 和 metadata。
