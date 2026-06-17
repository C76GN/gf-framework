# GFInputSignClampModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_sign_clamp_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入符号方向限制修饰器。 用于只保留正向或负向输入分量，也可以把保留的负向分量重新映射为正值。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`AllowedSign`](#member-gfinputsignclampmodifier-enums-allowedsign) | `enum AllowedSign` |
| 属性 | [`allowed_sign`](#member-gfinputsignclampmodifier-properties-allowed_sign) | `var allowed_sign: AllowedSign = AllowedSign.POSITIVE` |
| 属性 | [`apply_x`](#member-gfinputsignclampmodifier-properties-apply_x) | `var apply_x: bool = true` |
| 属性 | [`apply_y`](#member-gfinputsignclampmodifier-properties-apply_y) | `var apply_y: bool = true` |
| 属性 | [`apply_z`](#member-gfinputsignclampmodifier-properties-apply_z) | `var apply_z: bool = true` |
| 属性 | [`remap_to_positive`](#member-gfinputsignclampmodifier-properties-remap_to_positive) | `var remap_to_positive: bool = false` |
| 方法 | [`modify`](#member-gfinputsignclampmodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputsignclampmodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 枚举

<a id="member-gfinputsignclampmodifier-enums-allowedsign"></a>

### `AllowedSign`

- API：`public`

```gdscript
enum AllowedSign {
	## 只保留大于等于 0 的值。
	POSITIVE,
	## 只保留小于等于 0 的值。
	NEGATIVE,
}
```

允许通过的符号方向。

## 属性

<a id="member-gfinputsignclampmodifier-properties-allowed_sign"></a>

### `allowed_sign`

- API：`public`

```gdscript
var allowed_sign: AllowedSign = AllowedSign.POSITIVE
```

允许通过的符号方向。

<a id="member-gfinputsignclampmodifier-properties-apply_x"></a>

### `apply_x`

- API：`public`

```gdscript
var apply_x: bool = true
```

是否处理 X 分量。

<a id="member-gfinputsignclampmodifier-properties-apply_y"></a>

### `apply_y`

- API：`public`

```gdscript
var apply_y: bool = true
```

是否处理 Y 分量。

<a id="member-gfinputsignclampmodifier-properties-apply_z"></a>

### `apply_z`

- API：`public`

```gdscript
var apply_z: bool = true
```

是否处理 Z 分量。

<a id="member-gfinputsignclampmodifier-properties-remap_to_positive"></a>

### `remap_to_positive`

- API：`public`

```gdscript
var remap_to_positive: bool = false
```

是否把保留的负向分量转为正值。

## 方法

<a id="member-gfinputsignclampmodifier-methods-modify"></a>

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

返回：符号过滤后的二维输入值。

<a id="member-gfinputsignclampmodifier-methods-modify_3d"></a>

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

返回：符号过滤后的三维输入值。
