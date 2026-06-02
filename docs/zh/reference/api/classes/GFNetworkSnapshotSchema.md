# GFNetworkSnapshotSchema

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/snapshot/gf_network_snapshot_schema.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

网络快照字段编码表。 用字段级编码器转换快照 state，适合项目在自己的同步、回放或存储流程中 统一压缩、量化和恢复状态字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`include_unregistered_fields`](#member-gfnetworksnapshotschema-properties-include_unregistered_fields) | `var include_unregistered_fields: bool = true` |
| 属性 | [`field_serializers`](#member-gfnetworksnapshotschema-properties-field_serializers) | `var field_serializers: Dictionary = {}` |
| 方法 | [`set_field_serializer`](#member-gfnetworksnapshotschema-methods-set_field_serializer) | `func set_field_serializer(field_name: StringName, serializer: GFNetworkFieldSerializer) -> void:` |
| 方法 | [`remove_field_serializer`](#member-gfnetworksnapshotschema-methods-remove_field_serializer) | `func remove_field_serializer(field_name: StringName) -> void:` |
| 方法 | [`get_field_serializer`](#member-gfnetworksnapshotschema-methods-get_field_serializer) | `func get_field_serializer(field_name: StringName) -> GFNetworkFieldSerializer:` |
| 方法 | [`has_field_serializer`](#member-gfnetworksnapshotschema-methods-has_field_serializer) | `func has_field_serializer(field_name: StringName) -> bool:` |
| 方法 | [`get_registered_fields`](#member-gfnetworksnapshotschema-methods-get_registered_fields) | `func get_registered_fields() -> PackedStringArray:` |
| 方法 | [`encode_state`](#member-gfnetworksnapshotschema-methods-encode_state) | `func encode_state(state: Dictionary) -> Dictionary:` |
| 方法 | [`decode_state`](#member-gfnetworksnapshotschema-methods-decode_state) | `func decode_state(encoded_state: Dictionary) -> Dictionary:` |
| 方法 | [`encode_snapshot`](#member-gfnetworksnapshotschema-methods-encode_snapshot) | `func encode_snapshot(snapshot: GFNetworkSnapshot) -> Dictionary:` |
| 方法 | [`decode_snapshot`](#member-gfnetworksnapshotschema-methods-decode_snapshot) | `func decode_snapshot(data: Dictionary) -> GFNetworkSnapshot:` |
| 方法 | [`encode_patch`](#member-gfnetworksnapshotschema-methods-encode_patch) | `func encode_patch(patch: Dictionary) -> Dictionary:` |
| 方法 | [`decode_patch`](#member-gfnetworksnapshotschema-methods-decode_patch) | `func decode_patch(encoded_patch: Dictionary) -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfnetworksnapshotschema-methods-duplicate_schema) | `func duplicate_schema() -> GFNetworkSnapshotSchema:` |

## 属性

<a id="member-gfnetworksnapshotschema-properties-include_unregistered_fields"></a>

### `include_unregistered_fields`

- API：`public`

```gdscript
var include_unregistered_fields: bool = true
```

未注册字段是否原样保留。

<a id="member-gfnetworksnapshotschema-properties-field_serializers"></a>

### `field_serializers`

- API：`public`

```gdscript
var field_serializers: Dictionary = {}
```

字段编码器表。Key 推荐使用 StringName 或 String，Value 为 GFNetworkFieldSerializer。

结构：

- `field_serializers`: Dictionary[StringName|String, GFNetworkFieldSerializer]，字段名到字段编码器的映射。

## 方法

<a id="member-gfnetworksnapshotschema-methods-set_field_serializer"></a>

### `set_field_serializer`

- API：`public`

```gdscript
func set_field_serializer(field_name: StringName, serializer: GFNetworkFieldSerializer) -> void:
```

设置字段编码器。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |
| `serializer` | 字段编码器；为空时移除。 |

<a id="member-gfnetworksnapshotschema-methods-remove_field_serializer"></a>

### `remove_field_serializer`

- API：`public`

```gdscript
func remove_field_serializer(field_name: StringName) -> void:
```

移除字段编码器。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

<a id="member-gfnetworksnapshotschema-methods-get_field_serializer"></a>

### `get_field_serializer`

- API：`public`

```gdscript
func get_field_serializer(field_name: StringName) -> GFNetworkFieldSerializer:
```

获取字段编码器。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

返回：字段编码器；不存在时返回 null。

<a id="member-gfnetworksnapshotschema-methods-has_field_serializer"></a>

### `has_field_serializer`

- API：`public`

```gdscript
func has_field_serializer(field_name: StringName) -> bool:
```

检查字段是否注册了编码器。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

返回：已注册时返回 true。

<a id="member-gfnetworksnapshotschema-methods-get_registered_fields"></a>

### `get_registered_fields`

- API：`public`

```gdscript
func get_registered_fields() -> PackedStringArray:
```

获取已注册字段名。

返回：字段名列表。

<a id="member-gfnetworksnapshotschema-methods-encode_state"></a>

### `encode_state`

- API：`public`

```gdscript
func encode_state(state: Dictionary) -> Dictionary:
```

编码状态字典。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 原始状态。 |

返回：编码后的状态。

结构：

- `state`: Dictionary[StringName|String, Variant]，原始快照状态字段。
- `return`: Dictionary[StringName|String, Variant]，编码后的状态字段。

<a id="member-gfnetworksnapshotschema-methods-decode_state"></a>

### `decode_state`

- API：`public`

```gdscript
func decode_state(encoded_state: Dictionary) -> Dictionary:
```

解码状态字典。

参数：

| 名称 | 说明 |
|---|---|
| `encoded_state` | 编码后的状态。 |

返回：解码后的状态。

结构：

- `encoded_state`: Dictionary[StringName|String, Variant]，编码后的状态字段。
- `return`: Dictionary[StringName|String, Variant]，解码后的状态字段。

<a id="member-gfnetworksnapshotschema-methods-encode_snapshot"></a>

### `encode_snapshot`

- API：`public`

```gdscript
func encode_snapshot(snapshot: GFNetworkSnapshot) -> Dictionary:
```

编码快照。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 原始快照。 |

返回：快照字典；snapshot 为空时返回空字典。

结构：

- `return`: Dictionary，GFNetworkSnapshot.to_dict() 结构，其中 state 已按字段编码器转换。

<a id="member-gfnetworksnapshotschema-methods-decode_snapshot"></a>

### `decode_snapshot`

- API：`public`

```gdscript
func decode_snapshot(data: Dictionary) -> GFNetworkSnapshot:
```

解码快照。

参数：

| 名称 | 说明 |
|---|---|
| `data` | encode_snapshot() 或 GFNetworkSnapshot.to_dict() 形式的字典。 |

返回：解码后的快照。

结构：

- `data`: Dictionary，encode_snapshot() 或 GFNetworkSnapshot.to_dict() 结构。

<a id="member-gfnetworksnapshotschema-methods-encode_patch"></a>

### `encode_patch`

- API：`public`

```gdscript
func encode_patch(patch: Dictionary) -> Dictionary:
```

编码快照 patch。

参数：

| 名称 | 说明 |
|---|---|
| `patch` | GFNetworkSnapshot.make_patch_to() 生成的 patch 字典。 |

返回：编码后的 patch。

结构：

- `patch`: Dictionary，路径级 patch 结构。
- `return`: Dictionary，set 值已按已注册的顶层字段编码。

<a id="member-gfnetworksnapshotschema-methods-decode_patch"></a>

### `decode_patch`

- API：`public`

```gdscript
func decode_patch(encoded_patch: Dictionary) -> Dictionary:
```

解码快照 patch。

参数：

| 名称 | 说明 |
|---|---|
| `encoded_patch` | encode_patch() 生成的 patch 字典。 |

返回：解码后的 patch。

结构：

- `encoded_patch`: Dictionary，编码后的路径级 patch 结构。
- `return`: Dictionary，set 值已按已注册的顶层字段解码。

<a id="member-gfnetworksnapshotschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`

```gdscript
func duplicate_schema() -> GFNetworkSnapshotSchema:
```

复制 Schema 配置。

返回：新 Schema。
