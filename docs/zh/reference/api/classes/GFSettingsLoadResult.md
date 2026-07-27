# GFSettingsLoadResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings/gf_settings_load_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

设置加载操作的不可变终态快照。 结果将“合法空设置”与缺失、损坏、未来版本和底层存储失败明确区分， 并保留实际应用状态、恢复动作和底层读取证据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_LOADED`](#member-gfsettingsloadresult-constants-status_loaded) | `const STATUS_LOADED: StringName = &"loaded"` |
| 常量 | [`STATUS_RECOVERED`](#member-gfsettingsloadresult-constants-status_recovered) | `const STATUS_RECOVERED: StringName = &"recovered"` |
| 常量 | [`STATUS_INVALID_REQUEST`](#member-gfsettingsloadresult-constants-status_invalid_request) | `const STATUS_INVALID_REQUEST: StringName = &"invalid_request"` |
| 常量 | [`STATUS_MISSING`](#member-gfsettingsloadresult-constants-status_missing) | `const STATUS_MISSING: StringName = &"missing"` |
| 常量 | [`STATUS_CORRUPT`](#member-gfsettingsloadresult-constants-status_corrupt) | `const STATUS_CORRUPT: StringName = &"corrupt"` |
| 常量 | [`STATUS_FUTURE_SCHEMA`](#member-gfsettingsloadresult-constants-status_future_schema) | `const STATUS_FUTURE_SCHEMA: StringName = &"future_schema"` |
| 常量 | [`STATUS_MIGRATION_FAILED`](#member-gfsettingsloadresult-constants-status_migration_failed) | `const STATUS_MIGRATION_FAILED: StringName = &"migration_failed"` |
| 常量 | [`STATUS_STORAGE_FAILED`](#member-gfsettingsloadresult-constants-status_storage_failed) | `const STATUS_STORAGE_FAILED: StringName = &"storage_failed"` |
| 方法 | [`is_successful`](#member-gfsettingsloadresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfsettingsloadresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_file_name`](#member-gfsettingsloadresult-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`was_applied`](#member-gfsettingsloadresult-methods-was_applied) | `func was_applied() -> bool:` |
| 方法 | [`was_recovered`](#member-gfsettingsloadresult-methods-was_recovered) | `func was_recovered() -> bool:` |
| 方法 | [`get_recovery_action`](#member-gfsettingsloadresult-methods-get_recovery_action) | `func get_recovery_action() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfsettingsloadresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfsettingsloadresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_storage_result`](#member-gfsettingsloadresult-methods-get_storage_result) | `func get_storage_result() -> GFStorageReadResult:` |
| 方法 | [`duplicate_result`](#member-gfsettingsloadresult-methods-duplicate_result) | `func duplicate_result() -> GFSettingsLoadResult:` |
| 方法 | [`to_dict`](#member-gfsettingsloadresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfsettingsloadresult-constants-status_loaded"></a>

### `STATUS_LOADED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_LOADED: StringName = &"loaded"
```

持久化设置已成功读取并应用。

<a id="member-gfsettingsloadresult-constants-status_recovered"></a>

### `STATUS_RECOVERED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RECOVERED: StringName = &"recovered"
```

调用方选择的显式恢复动作已完成。

<a id="member-gfsettingsloadresult-constants-status_invalid_request"></a>

### `STATUS_INVALID_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"
```

文件名、路径或读取请求无效。

<a id="member-gfsettingsloadresult-constants-status_missing"></a>

### `STATUS_MISSING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_MISSING: StringName = &"missing"
```

设置文件不存在。

<a id="member-gfsettingsloadresult-constants-status_corrupt"></a>

### `STATUS_CORRUPT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_CORRUPT: StringName = &"corrupt"
```

设置文件格式、载荷或完整性损坏。

<a id="member-gfsettingsloadresult-constants-status_future_schema"></a>

### `STATUS_FUTURE_SCHEMA`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_FUTURE_SCHEMA: StringName = &"future_schema"
```

设置文件来自当前运行时无法读取的未来 schema。

<a id="member-gfsettingsloadresult-constants-status_migration_failed"></a>

### `STATUS_MIGRATION_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_MIGRATION_FAILED: StringName = &"migration_failed"
```

设置文件的迁移链缺失或迁移失败。

<a id="member-gfsettingsloadresult-constants-status_storage_failed"></a>

### `STATUS_STORAGE_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_STORAGE_FAILED: StringName = &"storage_failed"
```

底层存储读取失败或不可用。

## 方法

<a id="member-gfsettingsloadresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查加载是否进入成功终态。

返回：设置已加载或已按显式策略恢复时返回 true。

<a id="member-gfsettingsloadresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定加载状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfsettingsloadresult-methods-get_file_name"></a>

### `get_file_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_file_name() -> String:
```

获取本次加载使用的文件名。

返回：解析默认值后的设置文件名。

<a id="member-gfsettingsloadresult-methods-was_applied"></a>

### `was_applied`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func was_applied() -> bool:
```

检查本次操作是否替换了有效设置状态。

返回：已应用持久化载荷或默认值恢复时返回 true。

<a id="member-gfsettingsloadresult-methods-was_recovered"></a>

### `was_recovered`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func was_recovered() -> bool:
```

检查本次操作是否执行了显式恢复动作。

返回：使用恢复策略完成时返回 true。

<a id="member-gfsettingsloadresult-methods-get_recovery_action"></a>

### `get_recovery_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_recovery_action() -> StringName:
```

获取实际恢复动作。

返回：未恢复时为空，否则为 `GFSettingsRecoveryPolicy.ACTION_*` 常量之一。

<a id="member-gfsettingsloadresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取 Godot Error 码。

返回：成功时为 OK。

<a id="member-gfsettingsloadresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

获取稳定错误描述。

返回：成功时为空。

<a id="member-gfsettingsloadresult-methods-get_storage_result"></a>

### `get_storage_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_storage_result() -> GFStorageReadResult:
```

获取底层存储读取结果副本。

返回：原始读取证据的隔离副本；读取未启动时为 null。

<a id="member-gfsettingsloadresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFSettingsLoadResult:
```

创建结果的隔离副本。

返回：新结果对象。

<a id="member-gfsettingsloadresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不包含设置载荷的报告字典。

返回：加载终态摘要。

结构：

- `return`: Dictionary with ok, status, file_name, applied, recovered, recovery_action, error_code, error, and payload-free storage_result fields.
