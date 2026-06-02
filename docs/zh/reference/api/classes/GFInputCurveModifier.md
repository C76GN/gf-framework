# GFInputCurveModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_curve_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入曲线修饰器。 对输入分量按 Curve 重新采样，适合摇杆灵敏度、扳机响应和虚拟指针速度曲线。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`curve`](#member-gfinputcurvemodifier-properties-curve) | `var curve: Curve = null` |
| 属性 | [`preserve_sign`](#member-gfinputcurvemodifier-properties-preserve_sign) | `var preserve_sign: bool = true` |
| 属性 | [`apply_x`](#member-gfinputcurvemodifier-properties-apply_x) | `var apply_x: bool = true` |
| 属性 | [`apply_y`](#member-gfinputcurvemodifier-properties-apply_y) | `var apply_y: bool = true` |
| 属性 | [`apply_z`](#member-gfinputcurvemodifier-properties-apply_z) | `var apply_z: bool = true` |
| 方法 | [`modify`](#member-gfinputcurvemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputcurvemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 属性

<a id="member-gfinputcurvemodifier-properties-curve"></a>

### `curve`

- API：`public`

```gdscript
var curve: Curve = null
```

输入曲线。采样区间为 0..1。

<a id="member-gfinputcurvemodifier-properties-preserve_sign"></a>

### `preserve_sign`

- API：`public`

```gdscript
var preserve_sign: bool = true
```

是否保留输入符号，只用绝对值采样曲线。

<a id="member-gfinputcurvemodifier-properties-apply_x"></a>

### `apply_x`

- API：`public`

```gdscript
var apply_x: bool = true
```

是否处理 X 分量。

<a id="member-gfinputcurvemodifier-properties-apply_y"></a>

### `apply_y`

- API：`public`

```gdscript
var apply_y: bool = true
```

是否处理 Y 分量。

<a id="member-gfinputcurvemodifier-properties-apply_z"></a>

### `apply_z`

- API：`public`

```gdscript
var apply_z: bool = true
```

是否处理 Z 分量。

## 方法

<a id="member-gfinputcurvemodifier-methods-modify"></a>

### `modify`

- API：`public`

```gdscript
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
```

修改二维输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |
| `_event` | 原始输入事件，默认实现不直接使用。 |
| `_action` | 当前输入动作配置，默认实现不直接使用。 |

返回：按曲线采样后的二维输入值。

<a id="member-gfinputcurvemodifier-methods-modify_3d"></a>

### `modify_3d`

- API：`public`

```gdscript
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
```

修改三维输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |
| `_event` | 原始输入事件，默认实现不直接使用。 |
| `_action` | 当前输入动作配置，默认实现不直接使用。 |

返回：按曲线采样后的三维输入值。
