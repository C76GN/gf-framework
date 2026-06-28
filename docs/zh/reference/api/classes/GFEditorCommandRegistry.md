# GFEditorCommandRegistry

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_command_registry.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`7.0.0`

编辑器动作注册表。 收集由 kernel、standard、扩展或项目工具主动贡献的编辑器动作，并提供按 ID 查询、排序、布局解析和调用入口。注册表只保存动作声明与来源信息，不扫描脚本、 不保存业务逻辑，也不规定命令面板或工具栏的具体 UI。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_REGISTERED`](#member-gfeditorcommandregistry-constants-status_registered) | `const STATUS_REGISTERED: StringName = &"registered"` |
| 常量 | [`STATUS_REPLACED`](#member-gfeditorcommandregistry-constants-status_replaced) | `const STATUS_REPLACED: StringName = &"replaced"` |
| 常量 | [`STATUS_DUPLICATE`](#member-gfeditorcommandregistry-constants-status_duplicate) | `const STATUS_DUPLICATE: StringName = &"duplicate"` |
| 常量 | [`STATUS_INVALID`](#member-gfeditorcommandregistry-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 常量 | [`STATUS_MISSING`](#member-gfeditorcommandregistry-constants-status_missing) | `const STATUS_MISSING: StringName = &"missing"` |
| 常量 | [`STATUS_INVOKED`](#member-gfeditorcommandregistry-constants-status_invoked) | `const STATUS_INVOKED: StringName = &"invoked"` |
| 常量 | [`STATUS_FAILED`](#member-gfeditorcommandregistry-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 属性 | [`metadata`](#member-gfeditorcommandregistry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`clear`](#member-gfeditorcommandregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`register_action`](#member-gfeditorcommandregistry-methods-register_action) | `func register_action(action: GFEditorActionDefinitionBase, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`register_actions`](#member-gfeditorcommandregistry-methods-register_actions) | `func register_actions(actions: Array[GFEditorActionDefinitionBase], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`unregister_action`](#member-gfeditorcommandregistry-methods-unregister_action) | `func unregister_action(action_id: StringName) -> bool:` |
| 方法 | [`has_action`](#member-gfeditorcommandregistry-methods-has_action) | `func has_action(action_id: StringName) -> bool:` |
| 方法 | [`get_action`](#member-gfeditorcommandregistry-methods-get_action) | `func get_action(action_id: StringName) -> GFEditorActionDefinitionBase:` |
| 方法 | [`get_action_record`](#member-gfeditorcommandregistry-methods-get_action_record) | `func get_action_record(action_id: StringName) -> Dictionary:` |
| 方法 | [`get_action_ids`](#member-gfeditorcommandregistry-methods-get_action_ids) | `func get_action_ids(filters: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`get_action_snapshots`](#member-gfeditorcommandregistry-methods-get_action_snapshots) | `func get_action_snapshots(context: Dictionary = {}, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`resolve_layout`](#member-gfeditorcommandregistry-methods-resolve_layout) | `func resolve_layout( action_ids: PackedStringArray, context: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`invoke_action`](#member-gfeditorcommandregistry-methods-invoke_action) | `func invoke_action( action_id: StringName, context: Dictionary = {}, undo_manager: Object = null ) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditorcommandregistry-methods-get_debug_snapshot) | `func get_debug_snapshot(context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfeditorcommandregistry-constants-status_registered"></a>

### `STATUS_REGISTERED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_REGISTERED: StringName = &"registered"
```

动作已新增注册。

<a id="member-gfeditorcommandregistry-constants-status_replaced"></a>

### `STATUS_REPLACED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_REPLACED: StringName = &"replaced"
```

已存在动作被替换。

<a id="member-gfeditorcommandregistry-constants-status_duplicate"></a>

### `STATUS_DUPLICATE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_DUPLICATE: StringName = &"duplicate"
```

动作 ID 已存在且未允许替换。

<a id="member-gfeditorcommandregistry-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

动作声明无效。

<a id="member-gfeditorcommandregistry-constants-status_missing"></a>

### `STATUS_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_MISSING: StringName = &"missing"
```

动作不存在。

<a id="member-gfeditorcommandregistry-constants-status_invoked"></a>

### `STATUS_INVOKED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVOKED: StringName = &"invoked"
```

动作已调用。

<a id="member-gfeditorcommandregistry-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

动作调用失败。

## 属性

<a id="member-gfeditorcommandregistry-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

注册表元数据。

结构：

- `metadata`: Dictionary for caller-defined registry metadata.

## 方法

<a id="member-gfeditorcommandregistry-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空所有动作记录。

<a id="member-gfeditorcommandregistry-methods-register_action"></a>

### `register_action`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_action(action: GFEditorActionDefinitionBase, options: Dictionary = {}) -> Dictionary:
```

注册单个动作。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 要注册的动作声明。 |
| `options` | 注册选项，支持 replace_existing、group、source_id、sort_order 和 metadata。 |

返回：注册结果。

结构：

- `options`: Dictionary with replace_existing, group, source_id, sort_order, and metadata.
- `return`: Dictionary containing ok, status, action_id, replaced, error_code, message, and metadata.

<a id="member-gfeditorcommandregistry-methods-register_actions"></a>

### `register_actions`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_actions(actions: Array[GFEditorActionDefinitionBase], options: Dictionary = {}) -> Dictionary:
```

批量注册动作。

参数：

| 名称 | 说明 |
|---|---|
| `actions` | 动作声明数组。 |
| `options` | 注册选项，会传给每个 register_action()。 |

返回：批量注册摘要。

结构：

- `actions`: Array of GFEditorActionDefinition.
- `options`: Dictionary register_action() options.
- `return`: Dictionary containing ok, action_count, registered_count, failed_count, and results.

<a id="member-gfeditorcommandregistry-methods-unregister_action"></a>

### `unregister_action`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unregister_action(action_id: StringName) -> bool:
```

取消注册动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作 ID。 |

返回：存在并移除时返回 true。

<a id="member-gfeditorcommandregistry-methods-has_action"></a>

### `has_action`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_action(action_id: StringName) -> bool:
```

检查动作是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作 ID。 |

返回：存在返回 true。

<a id="member-gfeditorcommandregistry-methods-get_action"></a>

### `get_action`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_action(action_id: StringName) -> GFEditorActionDefinitionBase:
```

获取动作声明。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作 ID。 |

返回：动作声明；不存在时返回 null。

<a id="member-gfeditorcommandregistry-methods-get_action_record"></a>

### `get_action_record`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_action_record(action_id: StringName) -> Dictionary:
```

获取动作注册记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作 ID。 |

返回：动作记录；不存在时返回空字典。

结构：

- `return`: Dictionary containing action, action_id, group, source_id, sort_order, and metadata.

<a id="member-gfeditorcommandregistry-methods-get_action_ids"></a>

### `get_action_ids`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_action_ids(filters: Dictionary = {}) -> PackedStringArray:
```

获取动作 ID 列表。

参数：

| 名称 | 说明 |
|---|---|
| `filters` | 可选过滤条件，支持 group 与 source_id。 |

返回：按 group、sort_order、label 排序的动作 ID。

结构：

- `filters`: Dictionary with optional group and source_id.

<a id="member-gfeditorcommandregistry-methods-get_action_snapshots"></a>

### `get_action_snapshots`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_action_snapshots(context: Dictionary = {}, options: Dictionary = {}) -> Array[Dictionary]:
```

获取动作快照列表。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 用于可用性检查的调用上下文。 |
| `options` | 可选参数，支持 group、source_id 和 include_availability。 |

返回：动作快照数组。

结构：

- `context`: Dictionary passed to action availability checks.
- `options`: Dictionary with group, source_id, and include_availability.
- `return`: Array[Dictionary] action snapshots sorted for UI display.

<a id="member-gfeditorcommandregistry-methods-resolve_layout"></a>

### `resolve_layout`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func resolve_layout( action_ids: PackedStringArray, context: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

按保存的动作 ID 布局解析动作快照。

参数：

| 名称 | 说明 |
|---|---|
| `action_ids` | 已保存的动作 ID 顺序。 |
| `context` | 用于可用性检查的调用上下文。 |
| `options` | 可选参数，支持 include_availability。 |

返回：布局解析报告。

结构：

- `context`: Dictionary passed to action availability checks.
- `options`: Dictionary with optional include_availability.
- `return`: Dictionary containing entries and missing_ids.

<a id="member-gfeditorcommandregistry-methods-invoke_action"></a>

### `invoke_action`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func invoke_action( action_id: StringName, context: Dictionary = {}, undo_manager: Object = null ) -> Dictionary:
```

按 ID 调用动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作 ID。 |
| `context` | 动作上下文。 |
| `undo_manager` | EditorUndoRedoManager 或兼容对象；为空时直接执行命令。 |

返回：调用结果。

结构：

- `context`: Dictionary passed to action.invoke().
- `return`: Dictionary containing ok, status, action_id, error_code, message, and metadata.

<a id="member-gfeditorcommandregistry-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot(context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
```

获取注册表调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 可选动作上下文。 |
| `options` | 可选参数，透传给 get_action_snapshots()。 |

返回：调试快照。

结构：

- `context`: Dictionary passed to get_action_snapshots().
- `options`: Dictionary get_action_snapshots() options.
- `return`: Dictionary containing action_count, action_ids, actions, and metadata.
