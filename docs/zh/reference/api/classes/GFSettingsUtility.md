# GFSettingsUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings/gf_settings_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用设置注册、读写与持久化工具。 设置项以 StringName 键访问，可选使用 GFSettingDefinition 声明默认值和类型。 该工具只管理抽象设置值，不直接绑定窗口、音频、输入或任何项目业务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`setting_changed`](#member-gfsettingsutility-signals-setting_changed) | `signal setting_changed(key: StringName, old_value: Variant, new_value: Variant)` |
| 信号 | [`settings_load_completed`](#member-gfsettingsutility-signals-settings_load_completed) | `signal settings_load_completed(result: GFSettingsLoadResult)` |
| 信号 | [`settings_saved`](#member-gfsettingsutility-signals-settings_saved) | `signal settings_saved(data: Dictionary)` |
| 信号 | [`staged_setting_changed`](#member-gfsettingsutility-signals-staged_setting_changed) | `signal staged_setting_changed(key: StringName)` |
| 信号 | [`staged_settings_applied`](#member-gfsettingsutility-signals-staged_settings_applied) | `signal staged_settings_applied(report: Dictionary)` |
| 信号 | [`staged_settings_discarded`](#member-gfsettingsutility-signals-staged_settings_discarded) | `signal staged_settings_discarded(keys: PackedStringArray)` |
| 属性 | [`storage_file_name`](#member-gfsettingsutility-properties-storage_file_name) | `var storage_file_name: String = "settings.sav"` |
| 属性 | [`auto_load_on_init`](#member-gfsettingsutility-properties-auto_load_on_init) | `var auto_load_on_init: bool = true` |
| 属性 | [`auto_save_on_change`](#member-gfsettingsutility-properties-auto_save_on_change) | `var auto_save_on_change: bool = true` |
| 属性 | [`save_debounce_seconds`](#member-gfsettingsutility-properties-save_debounce_seconds) | `var save_debounce_seconds: float = 0.25` |
| 属性 | [`persistence_enabled`](#member-gfsettingsutility-properties-persistence_enabled) | `var persistence_enabled: bool = true:` |
| 方法 | [`init`](#member-gfsettingsutility-methods-init) | `func init() -> void:` |
| 方法 | [`get_required_utilities`](#member-gfsettingsutility-methods-get_required_utilities) | `func get_required_utilities() -> Array[Script]:` |
| 方法 | [`ready`](#member-gfsettingsutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`begin_activation`](#member-gfsettingsutility-methods-begin_activation) | `func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`begin_quiesce`](#member-gfsettingsutility-methods-begin_quiesce) | `func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`dispose`](#member-gfsettingsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`release_dependencies`](#member-gfsettingsutility-methods-release_dependencies) | `func release_dependencies() -> void:` |
| 方法 | [`register_definition`](#member-gfsettingsutility-methods-register_definition) | `func register_definition(definition: GFSettingDefinition, apply_default: bool = true) -> void:` |
| 方法 | [`register_setting`](#member-gfsettingsutility-methods-register_setting) | `func register_setting( key: StringName, default_value: Variant = null, value_type: GFSettingDefinition.ValueType = GFSettingDefinition.ValueType.ANY, persistent: bool = true, metadata: Dictionary = {} ) -> GFSettingDefinition:` |
| 方法 | [`register_definitions`](#member-gfsettingsutility-methods-register_definitions) | `func register_definitions(definitions: Array[GFSettingDefinition]) -> void:` |
| 方法 | [`get_definition`](#member-gfsettingsutility-methods-get_definition) | `func get_definition(key: StringName) -> GFSettingDefinition:` |
| 方法 | [`get_definitions`](#member-gfsettingsutility-methods-get_definitions) | `func get_definitions() -> Array[GFSettingDefinition]:` |
| 方法 | [`set_value`](#member-gfsettingsutility-methods-set_value) | `func set_value(key: StringName, value: Variant, save_after_change: bool = true) -> void:` |
| 方法 | [`stage_value`](#member-gfsettingsutility-methods-stage_value) | `func stage_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`get_staged_value`](#member-gfsettingsutility-methods-get_staged_value) | `func get_staged_value(key: StringName, fallback: Variant = null) -> Variant:` |
| 方法 | [`get_staged_or_value`](#member-gfsettingsutility-methods-get_staged_or_value) | `func get_staged_or_value(key: StringName, fallback: Variant = null) -> Variant:` |
| 方法 | [`has_staged_value`](#member-gfsettingsutility-methods-has_staged_value) | `func has_staged_value(key: StringName) -> bool:` |
| 方法 | [`has_staged_values`](#member-gfsettingsutility-methods-has_staged_values) | `func has_staged_values() -> bool:` |
| 方法 | [`get_staged_values`](#member-gfsettingsutility-methods-get_staged_values) | `func get_staged_values() -> Dictionary:` |
| 方法 | [`get_staged_keys`](#member-gfsettingsutility-methods-get_staged_keys) | `func get_staged_keys() -> PackedStringArray:` |
| 方法 | [`discard_staged_value`](#member-gfsettingsutility-methods-discard_staged_value) | `func discard_staged_value(key: StringName) -> bool:` |
| 方法 | [`discard_staged_values`](#member-gfsettingsutility-methods-discard_staged_values) | `func discard_staged_values() -> PackedStringArray:` |
| 方法 | [`apply_staged_values`](#member-gfsettingsutility-methods-apply_staged_values) | `func apply_staged_values(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_values`](#member-gfsettingsutility-methods-apply_values) | `func apply_values(values: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`begin_batch`](#member-gfsettingsutility-methods-begin_batch) | `func begin_batch() -> void:` |
| 方法 | [`end_batch`](#member-gfsettingsutility-methods-end_batch) | `func end_batch(save_after_change: bool = true) -> void:` |
| 方法 | [`queue_save`](#member-gfsettingsutility-methods-queue_save) | `func queue_save() -> void:` |
| 方法 | [`flush_pending_save`](#member-gfsettingsutility-methods-flush_pending_save) | `func flush_pending_save() -> Error:` |
| 方法 | [`get_value`](#member-gfsettingsutility-methods-get_value) | `func get_value(key: StringName, fallback: Variant = null) -> Variant:` |
| 方法 | [`has_setting`](#member-gfsettingsutility-methods-has_setting) | `func has_setting(key: StringName) -> bool:` |
| 方法 | [`reset_value`](#member-gfsettingsutility-methods-reset_value) | `func reset_value(key: StringName, save_after_change: bool = true) -> void:` |
| 方法 | [`reset_all`](#member-gfsettingsutility-methods-reset_all) | `func reset_all(save_after_change: bool = true) -> void:` |
| 方法 | [`to_dict`](#member-gfsettingsutility-methods-to_dict) | `func to_dict(persistent_only: bool = true) -> Dictionary:` |
| 方法 | [`replace_from_dict`](#member-gfsettingsutility-methods-replace_from_dict) | `func replace_from_dict(data: Dictionary, emit_changes: bool = true) -> void:` |
| 方法 | [`merge_from_dict`](#member-gfsettingsutility-methods-merge_from_dict) | `func merge_from_dict(data: Dictionary, emit_changes: bool = true) -> void:` |
| 方法 | [`load_settings`](#member-gfsettingsutility-methods-load_settings) | `func load_settings( file_name: String = "", recovery_policy: GFSettingsRecoveryPolicy = null ) -> GFSettingsLoadResult:` |
| 方法 | [`get_last_load_result`](#member-gfsettingsutility-methods-get_last_load_result) | `func get_last_load_result() -> GFSettingsLoadResult:` |
| 方法 | [`save_settings`](#member-gfsettingsutility-methods-save_settings) | `func save_settings(file_name: String = "") -> Error:` |
| 方法 | [`tick`](#member-gfsettingsutility-methods-tick) | `func tick(delta: float = 0.0) -> void:` |
| 方法 | [`_read_persisted_data`](#member-gfsettingsutility-methods-_read_persisted_data) | `func _read_persisted_data(file_name: String) -> GFStorageReadResult:` |
| 方法 | [`_write_persisted_data`](#member-gfsettingsutility-methods-_write_persisted_data) | `func _write_persisted_data(file_name: String, data: Dictionary) -> Error:` |

## 信号

<a id="member-gfsettingsutility-signals-setting_changed"></a>

### `setting_changed`

- API：`public`

```gdscript
signal setting_changed(key: StringName, old_value: Variant, new_value: Variant)
```

设置值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `old_value` | 旧值。 |
| `new_value` | 新值。 |

结构：

- `old_value`: Variant previous setting value or null when the setting did not exist.
- `new_value`: Variant next setting value or null when the setting was removed.

<a id="member-gfsettingsutility-signals-settings_load_completed"></a>

### `settings_load_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal settings_load_completed(result: GFSettingsLoadResult)
```

设置加载进入终态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 隔离的结构化加载结果。 |

<a id="member-gfsettingsutility-signals-settings_saved"></a>

### `settings_saved`

- API：`public`

```gdscript
signal settings_saved(data: Dictionary)
```

设置保存完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 已保存的持久化设置数据。 |

结构：

- `data`: Dictionary[String, Variant] saved persisted settings data produced by to_dict(true).

<a id="member-gfsettingsutility-signals-staged_setting_changed"></a>

### `staged_setting_changed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal staged_setting_changed(key: StringName)
```

暂存设置值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 暂存状态变化的设置键。 |

<a id="member-gfsettingsutility-signals-staged_settings_applied"></a>

### `staged_settings_applied`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal staged_settings_applied(report: Dictionary)
```

暂存设置值被应用到真实设置后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 应用报告。 |

结构：

- `report`: Dictionary with apply_values() report fields plus staged_applied_count, staged_remaining_count, and staged_applied_keys.

<a id="member-gfsettingsutility-signals-staged_settings_discarded"></a>

### `staged_settings_discarded`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal staged_settings_discarded(keys: PackedStringArray)
```

暂存设置值被丢弃后发出。

参数：

| 名称 | 说明 |
|---|---|
| `keys` | 被丢弃暂存值的设置键。 |

## 属性

<a id="member-gfsettingsutility-properties-storage_file_name"></a>

### `storage_file_name`

- API：`public`

```gdscript
var storage_file_name: String = "settings.sav"
```

默认持久化文件名。

<a id="member-gfsettingsutility-properties-auto_load_on_init"></a>

### `auto_load_on_init`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var auto_load_on_init: bool = true
```

standalone 模式在 init()、Architecture 模式在 activation 阶段是否自动读取持久化设置。

<a id="member-gfsettingsutility-properties-auto_save_on_change"></a>

### `auto_save_on_change`

- API：`public`

```gdscript
var auto_save_on_change: bool = true
```

set_value() 修改持久化设置时是否自动保存。

<a id="member-gfsettingsutility-properties-save_debounce_seconds"></a>

### `save_debounce_seconds`

- API：`public`

```gdscript
var save_debounce_seconds: float = 0.25
```

自动保存的防抖秒数；小于等于 0 时保持立即保存。

<a id="member-gfsettingsutility-properties-persistence_enabled"></a>

### `persistence_enabled`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var persistence_enabled: bool = true:
```

是否启用设置持久化。 架构模式启用时必须注册唯一的 GFSettingsStoreUtility；关闭时设置工具保持纯内存模式。

## 方法

<a id="member-gfsettingsutility-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func init() -> void:
```

初始化设置工具，并在 standalone 模式按配置自动加载持久化设置或应用默认值。

<a id="member-gfsettingsutility-methods-get_required_utilities"></a>

### `get_required_utilities`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_required_utilities() -> Array[Script]:
```

返回设置持久化端口依赖。

返回：启用持久化时仅包含 GFSettingsStoreUtility，否则为空。

<a id="member-gfsettingsutility-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func ready() -> void:
```

在架构 ready 阶段解析唯一的设置持久化端口。

<a id="member-gfsettingsutility-methods-begin_activation"></a>

### `begin_activation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
```

在依赖完成 activation 后执行架构模式的自动加载。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Settings 激活阶段的取消作用域。 |

返回：Store 可用并完成同步自动加载尝试时成功的一次性完成源。

<a id="member-gfsettingsutility-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
```

停止接纳设置变化与保存请求，并排空全部已接纳的冻结保存记录。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 当前 Settings 静默阶段的取消作用域。 |

返回：全部已接纳记录成功持久化时成功；失败时保留 target 证据；scope 取消时返回 CANCELLED，提升开放 batch 但不启动新 I/O，并保留 pending 供显式重试。

<a id="member-gfsettingsutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func dispose() -> void:
```

释放设置工具，并清理内存状态；持久化排空由 begin_quiesce() 负责。

<a id="member-gfsettingsutility-methods-release_dependencies"></a>

### `release_dependencies`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func release_dependencies() -> void:
```

释放架构 Store 引用和基类依赖作用域。

<a id="member-gfsettingsutility-methods-register_definition"></a>

### `register_definition`

- API：`public`

```gdscript
func register_definition(definition: GFSettingDefinition, apply_default: bool = true) -> void:
```

注册一个设置定义。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 设置定义。 |
| `apply_default` | 缺少当前值时是否写入默认值。 |

<a id="member-gfsettingsutility-methods-register_setting"></a>

### `register_setting`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func register_setting( key: StringName, default_value: Variant = null, value_type: GFSettingDefinition.ValueType = GFSettingDefinition.ValueType.ANY, persistent: bool = true, metadata: Dictionary = {} ) -> GFSettingDefinition:
```

使用参数快速注册一个设置定义。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `default_value` | 默认值。 |
| `value_type` | 值类型。 |
| `persistent` | 是否持久化。 |
| `metadata` | 可选元数据。 |

返回：注册成功时返回新设置定义；mutation gate 关闭时返回 null。

结构：

- `default_value`: Variant default setting value accepted by value_type.
- `metadata`: Dictionary with optional UI grouping, ordering, label, and project-defined metadata.

<a id="member-gfsettingsutility-methods-register_definitions"></a>

### `register_definitions`

- API：`public`

```gdscript
func register_definitions(definitions: Array[GFSettingDefinition]) -> void:
```

批量注册设置定义。

参数：

| 名称 | 说明 |
|---|---|
| `definitions` | 设置定义数组。 |

<a id="member-gfsettingsutility-methods-get_definition"></a>

### `get_definition`

- API：`public`

```gdscript
func get_definition(key: StringName) -> GFSettingDefinition:
```

获取指定设置定义。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |

返回：设置定义；不存在时返回 null。

<a id="member-gfsettingsutility-methods-get_definitions"></a>

### `get_definitions`

- API：`public`

```gdscript
func get_definitions() -> Array[GFSettingDefinition]:
```

获取所有设置定义。

返回：设置定义数组。

<a id="member-gfsettingsutility-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant, save_after_change: bool = true) -> void:
```

设置一个值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `value` | 设置值。 |
| `save_after_change` | 若为持久化设置，变化后是否保存。 |

结构：

- `value`: Variant setting value coerced by the registered definition when present.

<a id="member-gfsettingsutility-methods-stage_value"></a>

### `stage_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func stage_value(key: StringName, value: Variant) -> void:
```

设置一个暂存值。 暂存值不会改变当前有效设置，也不会触发保存；调用 apply_staged_values() 后才会写入真实设置。 如果暂存值等于当前有效值，会清除该键已有的暂存值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `value` | 暂存设置值。 |

结构：

- `value`: Variant setting value coerced by the registered definition when present.

<a id="member-gfsettingsutility-methods-get_staged_value"></a>

### `get_staged_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_staged_value(key: StringName, fallback: Variant = null) -> Variant:
```

获取指定键的暂存值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `fallback` | 没有暂存值时返回的值。 |

返回：暂存值或 fallback。

结构：

- `fallback`: Variant value returned when the setting has no staged value.
- `return`: Variant pending staged value or fallback.

<a id="member-gfsettingsutility-methods-get_staged_or_value"></a>

### `get_staged_or_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_staged_or_value(key: StringName, fallback: Variant = null) -> Variant:
```

获取用于预览的设置值。 若存在暂存值则返回暂存值，否则返回当前有效值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `fallback` | 无当前值、默认值和暂存值时返回的值。 |

返回：暂存值或当前有效值。

结构：

- `fallback`: Variant value returned when the setting has no staged, current, or default value.
- `return`: Variant staged value when present, otherwise current setting value.

<a id="member-gfsettingsutility-methods-has_staged_value"></a>

### `has_staged_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_staged_value(key: StringName) -> bool:
```

检查指定键是否存在暂存值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |

返回：存在暂存值时返回 true。

<a id="member-gfsettingsutility-methods-has_staged_values"></a>

### `has_staged_values`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_staged_values() -> bool:
```

检查是否存在任意暂存值。

返回：至少有一个暂存值时返回 true。

<a id="member-gfsettingsutility-methods-get_staged_values"></a>

### `get_staged_values`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_staged_values() -> Dictionary:
```

获取所有暂存值。

返回：暂存设置字典副本。

结构：

- `return`: Dictionary[StringName, Variant] staged setting values that are not yet applied.

<a id="member-gfsettingsutility-methods-get_staged_keys"></a>

### `get_staged_keys`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_staged_keys() -> PackedStringArray:
```

获取所有存在暂存值的设置键。

返回：排序后的暂存设置键。

<a id="member-gfsettingsutility-methods-discard_staged_value"></a>

### `discard_staged_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func discard_staged_value(key: StringName) -> bool:
```

丢弃指定键的暂存值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |

返回：实际丢弃暂存值时返回 true。

<a id="member-gfsettingsutility-methods-discard_staged_values"></a>

### `discard_staged_values`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func discard_staged_values() -> PackedStringArray:
```

丢弃全部暂存值。

返回：被丢弃暂存值的设置键。

<a id="member-gfsettingsutility-methods-apply_staged_values"></a>

### `apply_staged_values`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func apply_staged_values(options: Dictionary = {}) -> Dictionary:
```

应用暂存设置值。 只把暂存层提交到真实设置；真实设置变化、类型钳制和自动保存仍沿用 apply_values() 语义。 可通过 options.scope 只提交指定键。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选行为。支持 save_after_change、emit_changes 与 scope。 |

返回：应用报告。

结构：

- `options`: Dictionary with save_after_change: bool, emit_changes: bool, and scope as Array, PackedStringArray, Dictionary, String, or StringName.
- `return`: Dictionary with apply_values() report fields plus staged_applied_count, staged_remaining_count, and staged_applied_keys: PackedStringArray.

<a id="member-gfsettingsutility-methods-apply_values"></a>

### `apply_values`

- API：`public`

```gdscript
func apply_values(values: Dictionary, options: Dictionary = {}) -> Dictionary:
```

批量应用一组设置值，适合图形质量、辅助功能或输入方案等项目预设。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 设置键到设置值的字典。 |
| `options` | 可选行为。支持 save_after_change、emit_changes、reset_missing 与 scope。 |

返回：应用报告；问题项使用标准 kind 字段。

结构：

- `values`: Dictionary[String, Variant] mapping setting keys to new values.
- `options`: Dictionary with save_after_change: bool, emit_changes: bool, reset_missing: bool, and scope as Array, PackedStringArray, Dictionary, String, or StringName.
- `return`: Dictionary with ok, healthy, applied_count, changed_count, reset_count, skipped_count, error_count, warning_count, issue_count, and issues: Array[Dictionary].

<a id="member-gfsettingsutility-methods-begin_batch"></a>

### `begin_batch`

- API：`public`

```gdscript
func begin_batch() -> void:
```

开始一批设置修改。批处理中自动保存会延后到 end_batch()。

<a id="member-gfsettingsutility-methods-end_batch"></a>

### `end_batch`

- API：`public`

```gdscript
func end_batch(save_after_change: bool = true) -> void:
```

结束一批设置修改，并在需要时合并触发一次自动保存。

参数：

| 名称 | 说明 |
|---|---|
| `save_after_change` | 本批变化结束后是否允许保存。 |

<a id="member-gfsettingsutility-methods-queue_save"></a>

### `queue_save`

- API：`public`

```gdscript
func queue_save() -> void:
```

将当前设置标记为稍后保存，受 save_debounce_seconds 控制。

<a id="member-gfsettingsutility-methods-flush_pending_save"></a>

### `flush_pending_save`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func flush_pending_save() -> Error:
```

立即执行正在等待的自动保存。

返回：返回 OK、ERR_UNAVAILABLE、ERR_BUSY、冻结快照捕获错误或 Store 写入错误。

<a id="member-gfsettingsutility-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, fallback: Variant = null) -> Variant:
```

获取一个值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `fallback` | 无当前值和默认值时返回的值。 |

返回：设置值。

结构：

- `fallback`: Variant value returned when the setting has no current value or definition.
- `return`: Variant current setting value, coerced default, or fallback.

<a id="member-gfsettingsutility-methods-has_setting"></a>

### `has_setting`

- API：`public`

```gdscript
func has_setting(key: StringName) -> bool:
```

检查设置是否存在当前值或定义。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |

返回：存在时返回 true。

<a id="member-gfsettingsutility-methods-reset_value"></a>

### `reset_value`

- API：`public`

```gdscript
func reset_value(key: StringName, save_after_change: bool = true) -> void:
```

重置单个设置到默认值。未定义设置会被移除。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `save_after_change` | 若为持久化设置，变化后是否保存。 |

<a id="member-gfsettingsutility-methods-reset_all"></a>

### `reset_all`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func reset_all(save_after_change: bool = true) -> void:
```

重置所有已定义设置到默认值，并移除未定义的临时设置。

参数：

| 名称 | 说明 |
|---|---|
| `save_after_change` | 是否保存。 |

<a id="member-gfsettingsutility-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func to_dict(persistent_only: bool = true) -> Dictionary:
```

转换为可持久化字典。

参数：

| 名称 | 说明 |
|---|---|
| `persistent_only` | 是否仅包含 persistent 定义。 |

返回：设置字典。

结构：

- `return`: Dictionary[String, Variant] serialized setting values suitable for persistence.

<a id="member-gfsettingsutility-methods-replace_from_dict"></a>

### `replace_from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func replace_from_dict(data: Dictionary, emit_changes: bool = true) -> void:
```

使用字典完整替换当前设置。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 设置数据。 |
| `emit_changes` | 变化时是否发出 setting_changed。 |

结构：

- `data`: Dictionary[String, Variant] serialized setting values produced by to_dict().

<a id="member-gfsettingsutility-methods-merge_from_dict"></a>

### `merge_from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func merge_from_dict(data: Dictionary, emit_changes: bool = true) -> void:
```

将字典作为覆盖层合并到当前设置。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 设置数据。 |
| `emit_changes` | 变化时是否发出 setting_changed。 |

结构：

- `data`: Dictionary[String, Variant] serialized setting values produced by to_dict().

<a id="member-gfsettingsutility-methods-load_settings"></a>

### `load_settings`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func load_settings( file_name: String = "", recovery_policy: GFSettingsRecoveryPolicy = null ) -> GFSettingsLoadResult:
```

读取持久化设置并返回结构化终态。 默认策略严格失败；缺失、损坏、未来 schema、迁移失败或 IO 失败不会被 降级为空字典。只有显式恢复策略可以处理缺失或损坏，且加载本身从不保存。 非空策略会在 IO 前验证；合法加载请求会取消全部旧延迟/批处理保存请求， 防止新加载状态被旧保存目标重新序列化。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 可选文件名；为空时使用 storage_file_name。 |
| `recovery_policy` | 可选显式恢复策略；null 表示严格失败。 |

返回：隔离的结构化加载结果。

结构：

- `return`: GFSettingsLoadResult preserving status, application state, recovery action, and storage evidence.

<a id="member-gfsettingsutility-methods-get_last_load_result"></a>

### `get_last_load_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_last_load_result() -> GFSettingsLoadResult:
```

获取最近一次加载终态。

返回：最近结果的隔离副本；尚未加载或已释放时为 null。

<a id="member-gfsettingsutility-methods-save_settings"></a>

### `save_settings`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func save_settings(file_name: String = "") -> Error:
```

保存持久化设置。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 可选文件名；为空时使用 storage_file_name。 |

返回：返回 OK、ERR_UNAVAILABLE、ERR_BUSY、快照捕获错误或 Store 写入错误。

<a id="member-gfsettingsutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func tick(delta: float = 0.0) -> void:
```

驱动自动保存防抖。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 距离上一帧的秒数。 |

<a id="member-gfsettingsutility-methods-_read_persisted_data"></a>

### `_read_persisted_data`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _read_persisted_data(file_name: String) -> GFStorageReadResult:
```

读取持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 要读取的设置文件名。 |

返回：保留成功空载荷与稳定失败分类的存储读取结果。

结构：

- `return`: GFStorageReadResult with isolated Settings payload and failure_kind evidence.

<a id="member-gfsettingsutility-methods-_write_persisted_data"></a>

### `_write_persisted_data`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _write_persisted_data(file_name: String, data: Dictionary) -> Error:
```

写入持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 要写入的设置文件名。 |
| `data` | 要写入的设置数据。 |

返回：Godot 错误码。

结构：

- `data`: Dictionary[String, Variant] persisted settings data produced by to_dict(true).
