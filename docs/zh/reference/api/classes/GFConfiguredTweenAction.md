# GFConfiguredTweenAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_configured_tween_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

由 GFTweenActionConfig 驱动的通用 Tween 动作。 允许项目把表现动画拆成 Resource 配置，再交给 GFActionQueueSystem 编排。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`marker_reached`](#member-gfconfiguredtweenaction-signals-marker_reached) | `signal marker_reached(marker_id: StringName, step_index: int, target: Object)` |
| 属性 | [`target`](#member-gfconfiguredtweenaction-properties-target) | `var target: Object` |
| 属性 | [`config`](#member-gfconfiguredtweenaction-properties-config) | `var config: GFTweenActionConfig` |
| 属性 | [`host_node`](#member-gfconfiguredtweenaction-properties-host_node) | `var host_node: Node` |
| 方法 | [`execute`](#member-gfconfiguredtweenaction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfconfiguredtweenaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfconfiguredtweenaction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfconfiguredtweenaction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfconfiguredtweenaction-methods-finish) | `func finish() -> void:` |
| 方法 | [`get_wait_guard_node`](#member-gfconfiguredtweenaction-methods-get_wait_guard_node) | `func get_wait_guard_node() -> Node:` |

## 信号

<a id="member-gfconfiguredtweenaction-signals-marker_reached"></a>

### `marker_reached`

- API：`public`

```gdscript
signal marker_reached(marker_id: StringName, step_index: int, target: Object)
```

Tween 步骤标记到达后发出。

参数：

| 名称 | 说明 |
|---|---|
| `marker_id` | 标记标识。 |
| `step_index` | 步骤索引。 |
| `target` | 被缓动目标。 |

## 属性

<a id="member-gfconfiguredtweenaction-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: Object
```

被缓动的目标对象。

<a id="member-gfconfiguredtweenaction-properties-config"></a>

### `config`

- API：`public`

```gdscript
var config: GFTweenActionConfig
```

Tween 配置。

<a id="member-gfconfiguredtweenaction-properties-host_node"></a>

### `host_node`

- API：`public`

```gdscript
var host_node: Node
```

可选 Tween 宿主节点。目标不是 Node 时必须提供。

## 方法

<a id="member-gfconfiguredtweenaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行配置化 Tween。

返回：需要等待时返回内部完成 Signal；配置无效、目标无效或瞬时写入时返回 null。

结构：

- `return`: Variant，返回内部完成 Signal 或 null。

<a id="member-gfconfiguredtweenaction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消当前 Tween，并按配置恢复初始值。

<a id="member-gfconfiguredtweenaction-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停当前 Tween。

<a id="member-gfconfiguredtweenaction-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复当前 Tween。

<a id="member-gfconfiguredtweenaction-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

立即完成当前 Tween，并按配置恢复初始值。

<a id="member-gfconfiguredtweenaction-methods-get_wait_guard_node"></a>

### `get_wait_guard_node`

- API：`public`

```gdscript
func get_wait_guard_node() -> Node:
```

获取用于保护等待生命周期的 Tween 宿主节点。

返回：有效宿主节点；无效时返回 null。
