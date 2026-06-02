# GFInteractionFlow

[API Reference](../index.md) / [Interaction](../extensions-interaction.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/interaction/runtime/gf_interaction_flow.gd`
- 模块：`Interaction`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

基于 GFInteractionContext 的链式交互辅助对象。 保持上下文传递与命令执行的显式类型边界，适合一次性组织交互流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`context`](#member-gfinteractionflow-properties-context) | `var context: GFInteractionContext` |
| 方法 | [`to`](#member-gfinteractionflow-methods-to) | `func to(target: Object) -> GFInteractionFlow:` |
| 方法 | [`with_payload`](#member-gfinteractionflow-methods-with_payload) | `func with_payload(payload: Variant) -> GFInteractionFlow:` |
| 方法 | [`in_group`](#member-gfinteractionflow-methods-in_group) | `func in_group(group_name: StringName) -> GFInteractionFlow:` |
| 方法 | [`execute`](#member-gfinteractionflow-methods-execute) | `func execute(command: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfinteractionflow-methods-send_event) | `func send_event(event_instance: Object) -> void:` |

## 属性

<a id="member-gfinteractionflow-properties-context"></a>

### `context`

- API：`public`

```gdscript
var context: GFInteractionContext
```

当前交互上下文。

## 方法

<a id="member-gfinteractionflow-methods-to"></a>

### `to`

- API：`public`

```gdscript
func to(target: Object) -> GFInteractionFlow:
```

设置交互目标。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 交互目标对象。 |

返回：当前交互流程。

<a id="member-gfinteractionflow-methods-with_payload"></a>

### `with_payload`

- API：`public`

```gdscript
func with_payload(payload: Variant) -> GFInteractionFlow:
```

设置交互 payload。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 随事件或交互传递的数据。 |

返回：当前交互流程。

结构：

- `payload`: 交互携带的任意项目载荷；框架只透传。

<a id="member-gfinteractionflow-methods-in_group"></a>

### `in_group`

- API：`public`

```gdscript
func in_group(group_name: StringName) -> GFInteractionFlow:
```

设置交互分组。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 项目自定义分组名称。 |

返回：当前交互流程。

<a id="member-gfinteractionflow-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute(command: Object) -> Variant:
```

执行命令。命令可通过 interaction_context 属性或 set_interaction_context(context) 接收上下文。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要执行的命令实例。 |

返回：命令执行结果。

结构：

- `return`: GFArchitecture.send_command() 或 command.execute() 返回的任意项目结果；缺少命令时返回 null。

<a id="member-gfinteractionflow-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

发送事件。事件可通过 interaction_context 属性或 set_interaction_context(context) 接收上下文。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要派发的事件实例。 |
