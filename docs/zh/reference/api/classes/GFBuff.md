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
| 常量 | [`REMOVAL_REASON_EXPIRED`](#member-gfbuff-constants-removal_reason_expired) | `const REMOVAL_REASON_EXPIRED: StringName = &"expired"` |
| 常量 | [`REMOVAL_REASON_REMOVED`](#member-gfbuff-constants-removal_reason_removed) | `const REMOVAL_REASON_REMOVED: StringName = &"removed"` |
| 常量 | [`REMOVAL_REASON_CLEARED`](#member-gfbuff-constants-removal_reason_cleared) | `const REMOVAL_REASON_CLEARED: StringName = &"cleared"` |
| 常量 | [`REMOVAL_REASON_ENTITY_UNREGISTERED`](#member-gfbuff-constants-removal_reason_entity_unregistered) | `const REMOVAL_REASON_ENTITY_UNREGISTERED: StringName = &"entity_unregistered"` |
| 常量 | [`REMOVAL_REASON_DISPOSED`](#member-gfbuff-constants-removal_reason_disposed) | `const REMOVAL_REASON_DISPOSED: StringName = &"disposed"` |
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
| 属性 | [`checks`](#member-gfbuff-properties-checks) | `var checks: Array[GFBuffCheck] = []` |
| 属性 | [`effects`](#member-gfbuff-properties-effects) | `var effects: Array[GFBuffEffect] = []` |
| 属性 | [`metadata`](#member-gfbuff-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`removal_reason`](#member-gfbuff-properties-removal_reason) | `var removal_reason: StringName = &""` |
| 方法 | [`setup`](#member-gfbuff-methods-setup) | `func setup(p_id: StringName, p_duration: float, p_owner: Object) -> void:` |
| 方法 | [`get_apply_report`](#member-gfbuff-methods-get_apply_report) | `func get_apply_report(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`on_apply`](#member-gfbuff-methods-on_apply) | `func on_apply() -> Dictionary:` |
| 方法 | [`on_remove`](#member-gfbuff-methods-on_remove) | `func on_remove() -> Dictionary:` |
| 方法 | [`on_refresh`](#member-gfbuff-methods-on_refresh) | `func on_refresh(p_new_duration: float) -> Dictionary:` |
| 方法 | [`refresh_from`](#member-gfbuff-methods-refresh_from) | `func refresh_from(source_buff: GFBuff) -> Dictionary:` |
| 方法 | [`on_tick`](#member-gfbuff-methods-on_tick) | `func on_tick(_p_delta: float) -> void:` |
| 方法 | [`update`](#member-gfbuff-methods-update) | `func update(p_delta: float) -> bool:` |
| 方法 | [`mark_removed`](#member-gfbuff-methods-mark_removed) | `func mark_removed(reason: StringName = REMOVAL_REASON_REMOVED) -> void:` |
| 方法 | [`get_state_snapshot`](#member-gfbuff-methods-get_state_snapshot) | `func get_state_snapshot() -> Dictionary:` |
| 方法 | [`restore_state_snapshot`](#member-gfbuff-methods-restore_state_snapshot) | `func restore_state_snapshot(snapshot: Dictionary, owner_override: Object = null) -> void:` |

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

## 常量

<a id="member-gfbuff-constants-removal_reason_expired"></a>

### `REMOVAL_REASON_EXPIRED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const REMOVAL_REASON_EXPIRED: StringName = &"expired"
```

Buff 因持续时间耗尽而移除。

<a id="member-gfbuff-constants-removal_reason_removed"></a>

### `REMOVAL_REASON_REMOVED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const REMOVAL_REASON_REMOVED: StringName = &"removed"
```

Buff 被显式移除。

<a id="member-gfbuff-constants-removal_reason_cleared"></a>

### `REMOVAL_REASON_CLEARED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const REMOVAL_REASON_CLEARED: StringName = &"cleared"
```

Buff 被批量清理。

<a id="member-gfbuff-constants-removal_reason_entity_unregistered"></a>

### `REMOVAL_REASON_ENTITY_UNREGISTERED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const REMOVAL_REASON_ENTITY_UNREGISTERED: StringName = &"entity_unregistered"
```

Buff 随实体注销而移除。

<a id="member-gfbuff-constants-removal_reason_disposed"></a>

### `REMOVAL_REASON_DISPOSED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const REMOVAL_REASON_DISPOSED: StringName = &"disposed"
```

Buff 随系统释放而移除。

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

<a id="member-gfbuff-properties-checks"></a>

### `checks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var checks: Array[GFBuffCheck] = []
```

Buff 应用前检查列表。全部通过后才会应用。

<a id="member-gfbuff-properties-effects"></a>

### `effects`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var effects: Array[GFBuffEffect] = []
```

Buff 生命周期效果列表。

<a id="member-gfbuff-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 不解释该字段。

结构：

- `metadata`: Dictionary project-defined buff metadata.

<a id="member-gfbuff-properties-removal_reason"></a>

### `removal_reason`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var removal_reason: StringName = &""
```

最近一次移除原因。

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

<a id="member-gfbuff-methods-get_apply_report"></a>

### `get_apply_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_apply_report(context: Dictionary = {}) -> Dictionary:
```

获取应用检查报告。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 可选应用上下文。 |

返回：检查报告。

结构：

- `context`: Dictionary merged into the default buff apply context.
- `return`: Dictionary with ok, reason, buff_id, failed_check_id, metadata, and issues.

<a id="member-gfbuff-methods-on_apply"></a>

### `on_apply`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func on_apply() -> Dictionary:
```

当 Buff 首次应用时触发。

返回：生命周期报告；`ok=false` 时表示应用失败且内置效果已回滚。

结构：

- `return`: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.

<a id="member-gfbuff-methods-on_remove"></a>

### `on_remove`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func on_remove() -> Dictionary:
```

当 Buff 被移除时触发。

返回：生命周期报告；移除会尽力清理内置效果，即使自定义效果报告失败。

结构：

- `return`: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.

<a id="member-gfbuff-methods-on_refresh"></a>

### `on_refresh`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func on_refresh(p_new_duration: float) -> Dictionary:
```

当 Buff 层数增加时触发（通常用于刷新持续时间）。

参数：

| 名称 | 说明 |
|---|---|
| `p_new_duration` | 刷新后的持续时间（秒）。 |

返回：生命周期报告；`changed=false` 表示本次刷新未改变运行状态。

结构：

- `return`: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.

<a id="member-gfbuff-methods-refresh_from"></a>

### `refresh_from`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func refresh_from(source_buff: GFBuff) -> Dictionary:
```

使用同 ID 的新 Buff 刷新当前运行中实例。

参数：

| 名称 | 说明 |
|---|---|
| `source_buff` | 本次尝试添加的新 Buff。 |

返回：生命周期报告；`changed=false` 表示本次刷新被策略忽略。

结构：

- `return`: Dictionary with ok, reason, event, buff_id, changed, failed_effect_id, metadata, and effect_reports.

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
- 首次版本：`11.0.0`

```gdscript
func update(p_delta: float) -> bool:
```

内部状态更新流程。 非有限 delta 或非有限时间状态会在任何生命周期修改前失败关闭并返回 false。

参数：

| 名称 | 说明 |
|---|---|
| `p_delta` | 帧间隔。 |

返回：如果 Buff 已耗尽生命周期需要被移除，则返回 true。

<a id="member-gfbuff-methods-mark_removed"></a>

### `mark_removed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func mark_removed(reason: StringName = REMOVAL_REASON_REMOVED) -> void:
```

标记移除原因。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 移除原因。 |

<a id="member-gfbuff-methods-get_state_snapshot"></a>

### `get_state_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_state_snapshot() -> Dictionary:
```

获取运行时状态快照。

返回：状态快照。

结构：

- `return`: Dictionary with generic buff runtime state, modifiers, tags, metadata, and effect_states.

<a id="member-gfbuff-methods-restore_state_snapshot"></a>

### `restore_state_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func restore_state_snapshot(snapshot: Dictionary, owner_override: Object = null) -> void:
```

恢复运行时状态快照。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 状态快照。 |
| `owner_override` | 可选 owner 覆盖；为空时保留当前 owner。 |

结构：

- `snapshot`: Dictionary returned by get_state_snapshot().
