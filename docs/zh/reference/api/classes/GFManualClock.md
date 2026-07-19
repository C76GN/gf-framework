# GFManualClock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_manual_clock.gd`
- 模块：`Standard`
- 继承：`GFClock`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`9.0.0`

可确定推进的测试与模拟时钟。 单调时间只能向前推进；墙上时钟可通过 `set_unix_time_msec()` 模拟校时跳变。 该类型不自动读取系统时间，也不会随帧更新。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gfmanualclock-methods-_init) | `func _init(monotonic_usec: int = 0, unix_time_msec: int = 0) -> void:` |
| 方法 | [`get_monotonic_usec`](#member-gfmanualclock-methods-get_monotonic_usec) | `func get_monotonic_usec() -> int:` |
| 方法 | [`get_monotonic_msec`](#member-gfmanualclock-methods-get_monotonic_msec) | `func get_monotonic_msec() -> int:` |
| 方法 | [`get_unix_time_msec`](#member-gfmanualclock-methods-get_unix_time_msec) | `func get_unix_time_msec() -> int:` |
| 方法 | [`get_unix_time_seconds`](#member-gfmanualclock-methods-get_unix_time_seconds) | `func get_unix_time_seconds() -> int:` |
| 方法 | [`advance_usec`](#member-gfmanualclock-methods-advance_usec) | `func advance_usec(delta_usec: int) -> bool:` |
| 方法 | [`advance_msec`](#member-gfmanualclock-methods-advance_msec) | `func advance_msec(delta_msec: int) -> bool:` |
| 方法 | [`set_unix_time_msec`](#member-gfmanualclock-methods-set_unix_time_msec) | `func set_unix_time_msec(unix_time_msec: int) -> bool:` |

## 方法

<a id="member-gfmanualclock-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func _init(monotonic_usec: int = 0, unix_time_msec: int = 0) -> void:
```

创建手动时钟。

参数：

| 名称 | 说明 |
|---|---|
| `monotonic_usec` | 初始单调微秒值。 |
| `unix_time_msec` | 初始 Unix epoch 毫秒值。 |

<a id="member-gfmanualclock-methods-get_monotonic_usec"></a>

### `get_monotonic_usec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_monotonic_usec() -> int:
```

获取当前手动单调微秒值。

返回：当前单调微秒值。

<a id="member-gfmanualclock-methods-get_monotonic_msec"></a>

### `get_monotonic_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_monotonic_msec() -> int:
```

获取当前手动单调毫秒值。

返回：当前单调毫秒值。

<a id="member-gfmanualclock-methods-get_unix_time_msec"></a>

### `get_unix_time_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_unix_time_msec() -> int:
```

获取当前手动 Unix epoch 毫秒值。

返回：当前 Unix epoch 毫秒值。

<a id="member-gfmanualclock-methods-get_unix_time_seconds"></a>

### `get_unix_time_seconds`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_unix_time_seconds() -> int:
```

获取当前手动 Unix epoch 秒值。

返回：当前 Unix epoch 秒值。

<a id="member-gfmanualclock-methods-advance_usec"></a>

### `advance_usec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func advance_usec(delta_usec: int) -> bool:
```

同时向前推进单调时钟和墙上时钟。

参数：

| 名称 | 说明 |
|---|---|
| `delta_usec` | 非负推进微秒数。 |

返回：参数合法并完成推进时返回 true。

<a id="member-gfmanualclock-methods-advance_msec"></a>

### `advance_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func advance_msec(delta_msec: int) -> bool:
```

同时向前推进单调时钟和墙上时钟。

参数：

| 名称 | 说明 |
|---|---|
| `delta_msec` | 非负推进毫秒数。 |

返回：参数合法并完成推进时返回 true。

<a id="member-gfmanualclock-methods-set_unix_time_msec"></a>

### `set_unix_time_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_unix_time_msec(unix_time_msec: int) -> bool:
```

显式设置墙上时钟，用于模拟系统校时或恢复持久化时间。

参数：

| 名称 | 说明 |
|---|---|
| `unix_time_msec` | 非负 Unix epoch 毫秒值。 |

返回：参数合法并完成设置时返回 true。
