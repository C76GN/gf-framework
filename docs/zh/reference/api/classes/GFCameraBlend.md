# GFCameraBlend

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/resources/gf_camera_blend.gd`
- 模块：`Camera`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用相机过渡资源。 描述两个相机姿态之间的时间和缓动方式，不绑定具体相机节点、 目标选择规则、反馈效果或场景业务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`duration_seconds`](#member-gfcamerablend-properties-duration_seconds) | `var duration_seconds: float:` |
| 属性 | [`transition_type`](#member-gfcamerablend-properties-transition_type) | `var transition_type: Tween.TransitionType:` |
| 属性 | [`ease_type`](#member-gfcamerablend-properties-ease_type) | `var ease_type: Tween.EaseType:` |
| 方法 | [`is_instant`](#member-gfcamerablend-methods-is_instant) | `func is_instant() -> bool:` |
| 方法 | [`sample_weight`](#member-gfcamerablend-methods-sample_weight) | `func sample_weight(elapsed_seconds: float) -> float:` |
| 方法 | [`duplicate_blend`](#member-gfcamerablend-methods-duplicate_blend) | `func duplicate_blend() -> GFCameraBlend:` |

## 属性

<a id="member-gfcamerablend-properties-duration_seconds"></a>

### `duration_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var duration_seconds: float:
```

过渡持续时间，单位秒。小于等于 0 时表示立即切换。

<a id="member-gfcamerablend-properties-transition_type"></a>

### `transition_type`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var transition_type: Tween.TransitionType:
```

Tween 过渡类型。

<a id="member-gfcamerablend-properties-ease_type"></a>

### `ease_type`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var ease_type: Tween.EaseType:
```

Tween 缓动类型。

## 方法

<a id="member-gfcamerablend-methods-is_instant"></a>

### `is_instant`

- API：`public`

```gdscript
func is_instant() -> bool:
```

是否为立即切换。

返回：持续时间小于等于 0 时返回 true。

<a id="member-gfcamerablend-methods-sample_weight"></a>

### `sample_weight`

- API：`public`

```gdscript
func sample_weight(elapsed_seconds: float) -> float:
```

按已过时间采样 0..1 权重。

参数：

| 名称 | 说明 |
|---|---|
| `elapsed_seconds` | 已过时间。 |

返回：缓动后的权重。

<a id="member-gfcamerablend-methods-duplicate_blend"></a>

### `duplicate_blend`

- API：`public`

```gdscript
func duplicate_blend() -> GFCameraBlend:
```

创建深拷贝。

返回：新过渡资源。
