# GFInputSwizzleModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_swizzle_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入分量重排修饰器。 用于把二维或三维输入轴按通用顺序重排，适合在不改绑定资源的情况下 调整轴方向约定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`SwizzleOrder`](#member-gfinputswizzlemodifier-enums-swizzleorder) | `enum SwizzleOrder` |
| 属性 | [`order`](#member-gfinputswizzlemodifier-properties-order) | `var order: SwizzleOrder = SwizzleOrder.XYZ` |
| 方法 | [`modify`](#member-gfinputswizzlemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputswizzlemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 枚举

<a id="member-gfinputswizzlemodifier-enums-swizzleorder"></a>

### `SwizzleOrder`

- API：`public`

```gdscript
enum SwizzleOrder { ## 保持 X/Y/Z。 XYZ, ## 输出 X/Z/Y。 XZY, ## 输出 Y/X/Z。 YXZ, ## 输出 Y/Z/X。 YZX, ## 输出 Z/X/Y。 ZXY, ## 输出 Z/Y/X。 ZYX, }
```

分量重排顺序。

## 属性

<a id="member-gfinputswizzlemodifier-properties-order"></a>

### `order`

- API：`public`

```gdscript
var order: SwizzleOrder = SwizzleOrder.XYZ
```

分量重排顺序。

## 方法

<a id="member-gfinputswizzlemodifier-methods-modify"></a>

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

返回：分量重排后的二维输入值。

<a id="member-gfinputswizzlemodifier-methods-modify_3d"></a>

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

返回：分量重排后的三维输入值。
