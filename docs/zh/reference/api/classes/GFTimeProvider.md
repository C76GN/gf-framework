# GFTimeProvider

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_time_provider.gd`
- 模块：`Kernel`
- 继承：`GFUtility`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

架构 tick 时间缩放协议。 该基类只定义 `GFArchitecture` 需要理解的时间控制契约。 具体时间工具可以继承它来提供暂停、缩放和物理子步能力。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_scaled_delta`](#member-gftimeprovider-methods-get_scaled_delta) | `func get_scaled_delta(delta: float) -> float:` |
| 方法 | [`get_physics_scaled_delta_steps`](#member-gftimeprovider-methods-get_physics_scaled_delta_steps) | `func get_physics_scaled_delta_steps(delta: float) -> Array[float]:` |
| 方法 | [`should_substep_physics`](#member-gftimeprovider-methods-should_substep_physics) | `func should_substep_physics(delta: float) -> bool:` |
| 方法 | [`is_time_paused`](#member-gftimeprovider-methods-is_time_paused) | `func is_time_paused() -> bool:` |

## 方法

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
