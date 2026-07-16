# GFConfigTableQuery

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_query.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

配置表记录的通用查询器。 面向 GFConfigTableResource、导表记录数组和编辑器工具提供纯数据筛选、排序与分页。 它不改变配置表存储模型，也不绑定任何业务表语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Operator`](#member-gfconfigtablequery-enums-operator) | `enum Operator` |
| 方法 | [`from_table`](#member-gfconfigtablequery-methods-from_table) | `static func from_table(table: GFConfigTableResource, duplicate_records: bool = true) -> GFConfigTableQuery:` |
| 方法 | [`from_records`](#member-gfconfigtablequery-methods-from_records) | `static func from_records(records: Array[Dictionary], duplicate_records: bool = true) -> GFConfigTableQuery:` |
| 方法 | [`set_records`](#member-gfconfigtablequery-methods-set_records) | `func set_records(records: Array[Dictionary], duplicate_records: bool = true) -> GFConfigTableQuery:` |
| 方法 | [`clear_query`](#member-gfconfigtablequery-methods-clear_query) | `func clear_query() -> GFConfigTableQuery:` |
| 方法 | [`where_eq`](#member-gfconfigtablequery-methods-where_eq) | `func where_eq(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_ne`](#member-gfconfigtablequery-methods-where_ne) | `func where_ne(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_gt`](#member-gfconfigtablequery-methods-where_gt) | `func where_gt(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_gte`](#member-gfconfigtablequery-methods-where_gte) | `func where_gte(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_lt`](#member-gfconfigtablequery-methods-where_lt) | `func where_lt(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_lte`](#member-gfconfigtablequery-methods-where_lte) | `func where_lte(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_in`](#member-gfconfigtablequery-methods-where_in) | `func where_in(path: String, candidate_values: Array) -> GFConfigTableQuery:` |
| 方法 | [`where_contains`](#member-gfconfigtablequery-methods-where_contains) | `func where_contains(path: String, value: Variant) -> GFConfigTableQuery:` |
| 方法 | [`where_exists`](#member-gfconfigtablequery-methods-where_exists) | `func where_exists(path: String, exists: bool = true) -> GFConfigTableQuery:` |
| 方法 | [`where_predicate`](#member-gfconfigtablequery-methods-where_predicate) | `func where_predicate(predicate: Callable, description: StringName = &"") -> GFConfigTableQuery:` |
| 方法 | [`condition`](#member-gfconfigtablequery-methods-condition) | `static func condition( operator: Operator, path: String = "", value: Variant = null, description: StringName = &"" ) -> Dictionary:` |
| 方法 | [`where_filter`](#member-gfconfigtablequery-methods-where_filter) | `func where_filter(condition_data: Dictionary) -> GFConfigTableQuery:` |
| 方法 | [`where_any`](#member-gfconfigtablequery-methods-where_any) | `func where_any(conditions: Array[Dictionary], description: StringName = &"") -> GFConfigTableQuery:` |
| 方法 | [`where_none`](#member-gfconfigtablequery-methods-where_none) | `func where_none(conditions: Array[Dictionary], description: StringName = &"") -> GFConfigTableQuery:` |
| 方法 | [`order_by`](#member-gfconfigtablequery-methods-order_by) | `func order_by(path: String, ascending: bool = true) -> GFConfigTableQuery:` |
| 方法 | [`page`](#member-gfconfigtablequery-methods-page) | `func page(offset: int = 0, limit: int = -1) -> GFConfigTableQuery:` |
| 方法 | [`to_array`](#member-gfconfigtablequery-methods-to_array) | `func to_array(duplicate_records: bool = true) -> Array[Dictionary]:` |
| 方法 | [`first`](#member-gfconfigtablequery-methods-first) | `func first(duplicate_record: bool = true) -> Variant:` |
| 方法 | [`count`](#member-gfconfigtablequery-methods-count) | `func count() -> int:` |
| 方法 | [`values`](#member-gfconfigtablequery-methods-values) | `func values(path: String = "") -> Array:` |
| 方法 | [`read_path`](#member-gfconfigtablequery-methods-read_path) | `static func read_path(source: Variant, path: String, default_value: Variant = null) -> Variant:` |
| 方法 | [`describe_query`](#member-gfconfigtablequery-methods-describe_query) | `func describe_query() -> Dictionary:` |

## 枚举

<a id="member-gfconfigtablequery-enums-operator"></a>

### `Operator`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum Operator {
	## 字段值等于目标值。
	EQ,
	## 字段值不等于目标值。
	NE,
	## 字段值大于目标值。
	GT,
	## 字段值大于等于目标值。
	GTE,
	## 字段值小于目标值。
	LT,
	## 字段值小于等于目标值。
	LTE,
	## 字段值包含在目标集合中。
	IN,
	## 字段值包含目标值。
	CONTAINS,
	## 字段路径是否存在。
	EXISTS,
	## 使用 Callable 判断整条记录。
	PREDICATE,
	## 任一子条件匹配。
	ANY,
	## 所有子条件都不匹配。
	NONE,
}
```

过滤条件操作符。

## 方法

<a id="member-gfconfigtablequery-methods-from_table"></a>

### `from_table`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_table(table: GFConfigTableResource, duplicate_records: bool = true) -> GFConfigTableQuery:
```

从配置表资源创建查询器。

参数：

| 名称 | 说明 |
|---|---|
| `table` | 配置表资源。 |
| `duplicate_records` | 是否复制表记录，避免查询器持有资源内可变记录引用。 |

返回：新查询器。

<a id="member-gfconfigtablequery-methods-from_records"></a>

### `from_records`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_records(records: Array[Dictionary], duplicate_records: bool = true) -> GFConfigTableQuery:
```

从记录数组创建查询器。

参数：

| 名称 | 说明 |
|---|---|
| `records` | 配置记录数组。 |
| `duplicate_records` | 是否复制 Dictionary 记录。 |

返回：新查询器。

结构：

- `records`: Array[Dictionary]，每个 Dictionary 是一条配置记录。

<a id="member-gfconfigtablequery-methods-set_records"></a>

### `set_records`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_records(records: Array[Dictionary], duplicate_records: bool = true) -> GFConfigTableQuery:
```

设置查询源记录。

参数：

| 名称 | 说明 |
|---|---|
| `records` | 配置记录数组。 |
| `duplicate_records` | 是否复制 Dictionary 记录。 |

返回：当前查询器。

结构：

- `records`: Array[Dictionary]，每个 Dictionary 是一条配置记录。

<a id="member-gfconfigtablequery-methods-clear_query"></a>

### `clear_query`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_query() -> GFConfigTableQuery:
```

清空所有过滤条件、排序和分页。

返回：当前查询器。

<a id="member-gfconfigtablequery-methods-where_eq"></a>

### `where_eq`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_eq(path: String, value: Variant) -> GFConfigTableQuery:
```

添加等值过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_ne"></a>

### `where_ne`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_ne(path: String, value: Variant) -> GFConfigTableQuery:
```

添加不等值过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_gt"></a>

### `where_gt`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_gt(path: String, value: Variant) -> GFConfigTableQuery:
```

添加大于过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_gte"></a>

### `where_gte`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_gte(path: String, value: Variant) -> GFConfigTableQuery:
```

添加大于等于过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_lt"></a>

### `where_lt`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_lt(path: String, value: Variant) -> GFConfigTableQuery:
```

添加小于过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_lte"></a>

### `where_lte`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_lte(path: String, value: Variant) -> GFConfigTableQuery:
```

添加小于等于过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_in"></a>

### `where_in`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_in(path: String, candidate_values: Array) -> GFConfigTableQuery:
```

添加集合包含过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `candidate_values` | 目标值集合。 |

返回：当前查询器。

结构：

- `candidate_values`: Array，筛选候选值。

<a id="member-gfconfigtablequery-methods-where_contains"></a>

### `where_contains`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_contains(path: String, value: Variant) -> GFConfigTableQuery:
```

添加字段包含过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `value` | 目标值。 |

返回：当前查询器。

结构：

- `value`: Variant，筛选目标值。

<a id="member-gfconfigtablequery-methods-where_exists"></a>

### `where_exists`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_exists(path: String, exists: bool = true) -> GFConfigTableQuery:
```

添加字段存在性过滤。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `exists` | 为 true 时要求路径存在，为 false 时要求路径不存在。 |

返回：当前查询器。

<a id="member-gfconfigtablequery-methods-where_predicate"></a>

### `where_predicate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_predicate(predicate: Callable, description: StringName = &"") -> GFConfigTableQuery:
```

添加自定义记录过滤。

参数：

| 名称 | 说明 |
|---|---|
| `predicate` | 判断回调，签名为 Callable(record: Dictionary) -> bool。 |
| `description` | 可选描述 ID，进入 describe_query() 便于调试。 |

返回：当前查询器。

<a id="member-gfconfigtablequery-methods-condition"></a>

### `condition`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func condition( operator: Operator, path: String = "", value: Variant = null, description: StringName = &"" ) -> Dictionary:
```

创建可传给 where_filter()、where_any() 或 where_none() 的条件字典。

参数：

| 名称 | 说明 |
|---|---|
| `operator` | 过滤操作符。 |
| `path` | 字段路径；PREDICATE、ANY 和 NONE 可为空。 |
| `value` | 目标值、Callable，或条件组数组。 |
| `description` | 可选描述 ID，进入 describe_query() 便于调试。 |

返回：条件字典。

结构：

- `value`: Variant 目标值、Callable 谓词、Array[Dictionary] 条件组或 null。
- `return`: Dictionary，可直接传给 where_filter()、where_any() 或 where_none()。

<a id="member-gfconfigtablequery-methods-where_filter"></a>

### `where_filter`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_filter(condition_data: Dictionary) -> GFConfigTableQuery:
```

添加一个声明式条件。

参数：

| 名称 | 说明 |
|---|---|
| `condition_data` | 条件字典，通常由 condition() 创建。 |

返回：当前查询器。

结构：

- `condition_data`: Dictionary，包含 operator、path、value、description 或嵌套 filters/conditions。

<a id="member-gfconfigtablequery-methods-where_any"></a>

### `where_any`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_any(conditions: Array[Dictionary], description: StringName = &"") -> GFConfigTableQuery:
```

添加任一条件匹配过滤。

参数：

| 名称 | 说明 |
|---|---|
| `conditions` | 条件字典数组，任一条件匹配即通过。 |
| `description` | 可选描述 ID，进入 describe_query() 便于调试。 |

返回：当前查询器。

结构：

- `conditions`: Array[Dictionary]，每个元素通常由 condition() 创建。

<a id="member-gfconfigtablequery-methods-where_none"></a>

### `where_none`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func where_none(conditions: Array[Dictionary], description: StringName = &"") -> GFConfigTableQuery:
```

添加所有条件都不匹配过滤。

参数：

| 名称 | 说明 |
|---|---|
| `conditions` | 条件字典数组，只要其中任一条件匹配即拒绝记录。 |
| `description` | 可选描述 ID，进入 describe_query() 便于调试。 |

返回：当前查询器。

结构：

- `conditions`: Array[Dictionary]，每个元素通常由 condition() 创建。

<a id="member-gfconfigtablequery-methods-order_by"></a>

### `order_by`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func order_by(path: String, ascending: bool = true) -> GFConfigTableQuery:
```

设置排序字段。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `ascending` | 是否升序。 |

返回：当前查询器。

<a id="member-gfconfigtablequery-methods-page"></a>

### `page`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func page(offset: int = 0, limit: int = -1) -> GFConfigTableQuery:
```

设置分页。

参数：

| 名称 | 说明 |
|---|---|
| `offset` | 跳过记录数量。 |
| `limit` | 最多返回记录数量；小于 0 表示不限制。 |

返回：当前查询器。

<a id="member-gfconfigtablequery-methods-to_array"></a>

### `to_array`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_array(duplicate_records: bool = true) -> Array[Dictionary]:
```

返回匹配记录数组。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_records` | 是否复制返回记录。 |

返回：匹配记录数组。

结构：

- `return`: Array[Dictionary]，每个 Dictionary 是一条匹配记录。

<a id="member-gfconfigtablequery-methods-first"></a>

### `first`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func first(duplicate_record: bool = true) -> Variant:
```

返回第一条匹配记录。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_record` | 是否复制返回记录。 |

返回：匹配记录；没有匹配时返回 null。

结构：

- `return`: Variant，找到时为 Dictionary，未命中时为 null。

<a id="member-gfconfigtablequery-methods-count"></a>

### `count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func count() -> int:
```

返回匹配记录数量，不应用分页。

返回：匹配记录数量。

<a id="member-gfconfigtablequery-methods-values"></a>

### `values`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func values(path: String = "") -> Array:
```

返回匹配记录中的字段值。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 字段路径。为空时使用整条记录。 |

返回：字段值数组。

结构：

- `return`: Array，字段值列表。

<a id="member-gfconfigtablequery-methods-read_path"></a>

### `read_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func read_path(source: Variant, path: String, default_value: Variant = null) -> Variant:
```

读取任意源对象的路径值。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 源数据。 |
| `path` | 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。 |
| `default_value` | 路径不存在时返回的默认值。 |

返回：读取到的值或默认值。

结构：

- `source`: Variant，Dictionary、Array、Object 或标量数据。
- `default_value`: Variant，路径不存在时返回的默认值。
- `return`: Variant，读取到的值或默认值。

<a id="member-gfconfigtablequery-methods-describe_query"></a>

### `describe_query`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func describe_query() -> Dictionary:
```

描述当前查询。

返回：查询描述。

结构：

- `return`: Dictionary，包含 source_count、filter_count、filters、sort_path、sort_ascending、offset 和 limit。
