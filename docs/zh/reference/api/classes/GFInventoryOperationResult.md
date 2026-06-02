# GFInventoryOperationResult

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_operation_result.gd`
- 模块：`Domain`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用库存操作结果。 描述一次添加、移除、移动或合并操作的接受数量、剩余数量和失败原因。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`ok`](#member-gfinventoryoperationresult-properties-ok) | `var ok: bool = false` |
| 属性 | [`item_id`](#member-gfinventoryoperationresult-properties-item_id) | `var item_id: StringName = &""` |
| 属性 | [`requested_amount`](#member-gfinventoryoperationresult-properties-requested_amount) | `var requested_amount: int = 0` |
| 属性 | [`accepted_amount`](#member-gfinventoryoperationresult-properties-accepted_amount) | `var accepted_amount: int = 0` |
| 属性 | [`remaining_amount`](#member-gfinventoryoperationresult-properties-remaining_amount) | `var remaining_amount: int = 0` |
| 属性 | [`source_slot`](#member-gfinventoryoperationresult-properties-source_slot) | `var source_slot: int = -1` |
| 属性 | [`target_slot`](#member-gfinventoryoperationresult-properties-target_slot) | `var target_slot: int = -1` |
| 属性 | [`reason`](#member-gfinventoryoperationresult-properties-reason) | `var reason: StringName = &""` |
| 属性 | [`metadata`](#member-gfinventoryoperationresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`success`](#member-gfinventoryoperationresult-methods-success) | `static func success( result_item_id: StringName, amount: int, result_source_slot: int = -1, result_target_slot: int = -1 ) -> GFInventoryOperationResult:` |
| 方法 | [`partial`](#member-gfinventoryoperationresult-methods-partial) | `static func partial( result_item_id: StringName, requested: int, accepted: int, result_reason: StringName, result_source_slot: int = -1, result_target_slot: int = -1 ) -> GFInventoryOperationResult:` |
| 方法 | [`is_partial_success`](#member-gfinventoryoperationresult-methods-is_partial_success) | `func is_partial_success() -> bool:` |
| 方法 | [`to_dict`](#member-gfinventoryoperationresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 属性

<a id="member-gfinventoryoperationresult-properties-ok"></a>

### `ok`

- API：`public`

```gdscript
var ok: bool = false
```

操作是否完全成功。

<a id="member-gfinventoryoperationresult-properties-item_id"></a>

### `item_id`

- API：`public`

```gdscript
var item_id: StringName = &""
```

物品标识。

<a id="member-gfinventoryoperationresult-properties-requested_amount"></a>

### `requested_amount`

- API：`public`

```gdscript
var requested_amount: int = 0
```

请求处理的数量。

<a id="member-gfinventoryoperationresult-properties-accepted_amount"></a>

### `accepted_amount`

- API：`public`

```gdscript
var accepted_amount: int = 0
```

实际处理的数量。

<a id="member-gfinventoryoperationresult-properties-remaining_amount"></a>

### `remaining_amount`

- API：`public`

```gdscript
var remaining_amount: int = 0
```

未处理的剩余数量。

<a id="member-gfinventoryoperationresult-properties-source_slot"></a>

### `source_slot`

- API：`public`

```gdscript
var source_slot: int = -1
```

源槽位。没有源槽位时为 -1。

<a id="member-gfinventoryoperationresult-properties-target_slot"></a>

### `target_slot`

- API：`public`

```gdscript
var target_slot: int = -1
```

目标槽位。没有目标槽位时为 -1。

<a id="member-gfinventoryoperationresult-properties-reason"></a>

### `reason`

- API：`public`

```gdscript
var reason: StringName = &""
```

操作结果原因。

<a id="member-gfinventoryoperationresult-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义操作结果元数据；GF 会在 to_dict() 中复制输出。

## 方法

<a id="member-gfinventoryoperationresult-methods-success"></a>

### `success`

- API：`public`

```gdscript
static func success( result_item_id: StringName, amount: int, result_source_slot: int = -1, result_target_slot: int = -1 ) -> GFInventoryOperationResult:
```

创建成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `result_item_id` | 物品标识。 |
| `amount` | 处理数量。 |
| `result_source_slot` | 源槽位。 |
| `result_target_slot` | 目标槽位。 |

返回：操作结果。

<a id="member-gfinventoryoperationresult-methods-partial"></a>

### `partial`

- API：`public`

```gdscript
static func partial( result_item_id: StringName, requested: int, accepted: int, result_reason: StringName, result_source_slot: int = -1, result_target_slot: int = -1 ) -> GFInventoryOperationResult:
```

创建失败或部分成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `result_item_id` | 物品标识。 |
| `requested` | 请求数量。 |
| `accepted` | 实际处理数量。 |
| `result_reason` | 操作结果原因。 |
| `result_source_slot` | 源槽位。 |
| `result_target_slot` | 目标槽位。 |

返回：操作结果。

<a id="member-gfinventoryoperationresult-methods-is_partial_success"></a>

### `is_partial_success`

- API：`public`

```gdscript
func is_partial_success() -> bool:
```

检查操作是否处理了部分数量。

返回：有部分处理返回 true。

<a id="member-gfinventoryoperationresult-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：操作结果字典。

结构：

- `return`: Dictionary，包含 ok、item_id、requested_amount、accepted_amount、remaining_amount、source_slot、target_slot、reason 与 metadata。
