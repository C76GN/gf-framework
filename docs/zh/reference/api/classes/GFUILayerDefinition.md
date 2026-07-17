# GFUILayerDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_layer_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.1.0`

UI 逻辑层定义。 将稳定逻辑层 ID、Godot CanvasLayer 排序值和默认遮挡策略解耦， 供项目按窗口区域、导航域或显示优先级扩展 GFUIUtility。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`layer_id`](#member-gfuilayerdefinition-properties-layer_id) | `var layer_id: int = -1` |
| 属性 | [`display_name`](#member-gfuilayerdefinition-properties-display_name) | `var display_name: StringName = &""` |
| 属性 | [`canvas_layer`](#member-gfuilayerdefinition-properties-canvas_layer) | `var canvas_layer: int = 0` |
| 属性 | [`auto_hide_under`](#member-gfuilayerdefinition-properties-auto_hide_under) | `var auto_hide_under: bool = true` |
| 方法 | [`configure`](#member-gfuilayerdefinition-methods-configure) | `func configure( next_layer_id: int, next_display_name: StringName, next_canvas_layer: int, next_auto_hide_under: bool = true ) -> GFUILayerDefinition:` |
| 方法 | [`is_valid`](#member-gfuilayerdefinition-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`duplicate_definition`](#member-gfuilayerdefinition-methods-duplicate_definition) | `func duplicate_definition() -> GFUILayerDefinition:` |

## 属性

<a id="member-gfuilayerdefinition-properties-layer_id"></a>

### `layer_id`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
var layer_id: int = -1
```

稳定逻辑层 ID。必须为非负整数，只用于路由、栈和诊断，不决定绘制顺序。

<a id="member-gfuilayerdefinition-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
var display_name: StringName = &""
```

用于诊断和 CanvasLayer 节点命名的稳定名称。

<a id="member-gfuilayerdefinition-properties-canvas_layer"></a>

### `canvas_layer`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
var canvas_layer: int = 0
```

对应 Godot CanvasLayer.layer 的显示排序值，数值越大越靠前，与 layer_id 相互独立。 GF 预置 HUD、POPUP、TOP 分别使用 50、60、70。

<a id="member-gfuilayerdefinition-properties-auto_hide_under"></a>

### `auto_hide_under`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
var auto_hide_under: bool = true
```

新面板未显式指定 hide_under 时，是否隐藏同一逻辑层中的下方页面。 该策略不会隐藏或清理其他逻辑层。

## 方法

<a id="member-gfuilayerdefinition-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func configure( next_layer_id: int, next_display_name: StringName, next_canvas_layer: int, next_auto_hide_under: bool = true ) -> GFUILayerDefinition:
```

配置层定义。

参数：

| 名称 | 说明 |
|---|---|
| `next_layer_id` | 稳定逻辑层 ID。 |
| `next_display_name` | 稳定显示名。 |
| `next_canvas_layer` | Godot CanvasLayer 排序值。 |
| `next_auto_hide_under` | 默认是否隐藏同栈下方页面。 |

返回：当前层定义。

<a id="member-gfuilayerdefinition-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func is_valid() -> bool:
```

检查层定义是否可注册。

返回：逻辑层 ID 非负且显示名非空时返回 true。

<a id="member-gfuilayerdefinition-methods-duplicate_definition"></a>

### `duplicate_definition`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func duplicate_definition() -> GFUILayerDefinition:
```

创建不共享可变状态的定义副本。

返回：当前层定义的独立副本。
