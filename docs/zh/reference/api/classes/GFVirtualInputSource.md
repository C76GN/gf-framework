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
| 属性 | [`source_id`](#member-gfvirtualinputsource-properties-source_id) | `var source_id: StringName = &"virtual"` |
| 属性 | [`player_index`](#member-gfvirtualinputsource-properties-player_index) | `var player_index: int = -1` |
| 方法 | [`configure`](#member-gfvirtualinputsource-methods-configure) | `func configure( input_mapping: GFInputMappingUtility, p_source_id: StringName = &"virtual", p_player_index: int = -1 ) -> GFVirtualInputSource:` |
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
| 方法 | [`get_snapshot`](#member-gfvirtualinputsource-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfvirtualinputsource-properties-source_id"></a>

### `source_id`

- API：`public`

```gdscript
var source_id: StringName = &"virtual"
```

虚拟输入源标识。

<a id="member-gfvirtualinputsource-properties-player_index"></a>

### `player_index`

- API：`public`

```gdscript
var player_index: int = -1
```

玩家索引；小于 0 时只写入全局动作状态。

## 方法

<a id="member-gfvirtualinputsource-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( input_mapping: GFInputMappingUtility, p_source_id: StringName = &"virtual", p_player_index: int = -1 ) -> GFVirtualInputSource:
```

配置虚拟输入源。

参数：

| 名称 | 说明 |
|---|---|
| `input_mapping` | 输入映射工具。 |
| `p_source_id` | 虚拟输入源标识。 |
| `p_player_index` | 玩家索引。 |

返回：当前输入源。

<a id="member-gfvirtualinputsource-methods-set_action_value"></a>

### `set_action_value`

- API：`public`

```gdscript
func set_action_value(action_id: StringName, value: Variant) -> bool:
```

写入动作值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 动作值。 |

返回：写入成功返回 true。

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

```gdscript
func clear_all() -> void:
```

清除当前虚拟源的所有动作贡献。

<a id="member-gfvirtualinputsource-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`

```gdscript
func get_snapshot() -> Dictionary:
```

获取当前虚拟源快照。

返回：快照字典。

结构：

- `return`: Dictionary，包含 source_id: StringName、player_index: int，以及当前虚拟输入贡献的 actions: Array[Dictionary]。
