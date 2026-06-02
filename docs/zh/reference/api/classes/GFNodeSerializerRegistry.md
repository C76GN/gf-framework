# GFNodeSerializerRegistry

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_serializer_registry.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

节点序列化器注册表。 负责按 serializer_id 管理序列化器，并为节点执行一组可组合的采集和应用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_serializer`](#member-gfnodeserializerregistry-methods-register_serializer) | `func register_serializer(serializer: GFNodeSerializer) -> void:` |
| 方法 | [`unregister_serializer`](#member-gfnodeserializerregistry-methods-unregister_serializer) | `func unregister_serializer(serializer_id: StringName) -> void:` |
| 方法 | [`clear`](#member-gfnodeserializerregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_serializer`](#member-gfnodeserializerregistry-methods-get_serializer) | `func get_serializer(serializer_id: StringName) -> GFNodeSerializer:` |
| 方法 | [`get_serializers_for_node`](#member-gfnodeserializerregistry-methods-get_serializers_for_node) | `func get_serializers_for_node(node: Node) -> Array[GFNodeSerializer]:` |
| 方法 | [`gather_node`](#member-gfnodeserializerregistry-methods-gather_node) | `func gather_node(node: Node, context: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`apply_node`](#member-gfnodeserializerregistry-methods-apply_node) | `func apply_node(node: Node, serializer_payloads: Array, context: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnodeserializerregistry-methods-register_serializer"></a>

### `register_serializer`

- API：`public`

```gdscript
func register_serializer(serializer: GFNodeSerializer) -> void:
```

注册序列化器。相同 id 会被后注册的实例覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `serializer` | 序列化器。 |

<a id="member-gfnodeserializerregistry-methods-unregister_serializer"></a>

### `unregister_serializer`

- API：`public`

```gdscript
func unregister_serializer(serializer_id: StringName) -> void:
```

注销序列化器。

参数：

| 名称 | 说明 |
|---|---|
| `serializer_id` | 序列化器标识。 |

<a id="member-gfnodeserializerregistry-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空注册表。

<a id="member-gfnodeserializerregistry-methods-get_serializer"></a>

### `get_serializer`

- API：`public`

```gdscript
func get_serializer(serializer_id: StringName) -> GFNodeSerializer:
```

获取指定序列化器。

参数：

| 名称 | 说明 |
|---|---|
| `serializer_id` | 序列化器标识。 |

返回：序列化器实例。

<a id="member-gfnodeserializerregistry-methods-get_serializers_for_node"></a>

### `get_serializers_for_node`

- API：`public`

```gdscript
func get_serializers_for_node(node: Node) -> Array[GFNodeSerializer]:
```

获取所有支持指定节点的序列化器。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |

返回：序列化器数组。

<a id="member-gfnodeserializerregistry-methods-gather_node"></a>

### `gather_node`

- API：`public`

```gdscript
func gather_node(node: Node, context: Dictionary = {}) -> Array[Dictionary]:
```

采集节点上所有支持的默认序列化器数据。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `context` | 调用上下文字典。 |

返回：序列化片段数组。

结构：

- `context`: Dictionary，传递给各序列化器的调用上下文，可包含项目自定义字段。
- `return`: Array[Dictionary]，每项包含 id: StringName 与 data: Dictionary。

<a id="member-gfnodeserializerregistry-methods-apply_node"></a>

### `apply_node`

- API：`public`

```gdscript
func apply_node(node: Node, serializer_payloads: Array, context: Dictionary = {}) -> Dictionary:
```

应用节点序列化片段。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `serializer_payloads` | 由 gather_node 返回的片段数组。 |
| `context` | 调用上下文字典。 |

返回：结果字典。

结构：

- `serializer_payloads`: Array[Dictionary]，每项包含 id: StringName 与 data: Dictionary。
- `context`: Dictionary，传递给各序列化器的调用上下文，可包含项目自定义字段。
- `return`: Dictionary，包含 ok: bool、applied: int 与 errors: Array[String]。
