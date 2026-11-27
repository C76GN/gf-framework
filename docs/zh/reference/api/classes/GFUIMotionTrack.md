# GFUIMotionTrack

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_track.gd`
- 模块：`Action Queue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

在页面进入、退出或会话时钟上安排效果与标记。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Clock`](#member-gfuimotiontrack-enums-clock) | `enum Clock` |
| 属性 | [`cue`](#member-gfuimotiontrack-properties-cue) | `var cue: StringName` |
| 属性 | [`target`](#member-gfuimotiontrack-properties-target) | `var target: StringName = &"incoming"` |
| 属性 | [`clock`](#member-gfuimotiontrack-properties-clock) | `var clock: Clock = Clock.ENTER` |
| 属性 | [`at`](#member-gfuimotiontrack-properties-at) | `var at: float = 0.0` |
| 属性 | [`delay_seconds`](#member-gfuimotiontrack-properties-delay_seconds) | `var delay_seconds: float = 0.0` |
| 属性 | [`duration`](#member-gfuimotiontrack-properties-duration) | `var duration: float = 1.0` |
| 属性 | [`relative_duration`](#member-gfuimotiontrack-properties-relative_duration) | `var relative_duration: bool = true` |
| 属性 | [`stagger_seconds`](#member-gfuimotiontrack-properties-stagger_seconds) | `var stagger_seconds: float = 0.0` |
| 属性 | [`transition`](#member-gfuimotiontrack-properties-transition) | `var transition: Tween.TransitionType = Tween.TRANS_LINEAR` |
| 属性 | [`easing`](#member-gfuimotiontrack-properties-easing) | `var easing: Tween.EaseType = Tween.EASE_IN_OUT` |
| 属性 | [`curve`](#member-gfuimotiontrack-properties-curve) | `var curve: Curve` |
| 属性 | [`effect`](#member-gfuimotiontrack-properties-effect) | `var effect: GFUIMotionEffect` |

## 枚举

<a id="member-gfuimotiontrack-enums-clock"></a>

### `Clock`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Clock {
	## 以新页入场区间为基准。
	ENTER,
	## 以旧页退出区间为基准。
	EXIT,
	## 以会话起点、以秒为单位安排动作。
	SESSION,
}
```

定义时刻和相对时长的参考区间。

## 属性

<a id="member-gfuimotiontrack-properties-cue"></a>

### `cue`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var cue: StringName
```

轨道开始时发送的标识。单独填写可通知页面播放自己的原生动画。

<a id="member-gfuimotiontrack-properties-target"></a>

### `target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var target: StringName = &"incoming"
```

从播放调用的绑定表中查找此目标；目标数组依次错峰。

<a id="member-gfuimotiontrack-properties-clock"></a>

### `clock`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var clock: Clock = Clock.ENTER
```

选择时间参考系。

<a id="member-gfuimotiontrack-properties-at"></a>

### `at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 1, 0.001)
var at: float = 0.0
```

页时钟下为 0 到 1 的起始比例，会话时钟下直接使用 delay_seconds。

<a id="member-gfuimotiontrack-properties-delay_seconds"></a>

### `delay_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 60, 0.001, "or_greater")
var delay_seconds: float = 0.0
```

相对触发点的额外延迟，单位秒。

<a id="member-gfuimotiontrack-properties-duration"></a>

### `duration`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 60, 0.001, "or_greater")
var duration: float = 1.0
```

局部时长，可按参考区间比例或秒解释。

<a id="member-gfuimotiontrack-properties-relative_duration"></a>

### `relative_duration`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var relative_duration: bool = true
```

在页时钟中用参考页时长乘 duration。会话时钟始终使用秒。

<a id="member-gfuimotiontrack-properties-stagger_seconds"></a>

### `stagger_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 5, 0.001, "or_greater")
var stagger_seconds: float = 0.0
```

对目标数组每个后继元素增加的时间偏移，单位秒。

<a id="member-gfuimotiontrack-properties-transition"></a>

### `transition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var transition: Tween.TransitionType = Tween.TRANS_LINEAR
```

插值使用的 Godot 曲线类型。

<a id="member-gfuimotiontrack-properties-easing"></a>

### `easing`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var easing: Tween.EaseType = Tween.EASE_IN_OUT
```

插值曲线的缓入缓出方向。

<a id="member-gfuimotiontrack-properties-curve"></a>

### `curve`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var curve: Curve
```

可选进度曲线，存在时覆盖原生缓动并允许中途超调。

<a id="member-gfuimotiontrack-properties-effect"></a>

### `effect`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var effect: GFUIMotionEffect
```

可复用的效果。留空并填写 cue 时只发送瞬时标记，目标及错峰照常生效。
