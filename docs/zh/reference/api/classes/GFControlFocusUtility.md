# GFControlFocusUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_control_focus_utility.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

Control 焦点顺序工具。 收集可聚焦 Control，按显式顺序写入 Tab 顺序和方向邻居，并提供焦点步进 helper。 该工具只处理 Godot Control 焦点属性，不规定具体 UI 控件、视觉样式或业务流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`AXIS_NONE`](#member-gfcontrolfocusutility-constants-axis_none) | `const AXIS_NONE: StringName = &"none"` |
| 常量 | [`AXIS_HORIZONTAL`](#member-gfcontrolfocusutility-constants-axis_horizontal) | `const AXIS_HORIZONTAL: StringName = &"horizontal"` |
| 常量 | [`AXIS_VERTICAL`](#member-gfcontrolfocusutility-constants-axis_vertical) | `const AXIS_VERTICAL: StringName = &"vertical"` |
| 常量 | [`AXIS_BOTH`](#member-gfcontrolfocusutility-constants-axis_both) | `const AXIS_BOTH: StringName = &"both"` |
| 方法 | [`collect_focusable_controls`](#member-gfcontrolfocusutility-methods-collect_focusable_controls) | `static func collect_focusable_controls(root: Node, options: Dictionary = {}) -> Array[Control]:` |
| 方法 | [`apply_focus_order_from_root`](#member-gfcontrolfocusutility-methods-apply_focus_order_from_root) | `static func apply_focus_order_from_root(root: Node, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_focus_order`](#member-gfcontrolfocusutility-methods-apply_focus_order) | `static func apply_focus_order(controls: Array[Control], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_next_focus_control`](#member-gfcontrolfocusutility-methods-get_next_focus_control) | `static func get_next_focus_control( controls: Array[Control], current: Control, step: int = 1, wrap_enabled: bool = true ) -> Control:` |
| 方法 | [`grab_next_focus`](#member-gfcontrolfocusutility-methods-grab_next_focus) | `static func grab_next_focus( controls: Array[Control], current: Control, step: int = 1, wrap_enabled: bool = true ) -> Control:` |

## 常量

<a id="member-gfcontrolfocusutility-constants-axis_none"></a>

### `AXIS_NONE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const AXIS_NONE: StringName = &"none"
```

不写入方向邻居，只处理 focus_next / focus_previous。

<a id="member-gfcontrolfocusutility-constants-axis_horizontal"></a>

### `AXIS_HORIZONTAL`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const AXIS_HORIZONTAL: StringName = &"horizontal"
```

按顺序写入 focus_neighbor_left / focus_neighbor_right。

<a id="member-gfcontrolfocusutility-constants-axis_vertical"></a>

### `AXIS_VERTICAL`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const AXIS_VERTICAL: StringName = &"vertical"
```

按顺序写入 focus_neighbor_top / focus_neighbor_bottom。

<a id="member-gfcontrolfocusutility-constants-axis_both"></a>

### `AXIS_BOTH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const AXIS_BOTH: StringName = &"both"
```

同时写入水平和垂直方向邻居。

## 方法

<a id="member-gfcontrolfocusutility-methods-collect_focusable_controls"></a>

### `collect_focusable_controls`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func collect_focusable_controls(root: Node, options: Dictionary = {}) -> Array[Control]:
```

从节点树中按场景树顺序收集可聚焦 Control。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 查询根节点。 |
| `options` | 收集选项，支持 include_root、include_hidden、include_disabled、include_internal、max_depth 和 limit。 |

返回：可聚焦控件数组。

结构：

- `options`: Dictionary，include_root 默认 true，include_hidden 默认 false，include_disabled 默认 false，include_internal 默认 false，max_depth 默认 -1，limit 默认 -1。

<a id="member-gfcontrolfocusutility-methods-apply_focus_order_from_root"></a>

### `apply_focus_order_from_root`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func apply_focus_order_from_root(root: Node, options: Dictionary = {}) -> Dictionary:
```

从节点树收集可聚焦 Control，并按收集顺序应用焦点顺序。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 查询根节点。 |
| `options` | 收集与应用选项。 |

返回：应用报告。

结构：

- `options`: Dictionary，支持 collect_focusable_controls() 的选项，以及 wrap、axis、wire_tab_order 和 wire_directional_neighbors。
- `return`: Dictionary，包含 ok、control_count、wired_count、wrap、axis、wire_tab_order、wire_directional_neighbors、entries 和 issues。

<a id="member-gfcontrolfocusutility-methods-apply_focus_order"></a>

### `apply_focus_order`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func apply_focus_order(controls: Array[Control], options: Dictionary = {}) -> Dictionary:
```

按显式数组顺序写入 Control 焦点顺序。

参数：

| 名称 | 说明 |
|---|---|
| `controls` | 目标控件顺序。 |
| `options` | 应用选项，支持 wrap、axis、wire_tab_order、wire_directional_neighbors、include_hidden 和 include_disabled。 |

返回：应用报告。

结构：

- `options`: Dictionary，wrap 默认 true；axis 可为 none、horizontal、vertical 或 both，默认 both；wire_tab_order 默认 true；wire_directional_neighbors 默认 true；preserve_unwired_directional_neighbors 默认 false；include_hidden 默认 false；include_disabled 默认 false。
- `return`: Dictionary，包含 ok、control_count、wired_count、wrap、axis、wire_tab_order、wire_directional_neighbors、preserve_unwired_directional_neighbors、entries 和 issues。entries 每项包含 index、name、path、previous 和 next；issues 每项包含 code、message 和 index。

<a id="member-gfcontrolfocusutility-methods-get_next_focus_control"></a>

### `get_next_focus_control`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_next_focus_control( controls: Array[Control], current: Control, step: int = 1, wrap_enabled: bool = true ) -> Control:
```

按顺序数组计算下一次应聚焦的 Control。

参数：

| 名称 | 说明 |
|---|---|
| `controls` | 目标控件顺序。 |
| `current` | 当前控件；为空或不在列表中时，从列表起点或终点开始。 |
| `step` | 步进数量，正数向后，负数向前，0 返回当前有效控件。 |
| `wrap_enabled` | 是否允许在两端循环。 |

返回：目标控件；没有可用目标时返回 null。

<a id="member-gfcontrolfocusutility-methods-grab_next_focus"></a>

### `grab_next_focus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func grab_next_focus( controls: Array[Control], current: Control, step: int = 1, wrap_enabled: bool = true ) -> Control:
```

计算并抓取下一次焦点。

参数：

| 名称 | 说明 |
|---|---|
| `controls` | 目标控件顺序。 |
| `current` | 当前控件；为空或不在列表中时，从列表起点或终点开始。 |
| `step` | 步进数量，正数向后，负数向前。 |
| `wrap_enabled` | 是否允许在两端循环。 |

返回：实际抓取焦点的控件；没有可用目标时返回 null。
