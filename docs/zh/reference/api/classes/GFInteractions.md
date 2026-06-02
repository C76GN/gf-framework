# GFInteractions

[API Reference](../index.md) / [Interaction](../extensions-interaction.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/interaction/runtime/gf_interactions.gd`
- 模块：`Interaction`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

创建交互上下文与链式交互流程的静态入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`with_sender`](#member-gfinteractions-methods-with_sender) | `static func with_sender(sender: Object, architecture: GFArchitecture = null) -> GFInteractionFlow:` |
| 方法 | [`between`](#member-gfinteractions-methods-between) | `static func between( sender: Object, target: Object, payload: Variant = null, group_name: StringName = &"" ) -> GFInteractionContext:` |

## 方法

<a id="member-gfinteractions-methods-with_sender"></a>

### `with_sender`

- API：`public`

```gdscript
static func with_sender(sender: Object, architecture: GFArchitecture = null) -> GFInteractionFlow:
```

创建以 sender 为发起者的交互流程。

参数：

| 名称 | 说明 |
|---|---|
| `sender` | 交互发起者。 |
| `architecture` | 用于命令或事件派发的架构实例。 |

返回：新交互流程。

<a id="member-gfinteractions-methods-between"></a>

### `between`

- API：`public`

```gdscript
static func between( sender: Object, target: Object, payload: Variant = null, group_name: StringName = &"" ) -> GFInteractionContext:
```

创建一次 sender 到 target 的交互上下文。

参数：

| 名称 | 说明 |
|---|---|
| `sender` | 交互发起者。 |
| `target` | 交互目标对象。 |
| `payload` | 随事件或交互传递的数据。 |
| `group_name` | 项目自定义分组名称。 |

返回：新交互上下文。

结构：

- `payload`: 交互携带的任意项目载荷；框架只透传。
