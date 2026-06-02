# GFScreenTransitionUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_screen_transition_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.23.0`

通用屏幕覆盖式转场工具。 管理一个轻量 CanvasLayer + ColorRect 覆盖层，按 GFScreenTransitionEffect 推进颜色、 透明度和可选 shader progress。它不直接切换场景，项目可把它组合到任意流程中。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`transition_started`](#member-gfscreentransitionutility-signals-transition_started) | `signal transition_started(effect: GFScreenTransitionEffect)` |
| 信号 | [`transition_progressed`](#member-gfscreentransitionutility-signals-transition_progressed) | `signal transition_progressed(progress: float, alpha: float)` |
| 信号 | [`transition_finished`](#member-gfscreentransitionutility-signals-transition_finished) | `signal transition_finished(effect: GFScreenTransitionEffect)` |
| 信号 | [`transition_cancelled`](#member-gfscreentransitionutility-signals-transition_cancelled) | `signal transition_cancelled(effect: GFScreenTransitionEffect)` |
| 方法 | [`init`](#member-gfscreentransitionutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfscreentransitionutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfscreentransitionutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`play`](#member-gfscreentransitionutility-methods-play) | `func play(effect: GFScreenTransitionEffect, on_finished: Callable = Callable()) -> Error:` |
| 方法 | [`fade_out`](#member-gfscreentransitionutility-methods-fade_out) | `func fade_out( duration_seconds: float = 0.25, color: Color = Color.BLACK, on_finished: Callable = Callable() ) -> Error:` |
| 方法 | [`fade_in`](#member-gfscreentransitionutility-methods-fade_in) | `func fade_in( duration_seconds: float = 0.25, color: Color = Color.BLACK, on_finished: Callable = Callable() ) -> Error:` |
| 方法 | [`set_overlay_alpha`](#member-gfscreentransitionutility-methods-set_overlay_alpha) | `func set_overlay_alpha(alpha: float, color: Color = Color.BLACK) -> void:` |
| 方法 | [`hide_overlay`](#member-gfscreentransitionutility-methods-hide_overlay) | `func hide_overlay() -> void:` |
| 方法 | [`is_transition_active`](#member-gfscreentransitionutility-methods-is_transition_active) | `func is_transition_active() -> bool:` |
| 方法 | [`get_overlay_alpha`](#member-gfscreentransitionutility-methods-get_overlay_alpha) | `func get_overlay_alpha() -> float:` |
| 方法 | [`complete_transition`](#member-gfscreentransitionutility-methods-complete_transition) | `func complete_transition() -> bool:` |
| 方法 | [`cancel_transition`](#member-gfscreentransitionutility-methods-cancel_transition) | `func cancel_transition() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfscreentransitionutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfscreentransitionutility-signals-transition_started"></a>

### `transition_started`

- API：`public`

```gdscript
signal transition_started(effect: GFScreenTransitionEffect)
```

转场开始后发出。

参数：

| 名称 | 说明 |
|---|---|
| `effect` | 本次转场使用的效果配置副本。 |

<a id="member-gfscreentransitionutility-signals-transition_progressed"></a>

### `transition_progressed`

- API：`public`

```gdscript
signal transition_progressed(progress: float, alpha: float)
```

转场推进时发出。

参数：

| 名称 | 说明 |
|---|---|
| `progress` | 0 到 1 的转场权重。 |
| `alpha` | 当前覆盖层透明度。 |

<a id="member-gfscreentransitionutility-signals-transition_finished"></a>

### `transition_finished`

- API：`public`

```gdscript
signal transition_finished(effect: GFScreenTransitionEffect)
```

转场正常完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `effect` | 完成的效果配置副本。 |

<a id="member-gfscreentransitionutility-signals-transition_cancelled"></a>

### `transition_cancelled`

- API：`public`

```gdscript
signal transition_cancelled(effect: GFScreenTransitionEffect)
```

转场被取消后发出。

参数：

| 名称 | 说明 |
|---|---|
| `effect` | 被取消的效果配置副本。 |

## 方法

<a id="member-gfscreentransitionutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化覆盖层节点。

<a id="member-gfscreentransitionutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放覆盖层节点并取消当前转场。

<a id="member-gfscreentransitionutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进当前转场。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfscreentransitionutility-methods-play"></a>

### `play`

- API：`public`

```gdscript
func play(effect: GFScreenTransitionEffect, on_finished: Callable = Callable()) -> Error:
```

播放一个转场效果。若已有转场正在播放，会先取消旧转场。

参数：

| 名称 | 说明 |
|---|---|
| `effect` | 转场效果配置；Utility 会复制后使用。 |
| `on_finished` | 可选完成回调。 |

返回：启动结果。

<a id="member-gfscreentransitionutility-methods-fade_out"></a>

### `fade_out`

- API：`public`

```gdscript
func fade_out( duration_seconds: float = 0.25, color: Color = Color.BLACK, on_finished: Callable = Callable() ) -> Error:
```

播放淡出到不透明覆盖层的转场。

参数：

| 名称 | 说明 |
|---|---|
| `duration_seconds` | 转场时长，单位秒。 |
| `color` | 覆盖层颜色。 |
| `on_finished` | 可选完成回调。 |

返回：启动结果。

<a id="member-gfscreentransitionutility-methods-fade_in"></a>

### `fade_in`

- API：`public`

```gdscript
func fade_in( duration_seconds: float = 0.25, color: Color = Color.BLACK, on_finished: Callable = Callable() ) -> Error:
```

播放从不透明覆盖层淡入画面的转场。

参数：

| 名称 | 说明 |
|---|---|
| `duration_seconds` | 转场时长，单位秒。 |
| `color` | 覆盖层颜色。 |
| `on_finished` | 可选完成回调。 |

返回：启动结果。

<a id="member-gfscreentransitionutility-methods-set_overlay_alpha"></a>

### `set_overlay_alpha`

- API：`public`

```gdscript
func set_overlay_alpha(alpha: float, color: Color = Color.BLACK) -> void:
```

手动设置覆盖层透明度，不会启动转场。

参数：

| 名称 | 说明 |
|---|---|
| `alpha` | 覆盖层透明度。 |
| `color` | 覆盖层颜色。 |

<a id="member-gfscreentransitionutility-methods-hide_overlay"></a>

### `hide_overlay`

- API：`public`

```gdscript
func hide_overlay() -> void:
```

隐藏覆盖层并清空临时材质。

<a id="member-gfscreentransitionutility-methods-is_transition_active"></a>

### `is_transition_active`

- API：`public`

```gdscript
func is_transition_active() -> bool:
```

检查是否有转场正在播放。

返回：正在播放时返回 true。

<a id="member-gfscreentransitionutility-methods-get_overlay_alpha"></a>

### `get_overlay_alpha`

- API：`public`

```gdscript
func get_overlay_alpha() -> float:
```

获取当前覆盖层透明度。

返回：当前透明度。

<a id="member-gfscreentransitionutility-methods-complete_transition"></a>

### `complete_transition`

- API：`public`

```gdscript
func complete_transition() -> bool:
```

立即完成当前转场。

返回：有活动转场并完成时返回 true。

<a id="member-gfscreentransitionutility-methods-cancel_transition"></a>

### `cancel_transition`

- API：`public`

```gdscript
func cancel_transition() -> bool:
```

取消当前转场，不调用完成回调。

返回：有活动转场并取消时返回 true。

<a id="member-gfscreentransitionutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取转场工具运行时快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 overlay_created、overlay_visible、transition_active、elapsed_seconds、overlay_alpha 和 active_effect。
