# GFUIPropertyMotion

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_property_motion.gd`
- 模块：`Action Queue`
- 继承：`GFUIMotionEffect`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

在绑定对象上插值一个属性，支持按父级布局大小计算的位移和相对初始姿态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`property`](#member-gfuipropertymotion-properties-property) | `var property: NodePath = ^"modulate:a"` |
| 属性 | [`start_value`](#member-gfuipropertymotion-properties-start_value) | `var start_value: Variant = 0.0` |
| 属性 | [`end_value`](#member-gfuipropertymotion-properties-end_value) | `var end_value: Variant = 1.0` |
| 属性 | [`relative`](#member-gfuipropertymotion-properties-relative) | `var relative: bool = false` |
| 属性 | [`in_parent_units`](#member-gfuipropertymotion-properties-in_parent_units) | `var in_parent_units: bool = false` |
| 方法 | [`written_properties`](#member-gfuipropertymotion-methods-written_properties) | `func written_properties() -> Array[NodePath]:` |
| 方法 | [`binding_error`](#member-gfuipropertymotion-methods-binding_error) | `func binding_error(target: Object, _inputs: Dictionary) -> String:` |
| 方法 | [`bind_target`](#member-gfuipropertymotion-methods-bind_target) | `func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:` |

## 属性

<a id="member-gfuipropertymotion-properties-property"></a>

### `property`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var property: NodePath = ^"modulate:a"
```

Godot 索引属性路径，例如 position 或 modulate:a。

<a id="member-gfuipropertymotion-properties-start_value"></a>

### `start_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var start_value: Variant = 0.0
```

局部进度为零时的值。

结构：

- `start_value`: Variant，可为 float、int、Vector2、Vector3、Rect2 或 Color。

<a id="member-gfuipropertymotion-properties-end_value"></a>

### `end_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var end_value: Variant = 1.0
```

局部进度为一时的值。

结构：

- `end_value`: Variant，必须与起始值相容。

<a id="member-gfuipropertymotion-properties-relative"></a>

### `relative`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var relative: bool = false
```

把端点解释为相对于开始时真实属性的增量。

<a id="member-gfuipropertymotion-properties-in_parent_units"></a>

### `in_parent_units`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var in_parent_units: bool = false
```

将 Vector2 起止值按 Control 所在父区域的当前尺寸缩放。

## 方法

<a id="member-gfuipropertymotion-methods-written_properties"></a>

### `written_properties`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func written_properties() -> Array[NodePath]:
```

声明本次会话独占的属性路径。

返回：用于冲突检查的单一属性。

<a id="member-gfuipropertymotion-methods-binding_error"></a>

### `binding_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func binding_error(target: Object, _inputs: Dictionary) -> String:
```

检查属性存在、类型相容和布局坐标要求。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `_inputs` | 保留给项目输入。 |

返回：失败原因或空串。

结构：

- `_inputs`: Dictionary，属性动作不需要额外输入。

<a id="member-gfuipropertymotion-methods-bind_target"></a>

### `bind_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
```

冻结端点及基线，窗口改变时重新读取父区域大小。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 已确认兼容的对象。 |
| `_inputs` | 保留给项目输入。 |

返回：每次播放独立的属性写入与回滚操作。

结构：

- `_inputs`: Dictionary，属性动作不读取此映射。
