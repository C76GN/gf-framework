# GFLevelUtility

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/level/gf_level_utility.gd`
- 模块：`Domain`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

关卡流程管理工具。 负责统一关卡数据读取、开始、重开、胜利和失败信号派发。 默认通过 GFConfigProvider 读取静态关卡表，并可在重开关卡时清理 命令历史与外部显式注册的运行时残留。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`level_started`](#member-gflevelutility-signals-level_started) | `signal level_started(level_id: Variant, level_data: Dictionary)` |
| 信号 | [`level_restarted`](#member-gflevelutility-signals-level_restarted) | `signal level_restarted(level_id: Variant, level_data: Dictionary)` |
| 信号 | [`level_won`](#member-gflevelutility-signals-level_won) | `signal level_won(level_id: Variant)` |
| 信号 | [`level_lost`](#member-gflevelutility-signals-level_lost) | `signal level_lost(level_id: Variant)` |
| 属性 | [`level_table_name`](#member-gflevelutility-properties-level_table_name) | `var level_table_name: StringName = &"levels"` |
| 属性 | [`current_level_id`](#member-gflevelutility-properties-current_level_id) | `var current_level_id: Variant = null` |
| 属性 | [`current_level_data`](#member-gflevelutility-properties-current_level_data) | `var current_level_data: Dictionary = {}` |
| 属性 | [`catalog`](#member-gflevelutility-properties-catalog) | `var catalog: GFLevelCatalog = null` |
| 属性 | [`fail_on_missing_level_data`](#member-gflevelutility-properties-fail_on_missing_level_data) | `var fail_on_missing_level_data: bool = false` |
| 方法 | [`configure`](#member-gflevelutility-methods-configure) | `func configure(table_name: StringName = &"levels") -> void:` |
| 方法 | [`set_catalog`](#member-gflevelutility-methods-set_catalog) | `func set_catalog(level_catalog: GFLevelCatalog) -> void:` |
| 方法 | [`get_catalog`](#member-gflevelutility-methods-get_catalog) | `func get_catalog() -> GFLevelCatalog:` |
| 方法 | [`get_level_entry`](#member-gflevelutility-methods-get_level_entry) | `func get_level_entry(level_id: StringName) -> GFLevelEntry:` |
| 方法 | [`get_catalog_levels`](#member-gflevelutility-methods-get_catalog_levels) | `func get_catalog_levels(pack_id: StringName = &"") -> Array[GFLevelEntry]:` |
| 方法 | [`load_level_data`](#member-gflevelutility-methods-load_level_data) | `func load_level_data(level_id: Variant) -> Dictionary:` |
| 方法 | [`start_level`](#member-gflevelutility-methods-start_level) | `func start_level(level_id: Variant, level_data_override: Dictionary = {}) -> Dictionary:` |
| 方法 | [`restart_level`](#member-gflevelutility-methods-restart_level) | `func restart_level(clear_runtime: bool = true) -> Dictionary:` |
| 方法 | [`win_current_level`](#member-gflevelutility-methods-win_current_level) | `func win_current_level() -> void:` |
| 方法 | [`complete_current_level`](#member-gflevelutility-methods-complete_current_level) | `func complete_current_level( result: Dictionary = {}, unlock_next: bool = true, emit_win_signal: bool = true ) -> void:` |
| 方法 | [`lose_current_level`](#member-gflevelutility-methods-lose_current_level) | `func lose_current_level() -> void:` |
| 方法 | [`clear_level_runtime`](#member-gflevelutility-methods-clear_level_runtime) | `func clear_level_runtime() -> void:` |
| 方法 | [`register_runtime_cleanup`](#member-gflevelutility-methods-register_runtime_cleanup) | `func register_runtime_cleanup(cleanup_id: StringName, callback: Callable) -> bool:` |
| 方法 | [`unregister_runtime_cleanup`](#member-gflevelutility-methods-unregister_runtime_cleanup) | `func unregister_runtime_cleanup(cleanup_id: StringName) -> void:` |
| 方法 | [`has_runtime_cleanup`](#member-gflevelutility-methods-has_runtime_cleanup) | `func has_runtime_cleanup(cleanup_id: StringName) -> bool:` |
| 方法 | [`get_runtime_cleanup_ids`](#member-gflevelutility-methods-get_runtime_cleanup_ids) | `func get_runtime_cleanup_ids() -> PackedStringArray:` |
| 方法 | [`clear_current_level`](#member-gflevelutility-methods-clear_current_level) | `func clear_current_level() -> void:` |
| 方法 | [`start_next_level`](#member-gflevelutility-methods-start_next_level) | `func start_next_level() -> Dictionary:` |
| 方法 | [`unlock_level`](#member-gflevelutility-methods-unlock_level) | `func unlock_level(level_id: StringName) -> void:` |
| 方法 | [`is_level_unlocked`](#member-gflevelutility-methods-is_level_unlocked) | `func is_level_unlocked(level_id: StringName) -> bool:` |

## 信号

<a id="member-gflevelutility-signals-level_started"></a>

### `level_started`

- API：`public`

```gdscript
signal level_started(level_id: Variant, level_data: Dictionary)
```

当关卡开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `level_data` | 当前关卡数据。 |

结构：

- `level_id`: Variant，项目传入的关卡 ID，通常为 StringName 或 String。
- `level_data`: Dictionary，当前关卡数据副本。

<a id="member-gflevelutility-signals-level_restarted"></a>

### `level_restarted`

- API：`public`

```gdscript
signal level_restarted(level_id: Variant, level_data: Dictionary)
```

当关卡重开时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `level_data` | 当前关卡数据。 |

结构：

- `level_id`: Variant，项目传入的关卡 ID，通常为 StringName 或 String。
- `level_data`: Dictionary，当前关卡数据副本。

<a id="member-gflevelutility-signals-level_won"></a>

### `level_won`

- API：`public`

```gdscript
signal level_won(level_id: Variant)
```

当关卡胜利时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

结构：

- `level_id`: Variant，项目传入的关卡 ID，通常为 StringName 或 String。

<a id="member-gflevelutility-signals-level_lost"></a>

### `level_lost`

- API：`public`

```gdscript
signal level_lost(level_id: Variant)
```

当关卡失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

结构：

- `level_id`: Variant，项目传入的关卡 ID，通常为 StringName 或 String。

## 属性

<a id="member-gflevelutility-properties-level_table_name"></a>

### `level_table_name`

- API：`public`

```gdscript
var level_table_name: StringName = &"levels"
```

默认关卡配置表名。

<a id="member-gflevelutility-properties-current_level_id"></a>

### `current_level_id`

- API：`public`

```gdscript
var current_level_id: Variant = null
```

当前关卡 ID。

结构：

- `current_level_id`: Variant，项目传入的当前关卡 ID；未启动关卡时为 null。

<a id="member-gflevelutility-properties-current_level_data"></a>

### `current_level_data`

- API：`public`

```gdscript
var current_level_data: Dictionary = {}
```

当前关卡数据副本。

结构：

- `current_level_data`: Dictionary，当前关卡数据副本；来源可以是配置表、目录条目或外部覆盖。

<a id="member-gflevelutility-properties-catalog"></a>

### `catalog`

- API：`public`

```gdscript
var catalog: GFLevelCatalog = null
```

可选关卡目录资源。

<a id="member-gflevelutility-properties-fail_on_missing_level_data"></a>

### `fail_on_missing_level_data`

- API：`public`

```gdscript
var fail_on_missing_level_data: bool = false
```

为 true 时，找不到关卡数据会拒绝启动或重开当前关卡。

## 方法

<a id="member-gflevelutility-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(table_name: StringName = &"levels") -> void:
```

