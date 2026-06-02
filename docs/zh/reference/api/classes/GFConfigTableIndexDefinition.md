# GFConfigTableIndexDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_index_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

导表索引声明。 描述一组字段如何组成查询键或唯一键，不绑定任何具体业务表。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`index_id`](#member-gfconfigtableindexdefinition-properties-index_id) | `var index_id: StringName = &""` |
| 属性 | [`field_names`](#member-gfconfigtableindexdefinition-properties-field_names) | `var field_names: PackedStringArray = PackedStringArray()` |
| 属性 | [`unique`](#member-gfconfigtableindexdefinition-properties-unique) | `var unique: bool = false` |
| 属性 | [`allow_null_values`](#member-gfconfigtableindexdefinition-properties-allow_null_values) | `var allow_null_values: bool = true` |
| 属性 | [`metadata`](#member-gfconfigtableindexdefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_index_id`](#member-gfconfigtableindexdefinition-methods-get_index_id) | `func get_index_id() -> StringName:` |
| 方法 | [`is_valid_definition`](#member-gfconfigtableindexdefinition-methods-is_valid_definition) | `func is_valid_definition() -> bool:` |
| 方法 | [`make_key`](#member-gfconfigtableindexdefinition-methods-make_key) | `func make_key(record: Dictionary) -> String:` |
| 方法 | [`duplicate_index`](#member-gfconfigtableindexdefinition-methods-duplicate_index) | `func duplicate_index() -> GFConfigTableIndexDefinition:` |
| 方法 | [`describe`](#member-gfconfigtableindexdefinition-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigtableindexdefinition-properties-index_id"></a>

### `index_id`

- API：`public`

```gdscript
var index_id: StringName = &""
```

索引稳定标识。为空时会根据字段名生成。

<a id="member-gfconfigtableindexdefinition-properties-field_names"></a>

### `field_names`

- API：`public`

```gdscript
var field_names: PackedStringArray = PackedStringArray()
```

参与索引的字段名，顺序会影响复合键。

<a id="member-gfconfigtableindexdefinition-properties-unique"></a>

### `unique`

- API：`public`

```gdscript
var unique: bool = false
```

为 true 时校验表数据中该复合键唯一。

<a id="member-gfconfigtableindexdefinition-properties-allow_null_values"></a>

### `allow_null_values`

- API：`public`

```gdscript
var allow_null_values: bool = true
```

是否允许索引键中出现 null 值。

<a id="member-gfconfigtableindexdefinition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供导入器、编辑器或项目层扩展使用。

结构：

- `metadata`: Dictionary，保存导入器、编辑器或项目层附加到当前索引的元数据。

## 方法

<a id="member-gfconfigtableindexdefinition-methods-get_index_id"></a>

### `get_index_id`

- API：`public`

```gdscript
func get_index_id() -> StringName:
```

获取稳定索引标识。

返回：索引标识。

<a id="member-gfconfigtableindexdefinition-methods-is_valid_definition"></a>

### `is_valid_definition`

- API：`public`

```gdscript
func is_valid_definition() -> bool:
```

检查索引声明是否有效。

返回：有效返回 true。

<a id="member-gfconfigtableindexdefinition-methods-make_key"></a>

### `make_key`

- API：`public`

```gdscript
func make_key(record: Dictionary) -> String:
```

根据记录构建索引键。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 记录数据。 |

返回：索引键；字段缺失或 null 不允许时返回空字符串。

结构：

- `record`: Dictionary，用于构建索引键的配置记录。

<a id="member-gfconfigtableindexdefinition-methods-duplicate_index"></a>

### `duplicate_index`

- API：`public`

```gdscript
func duplicate_index() -> GFConfigTableIndexDefinition:
```

创建同内容拷贝。

返回：新索引声明。

<a id="member-gfconfigtableindexdefinition-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出索引声明摘要。

返回：索引声明字典。

结构：

- `return`: Dictionary，包含 index_id、field_names、unique、allow_null_values 和 metadata。
