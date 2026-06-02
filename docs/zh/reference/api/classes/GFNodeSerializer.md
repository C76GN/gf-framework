# GFNodeSerializer

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_serializer.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

节点序列化器基类。 用于把通用节点状态拆成可组合的序列化片段。具体项目可以继承该类， 在不修改存档图编排逻辑的前提下接入自己的节点状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`serializer_id`](#member-gfnodeserializer-properties-serializer_id) | `var serializer_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfnodeserializer-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`supported_class_name`](#member-gfnodeserializer-properties-supported_class_name) | `var supported_class_name: String = ""` |
| 方法 | [`get_serializer_id`](#member-gfnodeserializer-methods-get_serializer_id) | `func get_serializer_id() -> StringName:` |
| 方法 | [`supports_node`](#member-gfnodeserializer-methods-supports_node) | `func supports_node(node: Node) -> bool:` |
| 方法 | [`gather`](#member-gfnodeserializer-methods-gather) | `func gather(_node: Node, _context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply`](#member-gfnodeserializer-methods-apply) | `func apply(_node: Node, _payload: Dictionary, _context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_result`](#member-gfnodeserializer-methods-make_result) | `func make_result(ok: bool, error: String = "") -> Dictionary:` |

## 属性

<a id="member-gfnodeserializer-properties-serializer_id"></a>

### `serializer_id`

- API：`public`

```gdscript
var serializer_id: StringName = &""
```

序列化器稳定标识。

<a id="member-gfnodeserializer-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器展示名称。

<a id="member-gfnodeserializer-properties-supported_class_name"></a>

### `supported_class_name`

- API：`public`

```gdscript
var supported_class_name: String = ""
```

可选 Godot 类名过滤。为空时由子类自行判断。

## 方法

<a id="member-gfnodeserializer-methods-get_serializer_id"></a>

### `get_serializer_id`

- API：`public`

```gdscript
func get_serializer_id() -> StringName:
```

获取序列化器标识。

返回：稳定标识。

<a id="member-gfnodeserializer-methods-supports_node"></a>

### `supports_node`

- API：`public`

```gdscript
func supports_node(node: Node) -> bool:
```

判断当前序列化器是否支持节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 待序列化节点。 |

返回：支持时返回 true。

<a id="member-gfnodeserializer-methods-gather"></a>

### `gather`

- API：`public`

```gdscript
func gather(_node: Node, _context: Dictionary = {}) -> Dictionary:
```

采集节点数据。

参数：

| 名称 | 说明 |
|---|---|
| `_node` | 待序列化节点。 |
| `_context` | 调用上下文字典。 |

返回：可写入存档的字典。

结构：

- `_context`: Dictionary，调用方附加上下文；基础实现保留给子类扩展。
- `return`: Dictionary，当前序列化器写入存档的字段集合；空字典表示无需保存。

<a id="member-gfnodeserializer-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply(_node: Node, _payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
```

应用节点数据。

参数：

| 名称 | 说明 |
|---|---|
| `_node` | 目标节点。 |
| `_payload` | 当前序列化器的数据。 |
| `_context` | 调用上下文字典。 |

返回：结果字典。

结构：

- `_payload`: Dictionary，来自 gather() 的当前序列化器数据。
- `_context`: Dictionary，调用方附加上下文；基础实现保留给子类扩展。
- `return`: Dictionary，包含 ok: bool 与 error: String。

<a id="member-gfnodeserializer-methods-make_result"></a>

### `make_result`

- API：`public`

```gdscript
func make_result(ok: bool, error: String = "") -> Dictionary:
```

构造统一结果。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 是否成功。 |
| `error` | 错误描述。 |

返回：结果字典。

结构：

- `return`: Dictionary，包含 ok: bool 与 error: String。
