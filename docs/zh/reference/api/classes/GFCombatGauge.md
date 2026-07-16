# GFCombatGauge

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_combat_gauge.gd`
- 模块：`Combat`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用可变数值槽。 用 GFCombatAction 驱动一个带上下限的数值。它可表示生命、护盾、能量、 耐久或任意项目自定义资源，但框架不绑定这些业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`value_changed`](#member-gfcombatgauge-signals-value_changed) | `signal value_changed(previous_value: float, current_value: float)` |
| 信号 | [`action_validating`](#member-gfcombatgauge-signals-action_validating) | `signal action_validating(action: GFCombatAction, report: Dictionary)` |
| 信号 | [`action_applied`](#member-gfcombatgauge-signals-action_applied) | `signal action_applied(result: GFCombatActionResult)` |
| 信号 | [`action_rejected`](#member-gfcombatgauge-signals-action_rejected) | `signal action_rejected(result: GFCombatActionResult)` |
| 信号 | [`minimum_reached`](#member-gfcombatgauge-signals-minimum_reached) | `signal minimum_reached(current_value: float)` |
| 信号 | [`maximum_reached`](#member-gfcombatgauge-signals-maximum_reached) | `signal maximum_reached(current_value: float)` |
| 属性 | [`min_value`](#member-gfcombatgauge-properties-min_value) | `var min_value: float:` |
| 属性 | [`max_value`](#member-gfcombatgauge-properties-max_value) | `var max_value: float:` |
| 属性 | [`current_value`](#member-gfcombatgauge-properties-current_value) | `var current_value: float:` |
| 属性 | [`accepted_action_kinds`](#member-gfcombatgauge-properties-accepted_action_kinds) | `var accepted_action_kinds: Array[StringName] = []` |
| 属性 | [`rejected_action_kinds`](#member-gfcombatgauge-properties-rejected_action_kinds) | `var rejected_action_kinds: Array[StringName] = []` |
| 属性 | [`modifiers`](#member-gfcombatgauge-properties-modifiers) | `var modifiers: Array[GFCombatActionModifier] = []` |
| 属性 | [`metadata`](#member-gfcombatgauge-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`validation_callback`](#member-gfcombatgauge-properties-validation_callback) | `var validation_callback: Callable = Callable()` |
| 方法 | [`configure`](#member-gfcombatgauge-methods-configure) | `func configure(p_min_value: float, p_max_value: float, p_current_value: float) -> void:` |
| 方法 | [`set_value`](#member-gfcombatgauge-methods-set_value) | `func set_value(value: float) -> void:` |
| 方法 | [`set_bounds`](#member-gfcombatgauge-methods-set_bounds) | `func set_bounds(p_min_value: float, p_max_value: float) -> void:` |
| 方法 | [`get_ratio`](#member-gfcombatgauge-methods-get_ratio) | `func get_ratio() -> float:` |
| 方法 | [`can_receive_action_kind`](#member-gfcombatgauge-methods-can_receive_action_kind) | `func can_receive_action_kind(action_kind: StringName) -> bool:` |
| 方法 | [`add_modifier`](#member-gfcombatgauge-methods-add_modifier) | `func add_modifier(modifier: GFCombatActionModifier) -> void:` |
| 方法 | [`remove_modifier`](#member-gfcombatgauge-methods-remove_modifier) | `func remove_modifier(modifier: GFCombatActionModifier) -> void:` |
| 方法 | [`clear_modifiers`](#member-gfcombatgauge-methods-clear_modifiers) | `func clear_modifiers() -> void:` |
| 方法 | [`apply_action`](#member-gfcombatgauge-methods-apply_action) | `func apply_action(action: GFCombatAction) -> GFCombatActionResult:` |

## 信号

<a id="member-gfcombatgauge-signals-value_changed"></a>

### `value_changed`

- API：`public`

```gdscript
signal value_changed(previous_value: float, current_value: float)
```

数值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_value` | 旧值。 |
| `current_value` | 新值。 |

<a id="member-gfcombatgauge-signals-action_validating"></a>

### `action_validating`

- API：`public`

```gdscript
signal action_validating(action: GFCombatAction, report: Dictionary)
```

动作进入自定义校验阶段时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 已经应用修正器的动作副本。 |
| `report` | 当前校验报告。 |

结构：

- `report`: Dictionary，包含 ok、reason 和 metadata，可由监听者调整。

<a id="member-gfcombatgauge-signals-action_applied"></a>

### `action_applied`

- API：`public`

```gdscript
signal action_applied(result: GFCombatActionResult)
```

动作成功应用时发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 应用结果。 |

<a id="member-gfcombatgauge-signals-action_rejected"></a>

### `action_rejected`

- API：`public`

```gdscript
signal action_rejected(result: GFCombatActionResult)
```

