# GFInputBinding

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_binding.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

把一个 Godot 输入事件映射到动作值贡献。 该资源只描述输入来源和数值方向，实际动作归属由 GFInputMapping 决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueTarget`](#member-gfinputbinding-enums-valuetarget) | `enum ValueTarget` |
| 属性 | [`input_event`](#member-gfinputbinding-properties-input_event) | `var input_event: InputEvent` |
| 属性 | [`value_target`](#member-gfinputbinding-properties-value_target) | `var value_target: ValueTarget = ValueTarget.AUTO` |
| 属性 | [`deadzone`](#member-gfinputbinding-properties-deadzone) | `var deadzone: float = 0.2` |
| 属性 | [`scale`](#member-gfinputbinding-properties-scale) | `var scale: float = 1.0` |
| 属性 | [`modifiers`](#member-gfinputbinding-properties-modifiers) | `var modifiers: Array[GFInputModifier] = []` |
| 属性 | [`match_device`](#member-gfinputbinding-properties-match_device) | `var match_device: bool = false` |
| 属性 | [`match_touch_index`](#member-gfinputbinding-properties-match_touch_index) | `var match_touch_index: bool = false` |
| 属性 | [`display_name`](#member-gfinputbinding-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`remappable`](#member-gfinputbinding-properties-remappable) | `var remappable: bool = true` |
| 方法 | [`duplicate_binding`](#member-gfinputbinding-methods-duplicate_binding) | `func duplicate_binding() -> GFInputBinding:` |
| 方法 | [`matches_event`](#member-gfinputbinding-methods-matches_event) | `func matches_event(event: InputEvent) -> bool:` |
| 方法 | [`get_contribution`](#member-gfinputbinding-methods-get_contribution) | `func get_contribution( event: InputEvent, action_value_type: GFInputAction.ValueType, deadzone_override: float = -1.0 ) -> Vector3:` |
| 方法 | [`get_display_name`](#member-gfinputbinding-methods-get_display_name) | `func get_display_name() -> String:` |

## 枚举

<a id="member-gfinputbinding-enums-valuetarget"></a>

### `ValueTarget`

- API：`public`

```gdscript
enum ValueTarget {
	## 根据动作值类型自动映射；二维/三维轴默认写入 X 分量，需要其他分量时使用显式 AXIS_* 目标。
	AUTO,
	## 只作为开关输入。
	BOOL,
	## 一维轴正向。
	AXIS_1D_POSITIVE,
	## 一维轴负向。
	AXIS_1D_NEGATIVE,
	## 二维轴 X 正向。
	AXIS_2D_X_POSITIVE,
	## 二维轴 X 负向。
	AXIS_2D_X_NEGATIVE,
	## 二维轴 Y 正向。
	AXIS_2D_Y_POSITIVE,
	## 二维轴 Y 负向。
	AXIS_2D_Y_NEGATIVE,
	## 三维轴 X 正向。
	AXIS_3D_X_POSITIVE,
	## 三维轴 X 负向。
	AXIS_3D_X_NEGATIVE,
	## 三维轴 Y 正向。
	AXIS_3D_Y_POSITIVE,
	## 三维轴 Y 负向。
	AXIS_3D_Y_NEGATIVE,
	## 三维轴 Z 正向。
	AXIS_3D_Z_POSITIVE,
	## 三维轴 Z 负向。
	AXIS_3D_Z_NEGATIVE,
}
```

输入值贡献目标。

## 属性

<a id="member-gfinputbinding-properties-input_event"></a>

### `input_event`

- API：`public`

```gdscript
var input_event: InputEvent
```

Godot 原生输入事件模板。

<a id="member-gfinputbinding-properties-value_target"></a>

### `value_target`

- API：`public`

```gdscript
var value_target: ValueTarget = ValueTarget.AUTO
```

当前绑定贡献到动作值的方向。

<a id="member-gfinputbinding-properties-deadzone"></a>

### `deadzone`

- API：`public`

```gdscript
var deadzone: float = 0.2
```

轴输入死区。对按键和按钮输入无影响。

<a id="member-gfinputbinding-properties-scale"></a>

### `scale`

- API：`public`

```gdscript
var scale: float = 1.0
```

输入贡献缩放。

<a id="member-gfinputbinding-properties-modifiers"></a>

### `modifiers`

- API：`public`

```gdscript
var modifiers: Array[GFInputModifier] = []
```

绑定级输入修饰器，按顺序作用于该绑定产生的贡献值。

<a id="member-gfinputbinding-properties-match_device"></a>

### `match_device`

- API：`public`

```gdscript
var match_device: bool = false
```

是否按设备 ID 精确匹配。关闭时同类按键、鼠标按钮或手柄按钮可跨设备匹配。

<a id="member-gfinputbinding-properties-match_touch_index"></a>

### `match_touch_index`

- API：`public`

```gdscript
var match_touch_index: bool = false
```

是否按触点 index 精确匹配 InputEventScreenTouch。 默认关闭，表示任意触点都可匹配该绑定。

<a id="member-gfinputbinding-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

覆盖显示名称。

<a id="member-gfinputbinding-properties-remappable"></a>

### `remappable`

- API：`public`

```gdscript
var remappable: bool = true
```

该绑定是否可被玩家重绑。

## 方法

<a id="member-gfinputbinding-methods-duplicate_binding"></a>

### `duplicate_binding`

- API：`public`

```gdscript
func duplicate_binding() -> GFInputBinding:
```

创建深拷贝，避免运行时重映射污染原始资源。

返回：新绑定。

<a id="member-gfinputbinding-methods-matches_event"></a>

### `matches_event`

- API：`public`

```gdscript
func matches_event(event: InputEvent) -> bool:
```

判断当前绑定是否匹配输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 运行时输入事件。 |

返回：是否匹配。

<a id="member-gfinputbinding-methods-get_contribution"></a>

### `get_contribution`

- API：`public`

```gdscript
func get_contribution( event: InputEvent, action_value_type: GFInputAction.ValueType, deadzone_override: float = -1.0 ) -> Vector3:
```

计算该输入事件对动作值的贡献。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 运行时输入事件。 |
| `action_value_type` | 动作值类型。 |
| `deadzone_override` | 可选死区覆盖；小于 0 时使用绑定自身 deadzone。 |

返回：三维向量贡献；布尔与一维轴使用 x 分量，二维轴使用 x/y 分量。

<a id="member-gfinputbinding-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取显示名称。

返回：显示名称；为空时由输入事件格式化。
