# GFTweenActionStep

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd`
- 模块：`Action Queue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

配置化 Tween 属性步骤。 描述一个目标对象属性如何缓动，不绑定具体节点或业务动作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`property_name`](#member-gftweenactionstep-properties-property_name) | `var property_name: NodePath = ^"position"` |
| 属性 | [`target_value`](#member-gftweenactionstep-properties-target_value) | `var target_value: Variant = null` |
| 属性 | [`duration`](#member-gftweenactionstep-properties-duration) | `var duration: float = 0.2` |
| 属性 | [`delay`](#member-gftweenactionstep-properties-delay) | `var delay: float = 0.0` |
| 属性 | [`as_relative`](#member-gftweenactionstep-properties-as_relative) | `var as_relative: bool = false` |
| 属性 | [`parallel`](#member-gftweenactionstep-properties-parallel) | `var parallel: bool = false` |
| 属性 | [`transition_type`](#member-gftweenactionstep-properties-transition_type) | `var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC` |
| 属性 | [`ease_type`](#member-gftweenactionstep-properties-ease_type) | `var ease_type: Tween.EaseType = Tween.EASE_OUT` |
| 属性 | [`marker_id`](#member-gftweenactionstep-properties-marker_id) | `var marker_id: StringName = &""` |
| 方法 | [`append_to_tween`](#member-gftweenactionstep-methods-append_to_tween) | `func append_to_tween(tween: Tween, target: Object, duration_scale: float = 1.0) -> Variant:` |
| 方法 | [`apply_instant`](#member-gftweenactionstep-methods-apply_instant) | `func apply_instant(target: Object) -> void:` |
| 方法 | [`duplicate_step`](#member-gftweenactionstep-methods-duplicate_step) | `func duplicate_step() -> GFTweenActionStep:` |
| 方法 | [`can_apply_to`](#member-gftweenactionstep-methods-can_apply_to) | `func can_apply_to(target: Object) -> bool:` |
| 方法 | [`get_validation_error`](#member-gftweenactionstep-methods-get_validation_error) | `func get_validation_error(target: Object) -> String:` |
| 方法 | [`capture_initial_value`](#member-gftweenactionstep-methods-capture_initial_value) | `func capture_initial_value(target: Object) -> Variant:` |

## 属性

<a id="member-gftweenactionstep-properties-property_name"></a>

### `property_name`

- API：`public`

```gdscript
var property_name: NodePath = ^"position"
```

要缓动的属性路径。

<a id="member-gftweenactionstep-properties-target_value"></a>

### `target_value`

- API：`public`

```gdscript
var target_value: Variant = null
```

目标值。

结构：

- `target_value`: Variant，可写入 property_name 的目标值；相对步骤中会与当前值相加。

<a id="member-gftweenactionstep-properties-duration"></a>

### `duration`

- API：`public`

```gdscript
var duration: float = 0.2
```

步骤持续时间。

<a id="member-gftweenactionstep-properties-delay"></a>

### `delay`

- API：`public`

```gdscript
var delay: float = 0.0
```

步骤延迟。

<a id="member-gftweenactionstep-properties-as_relative"></a>

### `as_relative`

- API：`public`

```gdscript
var as_relative: bool = false
```

是否相对当前值偏移。

<a id="member-gftweenactionstep-properties-parallel"></a>

### `parallel`

- API：`public`

```gdscript
var parallel: bool = false
```

是否与前一个步骤并行。

<a id="member-gftweenactionstep-properties-transition_type"></a>

### `transition_type`

- API：`public`

```gdscript
var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
```

Tween 过渡类型。

<a id="member-gftweenactionstep-properties-ease_type"></a>

### `ease_type`

- API：`public`

```gdscript
var ease_type: Tween.EaseType = Tween.EASE_OUT
```

Tween 缓动类型。

<a id="member-gftweenactionstep-properties-marker_id"></a>

### `marker_id`

- API：`public`

```gdscript
var marker_id: StringName = &""
```

可选步骤标记。非空时 GFConfiguredTweenAction 会在步骤结束后发出 marker_reached。

## 方法

<a id="member-gftweenactionstep-methods-append_to_tween"></a>

### `append_to_tween`

- API：`public`

```gdscript
func append_to_tween(tween: Tween, target: Object, duration_scale: float = 1.0) -> Variant:
```

追加到 Tween。

参数：

| 名称 | 说明 |
|---|---|
| `tween` | 目标 Tween。 |
| `target` | 目标对象。 |
| `duration_scale` | 时长缩放。 |

返回：创建的 Tweener。

结构：

- `return`: Variant，成功时为 PropertyTweener；无效时为 null。

<a id="member-gftweenactionstep-methods-apply_instant"></a>

### `apply_instant`

- API：`public`

```gdscript
func apply_instant(target: Object) -> void:
```

立即应用步骤目标值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

<a id="member-gftweenactionstep-methods-duplicate_step"></a>

### `duplicate_step`

- API：`public`

```gdscript
func duplicate_step() -> GFTweenActionStep:
```

创建深拷贝。

返回：新步骤。

<a id="member-gftweenactionstep-methods-can_apply_to"></a>

### `can_apply_to`

- API：`public`

```gdscript
func can_apply_to(target: Object) -> bool:
```

检查目标对象是否能应用当前步骤。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

返回：可应用时返回 true。

<a id="member-gftweenactionstep-methods-get_validation_error"></a>

### `get_validation_error`

- API：`public`

```gdscript
func get_validation_error(target: Object) -> String:
```

获取当前步骤对目标对象的校验错误。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

返回：校验通过时返回空字符串。

<a id="member-gftweenactionstep-methods-capture_initial_value"></a>

### `capture_initial_value`

- API：`public`

```gdscript
func capture_initial_value(target: Object) -> Variant:
```

捕获当前属性值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

返回：属性值；步骤无效时返回 null。

结构：

- `return`: Variant，目标属性的深拷贝值；步骤无效时为 null。
