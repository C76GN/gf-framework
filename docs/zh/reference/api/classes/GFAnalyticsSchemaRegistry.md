# GFAnalyticsSchemaRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/analytics/gf_analytics_schema_registry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`10.0.0`

精确版本 Analytics 事件 Schema 注册表。 注册表以 event_name 与 schema_version 的组合保存隔离副本， 禁止同版本覆盖，也不提供隐式 latest 回退。公开 getter 再返回副本， 避免调用方通过可变 Resource 改写已经注册的契约。单个 Registry 最多保存 1024 个 Schema、同一事件最多 32 个精确版本，并对定义图、辅助值和文本执行 累计硬预算；只接受内置声明式 EventSchema、DictionarySchema、Field 和规则脚本。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_schema`](#member-gfanalyticsschemaregistry-methods-register_schema) | `func register_schema(schema: GFAnalyticsEventSchema) -> Dictionary:` |
| 方法 | [`has_schema`](#member-gfanalyticsschemaregistry-methods-has_schema) | `func has_schema(event_name: StringName, schema_version: int) -> bool:` |
| 方法 | [`get_schema`](#member-gfanalyticsschemaregistry-methods-get_schema) | `func get_schema( event_name: StringName, schema_version: int ) -> GFAnalyticsEventSchema:` |
| 方法 | [`get_versions`](#member-gfanalyticsschemaregistry-methods-get_versions) | `func get_versions(event_name: StringName) -> PackedInt32Array:` |
| 方法 | [`validate`](#member-gfanalyticsschemaregistry-methods-validate) | `func validate( event_name: StringName, schema_version: int, properties: Dictionary, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`get_debug_snapshot`](#member-gfanalyticsschemaregistry-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfanalyticsschemaregistry-methods-register_schema"></a>

### `register_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func register_schema(schema: GFAnalyticsEventSchema) -> Dictionary:
```

注册一个事件 Schema 的隔离副本。 同一事件的同一版本只能注册一次；无效定义、容量超限或版本重复都会失败。

参数：

| 名称 | 说明 |
|---|---|
| `schema` | 待注册事件 Schema。 |

返回：注册结果。

结构：

- `return`: Dictionary with ok, reason, event_name, schema_version, registered_count, and validation.

<a id="member-gfanalyticsschemaregistry-methods-has_schema"></a>

### `has_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func has_schema(event_name: StringName, schema_version: int) -> bool:
```

检查精确事件 Schema 版本是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 稳定事件名。 |
| `schema_version` | 1..2_147_483_647 范围内的精确版本。 |

返回：已注册时返回 true。

<a id="member-gfanalyticsschemaregistry-methods-get_schema"></a>

### `get_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_schema( event_name: StringName, schema_version: int ) -> GFAnalyticsEventSchema:
```

获取精确事件 Schema 版本的隔离副本。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 稳定事件名。 |
| `schema_version` | 1..2_147_483_647 范围内的精确版本。 |

返回：已注册 Schema 的副本；不存在时返回 null。

<a id="member-gfanalyticsschemaregistry-methods-get_versions"></a>

### `get_versions`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_versions(event_name: StringName) -> PackedInt32Array:
```

获取事件已经注册的版本列表。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 稳定事件名。 |

返回：升序版本数组。

<a id="member-gfanalyticsschemaregistry-methods-validate"></a>

### `validate`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate( event_name: StringName, schema_version: int, properties: Dictionary, options: Dictionary = {} ) -> GFValidationReport:
```

使用精确注册版本校验事件属性。 版本不存在时返回 schema_not_registered，不会自动选择其他版本。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 稳定事件名。 |
| `schema_version` | 1..2_147_483_647 范围内的精确版本。 |
| `properties` | 编码前事件属性。 |
| `options` | 传给事件 Schema 的校验上下文与预算。 |

返回：校验报告。

结构：

- `properties`: Dictionary analytics event properties before report encoding.
- `options`: Dictionary validation context and bounded traversal options.

<a id="member-gfanalyticsschemaregistry-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含业务属性和默认值的调试快照。

返回：注册表调试信息。

结构：

- `return`: Dictionary with event_count, schema_count, registered footprint counters, registry limits, and events; each event contains event_name and versions.
