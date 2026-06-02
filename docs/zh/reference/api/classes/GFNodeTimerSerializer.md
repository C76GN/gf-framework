# GFNodeTimerSerializer

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_timer_serializer.gd`
- 模块：`Save`
- 继承：`GFNodeSerializer`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

Timer 通用状态序列化器。 保存 Timer 的等待时间、暂停、一次性和当前剩余时间等通用状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`supports_node`](#member-gfnodetimerserializer-methods-supports_node) | `func supports_node(node: Node) -> bool:` |
| 方法 | [`gather`](#member-gfnodetimerserializer-methods-gather) | `func gather(node: Node, _context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply`](#member-gfnodetimerserializer-methods-apply) | `func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnodetimerserializer-methods-supports_node"></a>

### `supports_node`

- API：`public`

```gdscript
func supports_node(node: Node) -> bool:
```

判断序列化器是否支持指定节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |

返回：节点是否为 Timer。

<a id="member-gfnodetimerserializer-methods-gather"></a>

### `gather`

- API：`public`

```gdscript
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
```

采集节点的可保存状态。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `_context` | 操作上下文字典，默认实现不直接使用。 |

返回：Timer 状态载荷。

结构：

- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，可包含 wait_time、one_shot、autostart、paused、time_left 与 stopped。

<a id="member-gfnodetimerserializer-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
```

将序列化数据应用到节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `payload` | Timer 状态载荷。 |
| `_context` | 操作上下文字典，默认实现不直接使用。 |

返回：应用结果字典。

结构：

- `payload`: Dictionary，可包含 wait_time、one_shot、autostart、paused、time_left 与 stopped。
- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，包含 ok: bool 与 error: String。
