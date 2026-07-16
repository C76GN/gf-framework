@tool

## GFThumbnailRenderRequest: 缩略图渲染请求描述。
##
## 请求只描述一次缩略图渲染的输入，不持有执行状态；执行状态由 GFThumbnailRenderTask 承载。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFThumbnailRenderRequest
extends RefCounted


# --- 枚举 ---

## 缩略图渲染请求类型。
## [br]
## @api public
## [br]
## @since 8.0.0
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
}


# --- 私有变量 ---

var _kind: Kind = Kind.NONE
var _source_node3d: Node3D = null
var _mesh: Mesh = null
var _mesh_library: MeshLibrary = null
var _size: Vector2i = Vector2i(256, 256)
var _transparent: bool = true
var _overwrite_existing: bool = true


# --- 公共方法 ---

## 创建 Node3D Image 渲染请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source: 要渲染的 3D 节点。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return Node3D Image 渲染请求。
static func for_node3d_image(
	source: Node3D,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true
) -> GFThumbnailRenderRequest:
	return _make_request(Kind.NODE3D_IMAGE, source, null, null, size, transparent, true)


## 创建 Node3D ImageTexture 渲染请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source: 要渲染的 3D 节点。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return Node3D ImageTexture 渲染请求。
static func for_node3d_texture(
	source: Node3D,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true
) -> GFThumbnailRenderRequest:
	return _make_request(Kind.NODE3D_TEXTURE, source, null, null, size, transparent, true)


## 创建 Mesh Image 渲染请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param mesh: 要渲染的 Mesh。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return Mesh Image 渲染请求。
static func for_mesh_image(
	mesh: Mesh,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true
) -> GFThumbnailRenderRequest:
	return _make_request(Kind.MESH_IMAGE, null, mesh, null, size, transparent, true)


## 创建 Mesh ImageTexture 渲染请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param mesh: 要渲染的 Mesh。
## [br]
## @param size: 输出尺寸。
## [br]
## @param transparent: 是否透明背景。
## [br]
## @return Mesh ImageTexture 渲染请求。
static func for_mesh_texture(
	mesh: Mesh,
	size: Vector2i = Vector2i(256, 256),
	transparent: bool = true
) -> GFThumbnailRenderRequest:
	return _make_request(Kind.MESH_TEXTURE, null, mesh, null, size, transparent, true)


## 创建 MeshLibrary 预览计划请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param mesh_library: 目标 MeshLibrary。
## [br]
## @param size: 预览尺寸。
## [br]
## @param overwrite_existing: 是否覆盖已有预览。
## [br]
## @return MeshLibrary 预览计划请求。
static func for_mesh_library_preview_plan(
	mesh_library: MeshLibrary,
	size: Vector2i = Vector2i(128, 128),
	overwrite_existing: bool = true
) -> GFThumbnailRenderRequest:
	return _make_request(Kind.MESH_LIBRARY_PREVIEW_PLAN, null, null, mesh_library, size, true, overwrite_existing)


## 返回请求类型。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 请求类型。
func get_kind() -> Kind:
	return _kind


## 返回 Node3D 来源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Node3D 来源；非 Node3D 请求时返回 null。
func get_source_node3d() -> Node3D:
	return _source_node3d


## 返回 Mesh 来源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Mesh 来源；非 Mesh 请求时返回 null。
func get_mesh() -> Mesh:
	return _mesh


## 返回 MeshLibrary 来源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return MeshLibrary 来源；非 MeshLibrary 请求时返回 null。
func get_mesh_library() -> MeshLibrary:
	return _mesh_library


## 返回请求尺寸。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 请求尺寸。
func get_size() -> Vector2i:
	return _size


## 返回是否使用透明背景。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 透明背景时返回 true。
func is_transparent() -> bool:
	return _transparent


## 返回 MeshLibrary 预览计划是否覆盖已有预览。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 覆盖已有预览时返回 true。
func should_overwrite_existing() -> bool:
	return _overwrite_existing


## 返回请求输入是否完整。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 请求可执行时返回 true。
func is_valid() -> bool:
	match _kind:
		Kind.NODE3D_IMAGE, Kind.NODE3D_TEXTURE:
			return _source_node3d != null and is_instance_valid(_source_node3d)
		Kind.MESH_IMAGE, Kind.MESH_TEXTURE:
			return _mesh != null
		Kind.MESH_LIBRARY_PREVIEW_PLAN:
			return _mesh_library != null
		_:
			return false


# --- 私有/辅助方法 ---

static func _make_request(
	kind: Kind,
	source_node3d: Node3D,
	mesh: Mesh,
	mesh_library: MeshLibrary,
	size: Vector2i,
	transparent: bool,
	overwrite_existing: bool
) -> GFThumbnailRenderRequest:
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.new()
	request._kind = kind
	request._source_node3d = source_node3d
	request._mesh = mesh
	request._mesh_library = mesh_library
	request._size = size
	request._transparent = transparent
	request._overwrite_existing = overwrite_existing
	return request
