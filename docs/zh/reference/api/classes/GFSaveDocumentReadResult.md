# GFSaveDocumentReadResult

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_document_read_result.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`9.0.0`

存档文档读取终态结果。 结果保留物理存储读取、文档解析、schema 校验和迁移状态，避免调用方 把读取失败、格式损坏、未来版本或迁移缺口都误判为空 Dictionary。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_LOADED`](#member-gfsavedocumentreadresult-constants-status_loaded) | `const STATUS_LOADED: StringName = &"loaded"` |
| 常量 | [`STATUS_MIGRATED`](#member-gfsavedocumentreadresult-constants-status_migrated) | `const STATUS_MIGRATED: StringName = &"migrated"` |
| 常量 | [`STATUS_FAILED`](#member-gfsavedocumentreadresult-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 方法 | [`is_successful`](#member-gfsavedocumentreadresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`was_migrated`](#member-gfsavedocumentreadresult-methods-was_migrated) | `func was_migrated() -> bool:` |
| 方法 | [`get_status`](#member-gfsavedocumentreadresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_document`](#member-gfsavedocumentreadresult-methods-get_document) | `func get_document() -> GFSaveDocument:` |
| 方法 | [`get_storage_result`](#member-gfsavedocumentreadresult-methods-get_storage_result) | `func get_storage_result() -> GFStorageReadResult:` |
| 方法 | [`get_migration_result`](#member-gfsavedocumentreadresult-methods-get_migration_result) | `func get_migration_result() -> GFSaveMigrationResult:` |
| 方法 | [`get_validation_report`](#member-gfsavedocumentreadresult-methods-get_validation_report) | `func get_validation_report() -> Dictionary:` |
| 方法 | [`get_error_code`](#member-gfsavedocumentreadresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfsavedocumentreadresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`to_dict`](#member-gfsavedocumentreadresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_result`](#member-gfsavedocumentreadresult-methods-duplicate_result) | `func duplicate_result() -> GFSaveDocumentReadResult:` |

## 常量

<a id="member-gfsavedocumentreadresult-constants-status_loaded"></a>

### `STATUS_LOADED`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STATUS_LOADED: StringName = &"loaded"
```

文档无需迁移并已加载。

<a id="member-gfsavedocumentreadresult-constants-status_migrated"></a>

### `STATUS_MIGRATED`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STATUS_MIGRATED: StringName = &"migrated"
```

文档迁移后已加载。

<a id="member-gfsavedocumentreadresult-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

文档读取失败。

## 方法

<a id="member-gfsavedocumentreadresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_successful() -> bool:
```

检查读取、解析、迁移和最终校验是否全部成功。

返回：成功时返回 true。

<a id="member-gfsavedocumentreadresult-methods-was_migrated"></a>

### `was_migrated`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func was_migrated() -> bool:
```

检查是否执行过迁移。

返回：migrated 状态返回 true。

<a id="member-gfsavedocumentreadresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_status() -> StringName:
```

获取终态状态。

返回：loaded、migrated 或 failed。

<a id="member-gfsavedocumentreadresult-methods-get_document"></a>

### `get_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_document() -> GFSaveDocument:
```

获取有效文档副本。

返回：成功文档；失败时返回 null。

<a id="member-gfsavedocumentreadresult-methods-get_storage_result"></a>

### `get_storage_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_storage_result() -> GFStorageReadResult:
```

获取底层存储读取结果副本。

返回：底层结果；尚未进入存储读取时可为 null。

<a id="member-gfsavedocumentreadresult-methods-get_migration_result"></a>

### `get_migration_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_migration_result() -> GFSaveMigrationResult:
```

获取迁移结果副本。

返回：运行过迁移注册表时的结果，否则为 null。

<a id="member-gfsavedocumentreadresult-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_validation_report() -> Dictionary:
```

获取最终校验报告副本。

返回：文档或目标 schema 校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report.

<a id="member-gfsavedocumentreadresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_error_code() -> Error:
```

获取错误码。

返回：Godot Error 码。

<a id="member-gfsavedocumentreadresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_error() -> String:
```

获取错误说明。

返回：失败说明。

<a id="member-gfsavedocumentreadresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为诊断字典。

返回：读取结果摘要。

结构：

- `return`: Dictionary with ok, status, error_code, error, migrated, document, storage_result, migration_result, and validation_report.

<a id="member-gfsavedocumentreadresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_result() -> GFSaveDocumentReadResult:
```

创建结果副本。

返回：隔离结果。
