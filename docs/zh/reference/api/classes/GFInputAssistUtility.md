# GFInputAssistUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_input_assist_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

输入手感辅助工具。 负责动作意图缓冲和通用宽容窗口。它不读取 InputEvent、不处理重绑定、 不维护玩家设备，也不替代 GFInputMappingUtility；正式输入映射仍应由 GFInputMappingUtility 负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`init`](#member-gfinputassistutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfinputassistutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfinputassistutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`buffer_action`](#member-gfinputassistutility-methods-buffer_action) | `func buffer_action(action_id: StringName, duration: float, player_index: int = -1) -> void:` |
| 方法 | [`consume_buffered_action`](#member-gfinputassistutility-methods-consume_buffered_action) | `func consume_buffered_action(action_id: StringName, player_index: int = -1) -> bool:` |
| 方法 | [`has_buffered_action`](#member-gfinputassistutility-methods-has_buffered_action) | `func has_buffered_action(action_id: StringName, player_index: int = -1) -> bool:` |
| 方法 | [`clear_buffered_action`](#member-gfinputassistutility-methods-clear_buffered_action) | `func clear_buffered_action(action_id: StringName, player_index: int = -1) -> void:` |
| 方法 | [`start_grace_window`](#member-gfinputassistutility-methods-start_grace_window) | `func start_grace_window(window_id: StringName, duration: float, player_index: int = -1) -> void:` |
| 方法 | [`is_grace_window_active`](#member-gfinputassistutility-methods-is_grace_window_active) | `func is_grace_window_active(window_id: StringName, player_index: int = -1) -> bool:` |
| 方法 | [`cancel_grace_window`](#member-gfinputassistutility-methods-cancel_grace_window) | `func cancel_grace_window(window_id: StringName, player_index: int = -1) -> void:` |
| 方法 | [`clear_player`](#member-gfinputassistutility-methods-clear_player) | `func clear_player(player_index: int) -> void:` |
| 方法 | [`clear_all`](#member-gfinputassistutility-methods-clear_all) | `func clear_all() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfinputassistutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfinputassistutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化输入辅助状态并让计时不受时间缩放影响。

<a id="member-gfinputassistutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

清理全部动作缓冲和宽容窗口。

<a id="member-gfinputassistutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

每帧驱动计时器递减。所有计时器归零后自动清除。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 帧间隔时间（秒）。 |

<a id="member-gfinputassistutility-methods-buffer_action"></a>

### `buffer_action`

- API：`public`

```gdscript
func buffer_action(action_id: StringName, duration: float, player_index: int = -1) -> void:
```

缓冲一个动作意图，在 duration 秒内可被消费。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `duration` | 缓冲持续时间（秒）。 |
| `player_index` | 玩家索引；小于 0 时使用全局缓冲。 |

<a id="member-gfinputassistutility-methods-consume_buffered_action"></a>

### `consume_buffered_action`

- API：`public`

```gdscript
func consume_buffered_action(action_id: StringName, player_index: int = -1) -> bool:
```

尝试消费一个缓冲动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `player_index` | 玩家索引；小于 0 时使用全局缓冲。 |

返回：是否成功消费。

<a id="member-gfinputassistutility-methods-has_buffered_action"></a>

### `has_buffered_action`

- API：`public`

```gdscript
func has_buffered_action(action_id: StringName, player_index: int = -1) -> bool:
```

查询指定动作是否有活跃的缓冲（不消费）。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `player_index` | 玩家索引；小于 0 时使用全局缓冲。 |

返回：是否有活跃缓冲。

<a id="member-gfinputassistutility-methods-clear_buffered_action"></a>

### `clear_buffered_action`

- API：`public`

```gdscript
func clear_buffered_action(action_id: StringName, player_index: int = -1) -> void:
```

清除指定动作缓冲。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `player_index` | 玩家索引；小于 0 时使用全局缓冲。 |

<a id="member-gfinputassistutility-methods-start_grace_window"></a>

### `start_grace_window`

- API：`public`

```gdscript
func start_grace_window(window_id: StringName, duration: float, player_index: int = -1) -> void:
```

开始一个通用宽容窗口。

参数：

| 名称 | 说明 |
|---|---|
| `window_id` | 窗口标识。 |
| `duration` | 宽容窗口持续时间（秒）。 |
| `player_index` | 玩家索引；小于 0 时使用全局窗口。 |

<a id="member-gfinputassistutility-methods-is_grace_window_active"></a>

### `is_grace_window_active`

- API：`public`

```gdscript
func is_grace_window_active(window_id: StringName, player_index: int = -1) -> bool:
```

查询指定宽容窗口是否活跃。

参数：

| 名称 | 说明 |
|---|---|
| `window_id` | 窗口标识。 |
| `player_index` | 玩家索引；小于 0 时使用全局窗口。 |

返回：是否在窗口内。

<a id="member-gfinputassistutility-methods-cancel_grace_window"></a>

### `cancel_grace_window`

- API：`public`

```gdscript
func cancel_grace_window(window_id: StringName, player_index: int = -1) -> void:
```

手动取消指定宽容窗口。

参数：

| 名称 | 说明 |
|---|---|
| `window_id` | 窗口标识。 |
| `player_index` | 玩家索引；小于 0 时使用全局窗口。 |

<a id="member-gfinputassistutility-methods-clear_player"></a>

### `clear_player`

- API：`public`

```gdscript
func clear_player(player_index: int) -> void:
```

清除指定玩家的全部输入辅助状态。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

<a id="member-gfinputassistutility-methods-clear_all"></a>

### `clear_all`

- API：`public`

```gdscript
func clear_all() -> void:
```

清除所有缓冲和宽容窗口状态。

<a id="member-gfinputassistutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：包含缓冲和宽容窗口剩余时间的字典。

结构：

- `return`: Dictionary，包含按 scoped action 或 window id 索引的 action_buffers 与 grace_windows 计时器快照。
