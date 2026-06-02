# GFInputMagnitudeModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_magnitude_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入幅值投影修饰器。 将多轴输入转换为长度值，并按配置写回到指定分量。它只处理向量数值， 不解释这个幅值代表移动、视角、压力或其他业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`output_x`](#member-gfinputmagnitudemodifier-properties-output_x) | `var output_x: bool = true` |
| 属性 | [`output_y`](#member-gfinputmagnitudemodifier-properties-output_y) | `var output_y: bool = false` |
| 属性 | [`output_z`](#member-gfinputmagnitudemodifier-properties-output_z) | `var output_z: bool = false` |
| 属性 | [`absolute_value`](#member-gfinputmagnitudemodifier-properties-absolute_value) | `var absolute_value: bool = true` |
| 属性 | [`preserve_unselected_components`](#member-gfinputmagnitudemodifier-properties-preserve_unselected_components) | `var preserve_unselected_components: bool = false` |
| 方法 | [`modify`](#member-gfinputmagnitudemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputmagnitudemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 属性

<a id="member-gfinputmagnitudemodifier-properties-output_x"></a>

### `output_x`

- API：`public`

```gdscript
var output_x: bool = true
```

输出幅值到 X 分量。

<a id="member-gfinputmagnitudemodifier-properties-output_y"></a>

### `output_y`

- API：`public`

```gdscript
var output_y: bool = false
```

输出幅值到 Y 分量。

<a id="member-gfinputmagnitudemodifier-properties-output_z"></a>

### `output_z`

- API：`public`

```gdscript
var output_z: bool = false
```

输出幅值到 Z 分量，仅用于三维输入。

<a id="member-gfinputmagnitudemodifier-properties-absolute_value"></a>

### `absolute_value`

- API：`public`

```gdscript
var absolute_value: bool = true
```

是否使用绝对值幅值。

<a id="member-gfinputmagnitudemodifier-properties-preserve_unselected_components"></a>

### `preserve_unselected_components`

- API：`public`

```gdscript
var preserve_unselected_components: bool = false
```

非输出分量是否保留原值。

## 方法

<a id="member-gfinputmagnitudemodifier-methods-modify"></a>

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

返回：幅值投影后的二维输入值。

<a id="member-gfinputmagnitudemodifier-methods-modify_3d"></a>

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

返回：幅值投影后的三维输入值。
