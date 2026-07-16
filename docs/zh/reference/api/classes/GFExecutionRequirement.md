# GFExecutionRequirement

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_execution_requirement.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`7.0.0`

通用执行条件集合。 用于在任务、系统、工具按钮或资源流程执行前统一评估一组声明式条件。 它只读取调用方传入的 context 字典和可选谓词，不绑定具体调度器或业务系统。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`MODE_ALL`](#member-gfexecutionrequirement-constants-mode_all) | `const MODE_ALL: StringName = &"all"` |
| 常量 | [`MODE_ANY`](#member-gfexecutionrequirement-constants-mode_any) | `const MODE_ANY: StringName = &"any"` |
| 常量 | [`MODE_NONE`](#member-gfexecutionrequirement-constants-mode_none) | `const MODE_NONE: StringName = &"none"` |
| 常量 | [`KIND_PREDICATE`](#member-gfexecutionrequirement-constants-kind_predicate) | `const KIND_PREDICATE: StringName = &"predicate"` |
| 常量 | [`KIND_VALUE`](#member-gfexecutionrequirement-constants-kind_value) | `const KIND_VALUE: StringName = &"value"` |
| 常量 | [`KIND_PRESENT`](#member-gfexecutionrequirement-constants-kind_present) | `const KIND_PRESENT: StringName = &"present"` |
| 属性 | [`requirement_id`](#member-gfexecutionrequirement-properties-requirement_id) | `var requirement_id: StringName = &""` |
| 属性 | [`label`](#member-gfexecutionrequirement-properties-label) | `var label: String = ""` |
| 属性 | [`metadata`](#member-gfexecutionrequirement-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfexecutionrequirement-methods-configure) | `func configure( p_requirement_id: StringName, p_label: String = "", p_metadata: Dictionary = {} ) -> GFExecutionRequirement:` |
| 方法 | [`add_predicate`](#member-gfexecutionrequirement-methods-add_predicate) | `func add_predicate(condition_id: StringName, predicate: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_value`](#member-gfexecutionrequirement-methods-add_value) | `func add_value( condition_id: StringName, key: Variant, expected_value: Variant, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_presence`](#member-gfexecutionrequirement-methods-add_presence) | `func add_presence(condition_id: StringName, key: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`evaluate`](#member-gfexecutionrequirement-methods-evaluate) | `func evaluate(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_satisfied`](#member-gfexecutionrequirement-methods-is_satisfied) | `func is_satisfied(context: Dictionary = {}) -> bool:` |
| 方法 | [`get_conditions`](#member-gfexecutionrequirement-methods-get_conditions) | `func get_conditions() -> Array[Dictionary]:` |
| 方法 | [`clear`](#member-gfexecutionrequirement-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfexecutionrequirement-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfexecutionrequirement-constants-mode_all"></a>

### `MODE_ALL`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const MODE_ALL: StringName = &"all"
```

条件必须满足。

<a id="member-gfexecutionrequirement-constants-mode_any"></a>

### `MODE_ANY`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const MODE_ANY: StringName = &"any"
```

同组条件至少满足一个。

<a id="member-gfexecutionrequirement-constants-mode_none"></a>

### `MODE_NONE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const MODE_NONE: StringName = &"none"
```

条件必须不满足。

<a id="member-gfexecutionrequirement-constants-kind_predicate"></a>

### `KIND_PREDICATE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_PREDICATE: StringName = &"predicate"
```

Callable 谓词条件。

<a id="member-gfexecutionrequirement-constants-kind_value"></a>

### `KIND_VALUE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_VALUE: StringName = &"value"
```

context 值比较条件。

<a id="member-gfexecutionrequirement-constants-kind_present"></a>

### `KIND_PRESENT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_PRESENT: StringName = &"present"
```

context key 存在性条件。

## 属性

<a id="member-gfexecutionrequirement-properties-requirement_id"></a>

### `requirement_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var requirement_id: StringName = &""
```

条件集合稳定标识。

<a id="member-gfexecutionrequirement-properties-label"></a>

### `label`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var label: String = ""
```

条件集合显示名称。

<a id="member-gfexecutionrequirement-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary for caller-defined requirement metadata.

## 方法

<a id="member-gfexecutionrequirement-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_requirement_id: StringName, p_label: String = "", p_metadata: Dictionary = {} ) -> GFExecutionRequirement:
```

配置条件集合。

参数：

| 名称 | 说明 |
|---|---|
| `p_requirement_id` | 条件集合稳定标识。 |
| `p_label` | 显示名称。 |
| `p_metadata` | 调用方元数据。 |

返回：当前条件集合。

结构：

- `p_metadata`: Dictionary copied into metadata.

<a id="member-gfexecutionrequirement-methods-add_predicate"></a>

### `add_predicate`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_predicate(condition_id: StringName, predicate: Callable, options: Dictionary = {}) -> Dictionary:
```

添加 Callable 谓词条件。谓词签名为 `(context: Dictionary) -> bool|Dictionary`。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件稳定标识。 |
| `predicate` | 条件谓词。 |
| `options` | 条件选项，支持 mode、label、negate 和 metadata。 |

返回：条件快照；predicate 无效时为空字典。

结构：

- `options`: Dictionary，可包含 mode: StringName、label: String、negate: bool、metadata: Dictionary。
- `return`: Dictionary，包含 condition_id、kind、mode、label、negate、metadata 和 has_predicate。

<a id="member-gfexecutionrequirement-methods-add_value"></a>

### `add_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_value( condition_id: StringName, key: Variant, expected_value: Variant, options: Dictionary = {} ) -> Dictionary:
```

添加 context 值比较条件。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件稳定标识。 |
| `key` | 要从 context 读取的 key。 |
| `expected_value` | 期望值。 |
| `options` | 条件选项，支持 mode、label、negate、metadata 和 equals_options。 |

返回：条件快照。

结构：

- `key`: Variant context key，通常为 String 或 StringName。
- `expected_value`: Variant expected context value.
- `options`: Dictionary，可包含 mode: StringName、label: String、negate: bool、metadata: Dictionary、equals_options: Dictionary。
- `return`: Dictionary，包含 condition_id、kind、mode、label、key、expected、negate 和 metadata。

<a id="member-gfexecutionrequirement-methods-add_presence"></a>

### `add_presence`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_presence(condition_id: StringName, key: Variant, options: Dictionary = {}) -> Dictionary:
```

添加 context key 存在性条件。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件稳定标识。 |
| `key` | 要检查的 context key。 |
| `options` | 条件选项，支持 mode、label、negate 和 metadata。 |

返回：条件快照。

结构：

- `key`: Variant context key，通常为 String 或 StringName。
- `options`: Dictionary，可包含 mode: StringName、label: String、negate: bool、metadata: Dictionary。
- `return`: Dictionary，包含 condition_id、kind、mode、label、key、negate 和 metadata。

<a id="member-gfexecutionrequirement-methods-evaluate"></a>

### `evaluate`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func evaluate(context: Dictionary = {}) -> Dictionary:
```

评估条件集合。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方上下文字典。 |

返回：条件评估报告。

结构：

- `context`: Dictionary read by value and predicate conditions.
- `return`: Dictionary，包含 ok、requirement_id、label、all_satisfied、any_satisfied、none_clear、satisfied_count、failed_count、raw_failed_count、blocking_count、none_matched_count、conditions 和 metadata。failed_count/raw_failed_count 记录原始谓词 false 数；blocking_count 记录导致 requirement 不通过的聚合阻塞数。

<a id="member-gfexecutionrequirement-methods-is_satisfied"></a>

### `is_satisfied`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_satisfied(context: Dictionary = {}) -> bool:
```

检查条件集合是否满足。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方上下文字典。 |

返回：满足时返回 true。

结构：

- `context`: Dictionary read by value and predicate conditions.

<a id="member-gfexecutionrequirement-methods-get_conditions"></a>

### `get_conditions`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_conditions() -> Array[Dictionary]:
```

获取条件快照数组。

返回：条件快照数组，不包含 Callable 本体。

结构：

- `return`: Array[Dictionary]，每个元素包含 condition_id、kind、mode、label、key、expected、negate、metadata 和 has_predicate。

<a id="member-gfexecutionrequirement-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部条件。

<a id="member-gfexecutionrequirement-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 requirement_id、label、condition_count、conditions 和 metadata。
