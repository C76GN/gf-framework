# GFPersistPropertiesSource

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_persist_properties_source.gd`
- 模块：`Save`
- 继承：`GFSaveSource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.23.0`

属性白名单存档 Source。 以节点形式包装 `GFNodePropertySerializer`，让项目可以直接在场景树中声明 需要保存的目标属性。它仍然使用 SaveGraph 的 Source/Serializer 协议， 不引入独立存储格式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`properties`](#member-gfpersistpropertiessource-properties-properties) | `var properties: PackedStringArray = PackedStringArray()` |
| 属性 | [`skip_missing_properties`](#member-gfpersistpropertiessource-properties-skip_missing_properties) | `var skip_missing_properties: bool = true` |
| 方法 | [`_gather_save_data`](#member-gfpersistpropertiessource-methods-_gather_save_data) | `func _gather_save_data( context: Dictionary = {}, serializer_registry: GFNodeSerializerRegistry = null ) -> Variant:` |
| 方法 | [`_apply_save_data`](#member-gfpersistpropertiessource-methods-_apply_save_data) | `func _apply_save_data( data: Variant, context: Dictionary = {}, serializer_registry: GFNodeSerializerRegistry = null ) -> Dictionary:` |

## 属性

<a id="member-gfpersistpropertiessource-properties-properties"></a>

### `properties`

- API：`public`

```gdscript
var properties: PackedStringArray = PackedStringArray()
```

需要保存的目标节点属性名。

<a id="member-gfpersistpropertiessource-properties-skip_missing_properties"></a>

### `skip_missing_properties`

- API：`public`

```gdscript
var skip_missing_properties: bool = true
```

应用数据时遇到缺失属性是否跳过。

## 方法

<a id="member-gfpersistpropertiessource-methods-_gather_save_data"></a>

### `_gather_save_data`

- API：`protected`

```gdscript
func _gather_save_data( context: Dictionary = {}, serializer_registry: GFNodeSerializerRegistry = null ) -> Variant:
```

采集属性白名单保存数据。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用上下文字典。 |
| `serializer_registry` | 可选节点序列化器注册表。 |

返回：可写入存档的数据。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Variant，通常为 Dictionary；默认实现返回包含 serializers: Array[Dictionary] 的载荷，或空 Dictionary。

<a id="member-gfpersistpropertiessource-methods-_apply_save_data"></a>

### `_apply_save_data`

- API：`protected`

```gdscript
func _apply_save_data( data: Variant, context: Dictionary = {}, serializer_registry: GFNodeSerializerRegistry = null ) -> Dictionary:
```

应用属性白名单保存数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 保存数据。 |
| `context` | 调用上下文字典。 |
| `serializer_registry` | 可选节点序列化器注册表。 |

返回：结果字典。

结构：

- `data`: Variant，默认实现要求为包含 serializers: Array[Dictionary] 的 Dictionary。
- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Dictionary，包含 ok、applied 与 errors。
