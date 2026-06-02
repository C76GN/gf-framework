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
| 属性 | [`sender`](#member-gfinteractioncontext-properties-sender) | `var sender: Object = null` |
| 属性 | [`target`](#member-gfinteractioncontext-properties-target) | `var target: Object = null` |
| 属性 | [`payload`](#member-gfinteractioncontext-properties-payload) | `var payload: Variant = null` |
| 属性 | [`group_name`](#member-gfinteractioncontext-properties-group_name) | `var group_name: StringName = &""` |
| 方法 | [`with_sender`](#member-gfinteractioncontext-methods-with_sender) | `func with_sender(value: Object) -> GFInteractionContext:` |
| 方法 | [`with_target`](#member-gfinteractioncontext-methods-with_target) | `func with_target(value: Object) -> GFInteractionContext:` |
| 方法 | [`with_payload`](#member-gfinteractioncontext-methods-with_payload) | `func with_payload(value: Variant) -> GFInteractionContext:` |
| 方法 | [`with_group`](#member-gfinteractioncontext-methods-with_group) | `func with_group(value: StringName) -> GFInteractionContext:` |

## 属性

<a id="member-gfinteractioncontext-properties-sender"></a>

### `sender`

- API：`public`

```gdscript
var sender: Object = null
```

交互发起者。

<a id="member-gfinteractioncontext-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: Object = null
```

交互目标。

<a id="member-gfinteractioncontext-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

交互携带的数据。

结构：

- `payload`: 交互携带的任意项目载荷；框架只透传，不解释其中结构。

<a id="member-gfinteractioncontext-properties-group_name"></a>

### `group_name`

- API：`public`

```gdscript
var group_name: StringName = &""
```

交互所属的可选分组。

## 方法

<a id="member-gfinteractioncontext-methods-with_sender"></a>

### `with_sender`

- API：`public`

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

```gdscript
func with_group(value: StringName) -> GFInteractionContext:
```

设置 group_name 并返回自身，便于链式构造。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |

返回：当前上下文。
