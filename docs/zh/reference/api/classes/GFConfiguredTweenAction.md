# GFConfiguredTweenAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_configured_tween_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

配置驱动的 Tween 动作，支持可选冻结时间轴与属性替换。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`marker_reached`](#member-gfconfiguredtweenaction-signals-marker_reached) | `signal marker_reached(marker_id: StringName, step_index: int, target: Object)` |
| 属性 | [`target`](#member-gfconfiguredtweenaction-properties-target) | `var target: Object` |
| 属性 | [`config`](#member-gfconfiguredtweenaction-properties-config) | `var config: GFTweenActionConfig` |
| 属性 | [`host_node`](#member-gfconfiguredtweenaction-properties-host_node) | `var host_node: Node` |
| 属性 | [`replacement_scope`](#member-gfconfiguredtweenaction-properties-replacement_scope) | `var replacement_scope: GFTweenReplacementScope = null` |
| 方法 | [`execute`](#member-gfconfiguredtweenaction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfconfiguredtweenaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfconfiguredtweenaction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfconfiguredtweenaction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfconfiguredtweenaction-methods-finish) | `func finish() -> void:` |
| 方法 | [`seek`](#member-gfconfiguredtweenaction-methods-seek) | `func seek(time_seconds: float) -> bool:` |
| 方法 | [`play_forward`](#member-gfconfiguredtweenaction-methods-play_forward) | `func play_forward() -> bool:` |
| 方法 | [`play_backward`](#member-gfconfiguredtweenaction-methods-play_backward) | `func play_backward() -> bool:` |
| 方法 | [`can_control_playback`](#member-gfconfiguredtweenaction-methods-can_control_playback) | `func can_control_playback() -> bool:` |
| 方法 | [`get_time_seconds`](#member-gfconfiguredtweenaction-methods-get_time_seconds) | `func get_time_seconds() -> float:` |
| 方法 | [`get_duration_seconds`](#member-gfconfiguredtweenaction-methods-get_duration_seconds) | `func get_duration_seconds() -> float:` |
| 方法 | [`get_wait_guard_node`](#member-gfconfiguredtweenaction-methods-get_wait_guard_node) | `func get_wait_guard_node() -> Node:` |

## 信号

<a id="member-gfconfiguredtweenaction-signals-marker_reached"></a>

### `marker_reached`

- API：`public`
- 首次版本：`3.9.0`

```gdscript
signal marker_reached(marker_id: StringName, step_index: int, target: Object)
```

正向到达标记时发出；定位、倒放和立即完成不补发标记。

参数：

| 名称 | 说明 |
|---|---|
| `marker_id` | 标记标识。 |
| `step_index` | 步骤索引。 |
| `target` | 本次执行的缓动目标。 |

## 属性

<a id="member-gfconfiguredtweenaction-properties-target"></a>

### `target`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
var target: Object
```

被缓动的目标对象。

<a id="member-gfconfiguredtweenaction-properties-config"></a>

### `config`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
var config: GFTweenActionConfig
```

Tween 配置；执行后修改不改变已捕获的时间轴。

<a id="member-gfconfiguredtweenaction-properties-host_node"></a>

### `host_node`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
var host_node: Node
```

可选宿主节点，目标不是 Node 时必须提供。

<a id="member-gfconfiguredtweenaction-properties-replacement_scope"></a>

### `replacement_scope`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var replacement_scope: GFTweenReplacementScope = null
```

属性替换作用域；启用冻结时间轴，接管时旧动作保留当前姿态并完成。

## 方法

<a id="member-gfconfiguredtweenaction-methods-execute"></a>

### `execute`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func execute() -> Variant:
```

开始新执行；先结束旧会话，再按当前配置捕获新会话。

返回：需要等待时返回内部完成 Signal；拒绝、重入失权或瞬时执行时返回 null。

结构：

- `return`: Variant，内部完成 Signal 或 null。

<a id="member-gfconfiguredtweenaction-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func cancel() -> void:
```

取消当前执行并按捕获配置恢复初值；终态重复调用无副作用。

<a id="member-gfconfiguredtweenaction-methods-pause"></a>

### `pause`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func pause() -> void:
```

暂停当前 Tween。

<a id="member-gfconfiguredtweenaction-methods-resume"></a>

### `resume`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func resume() -> void:
```

沿当前方向恢复播放。

<a id="member-gfconfiguredtweenaction-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func finish() -> void:
```

立即完成当前方向，不补发标记；按捕获配置恢复初值。 原生有限 Tween 推进到实际终点；无限循环停在当前姿态。 有限原生计划超过 4096 个展开属性步骤或总时长非有限时，警告并停止在当前姿态。 原生属性 setter 或标记回调内调用时延后到安全时机。

<a id="member-gfconfiguredtweenaction-methods-seek"></a>

### `seek`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func seek(time_seconds: float) -> bool:
```

定位并暂停，只提交最终样本；不触发完成或标记。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 0 至总时长的有限秒数，包含全部循环。 |

返回：定位成功返回 true；拒绝或提交期间失权返回 false。

<a id="member-gfconfiguredtweenaction-methods-play_forward"></a>

### `play_forward`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func play_forward() -> bool:
```

从当前时间向时间轴终点播放。

返回：活跃可控会话开始播放时返回 true。

<a id="member-gfconfiguredtweenaction-methods-play_backward"></a>

### `play_backward`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func play_backward() -> bool:
```

从当前时间倒放到时间轴起点，不发出步骤标记。

返回：活跃可控会话开始倒放时返回 true。

<a id="member-gfconfiguredtweenaction-methods-can_control_playback"></a>

### `can_control_playback`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func can_control_playback() -> bool:
```

查询本次执行是否支持定位和方向控制。

返回：已捕获且尚未终结的可控会话返回 true。

<a id="member-gfconfiguredtweenaction-methods-get_time_seconds"></a>

### `get_time_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_time_seconds() -> float:
```

获取可控会话当前时间；未捕获时为 0。

返回：当前秒数，终态保留最后提交时间。

<a id="member-gfconfiguredtweenaction-methods-get_duration_seconds"></a>

### `get_duration_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duration_seconds() -> float:
```

获取捕获时间轴的总时长，包含全部循环与回程。

返回：总秒数；原生模式或未捕获时为 0。

<a id="member-gfconfiguredtweenaction-methods-get_wait_guard_node"></a>

### `get_wait_guard_node`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func get_wait_guard_node() -> Node:
```

获取保护等待生命周期的宿主节点。

返回：有效宿主，无效时返回 null。
