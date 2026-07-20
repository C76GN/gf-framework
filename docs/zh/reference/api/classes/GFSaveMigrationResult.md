# GFSaveMigrationResult

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_migration_result.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`9.0.0`

存档迁移终态结果。 结果持有隔离文档、迁移轨迹和失败位置。失败时不暴露部分迁移文档， 确保调用方只能提交完整成功的迁移结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_successful`](#member-gfsavemigrationresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_document`](#member-gfsavemigrationresult-methods-get_document) | `func get_document() -> GFSaveDocument:` |
| 方法 | [`get_error_code`](#member-gfsavemigrationresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfsavemigrationresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_failed_step_id`](#member-gfsavemigrationresult-methods-get_failed_step_id) | `func get_failed_step_id() -> StringName:` |
| 方法 | [`was_migrated`](#member-gfsavemigrationresult-methods-was_migrated) | `func was_migrated() -> bool:` |
| 方法 | [`get_trace`](#member-gfsavemigrationresult-methods-get_trace) | `func get_trace() -> Array[Dictionary]:` |
| 方法 | [`to_dict`](#member-gfsavemigrationresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_result`](#member-gfsavemigrationresult-methods-duplicate_result) | `func duplicate_result() -> GFSaveMigrationResult:` |

## 方法

<a id="member-gfsavemigrationresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_successful() -> bool:
```

检查迁移是否完整成功。

返回：成功时返回 true。

<a id="member-gfsavemigrationresult-methods-get_document"></a>

### `get_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_document() -> GFSaveDocument:
```

获取成功文档副本。

返回：完整迁移后的文档；失败时返回 null。

<a id="member-gfsavemigrationresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_error_code() -> Error:
```

获取错误码。

返回：Godot Error 码。

<a id="member-gfsavemigrationresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_error() -> String:
```

获取错误说明。

返回：失败说明。

<a id="member-gfsavemigrationresult-methods-get_failed_step_id"></a>

### `get_failed_step_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_failed_step_id() -> StringName:
```

获取失败步骤 ID。

返回：失败步骤 ID；非步骤失败时为空。

<a id="member-gfsavemigrationresult-methods-was_migrated"></a>

### `was_migrated`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func was_migrated() -> bool:
```

检查是否实际执行过迁移步骤。

返回：轨迹非空时返回 true。

<a id="member-gfsavemigrationresult-methods-get_trace"></a>

### `get_trace`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_trace() -> Array[Dictionary]:
```

获取迁移轨迹副本。

返回：按执行顺序排列的步骤轨迹。

结构：

- `return`: Array[Dictionary] with step_id, schema_id, section_id, scope, from_version, and to_version.

<a id="member-gfsavemigrationresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为诊断字典。

返回：JSON-safe 迁移结果摘要。

结构：

- `return`: Dictionary with ok, error_code, error, failed_step_id, source_document_version, target_document_version, source_section_versions, target_section_versions, migrated, trace, and document.

<a id="member-gfsavemigrationresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_result() -> GFSaveMigrationResult:
```

创建结果副本。

返回：隔离结果。
