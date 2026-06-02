# GFNodeControlSerializer

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_control_serializer.gd`
- 模块：`Save`
- 继承：`GFNodeSerializer`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

Control 通用布局状态序列化器。 保存 Control 的锚点、偏移、尺寸和交互开关，适合简单 UI 状态恢复。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`supports_node`](#member-gfnodecontrolserializer-methods-supports_node) | `func supports_node(node: Node) -> bool:` |
| 方法 | [`gather`](#member-gfnodecontrolserializer-methods-gather) | `func gather(node: Node, _context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply`](#member-gfnodecontrolserializer-methods-apply) | `func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnodecontrolserializer-methods-supports_node"></a>

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

返回：节点是否为 Control。

<a id="member-gfnodecontrolserializer-methods-gather"></a>

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

返回：Control 布局状态载荷。

结构：

- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，可包含 anchor_*、offset_*、pivot_offset、rotation、scale、mouse_filter 与 focus_mode。

<a id="member-gfnodecontrolserializer-methods-apply"></a>

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
| `payload` | Control 布局状态载荷。 |
| `_context` | 操作上下文字典，默认实现不直接使用。 |

返回：应用结果字典。

结构：

- `payload`: Dictionary，可包含 anchor_*、offset_*、pivot_offset、rotation、scale、mouse_filter 与 focus_mode。
- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，包含 ok: bool 与 error: String。
