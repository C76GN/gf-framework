# GFCombatAction

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/actions/gf_combat_action.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用战斗动作数据。 表达一次对目标系统可解释的数值动作。框架只保存动作类别、操作、数值、 标签和元数据，不规定伤害、治疗、阵营或生命值语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Operation`](#member-gfcombataction-enums-operation) | `enum Operation` |
| 属性 | [`action_id`](#member-gfcombataction-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`action_kind`](#member-gfcombataction-properties-action_kind) | `var action_kind: StringName = &""` |
| 属性 | [`operation`](#member-gfcombataction-properties-operation) | `var operation: Operation = Operation.SUBTRACT` |
| 属性 | [`amount`](#member-gfcombataction-properties-amount) | `var amount: float:` |
| 属性 | [`tags`](#member-gfcombataction-properties-tags) | `var tags: Array[StringName] = []` |
| 属性 | [`payload`](#member-gfcombataction-properties-payload) | `var payload: Variant = null` |
| 属性 | [`metadata`](#member-gfcombataction-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`duplicate_action`](#member-gfcombataction-methods-duplicate_action) | `func duplicate_action() -> GFCombatAction:` |
| 方法 | [`with_action_id`](#member-gfcombataction-methods-with_action_id) | `func with_action_id(value: StringName) -> GFCombatAction:` |
| 方法 | [`with_kind`](#member-gfcombataction-methods-with_kind) | `func with_kind(value: StringName) -> GFCombatAction:` |
| 方法 | [`with_operation`](#member-gfcombataction-methods-with_operation) | `func with_operation(value: Operation) -> GFCombatAction:` |
| 方法 | [`with_amount`](#member-gfcombataction-methods-with_amount) | `func with_amount(value: float) -> GFCombatAction:` |
| 方法 | [`is_numeric_state_valid`](#member-gfcombataction-methods-is_numeric_state_valid) | `func is_numeric_state_valid() -> bool:` |
| 方法 | [`with_tags`](#member-gfcombataction-methods-with_tags) | `func with_tags(value: Array[StringName]) -> GFCombatAction:` |
| 方法 | [`with_payload`](#member-gfcombataction-methods-with_payload) | `func with_payload(value: Variant) -> GFCombatAction:` |
| 方法 | [`with_metadata`](#member-gfcombataction-methods-with_metadata) | `func with_metadata(value: Dictionary) -> GFCombatAction:` |
| 方法 | [`to_dict`](#member-gfcombataction-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`to_report_dictionary`](#member-gfcombataction-methods-to_report_dictionary) | `func to_report_dictionary(options: Dictionary = {}) -> Dictionary:` |

## 枚举

<a id="member-gfcombataction-enums-operation"></a>

### `Operation`

- API：`public`

```gdscript
enum Operation {
	## 增加目标值。
	ADD,
	## 减少目标值。
	SUBTRACT,
	## 直接设置目标值。
	SET,
}
```

数值操作类型。

## 属性

<a id="member-gfcombataction-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

动作标识。

<a id="member-gfcombataction-properties-action_kind"></a>

### `action_kind`

- API：`public`

```gdscript
var action_kind: StringName = &""
```

动作类别，由项目定义。

<a id="member-gfcombataction-properties-operation"></a>

### `operation`

- API：`public`

```gdscript
var operation: Operation = Operation.SUBTRACT
```

数值操作。

<a id="member-gfcombataction-properties-amount"></a>

### `amount`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var amount: float:
```

动作数值。

<a id="member-gfcombataction-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: Array[StringName] = []
```

动作标签，由项目定义。

<a id="member-gfcombataction-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

项目自定义 payload。

结构：

- `payload`: Variant，可保存项目自定义动作载荷；框架只复制并透传。

<a id="member-gfcombataction-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义元数据；框架只复制并透传。

## 方法

<a id="member-gfcombataction-methods-duplicate_action"></a>

### `duplicate_action`

- API：`public`

```gdscript
func duplicate_action() -> GFCombatAction:
```

复制动作。

返回：新动作。

<a id="member-gfcombataction-methods-with_action_id"></a>

### `with_action_id`

- API：`public`

```gdscript
func with_action_id(value: StringName) -> GFCombatAction:
```

设置动作标识并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 动作标识。 |

返回：当前动作。

<a id="member-gfcombataction-methods-with_kind"></a>

### `with_kind`

- API：`public`

```gdscript
func with_kind(value: StringName) -> GFCombatAction:
```

设置动作类别并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 动作类别。 |

返回：当前动作。

<a id="member-gfcombataction-methods-with_operation"></a>

### `with_operation`

- API：`public`

```gdscript
func with_operation(value: Operation) -> GFCombatAction:
```

设置数值操作并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 数值操作。 |

返回：当前动作。

<a id="member-gfcombataction-methods-with_amount"></a>

### `with_amount`

- API：`public`

```gdscript
func with_amount(value: float) -> GFCombatAction:
```

设置动作数值并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 动作数值。 |

返回：当前动作。

<a id="member-gfcombataction-methods-is_numeric_state_valid"></a>

### `is_numeric_state_valid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_numeric_state_valid() -> bool:
```

检查动作数值是否可安全参与运算。

返回：最近一次 amount 写入有效且当前值有限时返回 true。

<a id="member-gfcombataction-methods-with_tags"></a>

### `with_tags`

- API：`public`

```gdscript
func with_tags(value: Array[StringName]) -> GFCombatAction:
```

设置动作标签并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 动作标签。 |

返回：当前动作。

<a id="member-gfcombataction-methods-with_payload"></a>

### `with_payload`

- API：`public`

```gdscript
func with_payload(value: Variant) -> GFCombatAction:
```

设置 payload 并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 载荷。 |

返回：当前动作。

结构：

- `value`: Variant，可保存项目自定义动作载荷；框架只复制并透传。

<a id="member-gfcombataction-methods-with_metadata"></a>

### `with_metadata`

- API：`public`

```gdscript
func with_metadata(value: Dictionary) -> GFCombatAction:
```

设置元数据并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 元数据。 |

返回：当前动作。

结构：

- `value`: Dictionary，项目自定义元数据；框架只复制并透传。

<a id="member-gfcombataction-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转为字典。

返回：字典快照。

结构：

- `return`: Dictionary，包含 action_id、action_kind、operation、amount、tags、payload 和 metadata。

<a id="member-gfcombataction-methods-to_report_dictionary"></a>

### `to_report_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
```

转为 JSON-safe 报告字典。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给 GFReportValueCodec 的编码选项。 |

返回：报告字典快照。

结构：

- `options`: Dictionary with GFReportValueCodec encoding options.
- `return`: JSON-safe Dictionary based on to_dict().
