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
| 方法 | [`supports_runtime_state`](#member-gfinputmodifier-methods-supports_runtime_state) | `func supports_runtime_state() -> bool:` |
| 方法 | [`get_modifier_runtime_state`](#member-gfinputmodifier-methods-get_modifier_runtime_state) | `func get_modifier_runtime_state() -> Dictionary:` |
| 方法 | [`restore_modifier_runtime_state`](#member-gfinputmodifier-methods-restore_modifier_runtime_state) | `func restore_modifier_runtime_state(state: Dictionary) -> GFInputModifier:` |
| 方法 | [`reset_modifier_runtime_state`](#member-gfinputmodifier-methods-reset_modifier_runtime_state) | `func reset_modifier_runtime_state() -> GFInputModifier:` |
| 方法 | [`set_runtime_delta_seconds`](#member-gfinputmodifier-methods-set_runtime_delta_seconds) | `func set_runtime_delta_seconds(delta_seconds: float) -> GFInputModifier:` |
| 方法 | [`clear_runtime_delta_seconds`](#member-gfinputmodifier-methods-clear_runtime_delta_seconds) | `func clear_runtime_delta_seconds() -> GFInputModifier:` |

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

<a id="member-gfinputmodifier-methods-supports_runtime_state"></a>

### `supports_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func supports_runtime_state() -> bool:
```

当前修饰器是否维护运行时状态。

返回：有运行时状态时返回 true。

<a id="member-gfinputmodifier-methods-get_modifier_runtime_state"></a>

### `get_modifier_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_modifier_runtime_state() -> Dictionary:
```

获取运行时状态快照。 无状态修饰器返回空字典。

返回：当前运行时状态。

结构：

- `return`: Dictionary，具体字段由修饰器实现定义。

<a id="member-gfinputmodifier-methods-restore_modifier_runtime_state"></a>

### `restore_modifier_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func restore_modifier_runtime_state(state: Dictionary) -> GFInputModifier:
```

从运行时状态快照恢复修饰器。 无状态修饰器忽略该调用。

参数：

| 名称 | 说明 |
|---|---|
| `state` | get_modifier_runtime_state() 生成的状态。 |

返回：当前修饰器。

结构：

- `state`: Dictionary，具体字段由修饰器实现定义。

<a id="member-gfinputmodifier-methods-reset_modifier_runtime_state"></a>

### `reset_modifier_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func reset_modifier_runtime_state() -> GFInputModifier:
```

重置运行时状态。 无状态修饰器忽略该调用。

返回：当前修饰器。

<a id="member-gfinputmodifier-methods-set_runtime_delta_seconds"></a>

### `set_runtime_delta_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_runtime_delta_seconds(delta_seconds: float) -> GFInputModifier:
```

设置修饰器下一步使用的运行时 delta 秒数。 不依赖 delta 的修饰器忽略该调用。

参数：

| 名称 | 说明 |
|---|---|
| `delta_seconds` | 运行时 delta 秒数；小于 0 时实现应按 0 处理。 |

返回：当前修饰器。

<a id="member-gfinputmodifier-methods-clear_runtime_delta_seconds"></a>

### `clear_runtime_delta_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_runtime_delta_seconds() -> GFInputModifier:
```

清除手动运行时 delta，恢复修饰器默认时间源。 不依赖 delta 的修饰器忽略该调用。

返回：当前修饰器。
