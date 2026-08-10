# GFDecisionContext

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/runtime/gf_decision_context.gd`
- 模块：`Decision`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`4.3.0`

通用决策上下文。 组合黑板、主体/目标快照视图和元数据，供决策候选与考虑项读取状态。 赋值时先主动捕获可见值；缺失 key 可由对象的 `get_decision_value()` 按需提供并写入当前上下文缓存。 subject/target 顶层句柄使用弱引用；项目提供的快照值仍可包含 Object/Resource 强引用， 因此返回 self 或包含 self 的对象图会延长其生命周期。需要严格弱所有权时，provider 不得把当前对象放入快照值图。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_SNAPSHOT_ENTRIES`](#member-gfdecisioncontext-constants-default_max_snapshot_entries) | `const DEFAULT_MAX_SNAPSHOT_ENTRIES: int = 1024` |
| 常量 | [`DEFAULT_MAX_REFLECTION_PROPERTIES`](#member-gfdecisioncontext-constants-default_max_reflection_properties) | `const DEFAULT_MAX_REFLECTION_PROPERTIES: int = 256` |
| 属性 | [`blackboard`](#member-gfdecisioncontext-properties-blackboard) | `var blackboard: GFDecisionBlackboard = null` |
| 属性 | [`subject`](#member-gfdecisioncontext-properties-subject) | `var subject: Object:` |
| 属性 | [`target`](#member-gfdecisioncontext-properties-target) | `var target: Object:` |
| 属性 | [`subject_values`](#member-gfdecisioncontext-properties-subject_values) | `var subject_values: Dictionary = {}` |
| 属性 | [`target_values`](#member-gfdecisioncontext-properties-target_values) | `var target_values: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfdecisioncontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`capture_options`](#member-gfdecisioncontext-properties-capture_options) | `var capture_options: Dictionary = {}` |
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

## 常量

<a id="member-gfdecisioncontext-constants-default_max_snapshot_entries"></a>

### `DEFAULT_MAX_SNAPSHOT_ENTRIES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_SNAPSHOT_ENTRIES: int = 1024
```

主体或目标主动捕获的默认最大条目数。

<a id="member-gfdecisioncontext-constants-default_max_reflection_properties"></a>

### `DEFAULT_MAX_REFLECTION_PROPERTIES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_REFLECTION_PROPERTIES: int = 256
```

反射属性捕获的默认最大条目数。

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

主体决策值快照视图。容器会循环安全地复制，但其中的 Object/Resource 身份保持共享；缺失 key 可被懒缓存补充。

结构：

- `subject_values`: Dictionary[StringName, Variant] eagerly captured at assignment and optionally extended by bounded lazy reads.

<a id="member-gfdecisioncontext-properties-target_values"></a>

### `target_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_values: Dictionary = {}
```

目标决策值快照视图。容器会循环安全地复制，但其中的 Object/Resource 身份保持共享；缺失 key 可被懒缓存补充。

结构：

- `target_values`: Dictionary[StringName, Variant] eagerly captured at assignment and optionally extended by bounded lazy reads.

<a id="member-gfdecisioncontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义上下文元数据。

结构：

- `metadata`: Dictionary[StringName, Variant] project-defined decision metadata.

<a id="member-gfdecisioncontext-properties-capture_options"></a>

### `capture_options`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var capture_options: Dictionary = {}
```

捕获预算选项。

结构：

- `capture_options`: Dictionary with optional max_snapshot_entries and max_reflection_properties integer fields.

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

从主体快照视图读取决策值；每个缺失 key 最多触发一次受预算约束的 provider 懒读取，miss 也会负缓存并消费预算。

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

从目标快照视图读取决策值；每个缺失 key 最多触发一次受预算约束的 provider 懒读取，miss 也会负缓存并消费预算。

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

创建上下文副本。 默认复用 subject 与 target 弱引用；循环安全地复制黑板、快照容器、捕获账本、诊断和元数据，嵌套 Object/Resource 身份保持共享。

返回：新上下文实例。

<a id="member-gfdecisioncontext-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: JSON-safe Dictionary，包含 blackboard、metadata、subject_class、target_class、subject_values、target_values 和 capture_diagnostics 字段。
