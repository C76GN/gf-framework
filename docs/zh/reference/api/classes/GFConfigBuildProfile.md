# GFConfigBuildProfile

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_build_profile.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

配置表构建过滤配置。 用 groups 与 tags 描述一组通用过滤条件，可用于导出前裁剪 schema 或记录。 具体分组名称由项目决定，GF 不内置 client、server 或 editor 语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`profile_id`](#member-gfconfigbuildprofile-properties-profile_id) | `var profile_id: StringName = &""` |
| 属性 | [`include_groups`](#member-gfconfigbuildprofile-properties-include_groups) | `var include_groups: PackedStringArray = PackedStringArray()` |
| 属性 | [`exclude_groups`](#member-gfconfigbuildprofile-properties-exclude_groups) | `var exclude_groups: PackedStringArray = PackedStringArray()` |
| 属性 | [`include_tags`](#member-gfconfigbuildprofile-properties-include_tags) | `var include_tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`exclude_tags`](#member-gfconfigbuildprofile-properties-exclude_tags) | `var exclude_tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`default_include`](#member-gfconfigbuildprofile-properties-default_include) | `var default_include: bool = true` |
| 属性 | [`record_metadata_field`](#member-gfconfigbuildprofile-properties-record_metadata_field) | `var record_metadata_field: StringName = &"_metadata"` |
| 属性 | [`groups_key`](#member-gfconfigbuildprofile-properties-groups_key) | `var groups_key: StringName = &"groups"` |
| 属性 | [`tags_key`](#member-gfconfigbuildprofile-properties-tags_key) | `var tags_key: StringName = &"tags"` |
| 属性 | [`metadata`](#member-gfconfigbuildprofile-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`allows_metadata`](#member-gfconfigbuildprofile-methods-allows_metadata) | `func allows_metadata(source_metadata: Dictionary) -> bool:` |
| 方法 | [`filter_schema`](#member-gfconfigbuildprofile-methods-filter_schema) | `func filter_schema(schema: GFConfigTableSchema) -> GFConfigTableSchema:` |
| 方法 | [`filter_records`](#member-gfconfigbuildprofile-methods-filter_records) | `func filter_records(table_data: Variant) -> Variant:` |
| 方法 | [`duplicate_profile`](#member-gfconfigbuildprofile-methods-duplicate_profile) | `func duplicate_profile() -> GFConfigBuildProfile:` |
| 方法 | [`describe`](#member-gfconfigbuildprofile-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigbuildprofile-properties-profile_id"></a>

### `profile_id`

- API：`public`

```gdscript
var profile_id: StringName = &""
```

Profile 稳定标识。

<a id="member-gfconfigbuildprofile-properties-include_groups"></a>

### `include_groups`

- API：`public`

```gdscript
var include_groups: PackedStringArray = PackedStringArray()
```

为空时不限制包含分组；非空时 metadata 至少命中一个分组才通过。

<a id="member-gfconfigbuildprofile-properties-exclude_groups"></a>

### `exclude_groups`

- API：`public`

```gdscript
var exclude_groups: PackedStringArray = PackedStringArray()
```

命中任意排除分组时过滤。

<a id="member-gfconfigbuildprofile-properties-include_tags"></a>

### `include_tags`

- API：`public`

```gdscript
var include_tags: PackedStringArray = PackedStringArray()
```

为空时不限制包含标签；非空时 metadata 至少命中一个标签才通过。

<a id="member-gfconfigbuildprofile-properties-exclude_tags"></a>

### `exclude_tags`

- API：`public`

```gdscript
var exclude_tags: PackedStringArray = PackedStringArray()
```

命中任意排除标签时过滤。

<a id="member-gfconfigbuildprofile-properties-default_include"></a>

### `default_include`

- API：`public`

```gdscript
var default_include: bool = true
```

metadata 缺少 groups/tags 时是否默认保留。

<a id="member-gfconfigbuildprofile-properties-record_metadata_field"></a>

### `record_metadata_field`

- API：`public`

```gdscript
var record_metadata_field: StringName = &"_metadata"
```

记录中存放元数据的字段名。

<a id="member-gfconfigbuildprofile-properties-groups_key"></a>

### `groups_key`

- API：`public`

```gdscript
var groups_key: StringName = &"groups"
```

metadata 中表示分组的键。

<a id="member-gfconfigbuildprofile-properties-tags_key"></a>

### `tags_key`

- API：`public`

```gdscript
var tags_key: StringName = &"tags"
```

metadata 中表示标签的键。

<a id="member-gfconfigbuildprofile-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目工具扩展使用。

结构：

- `metadata`: Dictionary，保存项目工具附加到当前构建 Profile 的元数据。

## 方法

<a id="member-gfconfigbuildprofile-methods-allows_metadata"></a>

### `allows_metadata`

- API：`public`

```gdscript
func allows_metadata(source_metadata: Dictionary) -> bool:
```

判断一份 metadata 是否通过当前 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `source_metadata` | 待检查元数据。 |

返回：通过时返回 true。

结构：

- `source_metadata`: Dictionary，包含可选 groups_key / tags_key 条目，值可为字符串或字符串数组。

<a id="member-gfconfigbuildprofile-methods-filter_schema"></a>

### `filter_schema`

- API：`public`

```gdscript
func filter_schema(schema: GFConfigTableSchema) -> GFConfigTableSchema:
```

过滤 schema，返回 schema 副本。

参数：

| 名称 | 说明 |
|---|---|
| `schema` | 原 schema。 |

返回：过滤后的 schema；schema 为空时返回 null。

<a id="member-gfconfigbuildprofile-methods-filter_records"></a>

### `filter_records`

- API：`public`

```gdscript
func filter_records(table_data: Variant) -> Variant:
```

过滤表记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_data` | Array[Dictionary] 或 Dictionary 表。 |

返回：与输入同形状的过滤结果；输入无效时返回原值副本。

结构：

- `table_data`: Variant，支持 Array[Dictionary]、Dictionary 表；其他值会按原形复制返回。
- `return`: Variant，过滤后的表数据；有效表会保持输入容器形态。

<a id="member-gfconfigbuildprofile-methods-duplicate_profile"></a>

### `duplicate_profile`

- API：`public`

```gdscript
func duplicate_profile() -> GFConfigBuildProfile:
```

创建同内容拷贝。

返回：新 Profile。

<a id="member-gfconfigbuildprofile-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出 Profile 摘要。

返回：Profile 摘要字典。

结构：

- `return`: Dictionary，包含 profile_id、分组/标签过滤器、元数据键设置和 metadata。