配置关卡数据表名。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 用于 GFConfigProvider.get_record() 的表名。 |

<a id="member-gflevelutility-methods-set_catalog"></a>

### `set_catalog`

- API：`public`

```gdscript
func set_catalog(level_catalog: GFLevelCatalog) -> void:
```

设置关卡目录资源。

参数：

| 名称 | 说明 |
|---|---|
| `level_catalog` | 关卡目录。 |

<a id="member-gflevelutility-methods-get_catalog"></a>

### `get_catalog`

- API：`public`

```gdscript
func get_catalog() -> GFLevelCatalog:
```

获取关卡目录资源。

返回：关卡目录；不存在时返回 null。

<a id="member-gflevelutility-methods-get_level_entry"></a>

### `get_level_entry`

- API：`public`

```gdscript
func get_level_entry(level_id: StringName) -> GFLevelEntry:
```

获取目录中的关卡条目。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：关卡条目；不存在时返回 null。

<a id="member-gflevelutility-methods-get_catalog_levels"></a>

### `get_catalog_levels`

- API：`public`

```gdscript
func get_catalog_levels(pack_id: StringName = &"") -> Array[GFLevelEntry]:
```

获取目录中的关卡列表。

参数：

| 名称 | 说明 |
|---|---|
| `pack_id` | 可选关卡扩展 ID；为空时返回全部。 |

返回：关卡条目数组。

结构：

- `return`: Array[GFLevelEntry]，目录返回的已排序关卡条目拷贝。

<a id="member-gflevelutility-methods-load_level_data"></a>

### `load_level_data`

- API：`public`

```gdscript
func load_level_data(level_id: Variant) -> Dictionary:
```

读取关卡数据。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：关卡数据副本，找不到时返回空字典。

结构：

