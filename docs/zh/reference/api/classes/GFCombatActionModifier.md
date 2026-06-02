# GFCombatActionModifier

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/actions/gf_combat_action_modifier.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用战斗动作修正器。 按动作类别和标签过滤后，调整动作数值或操作。它不解释动作业务语义， 只负责把一个 GFCombatAction 转换为另一个 GFCombatAction。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`modifier_id`](#member-gfcombatactionmodifier-properties-modifier_id) | `var modifier_id: StringName = &""` |
| 属性 | [`accepted_action_kinds`](#member-gfcombatactionmodifier-properties-accepted_action_kinds) | `var accepted_action_kinds: Array[StringName] = []` |
| 属性 | [`rejected_action_kinds`](#member-gfcombatactionmodifier-properties-rejected_action_kinds) | `var rejected_action_kinds: Array[StringName] = []` |
| 属性 | [`required_tags`](#member-gfcombatactionmodifier-properties-required_tags) | `var required_tags: Array[StringName] = []` |
| 属性 | [`amount_add`](#member-gfcombatactionmodifier-properties-amount_add) | `var amount_add: float = 0.0` |
| 属性 | [`amount_multiplier`](#member-gfcombatactionmodifier-properties-amount_multiplier) | `var amount_multiplier: float = 1.0` |
| 属性 | [`override_operation`](#member-gfcombatactionmodifier-properties-override_operation) | `var override_operation: bool = false` |
| 属性 | [`operation`](#member-gfcombatactionmodifier-properties-operation) | `var operation: GFCombatAction.Operation = GFCombatAction.Operation.SUBTRACT` |
| 属性 | [`override_action_kind`](#member-gfcombatactionmodifier-properties-override_action_kind) | `var override_action_kind: bool = false` |
| 属性 | [`action_kind`](#member-gfcombatactionmodifier-properties-action_kind) | `var action_kind: StringName = &""` |
| 属性 | [`metadata`](#member-gfcombatactionmodifier-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`matches`](#member-gfcombatactionmodifier-methods-matches) | `func matches(action: GFCombatAction) -> bool:` |
| 方法 | [`apply`](#member-gfcombatactionmodifier-methods-apply) | `func apply(action: GFCombatAction) -> GFCombatAction:` |
| 方法 | [`duplicate_modifier`](#member-gfcombatactionmodifier-methods-duplicate_modifier) | `func duplicate_modifier() -> GFCombatActionModifier:` |

## 属性

<a id="member-gfcombatactionmodifier-properties-modifier_id"></a>

### `modifier_id`

- API：`public`

```gdscript
var modifier_id: StringName = &""
```

修正器标识。

<a id="member-gfcombatactionmodifier-properties-accepted_action_kinds"></a>

### `accepted_action_kinds`

- API：`public`

```gdscript
var accepted_action_kinds: Array[StringName] = []
```

非空时，只匹配这些动作类别。

<a id="member-gfcombatactionmodifier-properties-rejected_action_kinds"></a>

### `rejected_action_kinds`

- API：`public`

```gdscript
var rejected_action_kinds: Array[StringName] = []
```

始终拒绝匹配的动作类别。

<a id="member-gfcombatactionmodifier-properties-required_tags"></a>

### `required_tags`

- API：`public`

```gdscript
var required_tags: Array[StringName] = []
```

非空时，动作必须包含这些标签。

<a id="member-gfcombatactionmodifier-properties-amount_add"></a>

### `amount_add`

- API：`public`

```gdscript
var amount_add: float = 0.0
```

数值加成。

<a id="member-gfcombatactionmodifier-properties-amount_multiplier"></a>

### `amount_multiplier`

- API：`public`

```gdscript
var amount_multiplier: float = 1.0
```

数值乘区。

<a id="member-gfcombatactionmodifier-properties-override_operation"></a>

### `override_operation`

- API：`public`

```gdscript
var override_operation: bool = false
```

是否覆盖动作操作。

<a id="member-gfcombatactionmodifier-properties-operation"></a>

### `operation`

- API：`public`

```gdscript
var operation: GFCombatAction.Operation = GFCombatAction.Operation.SUBTRACT
```

覆盖后的动作操作。

<a id="member-gfcombatactionmodifier-properties-override_action_kind"></a>

### `override_action_kind`

- API：`public`

```gdscript
var override_action_kind: bool = false
```

是否覆盖动作类别。

<a id="member-gfcombatactionmodifier-properties-action_kind"></a>

### `action_kind`

- API：`public`

```gdscript
var action_kind: StringName = &""
```

覆盖后的动作类别。

<a id="member-gfcombatactionmodifier-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

修正器元数据。

结构：

- `metadata`: Dictionary，项目自定义元数据；应用修正器时复制到动作结果的 modifiers 记录中。

## 方法

<a id="member-gfcombatactionmodifier-methods-matches"></a>

### `matches`

- API：`public`

```gdscript
func matches(action: GFCombatAction) -> bool:
```

检查修正器是否匹配动作。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 原始动作。 |

返回：匹配时返回 true。

<a id="member-gfcombatactionmodifier-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply(action: GFCombatAction) -> GFCombatAction:
```

应用修正器。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 原始动作。 |

返回：修正后的动作副本。

<a id="member-gfcombatactionmodifier-methods-duplicate_modifier"></a>

### `duplicate_modifier`

- API：`public`

```gdscript
func duplicate_modifier() -> GFCombatActionModifier:
```

复制修正器。

返回：新修正器。
