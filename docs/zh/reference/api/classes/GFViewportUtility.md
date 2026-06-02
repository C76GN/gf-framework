# GFViewportUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_viewport_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用 SubViewport 布局管理工具。 用于本地多人、调试监视器、小地图或多视角预览等场景。它只管理 Viewport 容器、相机挂载和后处理材质，不接管玩家、场景切换或输入规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`split_screen_configured`](#member-gfviewportutility-signals-split_screen_configured) | `signal split_screen_configured(viewports: Array)` |
| 信号 | [`split_screen_cleared`](#member-gfviewportutility-signals-split_screen_cleared) | `signal split_screen_cleared` |
| 属性 | [`viewport_resolution_scale`](#member-gfviewportutility-properties-viewport_resolution_scale) | `var viewport_resolution_scale: float = 1.0:` |
| 属性 | [`default_disable_3d`](#member-gfviewportutility-properties-default_disable_3d) | `var default_disable_3d: bool = false` |
| 属性 | [`default_transparent_bg`](#member-gfviewportutility-properties-default_transparent_bg) | `var default_transparent_bg: bool = false` |
| 方法 | [`setup_split_screen`](#member-gfviewportutility-methods-setup_split_screen) | `func setup_split_screen(root: Control, viewport_count: int, options: Dictionary = {}) -> Array[SubViewport]:` |
| 方法 | [`clear_split_screen`](#member-gfviewportutility-methods-clear_split_screen) | `func clear_split_screen(free_cameras: bool = false) -> void:` |
| 方法 | [`get_viewport_count`](#member-gfviewportutility-methods-get_viewport_count) | `func get_viewport_count() -> int:` |
| 方法 | [`get_viewports`](#member-gfviewportutility-methods-get_viewports) | `func get_viewports() -> Array[SubViewport]:` |
| 方法 | [`get_viewport`](#member-gfviewportutility-methods-get_viewport) | `func get_viewport(index: int) -> SubViewport:` |
| 方法 | [`get_container`](#member-gfviewportutility-methods-get_container) | `func get_container(index: int) -> SubViewportContainer:` |
| 方法 | [`set_viewport_camera`](#member-gfviewportutility-methods-set_viewport_camera) | `func set_viewport_camera(index: int, camera: Node) -> bool:` |
| 方法 | [`set_postprocess_material`](#member-gfviewportutility-methods-set_postprocess_material) | `func set_postprocess_material(index: int, material: Material) -> bool:` |
| 方法 | [`screen_to_world_ray_3d`](#member-gfviewportutility-methods-screen_to_world_ray_3d) | `func screen_to_world_ray_3d( camera: Camera3D, screen_position: Vector2, length: float = 1000.0 ) -> Dictionary:` |
| 方法 | [`raycast_from_screen_3d`](#member-gfviewportutility-methods-raycast_from_screen_3d) | `func raycast_from_screen_3d( camera: Camera3D, screen_position: Vector2, collision_mask: int = 0xffffffff, length: float = 1000.0, exclude: Array[RID] = [] ) -> Dictionary:` |
| 方法 | [`world_to_screen_3d`](#member-gfviewportutility-methods-world_to_screen_3d) | `func world_to_screen_3d(camera: Camera3D, world_position: Vector3) -> Vector2:` |
| 方法 | [`world_to_screen_2d`](#member-gfviewportutility-methods-world_to_screen_2d) | `func world_to_screen_2d(canvas_item: CanvasItem, world_position: Vector2) -> Vector2:` |
| 方法 | [`screen_to_world_2d`](#member-gfviewportutility-methods-screen_to_world_2d) | `func screen_to_world_2d(canvas_item: CanvasItem, screen_position: Vector2) -> Vector2:` |
| 方法 | [`get_debug_snapshot`](#member-gfviewportutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`tick`](#member-gfviewportutility-methods-tick) | `func tick(_delta: float) -> void:` |

## 信号

<a id="member-gfviewportutility-signals-split_screen_configured"></a>

### `split_screen_configured`

- API：`public`

```gdscript
signal split_screen_configured(viewports: Array)
```

分屏布局创建完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `viewports` | 当前 SubViewport 列表副本。 |

结构：

- `viewports`: Array，由分屏布局创建的 SubViewport 实例。

<a id="member-gfviewportutility-signals-split_screen_cleared"></a>

### `split_screen_cleared`

- API：`public`

```gdscript
signal split_screen_cleared
```

分屏布局被清理后发出。

## 属性

<a id="member-gfviewportutility-properties-viewport_resolution_scale"></a>

### `viewport_resolution_scale`

- API：`public`

```gdscript
var viewport_resolution_scale: float = 1.0:
```

子 viewport 渲染尺寸缩放。1 表示使用配置尺寸。

<a id="member-gfviewportutility-properties-default_disable_3d"></a>

### `default_disable_3d`

- API：`public`

```gdscript
var default_disable_3d: bool = false
```

新建 SubViewport 是否禁用 3D。

<a id="member-gfviewportutility-properties-default_transparent_bg"></a>

### `default_transparent_bg`

- API：`public`

```gdscript
var default_transparent_bg: bool = false
```

新建 SubViewport 是否启用透明背景。

## 方法

<a id="member-gfviewportutility-methods-setup_split_screen"></a>

### `setup_split_screen`

- API：`public`

```gdscript
func setup_split_screen(root: Control, viewport_count: int, options: Dictionary = {}) -> Array[SubViewport]:
```

创建 1 到 4 个 SubViewport 的分屏布局。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 承载布局的 Control。 |
| `viewport_count` | 目标 viewport 数量；小于等于 0 时只清理。 |
| `options` | 可选设置，支持 viewport_size、columns、disable_3d、transparent_bg、stretch。 |

返回：当前 SubViewport 列表副本。

结构：

- `options`: Dictionary，包含 viewport_size: Vector2i 或 Vector2、columns: int、disable_3d: bool、transparent_bg: bool 和 stretch: bool。

<a id="member-gfviewportutility-methods-clear_split_screen"></a>

### `clear_split_screen`

- API：`public`

```gdscript
func clear_split_screen(free_cameras: bool = false) -> void:
```

清理当前分屏布局。

参数：

| 名称 | 说明 |
|---|---|
| `free_cameras` | 是否连同已挂载相机一起释放。 |

<a id="member-gfviewportutility-methods-get_viewport_count"></a>

### `get_viewport_count`

- API：`public`

```gdscript
func get_viewport_count() -> int:
```

获取当前 SubViewport 数量。

返回：viewport 数量。

<a id="member-gfviewportutility-methods-get_viewports"></a>

### `get_viewports`

- API：`public`

```gdscript
func get_viewports() -> Array[SubViewport]:
```

获取当前 SubViewport 列表副本。

返回：viewport 列表。

<a id="member-gfviewportutility-methods-get_viewport"></a>

### `get_viewport`

- API：`public`

```gdscript
func get_viewport(index: int) -> SubViewport:
```

获取指定索引的 SubViewport。

参数：

| 名称 | 说明 |
|---|---|
| `index` | viewport 索引。 |

返回：SubViewport；不存在时返回 null。

<a id="member-gfviewportutility-methods-get_container"></a>

### `get_container`

- API：`public`

```gdscript
func get_container(index: int) -> SubViewportContainer:
```

获取指定索引的 SubViewportContainer。

参数：

| 名称 | 说明 |
|---|---|
| `index` | viewport 索引。 |

返回：SubViewportContainer；不存在时返回 null。

<a id="member-gfviewportutility-methods-set_viewport_camera"></a>

### `set_viewport_camera`

- API：`public`

```gdscript
func set_viewport_camera(index: int, camera: Node) -> bool:
```

将相机挂载到指定 SubViewport。

参数：

| 名称 | 说明 |
|---|---|
| `index` | viewport 索引。 |
| `camera` | Camera2D 或 Camera3D 节点。 |

返回：挂载成功返回 true。

<a id="member-gfviewportutility-methods-set_postprocess_material"></a>

### `set_postprocess_material`

- API：`public`

```gdscript
func set_postprocess_material(index: int, material: Material) -> bool:
```

设置指定 SubViewportContainer 的后处理材质。

参数：

| 名称 | 说明 |
|---|---|
| `index` | viewport 索引。 |
| `material` | 材质；传 null 可清除。 |

返回：设置成功返回 true。

<a id="member-gfviewportutility-methods-screen_to_world_ray_3d"></a>

### `screen_to_world_ray_3d`

- API：`public`

```gdscript
func screen_to_world_ray_3d( camera: Camera3D, screen_position: Vector2, length: float = 1000.0 ) -> Dictionary:
```

从屏幕/Viewport 坐标构建 3D 射线。

参数：

| 名称 | 说明 |
|---|---|
| `camera` | 用于投射的 Camera3D。 |
| `screen_position` | Viewport 内的屏幕坐标。 |
| `length` | 射线长度。 |

返回：包含 ok、origin、direction、end 的字典。

结构：

- `return`: Dictionary，包含 ok: bool、origin: Vector3、direction: Vector3 和 end: Vector3。

<a id="member-gfviewportutility-methods-raycast_from_screen_3d"></a>

### `raycast_from_screen_3d`

- API：`public`

```gdscript
func raycast_from_screen_3d( camera: Camera3D, screen_position: Vector2, collision_mask: int = 0xffffffff, length: float = 1000.0, exclude: Array[RID] = [] ) -> Dictionary:
```

从屏幕/Viewport 坐标执行 3D 射线检测。

参数：

| 名称 | 说明 |
|---|---|
| `camera` | 用于投射的 Camera3D。 |
| `screen_position` | Viewport 内的屏幕坐标。 |
| `collision_mask` | 物理碰撞层掩码。 |
| `length` | 射线长度。 |
| `exclude` | 要排除的 RID 列表。 |

返回：包含射线信息、hit 标记和 result 的字典。

结构：

- `return`: Dictionary，包含物理射线检测得到的 ok、origin、direction、end、hit 和 result。

<a id="member-gfviewportutility-methods-world_to_screen_3d"></a>

### `world_to_screen_3d`

- API：`public`

```gdscript
func world_to_screen_3d(camera: Camera3D, world_position: Vector3) -> Vector2:
```

将 3D 世界坐标转换为屏幕/Viewport 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `camera` | 用于投影的 Camera3D。 |
| `world_position` | 3D 世界坐标。 |

返回：屏幕坐标；camera 无效时返回 INF 坐标。

<a id="member-gfviewportutility-methods-world_to_screen_2d"></a>

### `world_to_screen_2d`

- API：`public`

```gdscript
func world_to_screen_2d(canvas_item: CanvasItem, world_position: Vector2) -> Vector2:
```

将 CanvasItem 所在世界坐标转换为屏幕/Viewport 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_item` | 参考 CanvasItem。 |
| `world_position` | 2D 世界坐标。 |

返回：屏幕坐标。

<a id="member-gfviewportutility-methods-screen_to_world_2d"></a>

### `screen_to_world_2d`

- API：`public`

```gdscript
func screen_to_world_2d(canvas_item: CanvasItem, screen_position: Vector2) -> Vector2:
```

将屏幕/Viewport 坐标转换为 CanvasItem 所在世界坐标。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_item` | 参考 CanvasItem。 |
| `screen_position` | 屏幕坐标。 |

返回：2D 世界坐标。

<a id="member-gfviewportutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 viewport_count、container_count、has_root、has_grid 和 resolution_scale。

<a id="member-gfviewportutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float) -> void:
```

驱动布局生命周期清理。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量。 |
