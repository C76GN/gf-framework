# GFInputScaleModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_scale_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入缩放修饰器。 适合统一调节轴灵敏度、反转某个方向或压低虚拟摇杆输出。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`scale_x`](#member-gfinputscalemodifier-properties-scale_x) | `var scale_x: float = 1.0` |
| 属性 | [`scale_y`](#member-gfinputscalemodifier-properties-scale_y) | `var scale_y: float = 1.0` |
| 属性 | [`scale_z`](#member-gfinputscalemodifier-properties-scale_z) | `var scale_z: float = 1.0` |
| 方法 | [`modify`](#member-gfinputscalemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputscalemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 属性

<a id="member-gfinputscalemodifier-properties-scale_x"></a>

### `scale_x`

- API：`public`

```gdscript
var scale_x: float = 1.0
```

X 分量缩放。

<a id="member-gfinputscalemodifier-properties-scale_y"></a>

### `scale_y`

- API：`public`

```gdscript
var scale_y: float = 1.0
```

Y 分量缩放。

<a id="member-gfinputscalemodifier-properties-scale_z"></a>

### `scale_z`

- API：`public`

```gdscript
var scale_z: float = 1.0
```

Z 分量缩放，仅用于三维轴动作。

## 方法

<a id="member-gfinputscalemodifier-methods-modify"></a>

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

返回：缩放后的二维输入值。

<a id="member-gfinputscalemodifier-methods-modify_3d"></a>

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

返回：缩放后的三维输入值。
