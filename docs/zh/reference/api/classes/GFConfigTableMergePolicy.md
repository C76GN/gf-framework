# GFConfigTableMergePolicy

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_merge_policy.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

配置表补丁合并策略。 描述如何识别记录、覆盖记录和处理删除标记。它只定义通用合并规则， 不绑定热更、模组、DLC 或任意项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`UpdateMode`](#member-gfconfigtablemergepolicy-enums-updatemode) | `enum UpdateMode` |
| 属性 | [`key_fields`](#member-gfconfigtablemergepolicy-properties-key_fields) | `var key_fields: PackedStringArray = PackedStringArray(["id"])` |
| 属性 | [`update_mode`](#member-gfconfigtablemergepolicy-properties-update_mode) | `var update_mode: UpdateMode = UpdateMode.MERGE_FIELDS` |
| 属性 | [`allow_insert`](#member-gfconfigtablemergepolicy-properties-allow_insert) | `var allow_insert: bool = true` |
| 属性 | [`allow_update`](#member-gfconfigtablemergepolicy-properties-allow_update) | `var allow_update: bool = true` |
| 属性 | [`allow_delete`](#member-gfconfigtablemergepolicy-properties-allow_delete) | `var allow_delete: bool = true` |
| 属性 | [`delete_marker_field`](#member-gfconfigtablemergepolicy-properties-delete_marker_field) | `var delete_marker_field: StringName = &"_delete"` |
| 属性 | [`delete_marker_value`](#member-gfconfigtablemergepolicy-properties-delete_marker_value) | `var delete_marker_value: Variant = true` |
| 属性 | [`preserve_base_order`](#member-gfconfigtablemergepolicy-properties-preserve_base_order) | `var preserve_base_order: bool = true` |
| 属性 | [`metadata`](#member-gfconfigtablemergepolicy-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`is_delete_record`](#member-gfconfigtablemergepolicy-methods-is_delete_record) | `func is_delete_record(record: Dictionary) -> bool:` |
| 方法 | [`make_record_key`](#member-gfconfigtablemergepolicy-methods-make_record_key) | `func make_record_key(record: Dictionary, outer_key: Variant = null) -> String:` |
| 方法 | [`merge_record`](#member-gfconfigtablemergepolicy-methods-merge_record) | `func merge_record(base_record: Dictionary, patch_record: Dictionary) -> Dictionary:` |
| 方法 | [`duplicate_policy`](#member-gfconfigtablemergepolicy-methods-duplicate_policy) | `func duplicate_policy() -> GFConfigTableMergePolicy:` |
| 方法 | [`describe`](#member-gfconfigtablemergepolicy-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfconfigtablemergepolicy-enums-updatemode"></a>

### `UpdateMode`

- API：`public`

```gdscript
enum UpdateMode { ## patch 记录整体替换 base 记录。 REPLACE_RECORD, ## patch 记录与 base 记录按字段合并，嵌套 Dictionary 递归合并。 MERGE_FIELDS, }
```

记录更新方式。

## 属性

<a id="member-gfconfigtablemergepolicy-properties-key_fields"></a>

### `key_fields`

- API：`public`

```gdscript
var key_fields: PackedStringArray = PackedStringArray(["id"])
```

用于生成记录键的字段。为空时 Dictionary 表会优先使用外层 key。

<a id="member-gfconfigtablemergepolicy-properties-update_mode"></a>

### `update_mode`

- API：`public`

```gdscript
var update_mode: UpdateMode = UpdateMode.MERGE_FIELDS
```

更新已有记录时采用的合并方式。

<a id="member-gfconfigtablemergepolicy-properties-allow_insert"></a>

### `allow_insert`

- API：`public`

```gdscript
var allow_insert: bool = true
```

是否允许 patch 插入新记录。

<a id="member-gfconfigtablemergepolicy-properties-allow_update"></a>

### `allow_update`

- API：`public`

```gdscript
var allow_update: bool = true
```

是否允许 patch 更新已有记录。

<a id="member-gfconfigtablemergepolicy-properties-allow_delete"></a>

### `allow_delete`

- API：`public`

```gdscript
var allow_delete: bool = true
```

是否允许 patch 删除已有记录。

<a id="member-gfconfigtablemergepolicy-properties-delete_marker_field"></a>

### `delete_marker_field`

- API：`public`

```gdscript
var delete_marker_field: StringName = &"_delete"
```

删除标记字段。为空时不启用删除标记。

<a id="member-gfconfigtablemergepolicy-properties-delete_marker_value"></a>

### `delete_marker_value`

- API：`public`

```gdscript
var delete_marker_value: Variant = true
```

删除标记需要匹配的值。

结构：

- `delete_marker_value`: Variant，与删除标记字段比较的目标值。

<a id="member-gfconfigtablemergepolicy-properties-preserve_base_order"></a>

### `preserve_base_order`

- API：`public`

```gdscript
var preserve_base_order: bool = true
```

Array 表输出时是否保留 base 原有顺序，并把新增记录追加到末尾。

<a id="member-gfconfigtablemergepolicy-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目工具扩展使用。

结构：

- `metadata`: Dictionary，保存项目层附加到当前合并策略的元数据。

## 方法

<a id="member-gfconfigtablemergepolicy-methods-is_delete_record"></a>

### `is_delete_record`

- API：`public`

```gdscript
func is_delete_record(record: Dictionary) -> bool:
```

检查记录是否带有删除标记。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 记录。 |

返回：带有删除标记时返回 true。

结构：

- `record`: Dictionary，用于检查删除标记字段的配置记录。

<a id="member-gfconfigtablemergepolicy-methods-make_record_key"></a>

### `make_record_key`

- API：`public`

```gdscript
func make_record_key(record: Dictionary, outer_key: Variant = null) -> String:
```

根据记录生成稳定合并键。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 记录。 |
| `outer_key` | Dictionary 表外层 key。 |

返回：合并键，字段缺失时返回空字符串。

结构：

- `record`: Dictionary，用于构建合并键的配置记录。
- `outer_key`: Variant，key_fields 为空时用于构建合并键的外层 key。

<a id="member-gfconfigtablemergepolicy-methods-merge_record"></a>

### `merge_record`

- API：`public`

```gdscript
func merge_record(base_record: Dictionary, patch_record: Dictionary) -> Dictionary:
```

合并两条记录。

参数：

| 名称 | 说明 |
|---|---|
| `base_record` | 原始记录。 |
| `patch_record` | 补丁记录。 |

返回：合并后的记录。

结构：

- `base_record`: Dictionary，原始记录。
- `patch_record`: Dictionary，补丁记录。
- `return`: Dictionary，合并后的记录。

<a id="member-gfconfigtablemergepolicy-methods-duplicate_policy"></a>

### `duplicate_policy`

- API：`public`

```gdscript
func duplicate_policy() -> GFConfigTableMergePolicy:
```

创建同内容拷贝。

返回：新合并策略。

<a id="member-gfconfigtablemergepolicy-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出策略摘要。

返回：策略摘要字典。

结构：

- `return`: Dictionary，包含 key_fields、update_mode、权限开关、删除标记设置、preserve_base_order 和 metadata。
