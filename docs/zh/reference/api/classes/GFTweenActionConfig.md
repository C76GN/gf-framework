# GFTweenActionConfig

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd`
- 模块：`Action Queue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

配置化 Tween 动作资源。 可复用地描述一组属性 Tween 步骤，并生成 GFVisualAction。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`steps`](#member-gftweenactionconfig-properties-steps) | `var steps: Array[GFTweenActionStep] = []` |
| 属性 | [`duration_scale`](#member-gftweenactionconfig-properties-duration_scale) | `var duration_scale: float = 1.0` |
| 属性 | [`loop_count`](#member-gftweenactionconfig-properties-loop_count) | `var loop_count: int = 1` |
| 属性 | [`ignore_time_scale`](#member-gftweenactionconfig-properties-ignore_time_scale) | `var ignore_time_scale: bool = false` |
| 属性 | [`process_mode`](#member-gftweenactionconfig-properties-process_mode) | `var process_mode: Tween.TweenProcessMode = Tween.TWEEN_PROCESS_IDLE` |
| 属性 | [`pause_mode`](#member-gftweenactionconfig-properties-pause_mode) | `var pause_mode: Tween.TweenPauseMode = Tween.TWEEN_PAUSE_BOUND` |
| 属性 | [`restore_initial_values_on_cancel`](#member-gftweenactionconfig-properties-restore_initial_values_on_cancel) | `var restore_initial_values_on_cancel: bool = false` |
| 属性 | [`restore_initial_values_on_finish`](#member-gftweenactionconfig-properties-restore_initial_values_on_finish) | `var restore_initial_values_on_finish: bool = false` |
| 方法 | [`create_action`](#member-gftweenactionconfig-methods-create_action) | `func create_action(target: Object, host_node: Node = null) -> GFVisualAction:` |
| 方法 | [`add_property_step`](#member-gftweenactionconfig-methods-add_property_step) | `func add_property_step( property_name: NodePath, target_value: Variant, duration: float = 0.2 ) -> GFTweenActionStep:` |
| 方法 | [`is_empty`](#member-gftweenactionconfig-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`has_timed_steps`](#member-gftweenactionconfig-methods-has_timed_steps) | `func has_timed_steps() -> bool:` |
| 方法 | [`apply_instant`](#member-gftweenactionconfig-methods-apply_instant) | `func apply_instant(target: Object) -> void:` |
| 方法 | [`capture_initial_values`](#member-gftweenactionconfig-methods-capture_initial_values) | `func capture_initial_values(target: Object) -> Dictionary:` |
| 方法 | [`restore_initial_values`](#member-gftweenactionconfig-methods-restore_initial_values) | `func restore_initial_values(target: Object, snapshot: Dictionary) -> void:` |
| 方法 | [`get_validation_report`](#member-gftweenactionconfig-methods-get_validation_report) | `func get_validation_report(target: Object) -> GFValidationReport:` |
| 方法 | [`duplicate_config`](#member-gftweenactionconfig-methods-duplicate_config) | `func duplicate_config() -> GFTweenActionConfig:` |

## 属性

<a id="member-gftweenactionconfig-properties-steps"></a>

### `steps`

- API：`public`

```gdscript
var steps: Array[GFTweenActionStep] = []
```

Tween 步骤列表。

结构：

- `steps`: Array，元素为 GFTweenActionStep。

<a id="member-gftweenactionconfig-properties-duration_scale"></a>

### `duration_scale`

- API：`public`

```gdscript
var duration_scale: float = 1.0
```

全局时长缩放。

<a id="member-gftweenactionconfig-properties-loop_count"></a>

### `loop_count`

- API：`public`

```gdscript
var loop_count: int = 1
```

播放次数。1 表示播放一次，0 表示无限循环。

<a id="member-gftweenactionconfig-properties-ignore_time_scale"></a>

### `ignore_time_scale`

- API：`public`

```gdscript
var ignore_time_scale: bool = false
```

是否忽略全局 time scale。

<a id="member-gftweenactionconfig-properties-process_mode"></a>

### `process_mode`

- API：`public`

```gdscript
var process_mode: Tween.TweenProcessMode = Tween.TWEEN_PROCESS_IDLE
```

Tween 处理模式。

<a id="member-gftweenactionconfig-properties-pause_mode"></a>

### `pause_mode`

- API：`public`

```gdscript
var pause_mode: Tween.TweenPauseMode = Tween.TWEEN_PAUSE_BOUND
```

Tween 暂停模式。

<a id="member-gftweenactionconfig-properties-restore_initial_values_on_cancel"></a>

### `restore_initial_values_on_cancel`

- API：`public`

```gdscript
var restore_initial_values_on_cancel: bool = false
```

取消动作时是否恢复播放前捕获的属性值。

<a id="member-gftweenactionconfig-properties-restore_initial_values_on_finish"></a>

### `restore_initial_values_on_finish`

- API：`public`

```gdscript
var restore_initial_values_on_finish: bool = false
```

动作正常完成或 finish() 时是否恢复播放前捕获的属性值。

## 方法

<a id="member-gftweenactionconfig-methods-create_action"></a>

### `create_action`

- API：`public`

```gdscript
func create_action(target: Object, host_node: Node = null) -> GFVisualAction:
```

创建配置化 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `host_node` | 可选 Tween 宿主节点。 |

返回：动作实例。

<a id="member-gftweenactionconfig-methods-add_property_step"></a>

### `add_property_step`

- API：`public`

```gdscript
func add_property_step( property_name: NodePath, target_value: Variant, duration: float = 0.2 ) -> GFTweenActionStep:
```

添加一个属性步骤并返回该步骤。

参数：

| 名称 | 说明 |
|---|---|
| `property_name` | 属性路径。 |
| `target_value` | 目标值。 |
| `duration` | 持续时间。 |

返回：新步骤。

结构：

- `target_value`: Variant，可写入 property_name 的目标值。

<a id="member-gftweenactionconfig-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

是否没有有效步骤。

返回：无步骤返回 true。

<a id="member-gftweenactionconfig-methods-has_timed_steps"></a>

### `has_timed_steps`

- API：`public`

```gdscript
func has_timed_steps() -> bool:
```

是否包含需要等待的步骤。

返回：包含耗时步骤返回 true。

<a id="member-gftweenactionconfig-methods-apply_instant"></a>

### `apply_instant`

- API：`public`

```gdscript
func apply_instant(target: Object) -> void:
```

立即应用全部步骤。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

<a id="member-gftweenactionconfig-methods-capture_initial_values"></a>

### `capture_initial_values`

- API：`public`

```gdscript
func capture_initial_values(target: Object) -> Dictionary:
```

捕获所有有效步骤的初始属性值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

返回：属性路径字符串到初始值的字典。

结构：

- `return`: Dictionary，key 为属性路径 String，value 为对应初始属性值的深拷贝。

<a id="member-gftweenactionconfig-methods-restore_initial_values"></a>

### `restore_initial_values`

- API：`public`

```gdscript
func restore_initial_values(target: Object, snapshot: Dictionary) -> void:
```

恢复 capture_initial_values() 捕获的属性值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `snapshot` | 初始值快照。 |

结构：

- `snapshot`: Dictionary，key 为属性路径 String，value 为要恢复的属性值。

<a id="member-gftweenactionconfig-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`

```gdscript
func get_validation_report(target: Object) -> GFValidationReport:
```

获取配置对目标对象的校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

返回：校验报告。

<a id="member-gftweenactionconfig-methods-duplicate_config"></a>

### `duplicate_config`

- API：`public`

```gdscript
func duplicate_config() -> GFTweenActionConfig:
```

创建深拷贝。

返回：新配置。
