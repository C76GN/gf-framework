# GFInputAction

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_action.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

资源化输入动作描述。 只描述“项目想要读取的抽象动作”，不绑定具体按键、设备或玩法逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfinputaction-enums-valuetype) | `enum ValueType` |
| 属性 | [`action_id`](#member-gfinputaction-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfinputaction-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`display_category`](#member-gfinputaction-properties-display_category) | `var display_category: String = ""` |
| 属性 | [`value_type`](#member-gfinputaction-properties-value_type) | `var value_type: ValueType = ValueType.BOOL` |
| 属性 | [`remappable`](#member-gfinputaction-properties-remappable) | `var remappable: bool = true` |
| 属性 | [`block_lower_priority_actions`](#member-gfinputaction-properties-block_lower_priority_actions) | `var block_lower_priority_actions: bool = true` |
| 属性 | [`activation_threshold`](#member-gfinputaction-properties-activation_threshold) | `var activation_threshold: float = 0.5` |
| 属性 | [`release_threshold`](#member-gfinputaction-properties-release_threshold) | `var release_threshold: float = 0.5` |
| 方法 | [`get_display_name`](#member-gfinputaction-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`get_action_id`](#member-gfinputaction-methods-get_action_id) | `func get_action_id() -> StringName:` |

## 枚举

<a id="member-gfinputaction-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType {
	## 开关型动作，例如确认、跳跃、攻击。
	BOOL,
	## 一维轴动作，例如水平移动或缩放。
	AXIS_1D,
	## 二维轴动作，例如移动方向、瞄准方向。
	AXIS_2D,
	## 三维轴动作，例如飞行移动、自由相机或六自由度控制。
	AXIS_3D,
}
```

动作输出值类型。

## 属性

<a id="member-gfinputaction-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

动作稳定标识。建议使用不会随本地化变化的 snake_case 名称。

<a id="member-gfinputaction-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

显示名称，供设置界面或输入提示使用。

<a id="member-gfinputaction-properties-display_category"></a>

### `display_category`

- API：`public`

```gdscript
var display_category: String = ""
```

显示分类，供设置界面分组使用。

<a id="member-gfinputaction-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.BOOL
```

动作输出值类型。

<a id="member-gfinputaction-properties-remappable"></a>

### `remappable`

- API：`public`

```gdscript
var remappable: bool = true
```

是否允许玩家在项目层重绑定。

<a id="member-gfinputaction-properties-block_lower_priority_actions"></a>

### `block_lower_priority_actions`

- API：`public`

```gdscript
var block_lower_priority_actions: bool = true
```

同一输入事件命中多个动作时，较高优先级动作是否阻止低优先级动作。

<a id="member-gfinputaction-properties-activation_threshold"></a>

### `activation_threshold`

- API：`public`

```gdscript
var activation_threshold: float = 0.5
```

判断轴动作是否活跃的阈值。

<a id="member-gfinputaction-properties-release_threshold"></a>

### `release_threshold`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var release_threshold: float = 0.5
```

轴动作活跃后判断其是否释放的阈值。 仅用于轴动作，必须处于 0.0 到 1.0 且不高于 [member activation_threshold]。 精确中立值始终释放；两个正阈值相等时与旧式单阈值行为一致。

## 方法

<a id="member-gfinputaction-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取可显示名称。

返回：显示名称；为空时回退到动作标识或资源文件名。

<a id="member-gfinputaction-methods-get_action_id"></a>

### `get_action_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_action_id() -> StringName:
```

获取稳定动作标识。

返回：显式动作标识；未设置时返回空标识。
