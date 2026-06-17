# GFBuff

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_buff.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

状态效果基类。 管理 Buff 的生命周期、层数以及对属性/标签的影响。 在 GFCombatSystem 的 tick 中驱动 update。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`StackMode`](#member-gfbuff-enums-stackmode) | `enum StackMode` |
| 枚举 | [`DurationRefreshPolicy`](#member-gfbuff-enums-durationrefreshpolicy) | `enum DurationRefreshPolicy` |
| 属性 | [`id`](#member-gfbuff-properties-id) | `var id: StringName = &""` |
| 属性 | [`duration`](#member-gfbuff-properties-duration) | `var duration: float = 0.0` |
| 属性 | [`time_left`](#member-gfbuff-properties-time_left) | `var time_left: float = 0.0` |
| 属性 | [`stacks`](#member-gfbuff-properties-stacks) | `var stacks: int = 1` |
| 属性 | [`max_stacks`](#member-gfbuff-properties-max_stacks) | `var max_stacks: int = 1` |
| 属性 | [`stack_mode`](#member-gfbuff-properties-stack_mode) | `var stack_mode: StackMode = StackMode.ADD_STACK` |
| 属性 | [`duration_refresh_policy`](#member-gfbuff-properties-duration_refresh_policy) | `var duration_refresh_policy: DurationRefreshPolicy = DurationRefreshPolicy.RESET_TO_NEW_DURATION` |
| 属性 | [`tick_interval_seconds`](#member-gfbuff-properties-tick_interval_seconds) | `var tick_interval_seconds: float = 0.0` |
| 属性 | [`max_periodic_ticks_per_update`](#member-gfbuff-properties-max_periodic_ticks_per_update) | `var max_periodic_ticks_per_update: int = 8` |
| 属性 | [`remove_on_expire`](#member-gfbuff-properties-remove_on_expire) | `var remove_on_expire: bool = true` |
| 属性 | [`modifiers`](#member-gfbuff-properties-modifiers) | `var modifiers: Array[GFModifier] = []` |
| 属性 | [`tags`](#member-gfbuff-properties-tags) | `var tags: Array[StringName] = []` |
| 属性 | [`owner`](#member-gfbuff-properties-owner) | `var owner: Object = null` |
| 方法 | [`setup`](#member-gfbuff-methods-setup) | `func setup(p_id: StringName, p_duration: float, p_owner: Object) -> void:` |
| 方法 | [`on_apply`](#member-gfbuff-methods-on_apply) | `func on_apply() -> void:` |
| 方法 | [`on_remove`](#member-gfbuff-methods-on_remove) | `func on_remove() -> void:` |
| 方法 | [`on_refresh`](#member-gfbuff-methods-on_refresh) | `func on_refresh(p_new_duration: float) -> void:` |
| 方法 | [`refresh_from`](#member-gfbuff-methods-refresh_from) | `func refresh_from(source_buff: GFBuff) -> void:` |
| 方法 | [`on_tick`](#member-gfbuff-methods-on_tick) | `func on_tick(_p_delta: float) -> void:` |
| 方法 | [`update`](#member-gfbuff-methods-update) | `func update(p_delta: float) -> bool:` |

## 枚举

<a id="member-gfbuff-enums-stackmode"></a>

### `StackMode`

- API：`public`

```gdscript
enum StackMode {
	## 只刷新持续时间，不改变层数。
	REFRESH_ONLY,
	## 刷新持续时间，并在 max_stacks 允许时增加层数。
	ADD_STACK,
	## 忽略重复添加，不刷新持续时间或层数。
	IGNORE,
}
```

重复添加同 ID Buff 时的层数策略。

<a id="member-gfbuff-enums-durationrefreshpolicy"></a>

### `DurationRefreshPolicy`

- API：`public`

```gdscript
enum DurationRefreshPolicy {
	## 保持当前剩余时间。
	KEEP_CURRENT,
	## 使用新的持续时间重置剩余时间。
	RESET_TO_NEW_DURATION,
	## 将新的持续时间追加到当前剩余时间。
	EXTEND_BY_NEW_DURATION,
	## 保留当前剩余时间与新持续时间中较长者。
	KEEP_LONGER_REMAINING,
}
```

重复添加同 ID Buff 时的持续时间刷新策略。

## 属性

<a id="member-gfbuff-properties-id"></a>

### `id`

- API：`public`

```gdscript
var id: StringName = &""
```

Buff 的唯一标识名（通常用于排斥逻辑）。

<a id="member-gfbuff-properties-duration"></a>

### `duration`

- API：`public`

```gdscript
var duration: float = 0.0
```

Buff 的总持续时间（秒）。如果为 -1 则视为永久 Buff。

<a id="member-gfbuff-properties-time_left"></a>

### `time_left`

- API：`public`

```gdscript
var time_left: float = 0.0
```

当前剩余剩余时间。

<a id="member-gfbuff-properties-stacks"></a>

### `stacks`

- API：`public`

```gdscript
var stacks: int = 1
```

当前层数。

<a id="member-gfbuff-properties-max_stacks"></a>

### `max_stacks`

- API：`public`

```gdscript
var max_stacks: int = 1
```

最大层数。

<a id="member-gfbuff-properties-stack_mode"></a>

### `stack_mode`

- API：`public`

```gdscript
var stack_mode: StackMode = StackMode.ADD_STACK
```

重复添加同 ID Buff 时的层数策略。

<a id="member-gfbuff-properties-duration_refresh_policy"></a>

### `duration_refresh_policy`

- API：`public`

```gdscript
var duration_refresh_policy: DurationRefreshPolicy = DurationRefreshPolicy.RESET_TO_NEW_DURATION
```

重复添加同 ID Buff 时的持续时间刷新策略。

<a id="member-gfbuff-properties-tick_interval_seconds"></a>

### `tick_interval_seconds`

- API：`public`

```gdscript
var tick_interval_seconds: float = 0.0
```

周期 Tick 间隔。小于等于 0 时保持每帧调用 on_tick() 的旧行为。

<a id="member-gfbuff-properties-max_periodic_ticks_per_update"></a>

### `max_periodic_ticks_per_update`

- API：`public`

```gdscript
var max_periodic_ticks_per_update: int = 8
```

单次 update 允许补偿触发的最大周期 Tick 次数。小于等于 0 时不限制。

<a id="member-gfbuff-properties-remove_on_expire"></a>

### `remove_on_expire`

- API：`public`

```gdscript
var remove_on_expire: bool = true
```

持续时间耗尽时是否由 CombatSystem 移除。

<a id="member-gfbuff-properties-modifiers"></a>

### `modifiers`

- API：`public`

```gdscript
var modifiers: Array[GFModifier] = []
```

Buff 携带的属性修饰器列表。应用时会自动挂载到宿主的 Attribute 上。

<a id="member-gfbuff-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: Array[StringName] = []
```

Buff 携带的标签列表。应用时会自动挂载到宿主的 TagComponent 上。

<a id="member-gfbuff-properties-owner"></a>

### `owner`

- API：`public`

```gdscript
var owner: Object = null
```

Buff 的拥有者（通常是一个持有 Combat 数据的 Object）。

## 方法

<a id="member-gfbuff-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup(p_id: StringName, p_duration: float, p_owner: Object) -> void:
```

初始化 Buff，由系统或工厂调用。

参数：

| 名称 | 说明 |
|---|---|
| `p_id` | Buff 标识。 |
| `p_duration` | Buff 持续时间（秒）。 |
| `p_owner` | Buff 所属对象。 |

<a id="member-gfbuff-methods-on_apply"></a>

### `on_apply`

- API：`public`

```gdscript
func on_apply() -> void:
```

当 Buff 首次应用时触发。

<a id="member-gfbuff-methods-on_remove"></a>

### `on_remove`

- API：`public`

```gdscript
func on_remove() -> void:
```

当 Buff 被移除时触发。

<a id="member-gfbuff-methods-on_refresh"></a>

### `on_refresh`

- API：`public`

```gdscript
func on_refresh(p_new_duration: float) -> void:
```

当 Buff 层数增加时触发（通常用于刷新持续时间）。

参数：

| 名称 | 说明 |
|---|---|
| `p_new_duration` | 刷新后的持续时间（秒）。 |

<a id="member-gfbuff-methods-refresh_from"></a>

### `refresh_from`

- API：`public`

```gdscript
func refresh_from(source_buff: GFBuff) -> void:
```

使用同 ID 的新 Buff 刷新当前运行中实例。

参数：

| 名称 | 说明 |
|---|---|
| `source_buff` | 本次尝试添加的新 Buff。 |

<a id="member-gfbuff-methods-on_tick"></a>

### `on_tick`

- API：`public`

```gdscript
func on_tick(_p_delta: float) -> void:
```

周期性触发逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `_p_delta` | 帧间隔。 |

<a id="member-gfbuff-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(p_delta: float) -> bool:
```

内部状态更新流程。

参数：

| 名称 | 说明 |
|---|---|
| `p_delta` | 帧间隔。 |

返回：如果 Buff 已耗尽生命周期需要被移除，则返回 true。
