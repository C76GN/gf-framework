# GFTimeUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_time_utility.gd`
- 模块：`Standard`
- 继承：`GFTimeProvider`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

全局时间控制工具。 继承自 GFUtility，提供全局时间缩放、暂停和组级暂停控制能力。 架构在 tick / physics_tick 中自动从本工具获取缩放后的 delta， 无需 System 自行处理暂停逻辑。 用法： 1. 在架构的 _on_init() 中注册本工具。 2. 设置 time_scale 可全局加减速（如子弹时间设为 0.3）。 3. 设置 is_paused = true 暂停所有受控 System。 4. 使用 set_group_paused() 实现 UI 层/逻辑层分组暂停。 5. System 可设置 ignore_pause = true 来忽略暂停（如暂停菜单动画）。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`time_scale`](#member-gftimeutility-properties-time_scale) | `var time_scale: float = 1.0:` |
| 属性 | [`max_scaled_delta`](#member-gftimeutility-properties-max_scaled_delta) | `var max_scaled_delta: float = 0.0:` |
| 属性 | [`physics_substep_max_delta`](#member-gftimeutility-properties-physics_substep_max_delta) | `var physics_substep_max_delta: float = 0.0:` |
| 属性 | [`max_physics_substeps`](#member-gftimeutility-properties-max_physics_substeps) | `var max_physics_substeps: int = 8:` |
| 属性 | [`is_paused`](#member-gftimeutility-properties-is_paused) | `var is_paused: bool = false` |
| 方法 | [`init`](#member-gftimeutility-methods-init) | `func init() -> void:` |
| 方法 | [`get_scaled_delta`](#member-gftimeutility-methods-get_scaled_delta) | `func get_scaled_delta(delta: float) -> float:` |
| 方法 | [`get_physics_scaled_delta_steps`](#member-gftimeutility-methods-get_physics_scaled_delta_steps) | `func get_physics_scaled_delta_steps(delta: float) -> Array[float]:` |
| 方法 | [`should_substep_physics`](#member-gftimeutility-methods-should_substep_physics) | `func should_substep_physics(delta: float) -> bool:` |
| 方法 | [`is_time_paused`](#member-gftimeutility-methods-is_time_paused) | `func is_time_paused() -> bool:` |
| 方法 | [`set_group_paused`](#member-gftimeutility-methods-set_group_paused) | `func set_group_paused(group: StringName, paused: bool) -> void:` |
| 方法 | [`is_group_paused`](#member-gftimeutility-methods-is_group_paused) | `func is_group_paused(group: StringName) -> bool:` |
| 方法 | [`get_group_scaled_delta`](#member-gftimeutility-methods-get_group_scaled_delta) | `func get_group_scaled_delta(group: StringName, delta: float) -> float:` |
| 方法 | [`remove_group`](#member-gftimeutility-methods-remove_group) | `func remove_group(group: StringName) -> void:` |
| 方法 | [`clear_groups`](#member-gftimeutility-methods-clear_groups) | `func clear_groups() -> void:` |

## 属性

<a id="member-gftimeutility-properties-time_scale"></a>

### `time_scale`

- API：`public`

```gdscript
var time_scale: float = 1.0:
```

全局时间缩放系数。1.0 为正常速度，0.5 为半速，2.0 为双倍速。 不得为负值，设置负值将被钳制为 0.0。

<a id="member-gftimeutility-properties-max_scaled_delta"></a>

### `max_scaled_delta`

- API：`public`

```gdscript
var max_scaled_delta: float = 0.0:
```

单次缩放后 delta 的最大值。小于等于 0 时不限制。 可用于避免极端 time_scale 或掉帧后向普通 tick 传入过大步长。

<a id="member-gftimeutility-properties-physics_substep_max_delta"></a>

### `physics_substep_max_delta`

- API：`public`

```gdscript
var physics_substep_max_delta: float = 0.0:
```

physics_tick 子步进的最大缩放步长。小于等于 0 时不启用子步进。

<a id="member-gftimeutility-properties-max_physics_substeps"></a>

### `max_physics_substeps`

- API：`public`

```gdscript
var max_physics_substeps: int = 8:
```

单个物理帧最多拆分出的子步数。

<a id="member-gftimeutility-properties-is_paused"></a>

### `is_paused`

- API：`public`

```gdscript
var is_paused: bool = false
```

全局暂停标志。为 true 时，所有未标记 ignore_pause 的 System 接收 delta = 0.0。

## 方法

<a id="member-gftimeutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化：重置时间状态。

<a id="member-gftimeutility-methods-get_scaled_delta"></a>

### `get_scaled_delta`

- API：`public`

```gdscript
func get_scaled_delta(delta: float) -> float:
```

获取经过全局缩放的 delta 值。暂停时返回 0.0。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始帧间隔时间。 |

返回：缩放后的 delta。

<a id="member-gftimeutility-methods-get_physics_scaled_delta_steps"></a>

### `get_physics_scaled_delta_steps`

- API：`public`

```gdscript
func get_physics_scaled_delta_steps(delta: float) -> Array[float]:
```

获取 physics_tick 使用的缩放 delta 子步数组。 未启用子步进或无需拆分时返回单元素数组。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始物理帧间隔时间。 |

返回：缩放后的 delta 子步数组。

<a id="member-gftimeutility-methods-should_substep_physics"></a>

### `should_substep_physics`

- API：`public`

```gdscript
func should_substep_physics(delta: float) -> bool:
```

判断当前物理帧是否会被拆分为多个子步。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始物理帧间隔时间。 |

返回：会拆分时返回 true。

<a id="member-gftimeutility-methods-is_time_paused"></a>

### `is_time_paused`

- API：`public`

```gdscript
func is_time_paused() -> bool:
```

检查当前工具是否处于全局暂停状态。

返回：暂停时返回 true。

<a id="member-gftimeutility-methods-set_group_paused"></a>

### `set_group_paused`

- API：`public`

```gdscript
func set_group_paused(group: StringName, paused: bool) -> void:
```

设置指定组的暂停状态。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 组标识符。 |
| `paused` | 是否暂停。 |

<a id="member-gftimeutility-methods-is_group_paused"></a>

### `is_group_paused`

- API：`public`

```gdscript
func is_group_paused(group: StringName) -> bool:
```

查询指定组是否处于暂停状态。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 组标识符。 |

返回：该组是否暂停，未注册的组返回 false。

<a id="member-gftimeutility-methods-get_group_scaled_delta"></a>

### `get_group_scaled_delta`

- API：`public`

```gdscript
func get_group_scaled_delta(group: StringName, delta: float) -> float:
```

获取指定组经过缩放的 delta 值。 若全局暂停或该组暂停，返回 0.0。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 组标识符。 |
| `delta` | 引擎原始帧间隔时间。 |

返回：缩放后的 delta。

<a id="member-gftimeutility-methods-remove_group"></a>

### `remove_group`

- API：`public`

```gdscript
func remove_group(group: StringName) -> void:
```

移除指定组的暂停记录。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 组标识符。 |

<a id="member-gftimeutility-methods-clear_groups"></a>

### `clear_groups`

- API：`public`

```gdscript
func clear_groups() -> void:
```

清除所有组级暂停记录。
