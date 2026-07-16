# GFInteractionContext

[API Reference](../index.md) / [Interaction](../extensions-interaction.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/interaction/runtime/gf_interaction_context.gd`
- 模块：`Interaction`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

一次交互流程的轻量上下文。 用于在 Command、事件或项目自定义方法之间传递 sender、target、payload 与可选分组信息。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`sender`](#member-gfinteractioncontext-properties-sender) | `var sender: Object:` |
| 属性 | [`target`](#member-gfinteractioncontext-properties-target) | `var target: Object:` |
| 属性 | [`sender_instance_id`](#member-gfinteractioncontext-properties-sender_instance_id) | `var sender_instance_id: int = 0` |
| 属性 | [`target_instance_id`](#member-gfinteractioncontext-properties-target_instance_id) | `var target_instance_id: int = 0` |
| 属性 | [`sender_path`](#member-gfinteractioncontext-properties-sender_path) | `var sender_path: NodePath = NodePath("")` |
| 属性 | [`target_path`](#member-gfinteractioncontext-properties-target_path) | `var target_path: NodePath = NodePath("")` |
| 属性 | [`sender_class`](#member-gfinteractioncontext-properties-sender_class) | `var sender_class: String = ""` |
| 属性 | [`target_class`](#member-gfinteractioncontext-properties-target_class) | `var target_class: String = ""` |
| 属性 | [`payload`](#member-gfinteractioncontext-properties-payload) | `var payload: Variant = null` |
| 属性 | [`group_name`](#member-gfinteractioncontext-properties-group_name) | `var group_name: StringName = &""` |
| 方法 | [`with_sender`](#member-gfinteractioncontext-methods-with_sender) | `func with_sender(value: Object) -> GFInteractionContext:` |
| 方法 | [`with_target`](#member-gfinteractioncontext-methods-with_target) | `func with_target(value: Object) -> GFInteractionContext:` |
| 方法 | [`with_payload`](#member-gfinteractioncontext-methods-with_payload) | `func with_payload(value: Variant) -> GFInteractionContext:` |
| 方法 | [`with_group`](#member-gfinteractioncontext-methods-with_group) | `func with_group(value: StringName) -> GFInteractionContext:` |
| 方法 | [`get_sender_or_null`](#member-gfinteractioncontext-methods-get_sender_or_null) | `func get_sender_or_null() -> Object:` |
| 方法 | [`get_target_or_null`](#member-gfinteractioncontext-methods-get_target_or_null) | `func get_target_or_null() -> Object:` |

## 属性

<a id="member-gfinteractioncontext-properties-sender"></a>

### `sender`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var sender: Object:
```

交互发起者。

<a id="member-gfinteractioncontext-properties-target"></a>

### `target`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target: Object:
```

交互目标。

<a id="member-gfinteractioncontext-properties-sender_instance_id"></a>

### `sender_instance_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var sender_instance_id: int = 0
```

交互发起者实例 ID 快照。

<a id="member-gfinteractioncontext-properties-target_instance_id"></a>

### `target_instance_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_instance_id: int = 0
```

交互目标实例 ID 快照。

<a id="member-gfinteractioncontext-properties-sender_path"></a>

### `sender_path`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var sender_path: NodePath = NodePath("")
```

交互发起者节点路径快照。

<a id="member-gfinteractioncontext-properties-target_path"></a>

### `target_path`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_path: NodePath = NodePath("")
```

交互目标节点路径快照。

<a id="member-gfinteractioncontext-properties-sender_class"></a>

### `sender_class`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var sender_class: String = ""
```

交互发起者类名快照。

<a id="member-gfinteractioncontext-properties-target_class"></a>

### `target_class`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_class: String = ""
```

交互目标类名快照。

<a id="member-gfinteractioncontext-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var payload: Variant = null
```

交互携带的数据。

结构：

- `payload`: 交互携带的任意项目载荷；框架只透传，不解释其中结构。

<a id="member-gfinteractioncontext-properties-group_name"></a>

### `group_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var group_name: StringName = &""
```

交互所属的可选分组。

## 方法

<a id="member-gfinteractioncontext-methods-with_sender"></a>

### `with_sender`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func with_sender(value: Object) -> GFInteractionContext:
```

设置 sender 并返回自身，便于链式构造。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |

返回：当前上下文。

<a id="member-gfinteractioncontext-methods-with_target"></a>

### `with_target`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func with_target(value: Object) -> GFInteractionContext:
```

设置 target 并返回自身，便于链式构造。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |

返回：当前上下文。

<a id="member-gfinteractioncontext-methods-with_payload"></a>

### `with_payload`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func with_payload(value: Variant) -> GFInteractionContext:
```

设置 payload 并返回自身，便于链式构造。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |

返回：当前上下文。

结构：

- `value`: 要写入 payload 的任意项目载荷。

<a id="member-gfinteractioncontext-methods-with_group"></a>

### `with_group`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func with_group(value: StringName) -> GFInteractionContext:
```

设置 group_name 并返回自身，便于链式构造。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |

返回：当前上下文。

<a id="member-gfinteractioncontext-methods-get_sender_or_null"></a>

### `get_sender_or_null`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_sender_or_null() -> Object:
```

获取当前 sender；对象已释放时返回 null。

返回：当前 sender 或 null。

<a id="member-gfinteractioncontext-methods-get_target_or_null"></a>

### `get_target_or_null`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_target_or_null() -> Object:
```

获取当前 target；对象已释放时返回 null。

返回：当前 target 或 null。
