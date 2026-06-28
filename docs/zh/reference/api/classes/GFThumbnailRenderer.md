# GFThumbnailRenderer

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_thumbnail_renderer.gd`
- 模块：`Kernel`
- 继承：`Node`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器缩略图渲染辅助节点。 使用独立 SubViewport 渲染 Node3D 或 Mesh，供项目自定义编辑器工具复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`cancel_preview_generation`](#member-gfthumbnailrenderer-properties-cancel_preview_generation) | `var cancel_preview_generation: bool = false` |
| 方法 | [`render_node3d`](#member-gfthumbnailrenderer-methods-render_node3d) | `func render_node3d(source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true) -> Image:` |
| 方法 | [`render_node3d_texture`](#member-gfthumbnailrenderer-methods-render_node3d_texture) | `func render_node3d_texture( source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> ImageTexture:` |
| 方法 | [`render_mesh`](#member-gfthumbnailrenderer-methods-render_mesh) | `func render_mesh(mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true) -> Image:` |
| 方法 | [`render_mesh_texture`](#member-gfthumbnailrenderer-methods-render_mesh_texture) | `func render_mesh_texture( mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> ImageTexture:` |
| 方法 | [`render_mesh_library_previews`](#member-gfthumbnailrenderer-methods-render_mesh_library_previews) | `func render_mesh_library_previews( mesh_library: MeshLibrary, size: Vector2i = Vector2i(128, 128), overwrite_existing: bool = true ) -> int:` |
| 方法 | [`build_mesh_library_preview_plan`](#member-gfthumbnailrenderer-methods-build_mesh_library_preview_plan) | `func build_mesh_library_preview_plan( mesh_library: MeshLibrary, size: Vector2i = Vector2i(128, 128), overwrite_existing: bool = true ) -> Dictionary:` |
| 方法 | [`apply_mesh_library_preview_plan`](#member-gfthumbnailrenderer-methods-apply_mesh_library_preview_plan) | `func apply_mesh_library_preview_plan(mesh_library: MeshLibrary, plan: Dictionary) -> int:` |
| 方法 | [`revert_mesh_library_preview_plan`](#member-gfthumbnailrenderer-methods-revert_mesh_library_preview_plan) | `func revert_mesh_library_preview_plan(mesh_library: MeshLibrary, plan: Dictionary) -> int:` |
| 方法 | [`add_mesh_library_preview_plan_to_undo_manager`](#member-gfthumbnailrenderer-methods-add_mesh_library_preview_plan_to_undo_manager) | `func add_mesh_library_preview_plan_to_undo_manager( mesh_library: MeshLibrary, plan: Dictionary, undo_manager: Object, action_name: String = "Generate MeshLibrary Previews" ) -> Error:` |

## 属性

<a id="member-gfthumbnailrenderer-properties-cancel_preview_generation"></a>

### `cancel_preview_generation`

- API：`public`

```gdscript
var cancel_preview_generation: bool = false
```

请求取消正在进行的 MeshLibrary 批量预览生成。

## 方法

<a id="member-gfthumbnailrenderer-methods-render_node3d"></a>

### `render_node3d`

- API：`public`

```gdscript
func render_node3d(source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true) -> Image:
```

渲染一个 3D 节点缩略图。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要渲染的 3D 节点，会被复制后放入内部 Viewport。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：渲染出的 Image；失败时返回 null。

<a id="member-gfthumbnailrenderer-methods-render_node3d_texture"></a>

### `render_node3d_texture`

- API：`public`

```gdscript
func render_node3d_texture( source: Node3D, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> ImageTexture:
```

渲染一个 3D 节点缩略图纹理。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要渲染的 3D 节点。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：渲染出的 ImageTexture；失败时返回 null。

<a id="member-gfthumbnailrenderer-methods-render_mesh"></a>

### `render_mesh`

- API：`public`

```gdscript
func render_mesh(mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true) -> Image:
```

渲染一个 Mesh 缩略图。

参数：

| 名称 | 说明 |
|---|---|
| `mesh` | 要渲染的 Mesh。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：渲染出的 Image；失败时返回 null。

<a id="member-gfthumbnailrenderer-methods-render_mesh_texture"></a>

### `render_mesh_texture`

- API：`public`

```gdscript
func render_mesh_texture( mesh: Mesh, size: Vector2i = Vector2i(256, 256), transparent: bool = true ) -> ImageTexture:
```

渲染一个 Mesh 缩略图纹理。

参数：

| 名称 | 说明 |
|---|---|
| `mesh` | 要渲染的 Mesh。 |
| `size` | 输出尺寸。 |
| `transparent` | 是否透明背景。 |

返回：渲染出的 ImageTexture；失败时返回 null。

<a id="member-gfthumbnailrenderer-methods-render_mesh_library_previews"></a>

### `render_mesh_library_previews`

- API：`public`

```gdscript
func render_mesh_library_previews( mesh_library: MeshLibrary, size: Vector2i = Vector2i(128, 128), overwrite_existing: bool = true ) -> int:
```

为 MeshLibrary 批量生成条目预览。

参数：

| 名称 | 说明 |
|---|---|
| `mesh_library` | 目标 MeshLibrary。 |
| `size` | 预览尺寸。 |
| `overwrite_existing` | 是否覆盖已有预览。 |

返回：成功生成的预览数量。

<a id="member-gfthumbnailrenderer-methods-build_mesh_library_preview_plan"></a>

### `build_mesh_library_preview_plan`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func build_mesh_library_preview_plan( mesh_library: MeshLibrary, size: Vector2i = Vector2i(128, 128), overwrite_existing: bool = true ) -> Dictionary:
```

为 MeshLibrary 批量生成预览修改计划，不直接修改资源。

参数：

| 名称 | 说明 |
|---|---|
| `mesh_library` | 目标 MeshLibrary。 |
| `size` | 预览尺寸。 |
| `overwrite_existing` | 是否覆盖已有预览。 |

返回：包含 changes、generated_count 和 cancelled 的修改计划。

结构：

- `return`: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.

<a id="member-gfthumbnailrenderer-methods-apply_mesh_library_preview_plan"></a>

### `apply_mesh_library_preview_plan`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func apply_mesh_library_preview_plan(mesh_library: MeshLibrary, plan: Dictionary) -> int:
```

应用 MeshLibrary 预览修改计划。

参数：

| 名称 | 说明 |
|---|---|
| `mesh_library` | 目标 MeshLibrary。 |
| `plan` | build_mesh_library_preview_plan() 返回的计划。 |

返回：实际应用的变更数量。

结构：

- `plan`: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.

<a id="member-gfthumbnailrenderer-methods-revert_mesh_library_preview_plan"></a>

### `revert_mesh_library_preview_plan`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func revert_mesh_library_preview_plan(mesh_library: MeshLibrary, plan: Dictionary) -> int:
```

撤销 MeshLibrary 预览修改计划。

参数：

| 名称 | 说明 |
|---|---|
| `mesh_library` | 目标 MeshLibrary。 |
| `plan` | build_mesh_library_preview_plan() 返回的计划。 |

返回：实际还原的变更数量。

结构：

- `plan`: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.

<a id="member-gfthumbnailrenderer-methods-add_mesh_library_preview_plan_to_undo_manager"></a>

### `add_mesh_library_preview_plan_to_undo_manager`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_mesh_library_preview_plan_to_undo_manager( mesh_library: MeshLibrary, plan: Dictionary, undo_manager: Object, action_name: String = "Generate MeshLibrary Previews" ) -> Error:
```

将 MeshLibrary 预览修改计划注册到 UndoRedo 管理器。

参数：

| 名称 | 说明 |
|---|---|
| `mesh_library` | 目标 MeshLibrary。 |
| `plan` | build_mesh_library_preview_plan() 返回的计划。 |
| `undo_manager` | EditorUndoRedoManager 或兼容对象。 |
| `action_name` | UndoRedo 动作名。 |

返回：Godot 错误码。

结构：

- `plan`: Dictionary { ok: bool, generated_count: int, cancelled: bool, changes: Array[Dictionary] }.
