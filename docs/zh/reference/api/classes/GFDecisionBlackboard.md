# GFDecisionBlackboard

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/runtime/gf_decision_blackboard.gd`
- 模块：`Decision`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`4.3.0`

通用决策黑板。 保存一组由项目定义的运行时值，用于 Utility AI、导演系统或其他决策流程读取。 它只管理键值、变更信号和调试快照，不规定任何玩法字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`value_changed`](#member-gfdecisionblackboard-signals-value_changed) | `signal value_changed(key: StringName, old_value: Variant, new_value: Variant)` |
| 信号 | [`value_removed`](#member-gfdecisionblackboard-signals-value_removed) | `signal value_removed(key: StringName, old_value: Variant)` |
| 属性 | [`values`](#member-gfdecisionblackboard-properties-values) | `var values: Dictionary = {}` |
| 方法 | [`set_value`](#member-gfdecisionblackboard-methods-set_value) | `func set_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`get_value`](#member-gfdecisionblackboard-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`has_value`](#member-gfdecisionblackboard-methods-has_value) | `func has_value(key: StringName) -> bool:` |
| 方法 | [`erase_value`](#member-gfdecisionblackboard-methods-erase_value) | `func erase_value(key: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfdecisionblackboard-methods-clear) | `func clear() -> void:` |
| 方法 | [`merge`](#member-gfdecisionblackboard-methods-merge) | `func merge(source_values: Dictionary, overwrite: bool = true) -> void:` |
| 方法 | [`to_dictionary`](#member-gfdecisionblackboard-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`duplicate_blackboard`](#member-gfdecisionblackboard-methods-duplicate_blackboard) | `func duplicate_blackboard() -> GFDecisionBlackboard:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionblackboard-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfdecisionblackboard-signals-value_changed"></a>

### `value_changed`

- API：`public`

```gdscript
signal value_changed(key: StringName, old_value: Variant, new_value: Variant)
```

当黑板值发生变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |
| `old_value` | 旧值。 |
| `new_value` | 新值。 |

结构：

- `old_value`: 黑板中的任意项目值；之前不存在时为 null。
- `new_value`: 黑板中的任意项目值。

<a id="member-gfdecisionblackboard-signals-value_removed"></a>

### `value_removed`

- API：`public`

```gdscript
signal value_removed(key: StringName, old_value: Variant)
```

当黑板值被移除时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |
| `old_value` | 被移除的旧值。 |

结构：

- `old_value`: 黑板中的任意项目值。

## 属性

<a id="member-gfdecisionblackboard-properties-values"></a>

### `values`

- API：`public`

```gdscript
var values: Dictionary = {}
```

黑板值表。键通常为 StringName，值由项目决定。

结构：

- `values`: Dictionary[StringName, Variant] project-defined decision values.

## 方法

<a id="member-gfdecisionblackboard-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant) -> void:
```

设置黑板值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |
| `value` | 要写入或修改的值。 |

结构：

- `value`: 要写入黑板的任意项目值。

<a id="member-gfdecisionblackboard-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

获取黑板值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |
| `default_value` | 缺失时返回的默认值。 |

返回：黑板值或默认值。

结构：

- `default_value`: 黑板缺失时返回的任意默认值。
- `return`: 黑板中的项目值，或传入的 default_value。

<a id="member-gfdecisionblackboard-methods-has_value"></a>

### `has_value`

- API：`public`

```gdscript
func has_value(key: StringName) -> bool:
```

检查黑板值是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |

返回：存在返回 true。

<a id="member-gfdecisionblackboard-methods-erase_value"></a>

### `erase_value`

- API：`public`

```gdscript
func erase_value(key: StringName) -> bool:
```

移除黑板值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键。 |

返回：移除成功返回 true。

<a id="member-gfdecisionblackboard-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空全部黑板值。

<a id="member-gfdecisionblackboard-methods-merge"></a>

### `merge`

- API：`public`

```gdscript
func merge(source_values: Dictionary, overwrite: bool = true) -> void:
```

合并一批黑板值。

参数：

| 名称 | 说明 |
|---|---|
| `source_values` | 要合并的值表。 |
| `overwrite` | 已存在同名键时是否覆盖。 |

结构：

- `source_values`: Dictionary[StringName, Variant] project-defined decision values.

<a id="member-gfdecisionblackboard-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为值表副本。

返回：黑板值表副本。

结构：

- `return`: Dictionary[StringName, Variant] project-defined decision values.

<a id="member-gfdecisionblackboard-methods-duplicate_blackboard"></a>

### `duplicate_blackboard`

- API：`public`

```gdscript
func duplicate_blackboard() -> GFDecisionBlackboard:
```

创建黑板副本。

返回：新黑板实例。

<a id="member-gfdecisionblackboard-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: 包含 value_count、keys 和 values 字段的 Dictionary。
