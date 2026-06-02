# GFInputDirectionHistory

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/history/gf_input_direction_history.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

最后按下方向优先的输入历史。 维护动作 ID 到方向向量的按下顺序，适合网格移动、菜单导航或四方向角色控制。 它不读取 InputMap，也不规定动作命名。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`press_action`](#member-gfinputdirectionhistory-methods-press_action) | `func press_action(action_id: StringName, direction: Vector2i) -> void:` |
| 方法 | [`release_action`](#member-gfinputdirectionhistory-methods-release_action) | `func release_action(action_id: StringName) -> void:` |
| 方法 | [`press_direction`](#member-gfinputdirectionhistory-methods-press_direction) | `func press_direction(direction: Vector2i) -> void:` |
| 方法 | [`release_direction`](#member-gfinputdirectionhistory-methods-release_direction) | `func release_direction(direction: Vector2i) -> void:` |
| 方法 | [`update_action`](#member-gfinputdirectionhistory-methods-update_action) | `func update_action(action_id: StringName, direction: Vector2i, pressed: bool) -> void:` |
| 方法 | [`get_current_direction`](#member-gfinputdirectionhistory-methods-get_current_direction) | `func get_current_direction() -> Vector2i:` |
| 方法 | [`get_current_action`](#member-gfinputdirectionhistory-methods-get_current_action) | `func get_current_action() -> StringName:` |
| 方法 | [`get_history`](#member-gfinputdirectionhistory-methods-get_history) | `func get_history() -> Array[StringName]:` |
| 方法 | [`clear`](#member-gfinputdirectionhistory-methods-clear) | `func clear() -> void:` |

## 方法

<a id="member-gfinputdirectionhistory-methods-press_action"></a>

### `press_action`

- API：`public`

```gdscript
func press_action(action_id: StringName, direction: Vector2i) -> void:
```

标记一个方向动作被按下。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `direction` | 方向。 |

<a id="member-gfinputdirectionhistory-methods-release_action"></a>

### `release_action`

- API：`public`

```gdscript
func release_action(action_id: StringName) -> void:
```

标记一个方向动作被释放。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

<a id="member-gfinputdirectionhistory-methods-press_direction"></a>

### `press_direction`

- API：`public`

```gdscript
func press_direction(direction: Vector2i) -> void:
```

按方向值生成内部动作标识并标记按下。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 方向。 |

<a id="member-gfinputdirectionhistory-methods-release_direction"></a>

### `release_direction`

- API：`public`

```gdscript
func release_direction(direction: Vector2i) -> void:
```

按方向值生成内部动作标识并标记释放。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 方向。 |

<a id="member-gfinputdirectionhistory-methods-update_action"></a>

### `update_action`

- API：`public`

```gdscript
func update_action(action_id: StringName, direction: Vector2i, pressed: bool) -> void:
```

根据 pressed 状态更新动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `direction` | 方向。 |
| `pressed` | 是否按下。 |

<a id="member-gfinputdirectionhistory-methods-get_current_direction"></a>

### `get_current_direction`

- API：`public`

```gdscript
func get_current_direction() -> Vector2i:
```

获取当前优先方向。

返回：最近按下且尚未释放的方向；没有时返回 Vector2i.ZERO。

<a id="member-gfinputdirectionhistory-methods-get_current_action"></a>

### `get_current_action`

- API：`public`

```gdscript
func get_current_action() -> StringName:
```

获取当前优先动作。

返回：最近按下且尚未释放的动作；没有时返回空 StringName。

<a id="member-gfinputdirectionhistory-methods-get_history"></a>

### `get_history`

- API：`public`

```gdscript
func get_history() -> Array[StringName]:
```

获取按下历史副本。

返回：动作 ID 列表。

<a id="member-gfinputdirectionhistory-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空历史。
