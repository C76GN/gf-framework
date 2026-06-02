# GFConfigTableMergeTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_merge_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

配置表补丁合并工具。 提供 Array[Dictionary] 与 Dictionary 表的通用补丁合并，适合导表后处理、 编辑器工具或项目自己的配置包流程使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`merge_tables`](#member-gfconfigtablemergetools-methods-merge_tables) | `static func merge_tables( base_table: Variant, patch_table: Variant, policy: GFConfigTableMergePolicy = null ) -> Dictionary:` |

## 方法

<a id="member-gfconfigtablemergetools-methods-merge_tables"></a>

### `merge_tables`

- API：`public`

```gdscript
static func merge_tables( base_table: Variant, patch_table: Variant, policy: GFConfigTableMergePolicy = null ) -> Dictionary:
```

合并 base 表与 patch 表。

参数：

| 名称 | 说明 |
|---|---|
| `base_table` | Array[Dictionary] 或 Dictionary 形式的基础表。 |
| `patch_table` | Array[Dictionary] 或 Dictionary 形式的补丁表。 |
| `policy` | 可选合并策略；为空时使用默认策略。 |

返回：结果字典，包含 ok、data、issues 与统计信息。

结构：

- `base_table`: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
- `patch_table`: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
- `return`: GFConfigValidationReport 兼容 Dictionary，额外包含 data、dictionary_output、base_count、inserted_count、updated_count 和 deleted_count。
