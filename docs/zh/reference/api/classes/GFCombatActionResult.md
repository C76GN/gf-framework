# GFCombatActionResult

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/actions/gf_combat_action_result.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用战斗动作应用结果。 保存动作是否被接受、原始动作、最终动作、数值变化和元数据， 方便项目统一记录日志、派发事件或驱动反馈。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`ok`](#member-gfcombatactionresult-properties-ok) | `var ok: bool = false` |
| 属性 | [`reason`](#member-gfcombatactionresult-properties-reason) | `var reason: StringName = &""` |
| 属性 | [`original_action`](#member-gfcombatactionresult-properties-original_action) | `var original_action: GFCombatAction = null` |
| 属性 | [`action`](#member-gfcombatactionresult-properties-action) | `var action: GFCombatAction = null` |
| 属性 | [`previous_value`](#member-gfcombatactionresult-properties-previous_value) | `var previous_value: float = 0.0` |
| 属性 | [`current_value`](#member-gfcombatactionresult-properties-current_value) | `var current_value: float = 0.0` |
| 属性 | [`metadata`](#member-gfcombatactionresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`make_success`](#member-gfcombatactionresult-methods-make_success) | `static func make_success( p_original_action: GFCombatAction, p_action: GFCombatAction, p_previous_value: float, p_current_value: float, p_metadata: Dictionary = {} ) -> GFCombatActionResult:` |
| 方法 | [`make_failure`](#member-gfcombatactionresult-methods-make_failure) | `static func make_failure( p_reason: StringName, p_original_action: GFCombatAction = null, p_previous_value: float = 0.0, p_metadata: Dictionary = {} ) -> GFCombatActionResult:` |
| 方法 | [`to_dict`](#member-gfcombatactionresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`to_report_dictionary`](#member-gfcombatactionresult-methods-to_report_dictionary) | `func to_report_dictionary(options: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfcombatactionresult-properties-ok"></a>

### `ok`

- API：`public`

```gdscript
var ok: bool = false
```

是否成功应用。

<a id="member-gfcombatactionresult-properties-reason"></a>

### `reason`

- API：`public`

```gdscript
var reason: StringName = &""
```

结果原因。

<a id="member-gfcombatactionresult-properties-original_action"></a>

### `original_action`

- API：`public`

```gdscript
var original_action: GFCombatAction = null
```

原始动作副本。

<a id="member-gfcombatactionresult-properties-action"></a>

### `action`

- API：`public`

```gdscript
var action: GFCombatAction = null
```

最终动作副本。

<a id="member-gfcombatactionresult-properties-previous_value"></a>

### `previous_value`

- API：`public`

```gdscript
var previous_value: float = 0.0
```

应用前数值。

<a id="member-gfcombatactionresult-properties-current_value"></a>

### `current_value`

- API：`public`

```gdscript
var current_value: float = 0.0
```

应用后数值。

<a id="member-gfcombatactionresult-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义结果元数据；框架只复制并透传。

## 方法

<a id="member-gfcombatactionresult-methods-make_success"></a>

### `make_success`

- API：`public`

```gdscript
static func make_success( p_original_action: GFCombatAction, p_action: GFCombatAction, p_previous_value: float, p_current_value: float, p_metadata: Dictionary = {} ) -> GFCombatActionResult:
```

创建成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_original_action` | 原始动作。 |
| `p_action` | 最终动作。 |
| `p_previous_value` | 应用前数值。 |
| `p_current_value` | 应用后数值。 |
| `p_metadata` | 元数据。 |

返回：成功结果。

结构：

- `p_metadata`: Dictionary，项目自定义结果元数据；框架只复制并透传。

<a id="member-gfcombatactionresult-methods-make_failure"></a>

### `make_failure`

- API：`public`

```gdscript
static func make_failure( p_reason: StringName, p_original_action: GFCombatAction = null, p_previous_value: float = 0.0, p_metadata: Dictionary = {} ) -> GFCombatActionResult:
```

创建失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_reason` | 失败原因。 |
| `p_original_action` | 原始动作。 |
| `p_previous_value` | 当前数值。 |
| `p_metadata` | 元数据。 |

返回：失败结果。

结构：

- `p_metadata`: Dictionary，项目自定义结果元数据；框架只复制并透传。

<a id="member-gfcombatactionresult-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转为字典。

返回：字典快照。

结构：

- `return`: Dictionary，包含 ok、reason、original_action、action、previous_value、current_value、delta 和 metadata。

<a id="member-gfcombatactionresult-methods-to_report_dictionary"></a>

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
