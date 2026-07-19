# GFTimeProvider

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_time_provider.gd`
- 模块：`Kernel`
- 继承：`GFUtility`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

架构 tick 时间缩放与时钟提供协议。 该基类只定义 `GFArchitecture` 需要理解的时间控制契约。 具体时间工具可以继承它来提供暂停、缩放和物理子步能力，并通过独立 `GFClock` 明确区分单调运行时与 Unix 墙上时间。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_clock`](#member-gftimeprovider-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gftimeprovider-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`get_monotonic_usec`](#member-gftimeprovider-methods-get_monotonic_usec) | `func get_monotonic_usec() -> int:` |
| 方法 | [`get_monotonic_msec`](#member-gftimeprovider-methods-get_monotonic_msec) | `func get_monotonic_msec() -> int:` |
| 方法 | [`get_unix_time_msec`](#member-gftimeprovider-methods-get_unix_time_msec) | `func get_unix_time_msec() -> int:` |
| 方法 | [`get_unix_time_seconds`](#member-gftimeprovider-methods-get_unix_time_seconds) | `func get_unix_time_seconds() -> int:` |
| 方法 | [`get_scaled_delta`](#member-gftimeprovider-methods-get_scaled_delta) | `func get_scaled_delta(delta: float) -> float:` |
| 方法 | [`get_physics_scaled_delta_steps`](#member-gftimeprovider-methods-get_physics_scaled_delta_steps) | `func get_physics_scaled_delta_steps(delta: float) -> Array[float]:` |
| 方法 | [`should_substep_physics`](#member-gftimeprovider-methods-should_substep_physics) | `func should_substep_physics(delta: float) -> bool:` |
| 方法 | [`is_time_paused`](#member-gftimeprovider-methods-is_time_paused) | `func is_time_paused() -> bool:` |

## 方法

<a id="member-gftimeprovider-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

设置底层时钟。 注入只改变后续读取，不修改缩放或暂停状态。传入 null 会被拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 系统、测试或模拟时钟。 |

返回：设置成功返回 true。

<a id="member-gftimeprovider-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取当前底层时钟。

返回：当前时钟实例。

<a id="member-gftimeprovider-methods-get_monotonic_usec"></a>

### `get_monotonic_usec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_monotonic_usec() -> int:
```

获取单调运行时微秒值。

返回：不受暂停、缩放或系统校时影响的微秒值。

<a id="member-gftimeprovider-methods-get_monotonic_msec"></a>

### `get_monotonic_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_monotonic_msec() -> int:
```

获取单调运行时毫秒值。

返回：不受暂停、缩放或系统校时影响的毫秒值。

<a id="member-gftimeprovider-methods-get_unix_time_msec"></a>

### `get_unix_time_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_unix_time_msec() -> int:
```

获取 Unix epoch 毫秒时间戳。

返回：可持久化、但可能因系统校时跳变的毫秒时间戳。

<a id="member-gftimeprovider-methods-get_unix_time_seconds"></a>

### `get_unix_time_seconds`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_unix_time_seconds() -> int:
```

获取 Unix epoch 秒时间戳。

返回：可持久化、但可能因系统校时跳变的秒时间戳。

<a id="member-gftimeprovider-methods-get_scaled_delta"></a>

### `get_scaled_delta`

- API：`public`

```gdscript
func get_scaled_delta(delta: float) -> float:
```

获取普通 tick 使用的 delta。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始帧间隔时间。 |

返回：模块应接收的 delta。

<a id="member-gftimeprovider-methods-get_physics_scaled_delta_steps"></a>

### `get_physics_scaled_delta_steps`

- API：`public`

```gdscript
func get_physics_scaled_delta_steps(delta: float) -> Array[float]:
```

获取 physics_tick 使用的 delta 子步数组。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始物理帧间隔时间。 |

返回：模块应依次接收的 physics delta。

<a id="member-gftimeprovider-methods-should_substep_physics"></a>

### `should_substep_physics`

- API：`public`

```gdscript
func should_substep_physics(delta: float) -> bool:
```

判断当前物理帧是否需要拆分为多个子步。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始物理帧间隔时间。 |

返回：需要拆分时返回 true。

<a id="member-gftimeprovider-methods-is_time_paused"></a>

### `is_time_paused`

- API：`public`

```gdscript
func is_time_paused() -> bool:
```

检查当前时间提供者是否处于全局暂停状态。

返回：暂停时返回 true。
