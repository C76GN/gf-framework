# GFInputModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_modifier.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

输入值修饰器基类。 修饰器只处理输入值转换，不决定动作是否触发。可挂在 GFInputBinding 或 GFInputMapping 上，用于死区、缩放、归一化、范围映射等通用处理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`modify`](#member-gfinputmodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputmodifier-methods-modify_3d) | `func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:` |
| 方法 | [`duplicate_modifier`](#member-gfinputmodifier-methods-duplicate_modifier) | `func duplicate_modifier() -> GFInputModifier:` |

## 方法

<a id="member-gfinputmodifier-methods-modify"></a>

### `modify`

- API：`public`

```gdscript
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
```

修饰输入贡献值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 当前二维贡献值；布尔与一维轴使用 x 分量。 |
| `_event` | 产生该贡献的原生输入事件，可能为 null。 |
| `_action` | 当前输入动作。 |

返回：修饰后的贡献值。

<a id="member-gfinputmodifier-methods-modify_3d"></a>

### `modify_3d`

- API：`public`

```gdscript
func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:
```

修饰三维输入贡献值。 默认复用二维修饰逻辑处理 X/Y，并保留 Z 分量。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 当前三维贡献值。 |
| `event` | 产生该贡献的原生输入事件，可能为 null。 |
| `action` | 当前输入动作。 |

返回：修饰后的三维贡献值。

<a id="member-gfinputmodifier-methods-duplicate_modifier"></a>

### `duplicate_modifier`

- API：`public`

```gdscript
func duplicate_modifier() -> GFInputModifier:
```

创建运行时副本。

返回：修饰器副本。
