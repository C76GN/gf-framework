# GFSaveMigrationStep

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_migration_step.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`9.0.0`

单向相邻版本迁移步骤协议。 空 section_id 表示文档级迁移；非空 section_id 表示单个分区迁移。 每个步骤只允许 `N -> N + 1`，以消除路径歧义并保持迁移链可审计。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`step_id`](#member-gfsavemigrationstep-properties-step_id) | `var step_id: StringName = &""` |
| 属性 | [`schema_id`](#member-gfsavemigrationstep-properties-schema_id) | `var schema_id: StringName = &""` |
| 属性 | [`section_id`](#member-gfsavemigrationstep-properties-section_id) | `var section_id: StringName = &""` |
| 属性 | [`from_version`](#member-gfsavemigrationstep-properties-from_version) | `var from_version: int = 0` |
| 属性 | [`to_version`](#member-gfsavemigrationstep-properties-to_version) | `var to_version: int = 0` |
| 方法 | [`is_document_step`](#member-gfsavemigrationstep-methods-is_document_step) | `func is_document_step() -> bool:` |
| 方法 | [`validate_step`](#member-gfsavemigrationstep-methods-validate_step) | `func validate_step() -> Dictionary:` |
| 方法 | [`describe_step`](#member-gfsavemigrationstep-methods-describe_step) | `func describe_step() -> Dictionary:` |
| 方法 | [`_migrate_document`](#member-gfsavemigrationstep-methods-_migrate_document) | `func _migrate_document( document: GFSaveDocument, _context: Dictionary = {} ) -> GFSaveDocument:` |
| 方法 | [`_migrate_section`](#member-gfsavemigrationstep-methods-_migrate_section) | `func _migrate_section( section: GFSaveSection, _context: Dictionary = {} ) -> GFSaveSection:` |

## 属性

<a id="member-gfsavemigrationstep-properties-step_id"></a>

### `step_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var step_id: StringName = &""
```

稳定步骤 ID，用于诊断与审计。

<a id="member-gfsavemigrationstep-properties-schema_id"></a>

### `schema_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var schema_id: StringName = &""
```

步骤所属项目 schema ID。

<a id="member-gfsavemigrationstep-properties-section_id"></a>

### `section_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var section_id: StringName = &""
```

目标分区 ID；为空表示文档级迁移。

<a id="member-gfsavemigrationstep-properties-from_version"></a>

### `from_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var from_version: int = 0
```

来源版本。

<a id="member-gfsavemigrationstep-properties-to_version"></a>

### `to_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var to_version: int = 0
```

目标版本，必须等于 from_version + 1。

## 方法

<a id="member-gfsavemigrationstep-methods-is_document_step"></a>

### `is_document_step`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_document_step() -> bool:
```

检查是否为文档级步骤。

返回：section_id 为空时返回 true。

<a id="member-gfsavemigrationstep-methods-validate_step"></a>

### `validate_step`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func validate_step() -> Dictionary:
```

校验步骤身份和版本边。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsavemigrationstep-methods-describe_step"></a>

### `describe_step`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func describe_step() -> Dictionary:
```

描述步骤。

返回：步骤描述。

结构：

- `return`: Dictionary with step_id, schema_id, section_id, scope, from_version, and to_version.

<a id="member-gfsavemigrationstep-methods-_migrate_document"></a>

### `_migrate_document`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _migrate_document( document: GFSaveDocument, _context: Dictionary = {} ) -> GFSaveDocument:
```

执行文档级迁移。 输入是隔离副本；返回 null 表示失败。Registry 会强制保持 schema_id， 并在步骤成功后写入声明的目标版本。

参数：

| 名称 | 说明 |
|---|---|
| `document` | 当前文档副本。 |
| `_context` | 调用方迁移上下文副本。 |

返回：迁移后的文档；失败时返回 null。

结构：

- `_context`: Dictionary with caller-defined migration context and registry-provided step fields.

<a id="member-gfsavemigrationstep-methods-_migrate_section"></a>

### `_migrate_section`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _migrate_section( section: GFSaveSection, _context: Dictionary = {} ) -> GFSaveSection:
```

执行分区级迁移。 输入是隔离副本；返回 null 表示失败。Registry 会强制保持 section_id， 并在步骤成功后写入声明的目标版本。

参数：

| 名称 | 说明 |
|---|---|
| `section` | 当前分区副本。 |
| `_context` | 调用方迁移上下文副本。 |

返回：迁移后的分区；失败时返回 null。

结构：

- `_context`: Dictionary with caller-defined migration context and registry-provided step fields.
