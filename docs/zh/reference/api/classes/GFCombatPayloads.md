# GFCombatPayloads

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/core/gf_combat_payloads.gd`
- 模块：`Combat`
- 继承：`Node`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

存放战斗相关的事件载体类。

## 成员概览

此类不声明额外公开成员。

## 内部类概览

| 内部类 | 类别 | 继承 | 成员 |
|---|---|---|---:|
| [`GFCombatPayloads.GFBuffAppliedPayload`](#gfcombatpayloadsgfbuffappliedpayload) | 事件契约 (`event_contract`) | `GFPayload` | 2 |
| [`GFCombatPayloads.GFBuffRefreshedPayload`](#gfcombatpayloadsgfbuffrefreshedpayload) | 事件契约 (`event_contract`) | `GFPayload` | 2 |
| [`GFCombatPayloads.GFBuffRemovedPayload`](#gfcombatpayloadsgfbuffremovedpayload) | 事件契约 (`event_contract`) | `GFPayload` | 2 |

## 内部类详情

### GFCombatPayloads.GFBuffAppliedPayload

- 路径：`addons/gf/extensions/combat/core/gf_combat_payloads.gd`
- 模块：`Combat`
- 继承：`GFPayload`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

Buff 已应用事件。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target`](#member-gfcombatpayloads-gfbuffappliedpayload-properties-target) | `var target: Object` |
| 属性 | [`buff`](#member-gfcombatpayloads-gfbuffappliedpayload-properties-buff) | `var buff: GFBuff` |

#### 属性

<a id="member-gfcombatpayloads-gfbuffappliedpayload-properties-target"></a>

##### `target`

- API：`public`

```gdscript
var target: Object
```

目标对象。

<a id="member-gfcombatpayloads-gfbuffappliedpayload-properties-buff"></a>

##### `buff`

- API：`public`

```gdscript
var buff: GFBuff
```

已应用的 Buff 实例。

### GFCombatPayloads.GFBuffRefreshedPayload

- 路径：`addons/gf/extensions/combat/core/gf_combat_payloads.gd`
- 模块：`Combat`
- 继承：`GFPayload`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

Buff 已变动/刷新事件。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target`](#member-gfcombatpayloads-gfbuffrefreshedpayload-properties-target) | `var target: Object` |
| 属性 | [`buff`](#member-gfcombatpayloads-gfbuffrefreshedpayload-properties-buff) | `var buff: GFBuff` |

#### 属性

<a id="member-gfcombatpayloads-gfbuffrefreshedpayload-properties-target"></a>

##### `target`

- API：`public`

```gdscript
var target: Object
```

目标对象。

<a id="member-gfcombatpayloads-gfbuffrefreshedpayload-properties-buff"></a>

##### `buff`

- API：`public`

```gdscript
var buff: GFBuff
```

已刷新的 Buff 实例。

### GFCombatPayloads.GFBuffRemovedPayload

- 路径：`addons/gf/extensions/combat/core/gf_combat_payloads.gd`
- 模块：`Combat`
- 继承：`GFPayload`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

Buff 已移除事件。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target`](#member-gfcombatpayloads-gfbuffremovedpayload-properties-target) | `var target: Object` |
| 属性 | [`buff_id`](#member-gfcombatpayloads-gfbuffremovedpayload-properties-buff_id) | `var buff_id: StringName` |

#### 属性

<a id="member-gfcombatpayloads-gfbuffremovedpayload-properties-target"></a>

##### `target`

- API：`public`

```gdscript
var target: Object
```

目标对象。

<a id="member-gfcombatpayloads-gfbuffremovedpayload-properties-buff_id"></a>

##### `buff_id`

- API：`public`

```gdscript
var buff_id: StringName
```

被移除的 Buff ID。
