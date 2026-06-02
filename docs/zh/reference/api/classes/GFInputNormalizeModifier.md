# GFInputNormalizeModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_normalize_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入归一化修饰器。 可避免多个方向叠加后超过单位长度，也可强制非零输入变成单位向量。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`only_when_over_one`](#member-gfinputnormalizemodifier-properties-only_when_over_one) | `var only_when_over_one: bool = true` |
| 方法 | [`modify`](#member-gfinputnormalizemodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputnormalizemodifier-methods-modify_3d) | `func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:` |

## 属性

<a id="member-gfinputnormalizemodifier-properties-only_when_over_one"></a>

### `only_when_over_one`

- API：`public`

```gdscript
var only_when_over_one: bool = true
```

只在长度超过 1 时归一化；关闭后任何非零输入都会归一化。

## 方法

<a id="member-gfinputnormalizemodifier-methods-modify"></a>

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

返回：归一化后的二维输入值。

<a id="member-gfinputnormalizemodifier-methods-modify_3d"></a>

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

返回：归一化后的三维输入值。
