# GFEditorPropertyBatchCommand

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_property_batch_command.gd`
- 模块：`Kernel`
- 继承：`GFEditorCommand`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`10.0.0`

通用多目标属性事务命令。 对调用方显式提供的 Object 属性先做全量零写入预检，再按稳定顺序提交。 任一写入或最终状态验证失败时，会按相反顺序恢复本次尝试前的全部目标属性。 命令只保证显式属性值边界，不代理 setter 的外部副作用、文件保存或业务事务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_PENDING`](#member-gfeditorpropertybatchcommand-constants-status_pending) | `const STATUS_PENDING: StringName = &"pending"` |
| 常量 | [`STATUS_READY`](#member-gfeditorpropertybatchcommand-constants-status_ready) | `const STATUS_READY: StringName = &"ready"` |
| 常量 | [`STATUS_COMMITTED`](#member-gfeditorpropertybatchcommand-constants-status_committed) | `const STATUS_COMMITTED: StringName = &"committed"` |
| 常量 | [`STATUS_REVERTED`](#member-gfeditorpropertybatchcommand-constants-status_reverted) | `const STATUS_REVERTED: StringName = &"reverted"` |
| 常量 | [`STATUS_RECOVERED`](#member-gfeditorpropertybatchcommand-constants-status_recovered) | `const STATUS_RECOVERED: StringName = &"recovered"` |
| 常量 | [`STATUS_PREFLIGHT_FAILED`](#member-gfeditorpropertybatchcommand-constants-status_preflight_failed) | `const STATUS_PREFLIGHT_FAILED: StringName = &"preflight_failed"` |
| 常量 | [`STATUS_APPLY_FAILED`](#member-gfeditorpropertybatchcommand-constants-status_apply_failed) | `const STATUS_APPLY_FAILED: StringName = &"apply_failed"` |
| 常量 | [`STATUS_REVERT_FAILED`](#member-gfeditorpropertybatchcommand-constants-status_revert_failed) | `const STATUS_REVERT_FAILED: StringName = &"revert_failed"` |
| 常量 | [`STATUS_ROLLBACK_FAILED`](#member-gfeditorpropertybatchcommand-constants-status_rollback_failed) | `const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"` |
| 方法 | [`configure`](#member-gfeditorpropertybatchcommand-methods-configure) | `func configure( changes: Array[Dictionary], options: Dictionary = {} ) -> GFEditorPropertyBatchCommand:` |
| 方法 | [`validate`](#member-gfeditorpropertybatchcommand-methods-validate) | `func validate() -> Dictionary:` |
| 方法 | [`get_transaction_report`](#member-gfeditorpropertybatchcommand-methods-get_transaction_report) | `func get_transaction_report() -> Dictionary:` |
| 方法 | [`recover`](#member-gfeditorpropertybatchcommand-methods-recover) | `func recover() -> Error:` |
| 方法 | [`can_execute`](#member-gfeditorpropertybatchcommand-methods-can_execute) | `func can_execute() -> bool:` |
| 方法 | [`can_revert_before_execute`](#member-gfeditorpropertybatchcommand-methods-can_revert_before_execute) | `func can_revert_before_execute() -> bool:` |
| 方法 | [`_do_it`](#member-gfeditorpropertybatchcommand-methods-_do_it) | `func _do_it() -> Error:` |
| 方法 | [`_get_undo_context`](#member-gfeditorpropertybatchcommand-methods-_get_undo_context) | `func _get_undo_context() -> Object:` |
| 方法 | [`_get_undo_targets`](#member-gfeditorpropertybatchcommand-methods-_get_undo_targets) | `func _get_undo_targets() -> Array[Object]:` |
| 方法 | [`_undo_it`](#member-gfeditorpropertybatchcommand-methods-_undo_it) | `func _undo_it() -> Error:` |

## 常量

<a id="member-gfeditorpropertybatchcommand-constants-status_pending"></a>

### `STATUS_PENDING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_PENDING: StringName = &"pending"
```

尚未验证或执行。

<a id="member-gfeditorpropertybatchcommand-constants-status_ready"></a>

### `STATUS_READY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_READY: StringName = &"ready"
```

全量预检通过。

<a id="member-gfeditorpropertybatchcommand-constants-status_committed"></a>

### `STATUS_COMMITTED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_COMMITTED: StringName = &"committed"
```

属性事务已提交。

<a id="member-gfeditorpropertybatchcommand-constants-status_reverted"></a>

### `STATUS_REVERTED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_REVERTED: StringName = &"reverted"
```

属性事务已撤销。

<a id="member-gfeditorpropertybatchcommand-constants-status_recovered"></a>

### `STATUS_RECOVERED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_RECOVERED: StringName = &"recovered"
```

未完整补偿的事务已恢复到该次操作开始前状态。

<a id="member-gfeditorpropertybatchcommand-constants-status_preflight_failed"></a>

### `STATUS_PREFLIGHT_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_PREFLIGHT_FAILED: StringName = &"preflight_failed"
```

全量预检失败，未开始写入。

<a id="member-gfeditorpropertybatchcommand-constants-status_apply_failed"></a>

### `STATUS_APPLY_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_APPLY_FAILED: StringName = &"apply_failed"
```

提交失败，且已恢复本次尝试前状态。

<a id="member-gfeditorpropertybatchcommand-constants-status_revert_failed"></a>

### `STATUS_REVERT_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_REVERT_FAILED: StringName = &"revert_failed"
```

撤销失败，且已恢复撤销前状态。

<a id="member-gfeditorpropertybatchcommand-constants-status_rollback_failed"></a>

### `STATUS_ROLLBACK_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"
```

补偿写入未完整恢复属性状态。

## 方法

<a id="member-gfeditorpropertybatchcommand-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( changes: Array[Dictionary], options: Dictionary = {} ) -> GFEditorPropertyBatchCommand:
```

配置属性事务。 changes 必须至少包含一项。每个 change 必须包含 target、new_value，以及且仅包含 property_name 或 property_path。property_name 表示精确直接属性名；property_path 使用 Godot indexed path 语义。可选 metadata 会复制到条目和错误报告。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 非空属性变更数组。 |
| `options` | 配置选项。 |

返回：当前命令。

结构：

- `changes`: 非空 Array[Dictionary]，每项包含 target: Object、new_value: Variant、property_name: StringName/String 或 property_path: NodePath/String，以及可选 metadata: Dictionary。
- `options`: Dictionary，可包含 command_name、metadata 和 duplicate_resources。

<a id="member-gfeditorpropertybatchcommand-methods-validate"></a>

### `validate`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate() -> Dictionary:
```

零写入验证全部属性变更。

返回：结构化事务报告。

结构：

- `return`: Dictionary，包含 ok、status、phase、error、requested_count、applied_count、unchanged_count、attempted_count、rollback_count、failed_count、failed_index、rolled_back、recovery_required、entries、issues 和 metadata。

<a id="member-gfeditorpropertybatchcommand-methods-get_transaction_report"></a>

### `get_transaction_report`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_transaction_report() -> Dictionary:
```

获取最近一次预检、提交、撤销或恢复报告。

返回：结构化事务报告副本。

结构：

- `return`: Dictionary，形状与 validate() 返回值相同。

<a id="member-gfeditorpropertybatchcommand-methods-recover"></a>

### `recover`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func recover() -> Error:
```

恢复最近一次未完整补偿的操作。 恢复目标是该次失败 apply、redo 或 undo 开始前的 attempt guard，而不是固定的 首次 undo 基线。undo 补偿失败时，恢复成功后命令仍保持 executed，调用方可再 次调用 revert() 完成真正撤销。

返回：Godot 错误码。

<a id="member-gfeditorpropertybatchcommand-methods-can_execute"></a>

### `can_execute`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func can_execute() -> bool:
```

当前命令是否允许执行。

返回：配置完整、目标可写且没有待恢复残余状态时返回 true。

<a id="member-gfeditorpropertybatchcommand-methods-can_revert_before_execute"></a>

### `can_revert_before_execute`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func can_revert_before_execute() -> bool:
```

首次执行未成功但留下残余状态时，允许显式调用 revert() 重试恢复。

返回：存在首次快照且需要恢复时返回 true。

<a id="member-gfeditorpropertybatchcommand-methods-_do_it"></a>

### `_do_it`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _do_it() -> Error:
```

执行属性事务。

返回：Godot 错误码。

<a id="member-gfeditorpropertybatchcommand-methods-_get_undo_context"></a>

### `_get_undo_context`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_undo_context() -> Object:
```

返回第一个有效属性目标，作为 EditorUndoRedoManager 的 history 上下文。

返回：第一个有效属性目标。

<a id="member-gfeditorpropertybatchcommand-methods-_get_undo_targets"></a>

### `_get_undo_targets`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_undo_targets() -> Array[Object]:
```

返回全部唯一属性目标，供基类拒绝跨 UndoRedo history 的混合事务。

返回：全部唯一属性目标。

<a id="member-gfeditorpropertybatchcommand-methods-_undo_it"></a>

### `_undo_it`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _undo_it() -> Error:
```

撤销属性事务，或恢复首次执行失败留下的残余状态。

返回：Godot 错误码。
