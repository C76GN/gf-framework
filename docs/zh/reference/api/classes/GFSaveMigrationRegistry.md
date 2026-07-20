# GFSaveMigrationRegistry

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_migration_registry.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`9.0.0`

确定性存档迁移注册表。 Registry 强制每个 schema/owner/from_version 只有一条相邻版本边， 在隔离副本上先执行文档迁移，再按 section_id 排序执行分区迁移。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_step`](#member-gfsavemigrationregistry-methods-register_step) | `func register_step(step: GFSaveMigrationStep) -> bool:` |
| 方法 | [`unregister_step`](#member-gfsavemigrationregistry-methods-unregister_step) | `func unregister_step( schema_id: StringName, section_id: StringName, from_version: int ) -> bool:` |
| 方法 | [`clear`](#member-gfsavemigrationregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`has_step`](#member-gfsavemigrationregistry-methods-has_step) | `func has_step( schema_id: StringName, section_id: StringName, from_version: int ) -> bool:` |
| 方法 | [`describe_steps`](#member-gfsavemigrationregistry-methods-describe_steps) | `func describe_steps() -> Array[Dictionary]:` |
| 方法 | [`build_plan`](#member-gfsavemigrationregistry-methods-build_plan) | `func build_plan( document: GFSaveDocument, target_schema: GFSaveDocumentSchema ) -> Dictionary:` |
| 方法 | [`migrate`](#member-gfsavemigrationregistry-methods-migrate) | `func migrate( document: GFSaveDocument, target_schema: GFSaveDocumentSchema, context: Dictionary = {} ) -> GFSaveMigrationResult:` |

## 方法

<a id="member-gfsavemigrationregistry-methods-register_step"></a>

### `register_step`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func register_step(step: GFSaveMigrationStep) -> bool:
```

注册唯一迁移步骤。

参数：

| 名称 | 说明 |
|---|---|
| `step` | 有效的相邻版本迁移步骤。 |

返回：步骤有效且 edge 与 step_id 均未占用时返回 true。

<a id="member-gfsavemigrationregistry-methods-unregister_step"></a>

### `unregister_step`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func unregister_step( schema_id: StringName, section_id: StringName, from_version: int ) -> bool:
```

注销指定迁移边。

参数：

| 名称 | 说明 |
|---|---|
| `schema_id` | 项目 schema ID。 |
| `section_id` | 分区 ID；为空表示文档级迁移。 |
| `from_version` | 来源版本。 |

返回：原本存在时返回 true。

<a id="member-gfsavemigrationregistry-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func clear() -> void:
```

清空全部迁移步骤。

<a id="member-gfsavemigrationregistry-methods-has_step"></a>

### `has_step`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func has_step( schema_id: StringName, section_id: StringName, from_version: int ) -> bool:
```

检查指定版本边是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `schema_id` | 项目 schema ID。 |
| `section_id` | 分区 ID；为空表示文档级迁移。 |
| `from_version` | 来源版本。 |

返回：已注册时返回 true。

<a id="member-gfsavemigrationregistry-methods-describe_steps"></a>

### `describe_steps`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func describe_steps() -> Array[Dictionary]:
```

获取排序后的步骤描述。

返回：步骤描述数组。

结构：

- `return`: Array[Dictionary] following GFSaveMigrationStep.describe_step().

<a id="member-gfsavemigrationregistry-methods-build_plan"></a>

### `build_plan`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func build_plan( document: GFSaveDocument, target_schema: GFSaveDocumentSchema ) -> Dictionary:
```

构建不执行迁移代码的路径计划。 计划只验证当前已存在的文档和分区版本边；文档步骤可能新增或移除的 分区仍会在真实迁移后的最终 schema 校验中判定。

参数：

| 名称 | 说明 |
|---|---|
| `document` | 来源文档。 |
| `target_schema` | 目标 schema。 |

返回：静态迁移计划。

结构：

- `return`: Dictionary with ok, migration_required, requires_document_step_evaluation, source_document_version, target_document_version, source_section_versions, target_section_versions, steps, error, and missing_edge.

<a id="member-gfsavemigrationregistry-methods-migrate"></a>

### `migrate`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func migrate( document: GFSaveDocument, target_schema: GFSaveDocumentSchema, context: Dictionary = {} ) -> GFSaveMigrationResult:
```

把文档事务式迁移到目标 schema。 迁移期间只操作副本；所有步骤和最终 schema 校验成功后才在结果中暴露文档。

参数：

| 名称 | 说明 |
|---|---|
| `document` | 来源文档。 |
| `target_schema` | 目标 schema。 |
| `context` | 项目定义的迁移上下文。 |

返回：迁移终态结果。

结构：

- `context`: Dictionary with caller-defined ephemeral migration data.
