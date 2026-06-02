# GFScreenTransitionEffect

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_screen_transition_effect.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.23.0`

屏幕覆盖式转场效果配置。 只描述通用覆盖层颜色、透明度、时长、缓动和可选 ShaderMaterial 进度参数， 不绑定具体场景切换流程或项目视觉资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`EasingMode`](#member-gfscreentransitioneffect-enums-easingmode) | `enum EasingMode` |
| 属性 | [`duration_seconds`](#member-gfscreentransitioneffect-properties-duration_seconds) | `var duration_seconds: float = 0.25` |
| 属性 | [`from_alpha`](#member-gfscreentransitioneffect-properties-from_alpha) | `var from_alpha: float = 0.0` |
| 属性 | [`to_alpha`](#member-gfscreentransitioneffect-properties-to_alpha) | `var to_alpha: float = 1.0` |
| 属性 | [`color`](#member-gfscreentransitioneffect-properties-color) | `var color: Color = Color.BLACK` |
| 属性 | [`layer`](#member-gfscreentransitioneffect-properties-layer) | `var layer: int = 120` |
| 属性 | [`block_input`](#member-gfscreentransitioneffect-properties-block_input) | `var block_input: bool = true` |
| 属性 | [`easing_mode`](#member-gfscreentransitioneffect-properties-easing_mode) | `var easing_mode: EasingMode = EasingMode.SMOOTH_STEP` |
| 属性 | [`shader_material`](#member-gfscreentransitioneffect-properties-shader_material) | `var shader_material: ShaderMaterial = null` |
| 属性 | [`progress_parameter`](#member-gfscreentransitioneffect-properties-progress_parameter) | `var progress_parameter: StringName = &"progress"` |
| 属性 | [`metadata`](#member-gfscreentransitioneffect-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfscreentransitioneffect-methods-configure) | `func configure( new_duration_seconds: float, new_from_alpha: float, new_to_alpha: float, new_color: Color = Color.BLACK ) -> GFScreenTransitionEffect:` |
| 方法 | [`sample_weight`](#member-gfscreentransitioneffect-methods-sample_weight) | `func sample_weight(elapsed_seconds: float) -> float:` |
| 方法 | [`sample_alpha`](#member-gfscreentransitioneffect-methods-sample_alpha) | `func sample_alpha(weight: float) -> float:` |
| 方法 | [`duplicate_effect`](#member-gfscreentransitioneffect-methods-duplicate_effect) | `func duplicate_effect() -> GFScreenTransitionEffect:` |
| 方法 | [`to_dict`](#member-gfscreentransitioneffect-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfscreentransitioneffect-enums-easingmode"></a>

### `EasingMode`

- API：`public`

```gdscript
enum EasingMode { ## 线性采样。 LINEAR, ## smoothstep 采样。 SMOOTH_STEP, ## 二次缓入。 EASE_IN, ## 二次缓出。 EASE_OUT, ## 二次缓入缓出。 EASE_IN_OUT, }
```

转场权重采样的缓动模式。

## 属性

<a id="member-gfscreentransitioneffect-properties-duration_seconds"></a>

### `duration_seconds`

- API：`public`

```gdscript
var duration_seconds: float = 0.25
```

转场时长，单位秒。小于等于 0 时会在下一次推进时立即完成。

<a id="member-gfscreentransitioneffect-properties-from_alpha"></a>

### `from_alpha`

- API：`public`

```gdscript
var from_alpha: float = 0.0
```

起始透明度。

<a id="member-gfscreentransitioneffect-properties-to_alpha"></a>

### `to_alpha`

- API：`public`

```gdscript
var to_alpha: float = 1.0
```

结束透明度。

<a id="member-gfscreentransitioneffect-properties-color"></a>

### `color`

- API：`public`

```gdscript
var color: Color = Color.BLACK
```

覆盖层颜色。

<a id="member-gfscreentransitioneffect-properties-layer"></a>

### `layer`

- API：`public`

```gdscript
var layer: int = 120
```

CanvasLayer 层级。

<a id="member-gfscreentransitioneffect-properties-block_input"></a>

### `block_input`

- API：`public`

```gdscript
var block_input: bool = true
```

是否让覆盖层拦截鼠标和触摸输入。

<a id="member-gfscreentransitioneffect-properties-easing_mode"></a>

### `easing_mode`

- API：`public`

```gdscript
var easing_mode: EasingMode = EasingMode.SMOOTH_STEP
```

权重采样缓动模式。

<a id="member-gfscreentransitioneffect-properties-shader_material"></a>

### `shader_material`

- API：`public`

```gdscript
var shader_material: ShaderMaterial = null
```

可选 ShaderMaterial。Utility 会复制该材质并写入 progress_parameter。

<a id="member-gfscreentransitioneffect-properties-progress_parameter"></a>

### `progress_parameter`

- API：`public`

```gdscript
var progress_parameter: StringName = &"progress"
```

shader_material 中表示进度的参数名。为空时不写入 shader 参数。

<a id="member-gfscreentransitioneffect-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，项目自定义元数据；框架不会读取或改写其中字段。

## 方法

<a id="member-gfscreentransitioneffect-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( new_duration_seconds: float, new_from_alpha: float, new_to_alpha: float, new_color: Color = Color.BLACK ) -> GFScreenTransitionEffect:
```

批量配置转场效果。

参数：

| 名称 | 说明 |
|---|---|
| `new_duration_seconds` | 转场时长，单位秒。 |
| `new_from_alpha` | 起始透明度。 |
| `new_to_alpha` | 结束透明度。 |
| `new_color` | 覆盖层颜色。 |

返回：当前资源，便于链式配置。

<a id="member-gfscreentransitioneffect-methods-sample_weight"></a>

### `sample_weight`

- API：`public`

```gdscript
func sample_weight(elapsed_seconds: float) -> float:
```

根据已流逝时间采样 0 到 1 的转场权重。

参数：

| 名称 | 说明 |
|---|---|
| `elapsed_seconds` | 已流逝秒数。 |

返回：缓动后的权重。

<a id="member-gfscreentransitioneffect-methods-sample_alpha"></a>

### `sample_alpha`

- API：`public`

```gdscript
func sample_alpha(weight: float) -> float:
```

根据转场权重采样覆盖层透明度。

参数：

| 名称 | 说明 |
|---|---|
| `weight` | 0 到 1 的转场权重。 |

返回：插值后的透明度。

<a id="member-gfscreentransitioneffect-methods-duplicate_effect"></a>

### `duplicate_effect`

- API：`public`

```gdscript
func duplicate_effect() -> GFScreenTransitionEffect:
```

复制转场效果配置。

返回：深拷贝后的转场效果。

<a id="member-gfscreentransitioneffect-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：配置字典。

结构：

- `return`: Dictionary，包含 duration_seconds、from_alpha、to_alpha、color、layer、block_input、easing_mode、progress_parameter、has_shader_material 和 metadata。
