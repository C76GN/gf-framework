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
| 信号 | [`settings_loaded`](#member-gfsettingsutility-signals-settings_loaded) | `signal settings_loaded(data: Dictionary)` |
| 信号 | [`settings_saved`](#member-gfsettingsutility-signals-settings_saved) | `signal settings_saved(data: Dictionary)` |
| 属性 | [`storage_file_name`](#member-gfsettingsutility-properties-storage_file_name) | `var storage_file_name: String = "settings.sav"` |
| 属性 | [`auto_load_on_init`](#member-gfsettingsutility-properties-auto_load_on_init) | `var auto_load_on_init: bool = true` |
| 属性 | [`auto_save_on_change`](#member-gfsettingsutility-properties-auto_save_on_change) | `var auto_save_on_change: bool = true` |
| 属性 | [`save_debounce_seconds`](#member-gfsettingsutility-properties-save_debounce_seconds) | `var save_debounce_seconds: float = 0.25` |
| 方法 | [`init`](#member-gfsettingsutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfsettingsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_definition`](#member-gfsettingsutility-methods-register_definition) | `func register_definition(definition: GFSettingDefinition, apply_default: bool = true) -> void:` |
| 方法 | [`register_setting`](#member-gfsettingsutility-methods-register_setting) | `func register_setting( key: StringName, default_value: Variant = null, value_type: GFSettingDefinition.ValueType = GFSettingDefinition.ValueType.ANY, persistent: bool = true, metadata: Dictionary = {} ) -> GFSettingDefinition:` |
| 方法 | [`register_definitions`](#member-gfsettingsutility-methods-register_definitions) | `func register_definitions(definitions: Array[GFSettingDefinition]) -> void:` |
| 方法 | [`get_definition`](#member-gfsettingsutility-methods-get_definition) | `func get_definition(key: StringName) -> GFSettingDefinition:` |
| 方法 | [`get_definitions`](#member-gfsettingsutility-methods-get_definitions) | `func get_definitions() -> Array[GFSettingDefinition]:` |
| 方法 | [`set_value`](#member-gfsettingsutility-methods-set_value) | `func set_value(key: StringName, value: Variant, save_after_change: bool = true) -> void:` |
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
| 方法 | [`from_dict`](#member-gfsettingsutility-methods-from_dict) | `func from_dict(data: Dictionary, emit_changes: bool = true) -> void:` |
| 方法 | [`load_settings`](#member-gfsettingsutility-methods-load_settings) | `func load_settings(file_name: String = "") -> Dictionary:` |
| 方法 | [`save_settings`](#member-gfsettingsutility-methods-save_settings) | `func save_settings(file_name: String = "") -> Error:` |
| 方法 | [`tick`](#member-gfsettingsutility-methods-tick) | `func tick(delta: float = 0.0) -> void:` |
| 方法 | [`_read_persisted_data`](#member-gfsettingsutility-methods-_read_persisted_data) | `func _read_persisted_data(file_name: String) -> Dictionary:` |
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

<a id="member-gfsettingsutility-signals-settings_loaded"></a>

### `settings_loaded`

- API：`public`

```gdscript
signal settings_loaded(data: Dictionary)
```

设置加载完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 已加载的持久化设置数据。 |

结构：

- `data`: Dictionary[String, Variant] loaded persisted settings data.

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

```gdscript
var auto_load_on_init: bool = true
```

init() 时是否自动读取持久化设置。

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

## 方法

<a id="member-gfsettingsutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化设置工具，并按配置自动加载持久化设置或应用默认值。

<a id="member-gfsettingsutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放设置工具，并清理已注册定义、当前值和等待中的自动保存状态。

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

返回：新设置定义。

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

```gdscript
func flush_pending_save() -> Error:
```

立即执行正在等待的自动保存。

返回：保存结果；没有待保存内容时返回 OK。

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

<a id="member-gfsettingsutility-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary, emit_changes: bool = true) -> void:
```

从字典恢复设置。

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

```gdscript
func load_settings(file_name: String = "") -> Dictionary:
```

读取持久化设置。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 可选文件名；为空时使用 storage_file_name。 |

返回：已读取的数据。

结构：

- `return`: Dictionary[String, Variant] loaded persisted settings data.

<a id="member-gfsettingsutility-methods-save_settings"></a>

### `save_settings`

- API：`public`

```gdscript
func save_settings(file_name: String = "") -> Error:
```

保存持久化设置。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 可选文件名；为空时使用 storage_file_name。 |

返回：Godot 错误码。

<a id="member-gfsettingsutility-methods-tick"></a>

### `tick`

- API：`public`

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

```gdscript
func _read_persisted_data(file_name: String) -> Dictionary:
```

读取持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 要读取的设置文件名。 |

返回：已读取的数据；不存在或无法解析时返回空字典。

结构：

- `return`: Dictionary[String, Variant] persisted settings data.

<a id="member-gfsettingsutility-methods-_write_persisted_data"></a>

### `_write_persisted_data`

- API：`protected`

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
