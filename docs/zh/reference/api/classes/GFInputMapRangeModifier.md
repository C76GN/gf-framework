# GFInputMapRangeModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_map_range_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入范围映射修饰器。 将输入分量从一个数值范围线性映射到另一个范围，适合灵敏度曲线前后的 简单归一化处理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`input_min`](#member-gfinputmaprangemodifier-properties-input_min) | `var input_min: float = 0.0` |
| 属性 | [`input_max`](#member-gfinputmaprangemodifier-properties-input_max) | `var input_max: float = 1.0` |
| 属性 | [`output_min`](#member-gfinputmaprangemodifier-properties-output_min) | `var output_min: float = 0.0` |
| 属性 | [`output_max`](#member-gfinputmaprangemodifier-properties-output_max) | `var output_max: float = 1.0` |
| 属性 | [`clamp_output`](#member-gfinputmaprangemodifier-properties-clamp_output) | `var clamp_output: bool = true` |
| 方法 | [`modify`](#member-gfinputmaprangemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputmaprangemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 属性

<a id="member-gfinputmaprangemodifier-properties-input_min"></a>

### `input_min`

- API：`public`

```gdscript
var input_min: float = 0.0
```

输入最小值。

<a id="member-gfinputmaprangemodifier-properties-input_max"></a>

### `input_max`

- API：`public`

```gdscript
var input_max: float = 1.0
```

输入最大值。

<a id="member-gfinputmaprangemodifier-properties-output_min"></a>

### `output_min`

- API：`public`

```gdscript
var output_min: float = 0.0
```

输出最小值。

<a id="member-gfinputmaprangemodifier-properties-output_max"></a>

### `output_max`

- API：`public`

```gdscript
var output_max: float = 1.0
```

输出最大值。

<a id="member-gfinputmaprangemodifier-properties-clamp_output"></a>

### `clamp_output`

- API：`public`

```gdscript
var clamp_output: bool = true
```

是否限制输出到目标范围内。

## 方法

<a id="member-gfinputmaprangemodifier-methods-modify"></a>

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

返回：范围映射后的二维输入值。

<a id="member-gfinputmaprangemodifier-methods-modify_3d"></a>

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

返回：范围映射后的三维输入值。
