# GFDecisionContext

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/runtime/gf_decision_context.gd`
- 模块：`Decision`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`4.3.0`

通用决策上下文。 组合黑板、主体/目标快照和元数据，供决策候选与考虑项读取状态。 该类型只用弱引用暴露当前对象，不通过上下文延长对象生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`blackboard`](#member-gfdecisioncontext-properties-blackboard) | `var blackboard: GFDecisionBlackboard = null` |
| 属性 | [`subject`](#member-gfdecisioncontext-properties-subject) | `var subject: Object:` |
| 属性 | [`target`](#member-gfdecisioncontext-properties-target) | `var target: Object:` |
| 属性 | [`subject_values`](#member-gfdecisioncontext-properties-subject_values) | `var subject_values: Dictionary = {}` |
| 属性 | [`target_values`](#member-gfdecisioncontext-properties-target_values) | `var target_values: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfdecisioncontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_value`](#member-gfdecisioncontext-methods-set_value) | `func set_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`get_value`](#member-gfdecisioncontext-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`has_value`](#member-gfdecisioncontext-methods-has_value) | `func has_value(key: StringName) -> bool:` |
| 方法 | [`set_metadata_value`](#member-gfdecisioncontext-methods-set_metadata_value) | `func set_metadata_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`get_metadata_value`](#member-gfdecisioncontext-methods-get_metadata_value) | `func get_metadata_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_subject_value`](#member-gfdecisioncontext-methods-get_subject_value) | `func get_subject_value(key: StringName, fallback: Variant = null) -> Variant:` |
| 方法 | [`get_target_value`](#member-gfdecisioncontext-methods-get_target_value) | `func get_target_value(key: StringName, fallback: Variant = null) -> Variant:` |
| 方法 | [`get_subject_or_null`](#member-gfdecisioncontext-methods-get_subject_or_null) | `func get_subject_or_null() -> Object:` |
| 方法 | [`get_target_or_null`](#member-gfdecisioncontext-methods-get_target_or_null) | `func get_target_or_null() -> Object:` |
| 方法 | [`duplicate_context`](#member-gfdecisioncontext-methods-duplicate_context) | `func duplicate_context() -> GFDecisionContext:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisioncontext-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfdecisioncontext-properties-blackboard"></a>

### `blackboard`

- API：`public`

```gdscript
var blackboard: GFDecisionBlackboard = null
```

决策黑板。

<a id="member-gfdecisioncontext-properties-subject"></a>

### `subject`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var subject: Object:
```

决策主体，例如当前 agent、系统或导演对象。

<a id="member-gfdecisioncontext-properties-target"></a>

### `target`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target: Object:
```

可选决策目标。

<a id="member-gfdecisioncontext-properties-subject_values"></a>

### `subject_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var subject_values: Dictionary = {}
```

主体决策值快照。

结构：

- `subject_values`: Dictionary[StringName, Variant] captured from the subject at assignment time.

<a id="member-gfdecisioncontext-properties-target_values"></a>

### `target_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_values: Dictionary = {}
```

目标决策值快照。

结构：

- `target_values`: Dictionary[StringName, Variant] captured from the target at assignment time.

<a id="member-gfdecisioncontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义上下文元数据。

结构：

- `metadata`: Dictionary[StringName, Variant] project-defined decision metadata.

## 方法

<a id="member-gfdecisioncontext-methods-set_value"></a>

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

<a id="member-gfdecisioncontext-methods-get_value"></a>

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

<a id="member-gfdecisioncontext-methods-has_value"></a>

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

<a id="member-gfdecisioncontext-methods-set_metadata_value"></a>

### `set_metadata_value`

- API：`public`

```gdscript
func set_metadata_value(key: StringName, value: Variant) -> void:
```

设置元数据值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |
| `value` | 元数据值。 |

结构：

- `value`: 要写入元数据的任意项目值。

<a id="member-gfdecisioncontext-methods-get_metadata_value"></a>

### `get_metadata_value`

- API：`public`

```gdscript
func get_metadata_value(key: StringName, default_value: Variant = null) -> Variant:
```

获取元数据值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |
| `default_value` | 缺失时返回的默认值。 |

返回：元数据值或默认值。

结构：

- `default_value`: 元数据缺失时返回的任意默认值。
- `return`: 元数据中的项目值，或传入的 default_value。

<a id="member-gfdecisioncontext-methods-get_subject_value"></a>

### `get_subject_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_subject_value(key: StringName, fallback: Variant = null) -> Variant:
```

从主体快照读取决策值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键或属性名。 |
| `fallback` | 读取失败时的兜底值。 |

返回：主体值或兜底值。

结构：

- `fallback`: 读取失败时返回的任意项目值。
- `return`: 从主体读取的项目值，或传入的 fallback。

<a id="member-gfdecisioncontext-methods-get_target_value"></a>

### `get_target_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_target_value(key: StringName, fallback: Variant = null) -> Variant:
```

从目标快照读取决策值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值键或属性名。 |
| `fallback` | 读取失败时的兜底值。 |

返回：目标值或兜底值。

结构：

- `fallback`: 读取失败时返回的任意项目值。
- `return`: 从目标读取的项目值，或传入的 fallback。

<a id="member-gfdecisioncontext-methods-get_subject_or_null"></a>

### `get_subject_or_null`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_subject_or_null() -> Object:
```

获取当前主体对象；对象已释放时返回 null。

返回：当前主体对象或 null。

<a id="member-gfdecisioncontext-methods-get_target_or_null"></a>

### `get_target_or_null`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_target_or_null() -> Object:
```

获取当前目标对象；对象已释放时返回 null。

返回：当前目标对象或 null。

<a id="member-gfdecisioncontext-methods-duplicate_context"></a>

### `duplicate_context`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func duplicate_context() -> GFDecisionContext:
```

创建上下文副本。 默认复用 subject 与 target 弱引用，只复制黑板值、对象快照和元数据。

返回：新上下文实例。

<a id="member-gfdecisioncontext-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: 包含 blackboard、metadata、subject_class 和 target_class 字段的 Dictionary。
