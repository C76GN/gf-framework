# GFDebugDrawUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_debug_draw_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用调试绘制命令缓冲。 收集 2D/3D 线段、矩形、圆、文本等即时调试绘制命令。 Utility 只维护抽象命令和生命周期，具体渲染可由项目层 Overlay/Viewport 适配。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`items_changed`](#member-gfdebugdrawutility-signals-items_changed) | `signal items_changed` |
| 枚举 | [`PrimitiveType`](#member-gfdebugdrawutility-enums-primitivetype) | `enum PrimitiveType` |
| 属性 | [`enabled`](#member-gfdebugdrawutility-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`default_lifetime_seconds`](#member-gfdebugdrawutility-properties-default_lifetime_seconds) | `var default_lifetime_seconds: float = 0.0` |
| 属性 | [`max_items`](#member-gfdebugdrawutility-properties-max_items) | `var max_items: int = 2048` |
| 方法 | [`init`](#member-gfdebugdrawutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfdebugdrawutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfdebugdrawutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`draw_line_2d`](#member-gfdebugdrawutility-methods-draw_line_2d) | `func draw_line_2d( from: Vector2, to: Vector2, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0 ) -> int:` |
| 方法 | [`draw_vector_2d`](#member-gfdebugdrawutility-methods-draw_vector_2d) | `func draw_vector_2d( origin: Vector2, vector: Vector2, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0, options: Dictionary = {} ) -> Array[int]:` |
| 方法 | [`draw_rect_2d`](#member-gfdebugdrawutility-methods-draw_rect_2d) | `func draw_rect_2d( rect: Rect2, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", filled: bool = false, width: float = 1.0 ) -> int:` |
| 方法 | [`draw_circle_2d`](#member-gfdebugdrawutility-methods-draw_circle_2d) | `func draw_circle_2d( center: Vector2, radius: float, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", filled: bool = false, width: float = 1.0 ) -> int:` |
| 方法 | [`draw_text_2d`](#member-gfdebugdrawutility-methods-draw_text_2d) | `func draw_text_2d( position: Vector2, text: String, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", font_size: int = 16 ) -> int:` |
| 方法 | [`draw_line_3d`](#member-gfdebugdrawutility-methods-draw_line_3d) | `func draw_line_3d( from: Vector3, to: Vector3, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0 ) -> int:` |
| 方法 | [`draw_vector_3d`](#member-gfdebugdrawutility-methods-draw_vector_3d) | `func draw_vector_3d( origin: Vector3, vector: Vector3, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0, options: Dictionary = {} ) -> Array[int]:` |
| 方法 | [`draw_box_3d`](#member-gfdebugdrawutility-methods-draw_box_3d) | `func draw_box_3d( box: AABB, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", filled: bool = false, width: float = 1.0 ) -> int:` |
| 方法 | [`draw_text_3d`](#member-gfdebugdrawutility-methods-draw_text_3d) | `func draw_text_3d( position: Vector3, text: String, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", font_size: int = 16 ) -> int:` |
| 方法 | [`push_item`](#member-gfdebugdrawutility-methods-push_item) | `func push_item(item: Dictionary) -> int:` |
| 方法 | [`clear`](#member-gfdebugdrawutility-methods-clear) | `func clear(channel: StringName = &"") -> void:` |
| 方法 | [`set_channel_enabled`](#member-gfdebugdrawutility-methods-set_channel_enabled) | `func set_channel_enabled(channel: StringName, channel_enabled: bool) -> void:` |
| 方法 | [`is_channel_enabled`](#member-gfdebugdrawutility-methods-is_channel_enabled) | `func is_channel_enabled(channel: StringName) -> bool:` |
| 方法 | [`get_items`](#member-gfdebugdrawutility-methods-get_items) | `func get_items(channel: StringName = &"", include_disabled: bool = false) -> Array[Dictionary]:` |
| 方法 | [`get_item_count`](#member-gfdebugdrawutility-methods-get_item_count) | `func get_item_count(channel: StringName = &"") -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfdebugdrawutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfdebugdrawutility-signals-items_changed"></a>

### `items_changed`

- API：`public`

```gdscript
signal items_changed
```

绘制命令发生变化时发出。

## 枚举

<a id="member-gfdebugdrawutility-enums-primitivetype"></a>

### `PrimitiveType`

- API：`public`

```gdscript
enum PrimitiveType { ## 2D 线段命令。 LINE_2D, ## 2D 矩形命令。 RECT_2D, ## 2D 圆形命令。 CIRCLE_2D, ## 2D 文本命令。 TEXT_2D, ## 3D 线段命令。 LINE_3D, ## 3D AABB 盒命令。 BOX_3D, ## 3D 文本命令。 TEXT_3D, ## 项目自定义命令。 CUSTOM, }
```

调试绘制命令类型。

## 属性

<a id="member-gfdebugdrawutility-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用调试绘制。

<a id="member-gfdebugdrawutility-properties-default_lifetime_seconds"></a>

### `default_lifetime_seconds`

- API：`public`

```gdscript
var default_lifetime_seconds: float = 0.0
```

默认生命周期。小于 0 表示永久保留，0 表示等待下一次 tick 后清理。

<a id="member-gfdebugdrawutility-properties-max_items"></a>

### `max_items`

- API：`public`

```gdscript
var max_items: int = 2048
```

最大命令数量。小于等于 0 表示不限制。

## 方法

<a id="member-gfdebugdrawutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化调试绘制缓冲。

<a id="member-gfdebugdrawutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放并清空调试绘制命令。

<a id="member-gfdebugdrawutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfdebugdrawutility-methods-draw_line_2d"></a>

### `draw_line_2d`

- API：`public`

```gdscript
func draw_line_2d( from: Vector2, to: Vector2, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0 ) -> int:
```

绘制 2D 线段。

参数：

| 名称 | 说明 |
|---|---|
| `from` | 起点位置。 |
| `to` | 终点位置。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `width` | 绘制线宽。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-draw_vector_2d"></a>

### `draw_vector_2d`

- API：`public`

```gdscript
func draw_vector_2d( origin: Vector2, vector: Vector2, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0, options: Dictionary = {} ) -> Array[int]:
```

绘制 2D 向量。

参数：

| 名称 | 说明 |
|---|---|
| `origin` | 向量起点，centered 选项启用时表示中心点。 |
| `vector` | 要绘制的向量。 |
| `color` | 主向量颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `width` | 绘制线宽。 |
| `options` | 绘制选项。 |

返回：绘制命令 id 列表。

结构：

- `options`: Dictionary，支持 scale、length_mode、max_length、centered、draw_components、arrowhead、arrowhead_size、x_color、y_color。
- `return`: Array[int]，包含主线、可选分量线和可选箭头线的命令 id。

<a id="member-gfdebugdrawutility-methods-draw_rect_2d"></a>

### `draw_rect_2d`

- API：`public`

```gdscript
func draw_rect_2d( rect: Rect2, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", filled: bool = false, width: float = 1.0 ) -> int:
```

绘制 2D 矩形。

参数：

| 名称 | 说明 |
|---|---|
| `rect` | 矩形区域。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `filled` | 是否填充绘制图形。 |
| `width` | 绘制线宽。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-draw_circle_2d"></a>

### `draw_circle_2d`

- API：`public`

```gdscript
func draw_circle_2d( center: Vector2, radius: float, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", filled: bool = false, width: float = 1.0 ) -> int:
```

绘制 2D 圆。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 要绘制圆形的中心点。 |
| `radius` | 圆形半径。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `filled` | 是否填充绘制图形。 |
| `width` | 绘制线宽。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-draw_text_2d"></a>

### `draw_text_2d`

- API：`public`

```gdscript
func draw_text_2d( position: Vector2, text: String, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", font_size: int = 16 ) -> int:
```

绘制 2D 文本。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 绘制文本的位置。 |
| `text` | 要绘制或输出的文本。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `font_size` | 绘制文本字号。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-draw_line_3d"></a>

### `draw_line_3d`

- API：`public`

```gdscript
func draw_line_3d( from: Vector3, to: Vector3, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0 ) -> int:
```

绘制 3D 线段。

参数：

| 名称 | 说明 |
|---|---|
| `from` | 起点位置。 |
| `to` | 终点位置。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `width` | 绘制线宽。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-draw_vector_3d"></a>

### `draw_vector_3d`

- API：`public`

```gdscript
func draw_vector_3d( origin: Vector3, vector: Vector3, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", width: float = 1.0, options: Dictionary = {} ) -> Array[int]:
```

绘制 3D 向量。

参数：

| 名称 | 说明 |
|---|---|
| `origin` | 向量起点，centered 选项启用时表示中心点。 |
| `vector` | 要绘制的向量。 |
| `color` | 主向量颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `width` | 绘制线宽。 |
| `options` | 绘制选项。 |

返回：绘制命令 id 列表。

结构：

- `options`: Dictionary，支持 scale、length_mode、max_length、centered、draw_components、x_color、y_color、z_color。
- `return`: Array[int]，包含主线和可选分量线的命令 id。

<a id="member-gfdebugdrawutility-methods-draw_box_3d"></a>

### `draw_box_3d`

- API：`public`

```gdscript
func draw_box_3d( box: AABB, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", filled: bool = false, width: float = 1.0 ) -> int:
```

绘制 3D AABB。

参数：

| 名称 | 说明 |
|---|---|
| `box` | 要绘制的 3D 包围盒。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `filled` | 是否填充绘制图形。 |
| `width` | 绘制线宽。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-draw_text_3d"></a>

### `draw_text_3d`

- API：`public`

```gdscript
func draw_text_3d( position: Vector3, text: String, color: Color = Color.WHITE, lifetime_seconds: float = -1.0, channel: StringName = &"default", font_size: int = 16 ) -> int:
```

绘制 3D 文本。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 绘制文本的位置。 |
| `text` | 要绘制或输出的文本。 |
| `color` | 绘制颜色。 |
| `lifetime_seconds` | 调试绘制命令保留时间（秒）。 |
| `channel` | 调试绘制频道。 |
| `font_size` | 绘制文本字号。 |

返回：绘制命令 id。

<a id="member-gfdebugdrawutility-methods-push_item"></a>

### `push_item`

- API：`public`

```gdscript
func push_item(item: Dictionary) -> int:
```

推入自定义调试绘制命令。

参数：

| 名称 | 说明 |
|---|---|
| `item` | 命令字典。 |

返回：命令 id。

结构：

- `item`: Dictionary，至少可包含 type、channel、lifetime_seconds 以及项目自定义绘制载荷。

<a id="member-gfdebugdrawutility-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear(channel: StringName = &"") -> void:
```

清理命令。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 指定频道；为空时清空全部。 |

<a id="member-gfdebugdrawutility-methods-set_channel_enabled"></a>

### `set_channel_enabled`

- API：`public`

```gdscript
func set_channel_enabled(channel: StringName, channel_enabled: bool) -> void:
```

设置频道启用状态。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 频道。 |
| `channel_enabled` | 是否启用。 |

<a id="member-gfdebugdrawutility-methods-is_channel_enabled"></a>

### `is_channel_enabled`

- API：`public`

```gdscript
func is_channel_enabled(channel: StringName) -> bool:
```

检查频道是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 频道。 |

返回：启用返回 true。

<a id="member-gfdebugdrawutility-methods-get_items"></a>

### `get_items`

- API：`public`

```gdscript
func get_items(channel: StringName = &"", include_disabled: bool = false) -> Array[Dictionary]:
```

获取绘制命令。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 指定频道；为空时返回全部频道。 |
| `include_disabled` | 是否包含已禁用频道或全局禁用状态下的命令。 |

返回：命令副本列表。

结构：

- `return`: Array[Dictionary]，每个元素为调试绘制命令，包含 id、type、channel、created_at_msec、lifetime_seconds、remaining_seconds 和图元载荷。

<a id="member-gfdebugdrawutility-methods-get_item_count"></a>

### `get_item_count`

- API：`public`

```gdscript
func get_item_count(channel: StringName = &"") -> int:
```

获取命令数量。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 指定频道；为空时返回全部。 |

返回：数量。

<a id="member-gfdebugdrawutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：快照字典。

结构：

- `return`: Dictionary，包含 enabled、item_count、channels、primitive_types 和 max_items。
