# GFDataBatchSchema

[API Reference](../index.md) / [Data Batch](../extensions-data-batch.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/data_batch/runtime/gf_data_batch_schema.gd`
- 模块：`Data Batch`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

一次构造后固定的数值列布局。 字段含义和版本迁移属于项目；列索引在此 schema 的整个生命周期内不变。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`NumericType`](#member-gfdatabatchschema-enums-numerictype) | `enum NumericType` |
| 常量 | [`MAX_COLUMNS`](#member-gfdatabatchschema-constants-max_columns) | `const MAX_COLUMNS: int = 256` |
| 方法 | [`create`](#member-gfdatabatchschema-methods-create) | `static func create( schema_id: StringName, version: int, column_names: Array[StringName], column_types: PackedInt32Array ) -> GFDataBatchSchema:` |
| 方法 | [`is_valid`](#member-gfdatabatchschema-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_schema_id`](#member-gfdatabatchschema-methods-get_schema_id) | `func get_schema_id() -> StringName:` |
| 方法 | [`get_version`](#member-gfdatabatchschema-methods-get_version) | `func get_version() -> int:` |
| 方法 | [`get_column_count`](#member-gfdatabatchschema-methods-get_column_count) | `func get_column_count() -> int:` |
| 方法 | [`find_column`](#member-gfdatabatchschema-methods-find_column) | `func find_column(column_name: StringName) -> int:` |
| 方法 | [`get_column_name`](#member-gfdatabatchschema-methods-get_column_name) | `func get_column_name(column_index: int) -> StringName:` |
| 方法 | [`get_column_type`](#member-gfdatabatchschema-methods-get_column_type) | `func get_column_type(column_index: int) -> NumericType:` |
| 方法 | [`get_bytes_per_row`](#member-gfdatabatchschema-methods-get_bytes_per_row) | `func get_bytes_per_row() -> int:` |

## 枚举

<a id="member-gfdatabatchschema-enums-numerictype"></a>

### `NumericType`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum NumericType {
	## 查询索引无效时返回，不能用于构造列。
	INVALID,
	## PackedInt32Array，每个元素占四个 payload 字节。
	INT32,
	## PackedInt64Array，每个元素占八个 payload 字节。
	INT64,
}
```

支持的 PackedArray 数值列类型，不执行隐式数值转换。

## 常量

<a id="member-gfdatabatchschema-constants-max_columns"></a>

### `MAX_COLUMNS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_COLUMNS: int = 256
```

单个 schema 的最大列数，限制边界验证和每批元数据工作量。

## 方法

<a id="member-gfdatabatchschema-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( schema_id: StringName, version: int, column_names: Array[StringName], column_types: PackedInt32Array ) -> GFDataBatchSchema:
```

校验并复制布局定义。无效输入返回 null，不保留输入数组别名。

参数：

| 名称 | 说明 |
|---|---|
| `schema_id` | 非空的项目布局标识。 |
| `version` | 大于零的项目布局版本。 |
| `column_names` | 一至 MAX_COLUMNS 个非空、无重复的列名。 |
| `column_types` | 与列名等长，只包含 INT32 或 INT64。 |

返回：固定布局；验证失败返回 null。

<a id="member-gfdatabatchschema-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

检查此对象是否通过 create 完整构造。

返回：有效布局返回 true。

<a id="member-gfdatabatchschema-methods-get_schema_id"></a>

### `get_schema_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_schema_id() -> StringName:
```

返回项目布局标识。

返回：构造时固定的标识。

<a id="member-gfdatabatchschema-methods-get_version"></a>

### `get_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_version() -> int:
```

返回项目声明的布局版本。

返回：正版本号；无效对象为零。

<a id="member-gfdatabatchschema-methods-get_column_count"></a>

### `get_column_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_column_count() -> int:
```

返回固定列数。

返回：列数量。

<a id="member-gfdatabatchschema-methods-find_column"></a>

### `find_column`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func find_column(column_name: StringName) -> int:
```

在初始化消费者时将列名绑定到稳定索引。

参数：

| 名称 | 说明 |
|---|---|
| `column_name` | 项目定义的列名。 |

返回：零起始列索引；不存在返回 -1。

<a id="member-gfdatabatchschema-methods-get_column_name"></a>

### `get_column_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_column_name(column_index: int) -> StringName:
```

按稳定索引返回列名。

参数：

| 名称 | 说明 |
|---|---|
| `column_index` | 零起始列索引。 |

返回：列名；越界返回空 StringName。

<a id="member-gfdatabatchschema-methods-get_column_type"></a>

### `get_column_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_column_type(column_index: int) -> NumericType:
```

按稳定索引返回数值类型。

参数：

| 名称 | 说明 |
|---|---|
| `column_index` | 零起始列索引。 |

返回：列类型；越界返回 INVALID。

<a id="member-gfdatabatchschema-methods-get_bytes_per_row"></a>

### `get_bytes_per_row`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_bytes_per_row() -> int:
```

返回全部列每行占用的 payload 字节，不含对象、字典和数组头开销。

返回：每行四或八字节列宽之和。
