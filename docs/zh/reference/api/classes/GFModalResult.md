# GFModalResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_modal_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用 modal 交互结果。 只描述用户选择、附加载荷和调用上下文，不解释业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_CONFIRMED`](#member-gfmodalresult-constants-status_confirmed) | `const STATUS_CONFIRMED: StringName = &"confirmed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfmodalresult-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_DISMISSED`](#member-gfmodalresult-constants-status_dismissed) | `const STATUS_DISMISSED: StringName = &"dismissed"` |
| 属性 | [`status`](#member-gfmodalresult-properties-status) | `var status: StringName = STATUS_DISMISSED` |
| 属性 | [`action_id`](#member-gfmodalresult-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`payload`](#member-gfmodalresult-properties-payload) | `var payload: Variant = null` |
| 属性 | [`metadata`](#member-gfmodalresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`context`](#member-gfmodalresult-properties-context) | `var context: Dictionary = {}` |
| 方法 | [`create`](#member-gfmodalresult-methods-create) | `static func create( result_status: StringName, result_action_id: StringName = &"", result_payload: Variant = null, result_metadata: Dictionary = {}, result_context: Dictionary = {} ) -> GFModalResult:` |
| 方法 | [`to_dict`](#member-gfmodalresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfmodalresult-constants-status_confirmed"></a>

### `STATUS_CONFIRMED`

- API：`public`

```gdscript
const STATUS_CONFIRMED: StringName = &"confirmed"
```

表示肯定或主要操作。

<a id="member-gfmodalresult-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

表示取消、返回或关闭。

<a id="member-gfmodalresult-constants-status_dismissed"></a>

### `STATUS_DISMISSED`

- API：`public`

```gdscript
const STATUS_DISMISSED: StringName = &"dismissed"
```

表示中性关闭。

## 属性

<a id="member-gfmodalresult-properties-status"></a>

### `status`

- API：`public`

```gdscript
var status: StringName = STATUS_DISMISSED
```

结果状态。

<a id="member-gfmodalresult-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

触发该结果的动作 ID。

<a id="member-gfmodalresult-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

动作携带的通用载荷。

结构：

- `payload`: Variant，项目自定义动作载荷。

<a id="member-gfmodalresult-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

结果元数据。

结构：

- `metadata`: Dictionary，结果附带的项目侧元数据。

<a id="member-gfmodalresult-properties-context"></a>

### `context`

- API：`public`

```gdscript
var context: Dictionary = {}
```

打开 modal 时传入的调用上下文。

结构：

- `context`: Dictionary，打开 modal 时传入的调用上下文。

## 方法

<a id="member-gfmodalresult-methods-create"></a>

### `create`

- API：`public`

```gdscript
static func create( result_status: StringName, result_action_id: StringName = &"", result_payload: Variant = null, result_metadata: Dictionary = {}, result_context: Dictionary = {} ) -> GFModalResult:
```

创建结果实例。

参数：

| 名称 | 说明 |
|---|---|
| `result_status` | 结果状态。 |
| `result_action_id` | 触发动作 ID。 |
| `result_payload` | 动作载荷。 |
| `result_metadata` | 结果元数据。 |
| `result_context` | 调用上下文。 |

返回：新结果实例。

结构：

- `result_payload`: Variant，项目自定义动作载荷。
- `result_metadata`: Dictionary，结果附带的项目侧元数据。
- `result_context`: Dictionary，打开 modal 时传入的调用上下文。

<a id="member-gfmodalresult-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

导出为字典。

返回：结果字典。

结构：

- `return`: Dictionary，包含 status、action_id、payload、metadata 和 context。
