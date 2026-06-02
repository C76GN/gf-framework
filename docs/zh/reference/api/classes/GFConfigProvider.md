# GFConfigProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_provider.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用的静态导表数据适配器基类。 为了让框架无缝衔接不同项目的导表工具（JSON、CSV 或自定义流水线），提供统一的读取接口。 具体项目应该继承此基类，并实现其数据加载和查询逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_record`](#member-gfconfigprovider-methods-get_record) | `func get_record(_table_name: StringName, _id: Variant) -> Variant:` |
| 方法 | [`get_table`](#member-gfconfigprovider-methods-get_table) | `func get_table(_table_name: StringName) -> Variant:` |
| 方法 | [`register_schema`](#member-gfconfigprovider-methods-register_schema) | `func register_schema(schema: GFConfigTableSchema) -> bool:` |
| 方法 | [`unregister_schema`](#member-gfconfigprovider-methods-unregister_schema) | `func unregister_schema(table_name: StringName) -> void:` |
| 方法 | [`has_schema`](#member-gfconfigprovider-methods-has_schema) | `func has_schema(table_name: StringName) -> bool:` |
| 方法 | [`get_schema`](#member-gfconfigprovider-methods-get_schema) | `func get_schema(table_name: StringName) -> GFConfigTableSchema:` |
| 方法 | [`get_schema_ids`](#member-gfconfigprovider-methods-get_schema_ids) | `func get_schema_ids() -> PackedStringArray:` |
| 方法 | [`validate_record`](#member-gfconfigprovider-methods-validate_record) | `func validate_record( table_name: StringName, record: Dictionary, row_key: Variant = null, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`validate_table`](#member-gfconfigprovider-methods-validate_table) | `func validate_table(table_name: StringName, table_data: Variant = null, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`coerce_record`](#member-gfconfigprovider-methods-coerce_record) | `func coerce_record(table_name: StringName, record: Dictionary) -> Dictionary:` |

## 方法

<a id="member-gfconfigprovider-methods-get_record"></a>

### `get_record`

- API：`public`

```gdscript
func get_record(_table_name: StringName, _id: Variant) -> Variant:
```

根据表名和 ID 获取单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `_table_name` | 表名。 |
| `_id` | 记录的唯一标识符。 |

返回：返回对应的记录数据，默认返回 null 并报错。

结构：

- `_id`: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
- `return`: Variant，子类通常返回记录 Dictionary 或项目自定义记录对象；未命中时可返回 null。

<a id="member-gfconfigprovider-methods-get_table"></a>

### `get_table`

- API：`public`

```gdscript
func get_table(_table_name: StringName) -> Variant:
```

根据表名获取整张表的数据。

参数：

| 名称 | 说明 |
|---|---|
| `_table_name` | 表名。 |

返回：返回整张表的数据，默认返回 null 并报错。

结构：

- `return`: Variant，子类通常返回 Array[Dictionary]、Dictionary 或项目自定义表容器；未命中时可返回 null。

<a id="member-gfconfigprovider-methods-register_schema"></a>

### `register_schema`

- API：`public`

```gdscript
func register_schema(schema: GFConfigTableSchema) -> bool:
```

注册导表结构声明。

参数：

| 名称 | 说明 |
|---|---|
| `schema` | 表结构声明。 |

返回：注册成功返回 true。

<a id="member-gfconfigprovider-methods-unregister_schema"></a>

### `unregister_schema`

- API：`public`

```gdscript
func unregister_schema(table_name: StringName) -> void:
```

注销导表结构声明。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

<a id="member-gfconfigprovider-methods-has_schema"></a>

### `has_schema`

- API：`public`

```gdscript
func has_schema(table_name: StringName) -> bool:
```

检查是否注册了导表结构声明。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已注册返回 true。

<a id="member-gfconfigprovider-methods-get_schema"></a>

### `get_schema`

- API：`public`

```gdscript
func get_schema(table_name: StringName) -> GFConfigTableSchema:
```

获取导表结构声明。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已注册时返回 schema 拷贝，否则返回 null。

<a id="member-gfconfigprovider-methods-get_schema_ids"></a>

### `get_schema_ids`

- API：`public`

```gdscript
func get_schema_ids() -> PackedStringArray:
```

获取已注册的导表结构标识。

返回：表名列表。

<a id="member-gfconfigprovider-methods-validate_record"></a>

### `validate_record`

- API：`public`

```gdscript
func validate_record( table_name: StringName, record: Dictionary, row_key: Variant = null, options: Dictionary = {} ) -> Dictionary:
```

使用已注册 schema 校验单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `record` | 记录字典。 |
| `row_key` | 可选行标识。 |
| `options` | 可选校验上下文。 |

返回：校验报告字典。

结构：

- `record`: Dictionary，待校验的配置记录，键为字段名，值为字段数据。
- `row_key`: Variant，写入校验报告 issue 的行标识。
- `options`: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigprovider-methods-validate_table"></a>

### `validate_table`

- API：`public`

```gdscript
func validate_table(table_name: StringName, table_data: Variant = null, options: Dictionary = {}) -> Dictionary:
```

使用已注册 schema 校验整张表。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `table_data` | 可选表数据；为 null 时调用 get_table()。 |
| `options` | 可选校验上下文。 |

返回：校验报告字典。

结构：

- `table_data`: Variant，支持 Array[Dictionary]、Dictionary 或 null。
- `options`: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigprovider-methods-coerce_record"></a>

### `coerce_record`

- API：`public`

```gdscript
func coerce_record(table_name: StringName, record: Dictionary) -> Dictionary:
```

使用已注册 schema 转换单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `record` | 记录字典。 |

返回：转换后的新记录；缺少 schema 时返回记录拷贝。

结构：

- `record`: Dictionary，待转换的配置记录，键为字段名，值为字段数据。
- `return`: Dictionary，转换后的记录副本。