- `level_id`: Variant，项目传入的关卡 ID，通常为 StringName 或 String。
- `return`: Dictionary，当前关卡数据副本；找不到数据时为空字典。

<a id="member-gflevelutility-methods-start_level"></a>

### `start_level`

- API：`public`

```gdscript
func start_level(level_id: Variant, level_data_override: Dictionary = {}) -> Dictionary:
```

开始指定关卡。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `level_data_override` | 可选的外部数据覆盖；为空时从配置表读取。 |

返回：当前关卡数据副本。

结构：

- `level_id`: Variant，项目传入的关卡 ID，通常为 StringName 或 String。
- `level_data_override`: Dictionary，项目提供的关卡数据覆盖；非空时优先使用。
- `return`: Dictionary，启动后的当前关卡数据副本；失败时为空字典。

<a id="member-gflevelutility-methods-restart_level"></a>

### `restart_level`

- API：`public`

```gdscript
func restart_level(clear_runtime: bool = true) -> Dictionary:
```

重开当前关卡，并清理常见运行时队列。

参数：

| 名称 | 说明 |
|---|---|
| `clear_runtime` | 是否清理命令历史与表现队列。 |

返回：当前关卡数据副本。

结构：

- `return`: Dictionary，重开后的当前关卡数据副本；失败时为空字典。

<a id="member-gflevelutility-methods-win_current_level"></a>

### `win_current_level`

- API：`public`

```gdscript
func win_current_level() -> void:
```

标记当前关卡胜利。

<a id="member-gflevelutility-methods-complete_current_level"></a>

### `complete_current_level`

- API：`public`

```gdscript
func complete_current_level( result: Dictionary = {}, unlock_next: bool = true, emit_win_signal: bool = true ) -> void:
```

完成当前关卡并可选更新通用进度模型与后续解锁。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 项目层结果数据。 |
| `unlock_next` | 是否解锁目录中的后续关卡。 |
| `emit_win_signal` | 是否发出 level_won。 |

结构：

- `result`: Dictionary，项目自定义关卡完成结果。

<a id="member-gflevelutility-methods-lose_current_level"></a>

### `lose_current_level`

- API：`public`

```gdscript
func lose_current_level() -> void:
```

标记当前关卡失败。

<a id="member-gflevelutility-methods-clear_level_runtime"></a>

### `clear_level_runtime`

- API：`public`

```gdscript
func clear_level_runtime() -> void:
```

清理常见关卡运行时残留。

<a id="member-gflevelutility-methods-register_runtime_cleanup"></a>

### `register_runtime_cleanup`

- API：`public`

```gdscript
func register_runtime_cleanup(cleanup_id: StringName, callback: Callable) -> bool:
```

注册关卡运行时清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `cleanup_id` | 清理项唯一标识。 |
| `callback` | 无参数清理回调。 |

返回：注册成功返回 true。

<a id="member-gflevelutility-methods-unregister_runtime_cleanup"></a>

### `unregister_runtime_cleanup`

- API：`public`

```gdscript
func unregister_runtime_cleanup(cleanup_id: StringName) -> void:
```

注销关卡运行时清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `cleanup_id` | 清理项唯一标识。 |

<a id="member-gflevelutility-methods-has_runtime_cleanup"></a>

### `has_runtime_cleanup`

- API：`public`

```gdscript
func has_runtime_cleanup(cleanup_id: StringName) -> bool:
```

检查关卡运行时清理回调是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `cleanup_id` | 清理项唯一标识。 |

返回：存在返回 true。

<a id="member-gflevelutility-methods-get_runtime_cleanup_ids"></a>

### `get_runtime_cleanup_ids`

- API：`public`

```gdscript
func get_runtime_cleanup_ids() -> PackedStringArray:
```

获取已注册清理项标识。

返回：排序后的清理项标识。

<a id="member-gflevelutility-methods-clear_current_level"></a>

### `clear_current_level`

- API：`public`

```gdscript
func clear_current_level() -> void:
```

清除当前关卡记录。

<a id="member-gflevelutility-methods-start_next_level"></a>

### `start_next_level`

- API：`public`

```gdscript
func start_next_level() -> Dictionary:
```

启动目录中的下一个关卡。

返回：下一个关卡数据；没有后续关卡时返回空字典。

结构：

- `return`: Dictionary，下一个关卡数据副本；没有后续关卡时为空字典。

<a id="member-gflevelutility-methods-unlock_level"></a>

### `unlock_level`

- API：`public`

```gdscript
func unlock_level(level_id: StringName) -> void:
```

解锁关卡进度。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

<a id="member-gflevelutility-methods-is_level_unlocked"></a>

### `is_level_unlocked`

- API：`public`

```gdscript
func is_level_unlocked(level_id: StringName) -> bool:
```

检查关卡是否已解锁。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：已解锁时返回 true；未注册进度模型时返回 true。
