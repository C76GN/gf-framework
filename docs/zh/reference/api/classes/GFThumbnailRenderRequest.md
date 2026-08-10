# GFThumbnailRenderRequest

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_thumbnail_render_request.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`8.0.0`

缩略图渲染请求描述。 请求只描述一次缩略图渲染的输入，不持有执行状态；执行状态由 GFThumbnailRenderTask 承载。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Kind`](#member-gfthumbnailrenderrequest-enums-kind) | `enum Kind` |
| 方法 | [`for_node3d_image`](#member-gfthumbnailrenderrequest-methods-for_node3d_image) | `static func for_node3d_image( source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:` |
| 方法 | [`for_node3d_texture`](#member-gfthumbnailrenderrequest-methods-for_node3d_texture) | `static func for_node3d_texture( source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:` |
| 方法 | [`for_canvas_item_image`](#member-gfthumbnailrenderrequest-methods-for_canvas_item_image) | `static func for_canvas_item_image( source: CanvasItem, size: Vector2i = Vector2i(256, 256), transparent: bool = true, content_bounds: Rect2 = Rect2(), margin_ratio: float = 0.08 ) -> GFThumbnailRenderRequest:` |
| 方法 | [`for_canvas_item_texture`](#member-gfthumbnailrenderrequest-methods-for_canvas_item_texture) | `static func for_canvas_item_texture( source: CanvasItem, size: Vector2i = Vector2i(256, 256), transparent: bool = true, content_bounds: Rect2 = Rect2(), margin_ratio: float = 0.08 ) -> GFThumbnailRenderRequest:` |
| 方法 | [`for_mesh_image`](#member-gfthumbnailrenderrequest-methods-for_mesh_image) | `static func for_mesh_image( mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:` |
| 方法 | [`for_mesh_texture`](#member-gfthumbnailrenderrequest-methods-for_mesh_texture) | `static func for_mesh_texture( mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:` |
| 方法 | [`for_mesh_library_preview_plan`](#member-gfthumbnailrenderrequest-methods-for_mesh_library_preview_plan) | `static func for_mesh_library_preview_plan( mesh_library: MeshLibrary, size: Vector2i = Vector2i(128, 128), overwrite_existing: bool = true ) -> GFThumbnailRenderRequest:` |
| 方法 | [`get_kind`](#member-gfthumbnailrenderrequest-methods-get_kind) | `func get_kind() -> Kind:` |
| 方法 | [`get_source_node3d`](#member-gfthumbnailrenderrequest-methods-get_source_node3d) | `func get_source_node3d() -> Node3D:` |
| 方法 | [`get_source_canvas_item`](#member-gfthumbnailrenderrequest-methods-get_source_canvas_item) | `func get_source_canvas_item() -> CanvasItem:` |
| 方法 | [`get_mesh`](#member-gfthumbnailrenderrequest-methods-get_mesh) | `func get_mesh() -> Mesh:` |
| 方法 | [`get_mesh_library`](#member-gfthumbnailrenderrequest-methods-get_mesh_library) | `func get_mesh_library() -> MeshLibrary:` |
| 方法 | [`get_size`](#member-gfthumbnailrenderrequest-methods-get_size) | `func get_size() -> Vector2i:` |
| 方法 | [`is_transparent`](#member-gfthumbnailrenderrequest-methods-is_transparent) | `func is_transparent() -> bool:` |
| 方法 | [`should_overwrite_existing`](#member-gfthumbnailrenderrequest-methods-should_overwrite_existing) | `func should_overwrite_existing() -> bool:` |
| 方法 | [`get_content_bounds`](#member-gfthumbnailrenderrequest-methods-get_content_bounds) | `func get_content_bounds() -> Rect2:` |
| 方法 | [`has_content_bounds`](#member-gfthumbnailrenderrequest-methods-has_content_bounds) | `func has_content_bounds() -> bool:` |
| 方法 | [`get_margin_ratio`](#member-gfthumbnailrenderrequest-methods-get_margin_ratio) | `func get_margin_ratio() -> float:` |
| 方法 | [`is_valid`](#member-gfthumbnailrenderrequest-methods-is_valid) | `func is_valid() -> bool:` |

## 枚举

<a id="member-gfthumbnailrenderrequest-enums-kind"></a>

### `Kind`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum Kind {
	## 空请求。
	NONE,
	## 将 Node3D 渲染为 Image。
	NODE3D_IMAGE,
	## 将 Node3D 渲染为 ImageTexture。
	NODE3D_TEXTURE,
	## 将 Mesh 渲染为 Image。
	MESH_IMAGE,
	## 将 Mesh 渲染为 ImageTexture。
	MESH_TEXTURE,
	## 为 MeshLibrary 构建预览修改计划。
	MESH_LIBRARY_PREVIEW_PLAN,
	## 将 CanvasItem 渲染为 Image。
	CANVAS_ITEM_IMAGE,
	## 将 CanvasItem 渲染为 ImageTexture。
	CANVAS_ITEM_TEXTURE,
}
```

缩略图渲染请求类型。

## 方法

<a id="member-gfthumbnailrenderrequest-methods-for_node3d_image"></a>

### `for_node3d_image`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func for_node3d_image( source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:
```

创建 Node3D Image 渲染请求。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要渲染的 3D 节点。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：Node3D Image 渲染请求。

<a id="member-gfthumbnailrenderrequest-methods-for_node3d_texture"></a>

### `for_node3d_texture`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func for_node3d_texture( source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:
```

创建 Node3D ImageTexture 渲染请求。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要渲染的 3D 节点。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：Node3D ImageTexture 渲染请求。

<a id="member-gfthumbnailrenderrequest-methods-for_canvas_item_image"></a>

### `for_canvas_item_image`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func for_canvas_item_image( source: CanvasItem, size: Vector2i = Vector2i(256, 256), transparent: bool = true, content_bounds: Rect2 = Rect2(), margin_ratio: float = 0.08 ) -> GFThumbnailRenderRequest:
```

创建 CanvasItem Image 渲染请求。 `source` 可以是 Node2D 或 Control。显式边界为空或尺寸非正时，渲染器会 保守估算常见 CanvasItem 的内容边界；自定义 `_draw()` 节点应传入边界。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要渲染的 2D 画布节点。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |
| `content_bounds` | 来源局部坐标中的显式内容边界；非正尺寸表示自动估算。 |
| `margin_ratio` | 内容边界四周的有限相对留白，钳制到 0.0 至 1.0；非有限值会使请求无效。 |

返回：CanvasItem Image 渲染请求。

<a id="member-gfthumbnailrenderrequest-methods-for_canvas_item_texture"></a>

### `for_canvas_item_texture`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func for_canvas_item_texture( source: CanvasItem, size: Vector2i = Vector2i(256, 256), transparent: bool = true, content_bounds: Rect2 = Rect2(), margin_ratio: float = 0.08 ) -> GFThumbnailRenderRequest:
```

创建 CanvasItem ImageTexture 渲染请求。 `source` 可以是 Node2D 或 Control。显式边界为空或尺寸非正时，渲染器会 保守估算常见 CanvasItem 的内容边界；自定义 `_draw()` 节点应传入边界。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要渲染的 2D 画布节点。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |
| `content_bounds` | 来源局部坐标中的显式内容边界；非正尺寸表示自动估算。 |
| `margin_ratio` | 内容边界四周的有限相对留白，钳制到 0.0 至 1.0；非有限值会使请求无效。 |

返回：CanvasItem ImageTexture 渲染请求。

<a id="member-gfthumbnailrenderrequest-methods-for_mesh_image"></a>

### `for_mesh_image`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func for_mesh_image( mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:
```

创建 Mesh Image 渲染请求。

参数：

| 名称 | 说明 |
|---|---|
| `mesh` | 要渲染的 Mesh。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：Mesh Image 渲染请求。

<a id="member-gfthumbnailrenderrequest-methods-for_mesh_texture"></a>

### `for_mesh_texture`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func for_mesh_texture( mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> GFThumbnailRenderRequest:
```

创建 Mesh ImageTexture 渲染请求。

参数：

| 名称 | 说明 |
|---|---|
| `mesh` | 要渲染的 Mesh。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：Mesh ImageTexture 渲染请求。

<a id="member-gfthumbnailrenderrequest-methods-for_mesh_library_preview_plan"></a>

### `for_mesh_library_preview_plan`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func for_mesh_library_preview_plan( mesh_library: MeshLibrary, size: Vector2i = Vector2i(128, 128), overwrite_existing: bool = true ) -> GFThumbnailRenderRequest:
```

创建 MeshLibrary 预览计划请求。

参数：

| 名称 | 说明 |
|---|---|
| `mesh_library` | 目标 MeshLibrary。 |
| `size` | 预览尺寸。 |
| `overwrite_existing` | 是否覆盖已有预览。 |

返回：MeshLibrary 预览计划请求。

<a id="member-gfthumbnailrenderrequest-methods-get_kind"></a>

### `get_kind`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_kind() -> Kind:
```

返回请求类型。

返回：请求类型。

<a id="member-gfthumbnailrenderrequest-methods-get_source_node3d"></a>

### `get_source_node3d`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_source_node3d() -> Node3D:
```

返回 Node3D 来源。

返回：Node3D 来源；非 Node3D 请求时返回 null。

<a id="member-gfthumbnailrenderrequest-methods-get_source_canvas_item"></a>

### `get_source_canvas_item`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_source_canvas_item() -> CanvasItem:
```

返回 CanvasItem 来源。

返回：CanvasItem 来源；非 2D 请求时返回 null。

<a id="member-gfthumbnailrenderrequest-methods-get_mesh"></a>

### `get_mesh`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_mesh() -> Mesh:
```

返回 Mesh 来源。

返回：Mesh 来源；非 Mesh 请求时返回 null。

<a id="member-gfthumbnailrenderrequest-methods-get_mesh_library"></a>

### `get_mesh_library`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_mesh_library() -> MeshLibrary:
```

返回 MeshLibrary 来源。

返回：MeshLibrary 来源；非 MeshLibrary 请求时返回 null。

<a id="member-gfthumbnailrenderrequest-methods-get_size"></a>

### `get_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_size() -> Vector2i:
```

返回请求尺寸。

返回：请求尺寸。

<a id="member-gfthumbnailrenderrequest-methods-is_transparent"></a>

### `is_transparent`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_transparent() -> bool:
```

返回是否使用透明背景。

返回：透明背景时返回 true。

<a id="member-gfthumbnailrenderrequest-methods-should_overwrite_existing"></a>

### `should_overwrite_existing`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func should_overwrite_existing() -> bool:
```

返回 MeshLibrary 预览计划是否覆盖已有预览。

返回：覆盖已有预览时返回 true。

<a id="member-gfthumbnailrenderrequest-methods-get_content_bounds"></a>

### `get_content_bounds`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_content_bounds() -> Rect2:
```

返回显式 2D 内容边界。

返回：来源局部坐标中的内容边界；未设置时返回空 Rect2。

<a id="member-gfthumbnailrenderrequest-methods-has_content_bounds"></a>

### `has_content_bounds`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func has_content_bounds() -> bool:
```

返回请求是否携带有效的显式 2D 内容边界。

返回：两个边长都为正时返回 true。

<a id="member-gfthumbnailrenderrequest-methods-get_margin_ratio"></a>

### `get_margin_ratio`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_margin_ratio() -> float:
```

返回 2D 内容相对留白。

返回：0.0 至 1.0 的留白比例。

<a id="member-gfthumbnailrenderrequest-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_valid() -> bool:
```

返回请求输入是否完整。

返回：请求可执行时返回 true。
