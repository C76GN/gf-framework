# GFNodePropertySerializer

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_property_serializer.gd`
- 模块：`Save`
- 继承：`GFNodeSerializer`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用节点属性序列化器。 通过显式属性白名单保存和恢复节点属性，适合项目层快速接入简单状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`properties`](#member-gfnodepropertyserializer-properties-properties) | `var properties: PackedStringArray = PackedStringArray()` |
| 属性 | [`skip_missing_properties`](#member-gfnodepropertyserializer-properties-skip_missing_properties) | `var skip_missing_properties: bool = true` |
| 方法 | [`gather`](#member-gfnodepropertyserializer-methods-gather) | `func gather(node: Node, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply`](#member-gfnodepropertyserializer-methods-apply) | `func apply(node: Node, payload: Dictionary, context: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfnodepropertyserializer-properties-properties"></a>

### `properties`

- API：`public`

```gdscript
var properties: PackedStringArray = PackedStringArray()
```

需要保存的属性名。

<a id="member-gfnodepropertyserializer-properties-skip_missing_properties"></a>

### `skip_missing_properties`

- API：`public`

```gdscript
var skip_missing_properties: bool = true
```

应用数据时遇到缺失属性是否跳过。

## 方法

<a id="member-gfnodepropertyserializer-methods-gather"></a>

### `gather`

- API：`public`

```gdscript
func gather(node: Node, context: Dictionary = {}) -> Dictionary:
```

采集节点的可保存状态。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `context` | 操作上下文字典。 |

返回：属性载荷字典。

结构：

- `context`: Dictionary，可包含 reference_root_node: Node，用于保存 Node 引用属性。
- `return`: Dictionary，键为 properties 中声明的属性名，值为 JSON 兼容值；Resource / Node 引用使用 __gf_reference__ 标记。

<a id="member-gfnodepropertyserializer-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply(node: Node, payload: Dictionary, context: Dictionary = {}) -> Dictionary:
```

将序列化数据应用到节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `payload` | 属性载荷字典。 |
| `context` | 操作上下文字典。 |

返回：应用结果字典。

结构：

- `payload`: Dictionary，键为属性名，值为 JSON 兼容值或 __gf_reference__ 标记。
- `context`: Dictionary，可包含 reference_root_node: Node，用于恢复 Node 引用属性。
- `return`: Dictionary，包含 ok: bool 与 error: String。
