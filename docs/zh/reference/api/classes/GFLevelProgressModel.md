# GFLevelProgressModel

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/level/gf_level_progress_model.gd`
- 模块：`Domain`
- 继承：`GFModel`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用关卡解锁与完成进度模型。 只记录关卡是否解锁、是否完成以及项目层自定义结果字典。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`level_unlocked`](#member-gflevelprogressmodel-signals-level_unlocked) | `signal level_unlocked(level_id: StringName)` |
| 信号 | [`level_locked`](#member-gflevelprogressmodel-signals-level_locked) | `signal level_locked(level_id: StringName)` |
| 信号 | [`level_completed`](#member-gflevelprogressmodel-signals-level_completed) | `signal level_completed(level_id: StringName, result: Dictionary)` |
| 信号 | [`level_result_updated`](#member-gflevelprogressmodel-signals-level_result_updated) | `signal level_result_updated(level_id: StringName, result: Dictionary)` |
| 方法 | [`unlock_level`](#member-gflevelprogressmodel-methods-unlock_level) | `func unlock_level(level_id: StringName) -> void:` |
| 方法 | [`lock_level`](#member-gflevelprogressmodel-methods-lock_level) | `func lock_level(level_id: StringName) -> void:` |
| 方法 | [`is_level_unlocked`](#member-gflevelprogressmodel-methods-is_level_unlocked) | `func is_level_unlocked(level_id: StringName) -> bool:` |
| 方法 | [`complete_level`](#member-gflevelprogressmodel-methods-complete_level) | `func complete_level(level_id: StringName, result: Dictionary = {}, merge_result: bool = true) -> void:` |
| 方法 | [`is_level_completed`](#member-gflevelprogressmodel-methods-is_level_completed) | `func is_level_completed(level_id: StringName) -> bool:` |
| 方法 | [`set_level_result`](#member-gflevelprogressmodel-methods-set_level_result) | `func set_level_result(level_id: StringName, result: Dictionary, merge_result: bool = true) -> void:` |
| 方法 | [`get_level_result`](#member-gflevelprogressmodel-methods-get_level_result) | `func get_level_result(level_id: StringName) -> Dictionary:` |
| 方法 | [`clear_progress`](#member-gflevelprogressmodel-methods-clear_progress) | `func clear_progress() -> void:` |
| 方法 | [`to_dict`](#member-gflevelprogressmodel-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gflevelprogressmodel-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |

## 信号

<a id="member-gflevelprogressmodel-signals-level_unlocked"></a>

### `level_unlocked`

- API：`public`

```gdscript
signal level_unlocked(level_id: StringName)
```

关卡解锁时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

<a id="member-gflevelprogressmodel-signals-level_locked"></a>

### `level_locked`

- API：`public`

```gdscript
signal level_locked(level_id: StringName)
```

关卡锁定时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

<a id="member-gflevelprogressmodel-signals-level_completed"></a>

### `level_completed`

- API：`public`

```gdscript
signal level_completed(level_id: StringName, result: Dictionary)
```

关卡完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `result` | 完成结果。 |

结构：

- `result`: Dictionary，项目自定义关卡完成结果副本。

<a id="member-gflevelprogressmodel-signals-level_result_updated"></a>

### `level_result_updated`

- API：`public`

```gdscript
signal level_result_updated(level_id: StringName, result: Dictionary)
```

关卡结果更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `result` | 结果字典。 |

结构：

- `result`: Dictionary，项目自定义关卡结果副本。

## 方法

<a id="member-gflevelprogressmodel-methods-unlock_level"></a>

### `unlock_level`

- API：`public`

```gdscript
func unlock_level(level_id: StringName) -> void:
```

解锁关卡。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

<a id="member-gflevelprogressmodel-methods-lock_level"></a>

### `lock_level`

- API：`public`

```gdscript
func lock_level(level_id: StringName) -> void:
```

锁定关卡。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

<a id="member-gflevelprogressmodel-methods-is_level_unlocked"></a>

### `is_level_unlocked`

- API：`public`

```gdscript
func is_level_unlocked(level_id: StringName) -> bool:
```

检查关卡是否解锁。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：已解锁时返回 true。

<a id="member-gflevelprogressmodel-methods-complete_level"></a>

### `complete_level`

- API：`public`

```gdscript
func complete_level(level_id: StringName, result: Dictionary = {}, merge_result: bool = true) -> void:
```

标记关卡完成。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `result` | 项目层结果数据。 |
| `merge_result` | 是否合并已有结果。 |

结构：

- `result`: Dictionary，项目自定义关卡完成结果；merge_result 为 true 时会覆盖同名字段。

<a id="member-gflevelprogressmodel-methods-is_level_completed"></a>

### `is_level_completed`

- API：`public`

```gdscript
func is_level_completed(level_id: StringName) -> bool:
```

检查关卡是否完成。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：已完成时返回 true。

<a id="member-gflevelprogressmodel-methods-set_level_result"></a>

### `set_level_result`

- API：`public`

```gdscript
func set_level_result(level_id: StringName, result: Dictionary, merge_result: bool = true) -> void:
```

设置关卡结果。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |
| `result` | 结果字典。 |
| `merge_result` | 是否合并已有结果。 |

结构：

- `result`: Dictionary，项目自定义关卡结果；merge_result 为 true 时会覆盖同名字段。

<a id="member-gflevelprogressmodel-methods-get_level_result"></a>

### `get_level_result`

- API：`public`

```gdscript
func get_level_result(level_id: StringName) -> Dictionary:
```

获取关卡结果。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：结果字典副本。

结构：

- `return`: Dictionary，项目自定义关卡结果副本；不存在时为空字典。

<a id="member-gflevelprogressmodel-methods-clear_progress"></a>

### `clear_progress`

- API：`public`

```gdscript
func clear_progress() -> void:
```

清空所有进度。

<a id="member-gflevelprogressmodel-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

序列化进度。

返回：字典数据。

结构：

- `return`: Dictionary，包含 unlocked_levels、completed_levels 与 level_results 三个 String 键字典。

<a id="member-gflevelprogressmodel-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

反序列化进度。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

结构：

- `data`: Dictionary，包含 unlocked_levels、completed_levels 与 level_results 三个可选字典字段。
