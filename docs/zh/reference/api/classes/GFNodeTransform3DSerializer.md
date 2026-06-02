# GFNodeTransform3DSerializer

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_transform_3d_serializer.gd`
- 模块：`Save`
- 继承：`GFNodeSerializer`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

Node3D Transform 序列化器。 以 JSON 友好的标量数组保存 position、rotation 与 scale。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`supports_node`](#member-gfnodetransform3dserializer-methods-supports_node) | `func supports_node(node: Node) -> bool:` |
| 方法 | [`gather`](#member-gfnodetransform3dserializer-methods-gather) | `func gather(node: Node, _context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply`](#member-gfnodetransform3dserializer-methods-apply) | `func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnodetransform3dserializer-methods-supports_node"></a>

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

返回：节点是否为 Node3D。

<a id="member-gfnodetransform3dserializer-methods-gather"></a>

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

返回：Node3D transform 载荷。

结构：

- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，可包含 position: Array[float]、rotation: Array[float] 与 scale: Array[float]。

<a id="member-gfnodetransform3dserializer-methods-apply"></a>

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
| `payload` | Node3D transform 载荷。 |
| `_context` | 操作上下文字典，默认实现不直接使用。 |

返回：应用结果字典。

结构：

- `payload`: Dictionary，可包含 position: Array[float]、rotation: Array[float] 与 scale: Array[float]。
- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，包含 ok: bool 与 error: String。
