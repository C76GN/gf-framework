# GFVirtualInputSource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/sources/gf_virtual_input_source.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

可编程虚拟输入源。 用于测试、回放、AI 控制或项目自定义输入桥接，向 GFInputMappingUtility 注入抽象动作值；它不读取 InputMap，也不规定具体设备或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`PulseReplacementPolicy`](#member-gfvirtualinputsource-enums-pulsereplacementpolicy) | `enum PulseReplacementPolicy` |
| 属性 | [`source_id`](#member-gfvirtualinputsource-properties-source_id) | `var source_id: StringName:` |
| 属性 | [`player_index`](#member-gfvirtualinputsource-properties-player_index) | `var player_index: int:` |
| 方法 | [`configure`](#member-gfvirtualinputsource-methods-configure) | `func configure( input_mapping: GFInputMappingUtility, p_source_id: StringName = &"virtual", p_player_index: int = -1, timer_utility: GFTimerUtility = null ) -> GFVirtualInputSource:` |
| 方法 | [`set_timer_utility`](#member-gfvirtualinputsource-methods-set_timer_utility) | `func set_timer_utility(timer_utility: GFTimerUtility) -> GFVirtualInputSource:` |
| 方法 | [`get_timer_utility`](#member-gfvirtualinputsource-methods-get_timer_utility) | `func get_timer_utility() -> GFTimerUtility:` |
| 方法 | [`pulse_action`](#member-gfvirtualinputsource-methods-pulse_action) | `func pulse_action( action_id: StringName, value: Variant = true, duration_seconds: float = 0.1, owner: Variant = null, cancellation_token: GFCancellationToken = null, replacement_policy: PulseReplacementPolicy = PulseReplacementPolicy.REPLACE ) -> GFVirtualInputPulseOperation:` |
| 方法 | [`set_action_value`](#member-gfvirtualinputsource-methods-set_action_value) | `func set_action_value(action_id: StringName, value: Variant) -> bool:` |
| 方法 | [`set_action_value_for_player`](#member-gfvirtualinputsource-methods-set_action_value_for_player) | `func set_action_value_for_player(action_id: StringName, value: Variant, next_player_index: int) -> bool:` |
| 方法 | [`press`](#member-gfvirtualinputsource-methods-press) | `func press(action_id: StringName, strength: float = 1.0) -> bool:` |
| 方法 | [`release`](#member-gfvirtualinputsource-methods-release) | `func release(action_id: StringName) -> bool:` |
| 方法 | [`set_axis_1d`](#member-gfvirtualinputsource-methods-set_axis_1d) | `func set_axis_1d(action_id: StringName, value: float) -> bool:` |
| 方法 | [`set_axis_2d`](#member-gfvirtualinputsource-methods-set_axis_2d) | `func set_axis_2d(action_id: StringName, value: Vector2) -> bool:` |
| 方法 | [`set_axis_3d`](#member-gfvirtualinputsource-methods-set_axis_3d) | `func set_axis_3d(action_id: StringName, value: Vector3) -> bool:` |
| 方法 | [`clear_action`](#member-gfvirtualinputsource-methods-clear_action) | `func clear_action(action_id: StringName) -> bool:` |
| 方法 | [`clear_action_for_player`](#member-gfvirtualinputsource-methods-clear_action_for_player) | `func clear_action_for_player(action_id: StringName, next_player_index: int) -> bool:` |
| 方法 | [`clear_all`](#member-gfvirtualinputsource-methods-clear_all) | `func clear_all() -> void:` |
| 方法 | [`dispose`](#member-gfvirtualinputsource-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_snapshot`](#member-gfvirtualinputsource-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfvirtualinputsource-enums-pulsereplacementpolicy"></a>

### `PulseReplacementPolicy`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum PulseReplacementPolicy {
	## 原子交接同一动作贡献，不产生中间释放。
	REPLACE,
	## 保留旧脉冲，并让新句柄立即进入 REJECTED 终态。
	REJECT_NEW,
	## 清除旧贡献后重新写入；仅当聚合状态实际转为 inactive 时产生新的 release-to-press 边沿。
	RETRIGGER,
}
```

同一 source_id、player_index 与 action_id 已存在脉冲时的处理策略。

## 属性

<a id="member-gfvirtualinputsource-properties-source_id"></a>

### `source_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var source_id: StringName:
```

虚拟输入源标识。修改后会先释放该 handle 已写入的旧身份手动贡献； 已启动脉冲冻结创建时身份并继续独立运行。

<a id="member-gfvirtualinputsource-properties-player_index"></a>

### `player_index`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var player_index: int:
```

玩家索引；小于 0 时只写入全局动作状态。修改后会先释放旧玩家身份的 手动贡献；已启动脉冲冻结创建时身份并继续独立运行。

## 方法

<a id="member-gfvirtualinputsource-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func configure( input_mapping: GFInputMappingUtility, p_source_id: StringName = &"virtual", p_player_index: int = -1, timer_utility: GFTimerUtility = null ) -> GFVirtualInputSource:
```

配置虚拟输入源。身份或 mapping 改变时会先释放该 handle 追踪的旧身份手动贡献； 已启动脉冲冻结创建时依赖并继续运行。重复配置完全相同的身份只替换后续脉冲 使用的 timer，不清理当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `input_mapping` | 输入映射工具。 |
| `p_source_id` | 虚拟输入源标识。 |
| `p_player_index` | 玩家索引。 |
| `timer_utility` | 可选的脉冲定时器注入。 |

返回：当前输入源；dispose 后返回同一终态实例且不修改配置。

<a id="member-gfvirtualinputsource-methods-set_timer_utility"></a>

### `set_timer_utility`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_timer_utility(timer_utility: GFTimerUtility) -> GFVirtualInputSource:
```

替换后续脉冲使用的定时器工具。 已启动操作会继续使用其创建时冻结的定时器，不受本次替换影响。

参数：

| 名称 | 说明 |
|---|---|
| `timer_utility` | 可注入的定时器工具；null 会禁用后续 pulse_action()。 |

返回：当前输入源；dispose 后返回同一终态实例且不修改配置。

<a id="member-gfvirtualinputsource-methods-get_timer_utility"></a>

### `get_timer_utility`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_timer_utility() -> GFTimerUtility:
```

获取后续脉冲使用的定时器工具。

返回：当前注入且仍存活的 GFTimerUtility。

<a id="member-gfvirtualinputsource-methods-pulse_action"></a>

### `pulse_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pulse_action( action_id: StringName, value: Variant = true, duration_seconds: float = 0.1, owner: Variant = null, cancellation_token: GFCancellationToken = null, replacement_policy: PulseReplacementPolicy = PulseReplacementPolicy.REPLACE ) -> GFVirtualInputPulseOperation:
```

启动一次有界虚拟动作脉冲。 owner 与 cancellation_token 均可省略；同时提供时采用 OR 语义。返回句柄冻结 当前 Mapping、source_id、player_index 和 action_id，Source 后续重配不会改写旧操作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 已注册的抽象动作标识。 |
| `value` | 脉冲期间的动作值。 |
| `duration_seconds` | 非负且有限的脉冲时长；0 会同步释放。 |
| `owner` | 可选生命周期 owner；Node 离树或普通 Object 释放后取消。 |
| `cancellation_token` | 可选取消 token。 |
| `replacement_policy` | 同一稳定输入键已有脉冲时的策略。 |

返回：类型化脉冲句柄；输入无效时返回立即 FAILED 的句柄。

结构：

- `value`: Variant，GFInputMappingUtility 接受的 bool、float、Vector2 或 Vector3 动作值。
- `owner`: Variant，null 或仍有效的 Object；无效及已释放对象会在写入前失败。

<a id="member-gfvirtualinputsource-methods-set_action_value"></a>

### `set_action_value`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_action_value(action_id: StringName, value: Variant) -> bool:
```

写入动作值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 动作值。 |

返回：写入成功返回 true；非有限数值会被拒绝并保持旧贡献不变。

结构：

- `value`: Variant，GFInputMappingUtility 接受的动作值，通常为 bool、float、Vector2 或 Vector3。

<a id="member-gfvirtualinputsource-methods-set_action_value_for_player"></a>

### `set_action_value_for_player`

- API：`public`

```gdscript
func set_action_value_for_player(action_id: StringName, value: Variant, next_player_index: int) -> bool:
```

为指定玩家写入动作值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 动作值。 |
| `next_player_index` | 玩家索引。 |

返回：写入成功返回 true。

结构：

- `value`: Variant，GFInputMappingUtility 接受的动作值，通常为 bool、float、Vector2 或 Vector3。

<a id="member-gfvirtualinputsource-methods-press"></a>

### `press`

- API：`public`

```gdscript
func press(action_id: StringName, strength: float = 1.0) -> bool:
```

按下布尔动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `strength` | 输入强度。 |

返回：写入成功返回 true。

<a id="member-gfvirtualinputsource-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release(action_id: StringName) -> bool:
```

释放动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：写入成功返回 true。

<a id="member-gfvirtualinputsource-methods-set_axis_1d"></a>

### `set_axis_1d`

- API：`public`

```gdscript
func set_axis_1d(action_id: StringName, value: float) -> bool:
```

写入一维轴动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 一维轴值。 |

返回：写入成功返回 true。

<a id="member-gfvirtualinputsource-methods-set_axis_2d"></a>

### `set_axis_2d`

- API：`public`

```gdscript
func set_axis_2d(action_id: StringName, value: Vector2) -> bool:
```

写入二维轴动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 二维轴值。 |

返回：写入成功返回 true。

<a id="member-gfvirtualinputsource-methods-set_axis_3d"></a>

### `set_axis_3d`

- API：`public`

```gdscript
func set_axis_3d(action_id: StringName, value: Vector3) -> bool:
```

写入三维轴动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 三维轴值。 |

返回：写入成功返回 true。

<a id="member-gfvirtualinputsource-methods-clear_action"></a>

### `clear_action`

- API：`public`

```gdscript
func clear_action(action_id: StringName) -> bool:
```

清除指定动作贡献。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：清除成功返回 true。

<a id="member-gfvirtualinputsource-methods-clear_action_for_player"></a>

### `clear_action_for_player`

- API：`public`

```gdscript
func clear_action_for_player(action_id: StringName, next_player_index: int) -> bool:
```

清除指定玩家的动作贡献。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `next_player_index` | 玩家索引。 |

返回：清除成功返回 true。

<a id="member-gfvirtualinputsource-methods-clear_all"></a>

### `clear_all`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func clear_all() -> void:
```

清除同一 source_id 的所有玩家动作贡献。

<a id="member-gfvirtualinputsource-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

取消全部 Source-owned 脉冲、清除当前 source_id 贡献并释放依赖引用。

<a id="member-gfvirtualinputsource-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_snapshot() -> Dictionary:
```

获取当前虚拟源快照。

返回：快照字典。

结构：

- `return`: Dictionary，包含 source_id: StringName、player_index: int，以及当前 source/player 身份的 actions: Array[Dictionary]。
