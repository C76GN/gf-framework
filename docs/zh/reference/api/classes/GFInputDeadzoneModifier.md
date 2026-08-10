# GFInputDeadzoneModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_deadzone_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入死区修饰器。 可对一维或二维轴值应用径向死区，并可选择把剩余范围重新映射到 0..1。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`lower_threshold`](#member-gfinputdeadzonemodifier-properties-lower_threshold) | `var lower_threshold: float = 0.2:` |
| 属性 | [`upper_threshold`](#member-gfinputdeadzonemodifier-properties-upper_threshold) | `var upper_threshold: float = 1.0:` |
| 属性 | [`rescale_after_deadzone`](#member-gfinputdeadzonemodifier-properties-rescale_after_deadzone) | `var rescale_after_deadzone: bool = true` |
| 方法 | [`modify`](#member-gfinputdeadzonemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputdeadzonemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 属性

<a id="member-gfinputdeadzonemodifier-properties-lower_threshold"></a>

### `lower_threshold`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var lower_threshold: float = 0.2:
```

低于该阈值的输入会被视为 0。与 upper_threshold 相等时形成阶跃： 低于共同阈值为 0，达到阈值为满幅。

<a id="member-gfinputdeadzonemodifier-properties-upper_threshold"></a>

### `upper_threshold`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var upper_threshold: float = 1.0:
```

达到该阈值时视为满幅输入；可与 lower_threshold 相等以表达硬阈值。

<a id="member-gfinputdeadzonemodifier-properties-rescale_after_deadzone"></a>

### `rescale_after_deadzone`

- API：`public`

```gdscript
var rescale_after_deadzone: bool = true
```

是否把死区外的剩余范围重新映射到 0..1。

## 方法

<a id="member-gfinputdeadzonemodifier-methods-modify"></a>

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

返回：应用死区后的二维输入值。

<a id="member-gfinputdeadzonemodifier-methods-modify_3d"></a>

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

返回：应用死区后的三维输入值。
