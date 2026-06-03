# GFSaveDataSource

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_save_data_source.gd`
- 模块：`Save`
- 继承：`GFSaveSource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.18.0`

通用对象数据源适配器。 将 Resource、目标 Node 或目标属性上的对象按 Dictionary 载荷接入 SaveGraph。 适合已有 Model、Resource 或数据持有对象复用 to_dict()/from_dict() 等通用协议， 不要求项目为每份纯数据状态额外编写 GFSaveSource 子类。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`data`](#member-gfsavedatasource-properties-data) | `var data: Resource = null` |
| 属性 | [`provider_property`](#member-gfsavedatasource-properties-provider_property) | `var provider_property: StringName = &""` |
| 属性 | [`gather_method`](#member-gfsavedatasource-properties-gather_method) | `var gather_method: StringName = &"to_dict"` |
| 属性 | [`apply_method`](#member-gfsavedatasource-properties-apply_method) | `var apply_method: StringName = &"from_dict"` |
| 属性 | [`duplicate_payload`](#member-gfsavedatasource-properties-duplicate_payload) | `var duplicate_payload: bool = true` |
| 方法 | [`get_data_provider`](#member-gfsavedatasource-methods-get_data_provider) | `func get_data_provider() -> Object:` |
| 方法 | [`describe_data_provider`](#member-gfsavedatasource-methods-describe_data_provider) | `func describe_data_provider() -> Dictionary:` |
| 方法 | [`describe_source`](#member-gfsavedatasource-methods-describe_source) | `func describe_source(scope: Node = null) -> Dictionary:` |
| 方法 | [`_gather_save_data`](#member-gfsavedatasource-methods-_gather_save_data) | `func _gather_save_data( context: Dictionary = {}, _serializer_registry: GFNodeSerializerRegistry = null ) -> Variant:` |
| 方法 | [`_apply_save_data`](#member-gfsavedatasource-methods-_apply_save_data) | `func _apply_save_data( payload: Variant, _context: Dictionary = {}, _serializer_registry: GFNodeSerializerRegistry = null ) -> Dictionary:` |

## 属性

<a id="member-gfsavedatasource-properties-data"></a>

### `data`

- API：`public`

```gdscript
var data: Resource = null
```

直接保存的数据对象。设置后优先于 target_node_path 和 provider_property。

<a id="member-gfsavedatasource-properties-provider_property"></a>

### `provider_property`

- API：`public`

```gdscript
var provider_property: StringName = &""
```

目标节点上的数据对象属性。留空时使用目标节点自身作为数据对象。

<a id="member-gfsavedatasource-properties-gather_method"></a>

### `gather_method`

- API：`public`

```gdscript
var gather_method: StringName = &"to_dict"
```

采集载荷时调用的数据对象方法。方法必须返回 Dictionary。

<a id="member-gfsavedatasource-properties-apply_method"></a>

### `apply_method`

- API：`public`

```gdscript
var apply_method: StringName = &"from_dict"
```

应用载荷时调用的数据对象方法。方法接收 Dictionary。

<a id="member-gfsavedatasource-properties-duplicate_payload"></a>

### `duplicate_payload`

- API：`public`

```gdscript
var duplicate_payload: bool = true
```

是否复制传入/传出的 Dictionary，避免流程外部误改同一个引用。

## 方法

<a id="member-gfsavedatasource-methods-get_data_provider"></a>

### `get_data_provider`

- API：`public`

```gdscript
func get_data_provider() -> Object:
```

获取当前数据对象。

返回：数据对象；无法解析时返回 null。

<a id="member-gfsavedatasource-methods-describe_data_provider"></a>

### `describe_data_provider`

- API：`public`

```gdscript
func describe_data_provider() -> Dictionary:
```

构造数据对象诊断描述。

返回：诊断字典。

结构：

- `return`: Dictionary，包含 valid、reason、source_key、provider_location、provider_property、provider_class、provider_script、gather_method、apply_method、has_gather_method、has_apply_method 等字段。

<a id="member-gfsavedatasource-methods-describe_source"></a>

### `describe_source`

- API：`public`

```gdscript
func describe_source(scope: Node = null) -> Dictionary:
```

构造 Source 描述。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 当前 Scope。 |

返回：描述字典。

结构：

- `return`: Dictionary，包含父类描述字段，并追加 kind 与 data_provider 诊断字段。

<a id="member-gfsavedatasource-methods-_gather_save_data"></a>

### `_gather_save_data`

- API：`protected`

```gdscript
func _gather_save_data( context: Dictionary = {}, _serializer_registry: GFNodeSerializerRegistry = null ) -> Variant:
```

采集数据对象载荷。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用上下文字典。 |
| `_serializer_registry` | 未使用；保留以匹配 GFSaveSource 协议。 |

返回：数据对象返回的 Dictionary 载荷；失败时返回空 Dictionary 并写入流程错误。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Variant，成功时为 Dictionary。

<a id="member-gfsavedatasource-methods-_apply_save_data"></a>

### `_apply_save_data`

- API：`protected`

```gdscript
func _apply_save_data( payload: Variant, _context: Dictionary = {}, _serializer_registry: GFNodeSerializerRegistry = null ) -> Dictionary:
```

应用数据对象载荷。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 保存载荷。 |
| `_context` | 调用上下文字典。 |
| `_serializer_registry` | 未使用；保留以匹配 GFSaveSource 协议。 |

返回：结果字典。

结构：

- `payload`: Variant，要求为 Dictionary。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Dictionary，包含 ok: bool 与 error: String。
