# GFClock

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_clock.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`9.0.0`

单调运行时与 Unix 墙上时钟协议。 单调时间只用于耗时、截止时间和运行时排序；Unix 时间只用于持久化时间戳与 跨进程交换。默认实现直接读取 Godot 系统时钟，测试或模拟环境可以继承并 覆写读取方法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_monotonic_usec`](#member-gfclock-methods-get_monotonic_usec) | `func get_monotonic_usec() -> int:` |
| 方法 | [`get_monotonic_msec`](#member-gfclock-methods-get_monotonic_msec) | `func get_monotonic_msec() -> int:` |
| 方法 | [`get_unix_time_msec`](#member-gfclock-methods-get_unix_time_msec) | `func get_unix_time_msec() -> int:` |
| 方法 | [`get_unix_time_seconds`](#member-gfclock-methods-get_unix_time_seconds) | `func get_unix_time_seconds() -> int:` |

## 方法

<a id="member-gfclock-methods-get_monotonic_usec"></a>

### `get_monotonic_usec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_monotonic_usec() -> int:
```

获取自进程启动后单调递增的微秒数。

返回：单调时钟微秒值，不可作为持久化时间戳。

<a id="member-gfclock-methods-get_monotonic_msec"></a>

### `get_monotonic_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_monotonic_msec() -> int:
```

获取自进程启动后单调递增的毫秒数。

返回：单调时钟毫秒值，不可作为持久化时间戳。

<a id="member-gfclock-methods-get_unix_time_msec"></a>

### `get_unix_time_msec`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_unix_time_msec() -> int:
```

获取 Unix epoch 毫秒时间戳。

返回：可持久化的 Unix epoch 毫秒时间戳；该值可能因系统校时跳变。

<a id="member-gfclock-methods-get_unix_time_seconds"></a>

### `get_unix_time_seconds`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_unix_time_seconds() -> int:
```

获取 Unix epoch 秒时间戳。

返回：可持久化的 Unix epoch 秒时间戳；该值可能因系统校时跳变。
