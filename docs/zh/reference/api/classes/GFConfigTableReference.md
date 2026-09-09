# GFConfigTableReference

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_reference.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

导表跨表引用声明。 描述当前记录的一组字段如何指向另一张表的一组字段，或声明一维数组中每个标量值的引用约束。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`SourceMode`](#member-gfconfigtablereference-enums-sourcemode) | `enum SourceMode` |
| 属性 | [`reference_id`](#member-gfconfigtablereference-properties-reference_id) | `var reference_id: StringName = &""` |
| 属性 | [`source_fields`](#member-gfconfigtablereference-properties-source_fields) | `var source_fields: PackedStringArray = PackedStringArray()` |
| 属性 | [`source_mode`](#member-gfconfigtablereference-properties-source_mode) | `var source_mode: SourceMode = SourceMode.FIELDS` |
| 属性 | [`target_table_name`](#member-gfconfigtablereference-properties-target_table_name) | `var target_table_name: StringName = &""` |
| 属性 | [`target_fields`](#member-gfconfigtablereference-properties-target_fields) | `var target_fields: PackedStringArray = PackedStringArray()` |
| 属性 | [`required`](#member-gfconfigtablereference-properties-required) | `var required: bool = true` |
| 属性 | [`allow_null_values`](#member-gfconfigtablereference-properties-allow_null_values) | `var allow_null_values: bool = true` |
| 属性 | [`metadata`](#member-gfconfigtablereference-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_reference_id`](#member-gfconfigtablereference-methods-get_reference_id) | `func get_reference_id() -> StringName:` |
| 方法 | [`is_valid_definition`](#member-gfconfigtablereference-methods-is_valid_definition) | `func is_valid_definition() -> bool:` |
| 方法 | [`get_target_fields`](#member-gfconfigtablereference-methods-get_target_fields) | `func get_target_fields(target_schema: GFConfigTableSchema = null) -> PackedStringArray:` |
| 方法 | [`make_source_key`](#member-gfconfigtablereference-methods-make_source_key) | `func make_source_key(record: Dictionary) -> String:` |
| 方法 | [`make_target_key`](#member-gfconfigtablereference-methods-make_target_key) | `func make_target_key(record: Dictionary, target_schema: GFConfigTableSchema = null) -> String:` |
| 方法 | [`duplicate_reference`](#member-gfconfigtablereference-methods-duplicate_reference) | `func duplicate_reference() -> GFConfigTableReference:` |
| 方法 | [`describe`](#member-gfconfigtablereference-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfconfigtablereference-enums-sourcemode"></a>

### `SourceMode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum SourceMode {
	## 将来源字段的完整值组成一个引用键。
	FIELDS,
	## 逐项校验单个 Array 字段，目标必须是单字段键；不自动解析目标记录。
	ARRAY_ELEMENTS,
}
```

来源引用的取值方式。

## 属性

<a id="member-gfconfigtablereference-properties-reference_id"></a>

### `reference_id`

- API：`public`

```gdscript
var reference_id: StringName = &""
```

引用稳定标识。为空时会根据来源字段和目标表生成。

<a id="member-gfconfigtablereference-properties-source_fields"></a>

### `source_fields`

- API：`public`

```gdscript
var source_fields: PackedStringArray = PackedStringArray()
```

当前表中参与引用的字段名。

<a id="member-gfconfigtablereference-properties-source_mode"></a>

### `source_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var source_mode: SourceMode = SourceMode.FIELDS
```

来源取值方式。ARRAY_ELEMENTS 只接受单个一维 Array 字段，不转换元素类型。 元素支持 bool、int、有限 float、String、StringName，以及允许的 null；空数组合法，重复值按各自位置校验。

<a id="member-gfconfigtablereference-properties-target_table_name"></a>

### `target_table_name`

- API：`public`

```gdscript
var target_table_name: StringName = &""
```

目标表名。

<a id="member-gfconfigtablereference-properties-target_fields"></a>

### `target_fields`

- API：`public`

```gdscript
var target_fields: PackedStringArray = PackedStringArray()
```

目标表中参与匹配的字段名。为空时由目标 schema 的 id_field 补齐。

<a id="member-gfconfigtablereference-properties-required"></a>

### `required`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var required: bool = true
```

为 true 时，来源字段必须存在且每个引用键必须匹配目标；为 false 时允许来源缺失或目标不匹配。 ARRAY_ELEMENTS 的容器与元素类型约束不受此开关影响。

<a id="member-gfconfigtablereference-properties-allow_null_values"></a>

### `allow_null_values`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var allow_null_values: bool = true
```

是否允许来源字段值为 null；ARRAY_ELEMENTS 中只作用于元素，整个来源字段仍必须为 Array。 允许的 null 作为键参与目标匹配，不会跳过 required 约束。

<a id="member-gfconfigtablereference-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供导入器、编辑器或项目层扩展使用。

结构：

- `metadata`: Dictionary，保存导入器、编辑器或项目层附加到当前引用的元数据。

## 方法

<a id="member-gfconfigtablereference-methods-get_reference_id"></a>

### `get_reference_id`

- API：`public`

```gdscript
func get_reference_id() -> StringName:
```

获取稳定引用标识。

返回：引用标识。

<a id="member-gfconfigtablereference-methods-is_valid_definition"></a>

### `is_valid_definition`

- API：`public`

```gdscript
func is_valid_definition() -> bool:
```

检查引用声明是否有效。

返回：有效返回 true。

<a id="member-gfconfigtablereference-methods-get_target_fields"></a>

### `get_target_fields`

- API：`public`

```gdscript
func get_target_fields(target_schema: GFConfigTableSchema = null) -> PackedStringArray:
```

获取目标字段名。

参数：

| 名称 | 说明 |
|---|---|
| `target_schema` | 可选目标 schema。 |

返回：目标字段列表。

<a id="member-gfconfigtablereference-methods-make_source_key"></a>

### `make_source_key`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func make_source_key(record: Dictionary) -> String:
```

根据来源记录构建 FIELDS 模式的引用键。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 来源记录。 |

返回：引用键；字段缺失、null 不允许或使用 ARRAY_ELEMENTS 时返回空字符串。

结构：

- `record`: Dictionary，用于构建引用键的来源配置记录。

<a id="member-gfconfigtablereference-methods-make_target_key"></a>

### `make_target_key`

- API：`public`

```gdscript
func make_target_key(record: Dictionary, target_schema: GFConfigTableSchema = null) -> String:
```

根据目标记录构建引用键。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 目标记录。 |
| `target_schema` | 可选目标 schema。 |

返回：引用键；字段缺失或 null 不允许时返回空字符串。

结构：

- `record`: Dictionary，用于构建引用键的目标配置记录。

<a id="member-gfconfigtablereference-methods-duplicate_reference"></a>

### `duplicate_reference`

- API：`public`

```gdscript
func duplicate_reference() -> GFConfigTableReference:
```

创建同内容拷贝。

返回：新引用声明。

<a id="member-gfconfigtablereference-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func describe() -> Dictionary:
```

导出引用声明摘要。

返回：引用声明字典。

结构：

- `return`: Dictionary，包含 reference_id、source_fields、source_mode、target_table_name、target_fields、required、allow_null_values 和 metadata。
