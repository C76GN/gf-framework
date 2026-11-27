# GFUILayoutMotion

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_layout_motion.gd`
- 模块：`Action Queue`
- 继承：`GFUIMotionEffect`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

在项目提供的两份实测矩形之间移动和缩放表现节点，适用于共享元素及列表重排。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`from_layout`](#member-gfuilayoutmotion-properties-from_layout) | `var from_layout: StringName = &"from_rects"` |
| 属性 | [`to_layout`](#member-gfuilayoutmotion-properties-to_layout) | `var to_layout: StringName = &"to_rects"` |
| 方法 | [`input_types`](#member-gfuilayoutmotion-methods-input_types) | `func input_types() -> Dictionary:` |
| 方法 | [`written_properties`](#member-gfuilayoutmotion-methods-written_properties) | `func written_properties() -> Array[NodePath]:` |
| 方法 | [`binding_error`](#member-gfuilayoutmotion-methods-binding_error) | `func binding_error(target: Object, inputs: Dictionary) -> String:` |
| 方法 | [`bind_target`](#member-gfuilayoutmotion-methods-bind_target) | `func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:` |

## 属性

<a id="member-gfuilayoutmotion-properties-from_layout"></a>

### `from_layout`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var from_layout: StringName = &"from_rects"
```

起始布局表的具名输入。

<a id="member-gfuilayoutmotion-properties-to_layout"></a>

### `to_layout`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var to_layout: StringName = &"to_rects"
```

目标布局表的具名输入。

## 方法

<a id="member-gfuilayoutmotion-methods-input_types"></a>

### `input_types`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func input_types() -> Dictionary:
```

布局表以实际节点为键，矩形与表现节点使用同一父坐标系。

返回：两份布局表的类型。

结构：

- `return`: Dictionary，输入名映射到 TYPE_DICTIONARY。

<a id="member-gfuilayoutmotion-methods-written_properties"></a>

### `written_properties`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func written_properties() -> Array[NodePath]:
```

占有布局表现节点的矩形。

返回：位置和尺寸。

<a id="member-gfuilayoutmotion-methods-binding_error"></a>

### `binding_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func binding_error(target: Object, inputs: Dictionary) -> String:
```

确认两次布局均包含同一目标。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 位于同一父坐标空间的表现节点。 |
| `inputs` | 捕获的前后布局。 |

返回：错误或空串。

结构：

- `inputs`: Dictionary，两个具名布局表分别从 Object 映射到 Rect2。

<a id="member-gfuilayoutmotion-methods-bind_target"></a>

### `bind_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_target(target: Object, inputs: Dictionary) -> GFUIMotionBinding:
```

取得两个矩形后直接驱动专用表现节点。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标控件。 |
| `inputs` | 起止布局。 |

返回：基于实际布局的可定位操作。

结构：

- `inputs`: Dictionary，包含 from_layout 与 to_layout 所指的布局表。
