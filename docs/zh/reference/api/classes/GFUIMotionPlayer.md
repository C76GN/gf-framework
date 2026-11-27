# GFUIMotionPlayer

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_player.gd`
- 模块：`Action Queue`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

在一个宿主中播放双页与组件轨道，逐次绑定，并隔离各次运行、取消和定位。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cue_reached`](#member-gfuimotionplayer-signals-cue_reached) | `signal cue_reached(cue: StringName, target: Object)` |
| 信号 | [`page_entered`](#member-gfuimotionplayer-signals-page_entered) | `signal page_entered` |
| 信号 | [`ended`](#member-gfuimotionplayer-signals-ended) | `signal ended(reason: GFUIMotionBinding.EndReason)` |
| 属性 | [`take_over_properties`](#member-gfuimotionplayer-properties-take_over_properties) | `var take_over_properties: bool = false` |
| 方法 | [`play`](#member-gfuimotionplayer-methods-play) | `func play( recipe: GFUIMotionRecipe, targets: Dictionary, inputs: Dictionary = {}, paused: bool = false ) -> Error:` |
| 方法 | [`play_transition`](#member-gfuimotionplayer-methods-play_transition) | `func play_transition( outgoing: Control, incoming: Control, release: Callable, recipe: GFUIMotionRecipe, bind_roles: Callable, inputs: Dictionary = {} ) -> Error:` |
| 方法 | [`pause`](#member-gfuimotionplayer-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfuimotionplayer-methods-resume) | `func resume() -> void:` |
| 方法 | [`seek`](#member-gfuimotionplayer-methods-seek) | `func seek(seconds: float) -> bool:` |
| 方法 | [`finish`](#member-gfuimotionplayer-methods-finish) | `func finish() -> void:` |
| 方法 | [`cancel`](#member-gfuimotionplayer-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`is_active`](#member-gfuimotionplayer-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`can_seek`](#member-gfuimotionplayer-methods-can_seek) | `func can_seek() -> bool:` |
| 方法 | [`get_duration_seconds`](#member-gfuimotionplayer-methods-get_duration_seconds) | `func get_duration_seconds() -> float:` |
| 方法 | [`get_time_seconds`](#member-gfuimotionplayer-methods-get_time_seconds) | `func get_time_seconds() -> float:` |
| 方法 | [`get_diagnostic`](#member-gfuimotionplayer-methods-get_diagnostic) | `func get_diagnostic() -> String:` |
| 方法 | [`get_track_intervals`](#member-gfuimotionplayer-methods-get_track_intervals) | `func get_track_intervals() -> Array[Dictionary]:` |

## 信号

<a id="member-gfuimotionplayer-signals-cue_reached"></a>

### `cue_reached`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal cue_reached(cue: StringName, target: Object)
```

轨道对一个元素开始，仅正向播放跨过触点时发送。

参数：

| 名称 | 说明 |
|---|---|
| `cue` | 作者设置的轨道标记。 |
| `target` | 此次触发的目标。 |

<a id="member-gfuimotionplayer-signals-page_entered"></a>

### `page_entered`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal page_entered
```

新页的入场时间已结束，页内轨道可继续播放。

<a id="member-gfuimotionplayer-signals-ended"></a>

### `ended`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal ended(reason: GFUIMotionBinding.EndReason)
```

本次会话已经释放绑定。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 自然、立即完成或取消。 |

## 属性

<a id="member-gfuimotionplayer-properties-take_over_properties"></a>

### `take_over_properties`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var take_over_properties: bool = false
```

允许本播放器接管其他界面播放器已经拥有的属性。默认在修改任何目标前报告冲突。

## 方法

<a id="member-gfuimotionplayer-methods-play"></a>

### `play`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func play( recipe: GFUIMotionRecipe, targets: Dictionary, inputs: Dictionary = {}, paused: bool = false ) -> Error:
```

先检查完整配方和具名绑定，再替换本宿主的会话。配置的时间及曲线在本次播放开始时冻结。

参数：

| 名称 | 说明 |
|---|---|
| `recipe` | 双页与独立局部轨道。 |
| `targets` | 单一目标或同一轨道的有序目标数组。 |
| `inputs` | 共用的显式项目输入。 |
| `paused` | 从可定位的初始画面开始，仅实播动作等待恢复。 |

返回：OK 或错误码，细节可由 get_diagnostic 获取。

结构：

- `targets`: Dictionary，StringName 映射到 Object 或有序 Array[Object]。
- `inputs`: Dictionary，StringName 映射到效果声明的输入类型。

<a id="member-gfuimotionplayer-methods-play_transition"></a>

### `play_transition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func play_transition( outgoing: Control, incoming: Control, release: Callable, recipe: GFUIMotionRecipe, bind_roles: Callable, inputs: Dictionary = {} ) -> Error:
```

接受 GFUIUtility.navigate_with_presentation 的同步交接。普通页面切换直接播放原有控件。 项目按实际节点提供角色；旧页使用完毕时恢复其姿态并交还路由，页内动画继续。

参数：

| 名称 | 说明 |
|---|---|
| `outgoing` | 路由保留的旧页。 |
| `incoming` | 已经接管导航和焦点的新页。 |
| `release` | 路由提供的幂等释放回调。 |
| `recipe` | 可在不同页面之间复用的时序。 |
| `bind_roles` | 接收旧页和新页，返回角色到目标或有序目标列表的字典。 |
| `inputs` | 项目提供的额外输入。 |

返回：播放是否已启动。

结构：

- `inputs`: Dictionary，StringName 映射到效果声明的输入。

<a id="member-gfuimotionplayer-methods-pause"></a>

### `pause`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pause() -> void:
```

停止时间推进，同时暂停当前正在播放的外部动作。

<a id="member-gfuimotionplayer-methods-resume"></a>

### `resume`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func resume() -> void:
```

从当前时间继续前进。

<a id="member-gfuimotionplayer-methods-seek"></a>

### `seek`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func seek(seconds: float) -> bool:
```

暂停并直接重建指定时间的姿态，不触发标记或结束会话。实播动作拒绝定位。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 闭区间内的会话秒数。 |

返回：是否成功重建。

<a id="member-gfuimotionplayer-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func finish() -> void:
```

应用采样动作的终点，结束已经启动的实播动作，跳过尚未触发的事件。

<a id="member-gfuimotionplayer-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> void:
```

取消本次播放并释放拥有的临时资源。采样时发起的取消会在当前钩子返回后处理。

<a id="member-gfuimotionplayer-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

判断会话仍可控制。

返回：已准备且未释放时为 true。

<a id="member-gfuimotionplayer-methods-can_seek"></a>

### `can_seek`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func can_seek() -> bool:
```

当前会话是否所有轨道均可任意定位。

返回：有实播动作、已经交还目标或路由正在交接时为 false。

<a id="member-gfuimotionplayer-methods-get_duration_seconds"></a>

### `get_duration_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duration_seconds() -> float:
```

读取最近一次有效会话的总长。

返回：以秒计的有限端点。

<a id="member-gfuimotionplayer-methods-get_time_seconds"></a>

### `get_time_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_time_seconds() -> float:
```

读取当前的时间。

返回：会话开始后的秒数。

<a id="member-gfuimotionplayer-methods-get_diagnostic"></a>

### `get_diagnostic`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_diagnostic() -> String:
```

取得最近一次准备错误以定位轨道和输入。

返回：成功时为空。

<a id="member-gfuimotionplayer-methods-get_track_intervals"></a>

### `get_track_intervals`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_track_intervals() -> Array[Dictionary]:
```

获取当前会话已绑定的各目标区间，按实际触发时刻排列。

返回：每次调用返回独立快照；空闲时为空。

结构：

- `return`: Array[Dictionary]，每项含 track_index(int)、start_seconds(float)、end_seconds(float)，区间以会话起点为零。