动作被拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 拒绝结果。 |

<a id="member-gfcombatgauge-signals-minimum_reached"></a>

### `minimum_reached`

- API：`public`

```gdscript
signal minimum_reached(current_value: float)
```

数值到达下限时发出。

参数：

| 名称 | 说明 |
|---|---|
| `current_value` | 当前值。 |

<a id="member-gfcombatgauge-signals-maximum_reached"></a>

### `maximum_reached`

- API：`public`

```gdscript
signal maximum_reached(current_value: float)
```

数值到达上限时发出。

参数：

| 名称 | 说明 |
|---|---|
| `current_value` | 当前值。 |

## 属性

<a id="member-gfcombatgauge-properties-min_value"></a>

### `min_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var min_value: float:
```

数值下限。

<a id="member-gfcombatgauge-properties-max_value"></a>

### `max_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_value: float:
```

数值上限。

<a id="member-gfcombatgauge-properties-current_value"></a>

### `current_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var current_value: float:
```

当前数值。

<a id="member-gfcombatgauge-properties-accepted_action_kinds"></a>

### `accepted_action_kinds`

- API：`public`

```gdscript
var accepted_action_kinds: Array[StringName] = []
```

非空时，只接受这些动作类别。

<a id="member-gfcombatgauge-properties-rejected_action_kinds"></a>

### `rejected_action_kinds`

- API：`public`

```gdscript
var rejected_action_kinds: Array[StringName] = []
```

始终拒绝的动作类别。

<a id="member-gfcombatgauge-properties-modifiers"></a>

### `modifiers`

- API：`public`

```gdscript
var modifiers: Array[GFCombatActionModifier] = []
```

动作修正器。

<a id="member-gfcombatgauge-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义数值槽元数据；默认进入动作校验报告。

<a id="member-gfcombatgauge-properties-validation_callback"></a>

### `validation_callback`

- API：`public`

```gdscript
var validation_callback: Callable = Callable()
```

自定义校验回调，建议签名为 func(action: GFCombatAction, report: Dictionary) -> Variant。 返回 bool 可直接决定是否接受；返回 Dictionary 可覆盖 ok、reason、metadata 等报告字段。

## 方法

<a id="member-gfcombatgauge-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(p_min_value: float, p_max_value: float, p_current_value: float) -> void:
```

配置数值槽。

参数：

| 名称 | 说明 |
|---|---|
| `p_min_value` | 数值下限。 |
| `p_max_value` | 数值上限。 |
| `p_current_value` | 当前数值。 |

<a id="member-gfcombatgauge-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(value: float) -> void:
```

设置当前数值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新数值。 |

<a id="member-gfcombatgauge-methods-set_bounds"></a>

### `set_bounds`

- API：`public`

```gdscript
func set_bounds(p_min_value: float, p_max_value: float) -> void:
```

设置上下限并夹取当前值。

参数：

| 名称 | 说明 |
|---|---|
| `p_min_value` | 数值下限。 |
| `p_max_value` | 数值上限。 |

<a id="member-gfcombatgauge-methods-get_ratio"></a>

### `get_ratio`

- API：`public`

```gdscript
func get_ratio() -> float:
```

获取 0 到 1 的当前比例。

返回：当前比例。

<a id="member-gfcombatgauge-methods-can_receive_action_kind"></a>

### `can_receive_action_kind`

- API：`public`

```gdscript
func can_receive_action_kind(action_kind: StringName) -> bool:
```

检查动作类别是否可被当前数值槽接收。

参数：

| 名称 | 说明 |
|---|---|
| `action_kind` | 动作类别。 |

返回：可接收时返回 true。

<a id="member-gfcombatgauge-methods-add_modifier"></a>

### `add_modifier`

- API：`public`

```gdscript
func add_modifier(modifier: GFCombatActionModifier) -> void:
```

添加动作修正器。

参数：

| 名称 | 说明 |
|---|---|
| `modifier` | 修正器。 |

<a id="member-gfcombatgauge-methods-remove_modifier"></a>

### `remove_modifier`

- API：`public`

```gdscript
func remove_modifier(modifier: GFCombatActionModifier) -> void:
```

移除动作修正器。

参数：

| 名称 | 说明 |
|---|---|
| `modifier` | 修正器。 |

<a id="member-gfcombatgauge-methods-clear_modifiers"></a>

### `clear_modifiers`

- API：`public`

```gdscript
func clear_modifiers() -> void:
```

清空动作修正器。

<a id="member-gfcombatgauge-methods-apply_action"></a>

### `apply_action`

- API：`public`

```gdscript
func apply_action(action: GFCombatAction) -> GFCombatActionResult:
```

应用动作。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 原始动作。 |

返回：应用结果。
