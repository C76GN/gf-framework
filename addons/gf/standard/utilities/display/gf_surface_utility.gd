## GFSurfaceUtility: 3D 表面材质查询工具。
##
## 根据碰撞命中的 face index 推导 MeshInstance3D surface，并返回基础材质、
## 覆盖材质或最终 active material。框架只负责几何到材质的映射，不解释材质语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSurfaceUtility
extends GFUtility


# --- 枚举 ---

## Mesh surface face count 缓存策略。
## [br]
## @api public
enum CacheMode {
	## 不读写缓存，每次查询都重新计算。
	DISABLED,
	## 只使用显式预热写入的缓存。
	MANUAL,
	## 查询时自动缓存，并按 auto_cache_size 控制容量。
	AUTOMATIC,
}


# --- 常量 ---

## 自动缓存默认容量。
## [br]
## @api public
const DEFAULT_AUTO_CACHE_SIZE: int = 8

const _REASON_INVALID_FACE_INDEX: String = "invalid_face_index"
const _REASON_MESH_INSTANCE_NOT_FOUND: String = "mesh_instance_not_found"
const _REASON_MESH_NOT_FOUND: String = "mesh_not_found"
const _REASON_SURFACE_NOT_FOUND: String = "surface_not_found"


# --- 公共变量 ---

## 当前缓存策略。
## [br]
## @api public
var cache_mode: CacheMode = CacheMode.AUTOMATIC

## 自动缓存容量。小于 1 时会被归一化为 1。
## [br]
## @api public
var auto_cache_size: int = DEFAULT_AUTO_CACHE_SIZE


# --- 私有变量 ---

var _surface_face_counts_by_mesh: Dictionary = {}
var _surface_face_count_signatures_by_mesh: Dictionary = {}
var _mesh_cache_order: Array[int] = []


# --- GF 生命周期方法 ---

## 释放工具时清空 Mesh surface face count 缓存。
## [br]
## @api public
func dispose() -> void:
	clear_cache()


# --- 公共方法 ---

## 获取命中表面最终渲染使用的材质。
## [br]
## @api public
## [br]
## @param source: MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @param face_index: RayCast3D.get_collision_face_index() 返回的面索引。
## [br]
## @return 命中材质；无法解析时返回 null。
func get_active_material(source: Object, face_index: int) -> Material:
	var mesh_instance: MeshInstance3D = _resolve_mesh_instance(source)
	var surface_index: int = get_surface_index(source, face_index)
	if mesh_instance == null or surface_index < 0:
		return null
	return mesh_instance.get_active_material(surface_index)


## 描述命中表面的结构化报告。
##
## 返回值面向运行时分发、调试面板和日志摘要；GF 只暴露 surface/material 数据，
## 不解释脚步声、弹孔、地形标签或其它业务语义。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source: MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @param face_index: RayCast3D.get_collision_face_index() 返回的面索引。
## [br]
## @return 表面命中报告；无法解析时 ok 为 false，并保留 reason。
## [br]
## @schema return: Dictionary，包含 ok、reason、face_index、surface_index、base_material、override_material、active_material、has_*_material 以及对应 *_material_name、*_material_path、*_material_type 字段；material 字段为 JSON-safe 资源摘要，不包含运行时 Object 引用。
func describe_surface_hit(source: Object, face_index: int) -> Dictionary:
	if face_index < 0:
		return _make_surface_hit_report(false, _REASON_INVALID_FACE_INDEX, face_index, -1)

	var mesh_instance: MeshInstance3D = _resolve_mesh_instance(source)
	if mesh_instance == null:
		return _make_surface_hit_report(false, _REASON_MESH_INSTANCE_NOT_FOUND, face_index, -1)
	if mesh_instance.mesh == null:
		return _make_surface_hit_report(false, _REASON_MESH_NOT_FOUND, face_index, -1)

	var surface_index: int = _get_surface_index_for_mesh(mesh_instance.mesh, face_index)
	if surface_index < 0:
		return _make_surface_hit_report(false, _REASON_SURFACE_NOT_FOUND, face_index, -1)

	var base_material: Material = mesh_instance.mesh.surface_get_material(surface_index)
	var override_material: Material = mesh_instance.get_surface_override_material(surface_index)
	var active_material: Material = mesh_instance.get_active_material(surface_index)
	return _make_surface_hit_report(true, "", face_index, surface_index, base_material, override_material, active_material)


## 描述 Mesh 的 surface 布局。
##
## 返回值只包含 Mesh、surface、primitive、顶点/索引/面数和材质摘要，适合编辑器工具、
## 导入预检、调试面板或日志检查 Mesh 结构；不会修改 Mesh、创建碰撞体或生成节点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source: Mesh、MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @return Mesh surface 布局报告；无法解析时 ok 为 false，并保留 reason。
## [br]
## @schema return: Dictionary，包含 ok、reason、mesh、mesh_name、mesh_path、mesh_type、surface_count、vertex_count、index_count、face_count、aabb_position、aabb_size 和 surfaces；mesh 与 material 字段为 JSON-safe 资源摘要，不包含运行时 Object 引用。
func describe_mesh(source: Object) -> Dictionary:
	var mesh: Mesh = _resolve_mesh(source)
	if mesh == null:
		return _make_mesh_report(false, _REASON_MESH_NOT_FOUND)

	var surfaces: Array[Dictionary] = []
	var total_vertex_count: int = 0
	var total_index_count: int = 0
	var total_face_count: int = 0
	for surface_index: int in range(mesh.get_surface_count()):
		var surface_report: Dictionary = _describe_mesh_surface(mesh, surface_index)
		total_vertex_count += GFVariantData.get_option_int(surface_report, "vertex_count")
		total_index_count += GFVariantData.get_option_int(surface_report, "index_count")
		total_face_count += GFVariantData.get_option_int(surface_report, "face_count")
		surfaces.append(surface_report)

	return _make_mesh_report(
		true,
		"",
		mesh,
		surfaces,
		total_vertex_count,
		total_index_count,
		total_face_count
	)


## 获取 MeshInstance3D surface override 材质。
## [br]
## @api public
## [br]
## @param source: MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @param face_index: RayCast3D.get_collision_face_index() 返回的面索引。
## [br]
## @return 覆盖材质；未设置或无法解析时返回 null。
func get_surface_override_material(source: Object, face_index: int) -> Material:
	var mesh_instance: MeshInstance3D = _resolve_mesh_instance(source)
	var surface_index: int = get_surface_index(source, face_index)
	if mesh_instance == null or surface_index < 0:
		return null
	return mesh_instance.get_surface_override_material(surface_index)


## 获取 Mesh 资源自身的 surface 材质。
## [br]
## @api public
## [br]
## @param source: MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @param face_index: RayCast3D.get_collision_face_index() 返回的面索引。
## [br]
## @return 基础材质；无法解析时返回 null。
func get_base_material(source: Object, face_index: int) -> Material:
	var mesh_instance: MeshInstance3D = _resolve_mesh_instance(source)
	var surface_index: int = get_surface_index(source, face_index)
	if mesh_instance == null or mesh_instance.mesh == null or surface_index < 0:
		return null
	return mesh_instance.mesh.surface_get_material(surface_index)


## 获取 face index 所属的 Mesh surface 索引。
## [br]
## @api public
## [br]
## @param source: MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @param face_index: RayCast3D.get_collision_face_index() 返回的面索引。
## [br]
## @return surface 索引；无法解析时返回 -1。
func get_surface_index(source: Object, face_index: int) -> int:
	if face_index < 0:
		return -1

	var mesh_instance: MeshInstance3D = _resolve_mesh_instance(source)
	if mesh_instance == null or mesh_instance.mesh == null:
		return -1

	return _get_surface_index_for_mesh(mesh_instance.mesh, face_index)


## 清空 Mesh surface face count 缓存。
## [br]
## @api public
func clear_cache() -> void:
	_surface_face_counts_by_mesh.clear()
	_surface_face_count_signatures_by_mesh.clear()
	_mesh_cache_order.clear()


## 预热指定 Mesh 或 MeshInstance3D 的 surface face count 缓存。
## [br]
## @api public
## [br]
## @param source: Mesh、MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @return 缓存成功返回 true。
func cache_mesh_surface(source: Object) -> bool:
	if cache_mode == CacheMode.DISABLED:
		return false

	var mesh: Mesh = _resolve_mesh(source)
	if mesh == null:
		return false

	var cache_key: int = _get_mesh_cache_key(mesh)
	var face_count_data: Dictionary = _compute_surface_face_count_data(mesh)
	_store_surface_face_counts(
		cache_key,
		GFVariantData.get_option_int_array(face_count_data, "face_counts"),
		GFVariantData.get_option_int_array(face_count_data, "signature"),
		true
	)
	return true


## 移除指定 Mesh 或 MeshInstance3D 的 surface face count 缓存。
## [br]
## @api public
## [br]
## @param source: Mesh、MeshInstance3D、CollisionObject3D 或其相邻节点。
## [br]
## @return 移除成功返回 true。
func erase_cached_mesh(source: Object) -> bool:
	var mesh: Mesh = _resolve_mesh(source)
	if mesh == null:
		return false

	var cache_key: int = _get_mesh_cache_key(mesh)
	var existed: bool = _surface_face_counts_by_mesh.has(cache_key)
	var _face_counts_erased: bool = _surface_face_counts_by_mesh.erase(cache_key)
	var _signature_erased: bool = _surface_face_count_signatures_by_mesh.erase(cache_key)
	_mesh_cache_order.erase(cache_key)
	return existed


## 设置自动缓存容量。
## [br]
## @api public
## [br]
## @param size: 自动缓存容量；小于 1 时按 1 处理。
func set_auto_cache_size(size: int) -> void:
	auto_cache_size = maxi(size, 1)
	_trim_auto_cache()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 缓存状态。
## [br]
## @schema return: Dictionary，包含 cached_meshes、cache_mode 和 auto_cache_size。
func get_debug_snapshot() -> Dictionary:
	return {
		"cached_meshes": _surface_face_counts_by_mesh.size(),
		"cache_mode": cache_mode,
		"auto_cache_size": auto_cache_size,
	}


# --- 私有/辅助方法 ---

func _resolve_mesh_instance(source: Object) -> MeshInstance3D:
	if source is MeshInstance3D:
		var direct_mesh_instance: MeshInstance3D = source
		return direct_mesh_instance if direct_mesh_instance.mesh != null else null

	var node: Node = _variant_to_node(source)
	if node == null:
		return null

	var parent: Node = node.get_parent()
	var parent_mesh_instance: MeshInstance3D = _variant_to_mesh_instance_with_mesh(parent)
	if parent_mesh_instance != null:
		return parent_mesh_instance

	for child: Node in node.get_children():
		var child_mesh_instance: MeshInstance3D = _variant_to_mesh_instance_with_mesh(child)
		if child_mesh_instance != null:
			return child_mesh_instance

	if parent != null:
		for sibling: Node in parent.get_children():
			var sibling_mesh_instance: MeshInstance3D = _variant_to_mesh_instance_with_mesh(sibling)
			if sibling_mesh_instance != null:
				return sibling_mesh_instance

	return null


func _resolve_mesh(source: Object) -> Mesh:
	if source is Mesh:
		var mesh: Mesh = source
		return mesh

	var mesh_instance: MeshInstance3D = _resolve_mesh_instance(source)
	if mesh_instance != null:
		return mesh_instance.mesh
	return null


func _get_surface_index_for_mesh(mesh: Mesh, face_index: int) -> int:
	if face_index < 0 or mesh == null:
		return -1

	var face_counts: Array[int] = _get_surface_face_counts(mesh)
	return _get_surface_index_from_face_counts(face_counts, face_index)


func _get_surface_index_from_face_counts(face_counts: Array[int], face_index: int) -> int:
	var remaining_face_index: int = face_index
	for surface_index: int in range(face_counts.size()):
		var face_count: int = face_counts[surface_index]
		if remaining_face_index < face_count:
			return surface_index
		remaining_face_index -= face_count
	return -1


func _get_surface_face_counts(mesh: Mesh) -> Array[int]:
	var cache_key: int = _get_mesh_cache_key(mesh)
	var signature: Array[int] = _compute_surface_face_count_signature(mesh)
	if _surface_face_counts_by_mesh.has(cache_key) and _cached_surface_signature_matches(cache_key, signature):
		_touch_mesh_cache_key(cache_key)
		return GFVariantData.get_option_int_array(_surface_face_counts_by_mesh, cache_key)

	var face_counts: Array[int] = _compute_surface_face_counts(mesh)
	if cache_mode == CacheMode.AUTOMATIC:
		_store_surface_face_counts(cache_key, face_counts, signature, false)
	return face_counts


func _compute_surface_face_counts(mesh: Mesh) -> Array[int]:
	return GFVariantData.get_option_int_array(_compute_surface_face_count_data(mesh), "face_counts")


func _compute_surface_face_count_signature(mesh: Mesh) -> Array[int]:
	return GFVariantData.get_option_int_array(_compute_surface_face_count_data(mesh), "signature")


func _compute_surface_face_count_data(mesh: Mesh) -> Dictionary:
	var face_counts: Array[int] = []
	var signature: Array[int] = [mesh.get_surface_count()]
	for surface_index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var primitive_type: int = _get_surface_primitive_type(mesh, surface_index)
		var index_count: int = _get_surface_index_count(arrays)
		var vertex_count: int = _get_surface_vertex_count(arrays)
		signature.append(primitive_type)
		signature.append(index_count)
		signature.append(vertex_count)
		face_counts.append(_get_surface_face_count(mesh, surface_index, primitive_type, index_count, vertex_count))
	return {
		"face_counts": face_counts,
		"signature": signature,
	}


func _store_surface_face_counts(
	cache_key: int,
	face_counts: Array[int],
	signature: Array[int],
	keep_when_manual: bool
) -> void:
	if cache_key == 0:
		return
	if cache_mode == CacheMode.DISABLED:
		return
	if cache_mode == CacheMode.MANUAL and not keep_when_manual:
		return

	_surface_face_counts_by_mesh[cache_key] = face_counts.duplicate()
	_surface_face_count_signatures_by_mesh[cache_key] = signature.duplicate()
	_touch_mesh_cache_key(cache_key)
	if cache_mode == CacheMode.AUTOMATIC:
		_trim_auto_cache()


func _touch_mesh_cache_key(cache_key: int) -> void:
	_mesh_cache_order.erase(cache_key)
	_mesh_cache_order.append(cache_key)


func _trim_auto_cache() -> void:
	auto_cache_size = maxi(auto_cache_size, 1)
	while cache_mode == CacheMode.AUTOMATIC and _mesh_cache_order.size() > auto_cache_size:
		var oldest_key: int = GFVariantData.to_int(_mesh_cache_order.pop_front())
		var _face_counts_erased: bool = _surface_face_counts_by_mesh.erase(oldest_key)
		var _signature_erased: bool = _surface_face_count_signatures_by_mesh.erase(oldest_key)


func _cached_surface_signature_matches(cache_key: int, signature: Array[int]) -> bool:
	var cached_signature: Array[int] = GFVariantData.get_option_int_array(
		_surface_face_count_signatures_by_mesh,
		cache_key
	)
	return cached_signature == signature


func _get_surface_face_count(
	mesh: Mesh,
	surface_index: int,
	primitive_type: int,
	index_count: int,
	vertex_count: int
) -> int:
	var element_count: int = index_count if index_count > 0 else vertex_count
	match primitive_type:
		Mesh.PRIMITIVE_TRIANGLES:
			return floori(float(element_count) / 3.0)
		Mesh.PRIMITIVE_TRIANGLE_STRIP:
			return maxi(element_count - 2, 0)

	return _get_surface_face_count_with_mesh_data_tool(mesh, surface_index)


func _get_surface_primitive_type(mesh: Mesh, surface_index: int) -> int:
	if mesh is ArrayMesh:
		var array_mesh: ArrayMesh = mesh
		return array_mesh.surface_get_primitive_type(surface_index)
	return Mesh.PRIMITIVE_TRIANGLES


func _get_surface_index_count(arrays: Array) -> int:
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return 0
	var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
	if index_data is PackedInt32Array:
		var indices: PackedInt32Array = index_data
		return indices.size()
	return 0


func _get_surface_vertex_count(arrays: Array) -> int:
	if arrays.size() <= Mesh.ARRAY_VERTEX:
		return 0
	var vertex_data: Variant = arrays[Mesh.ARRAY_VERTEX]
	if vertex_data is PackedVector3Array:
		var vertices: PackedVector3Array = vertex_data
		return vertices.size()
	return 0


func _get_surface_face_count_with_mesh_data_tool(mesh: Mesh, surface_index: int) -> int:
	if not mesh is ArrayMesh:
		return 0

	var array_mesh: ArrayMesh = mesh
	var mesh_data_tool: MeshDataTool = MeshDataTool.new()
	var error: Error = mesh_data_tool.create_from_surface(array_mesh, surface_index) as Error
	if error != OK:
		return 0
	return mesh_data_tool.get_face_count()


func _describe_mesh_surface(mesh: Mesh, surface_index: int) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(surface_index)
	var primitive_type: int = _get_surface_primitive_type(mesh, surface_index)
	var index_count: int = _get_surface_index_count(arrays)
	var vertex_count: int = _get_surface_vertex_count(arrays)
	var face_count: int = _get_surface_face_count(mesh, surface_index, primitive_type, index_count, vertex_count)
	var material: Material = mesh.surface_get_material(surface_index)
	return {
		"surface_index": surface_index,
		"primitive_type": primitive_type,
		"primitive_name": _get_primitive_name(primitive_type),
		"vertex_count": vertex_count,
		"index_count": index_count,
		"face_count": face_count,
		"material": _make_resource_summary(material),
		"material_name": _get_resource_name(material),
		"material_path": _get_resource_path(material),
		"material_type": _get_resource_type(material),
		"has_material": material != null,
	}


func _make_mesh_report(
	ok: bool,
	reason: String,
	mesh: Mesh = null,
	surfaces: Array[Dictionary] = [],
	vertex_count: int = 0,
	index_count: int = 0,
	face_count: int = 0
) -> Dictionary:
	var aabb: AABB = AABB()
	if mesh != null:
		aabb = mesh.get_aabb()

	return {
		"ok": ok,
		"reason": reason,
		"mesh": _make_resource_summary(mesh),
		"mesh_name": _get_resource_name(mesh),
		"mesh_path": _get_resource_path(mesh),
		"mesh_type": _get_resource_type(mesh),
		"surface_count": surfaces.size(),
		"vertex_count": vertex_count,
		"index_count": index_count,
		"face_count": face_count,
		"aabb_position": aabb.position,
		"aabb_size": aabb.size,
		"surfaces": surfaces,
	}


func _get_primitive_name(primitive_type: int) -> StringName:
	match primitive_type:
		Mesh.PRIMITIVE_POINTS:
			return &"points"
		Mesh.PRIMITIVE_LINES:
			return &"lines"
		Mesh.PRIMITIVE_LINE_STRIP:
			return &"line_strip"
		Mesh.PRIMITIVE_TRIANGLES:
			return &"triangles"
		Mesh.PRIMITIVE_TRIANGLE_STRIP:
			return &"triangle_strip"
		_:
			return &"unknown"


func _make_surface_hit_report(
	ok: bool,
	reason: String,
	face_index: int,
	surface_index: int,
	base_material: Material = null,
	override_material: Material = null,
	active_material: Material = null
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"face_index": face_index,
		"surface_index": surface_index,
		"base_material": _make_resource_summary(base_material),
		"base_material_name": _get_resource_name(base_material),
		"base_material_path": _get_resource_path(base_material),
		"base_material_type": _get_resource_type(base_material),
		"has_base_material": base_material != null,
		"override_material": _make_resource_summary(override_material),
		"override_material_name": _get_resource_name(override_material),
		"override_material_path": _get_resource_path(override_material),
		"override_material_type": _get_resource_type(override_material),
		"has_override_material": override_material != null,
		"active_material": _make_resource_summary(active_material),
		"active_material_name": _get_resource_name(active_material),
		"active_material_path": _get_resource_path(active_material),
		"active_material_type": _get_resource_type(active_material),
		"has_active_material": active_material != null,
	}


func _make_resource_summary(resource: Resource) -> Dictionary:
	if resource == null:
		return {
			"has_resource": false,
			"name": "",
			"path": "",
			"type": "",
			"instance_id": 0,
		}
	return {
		"has_resource": true,
		"name": _get_resource_name(resource),
		"path": _get_resource_path(resource),
		"type": _get_resource_type(resource),
		"instance_id": resource.get_instance_id(),
	}


func _get_resource_name(resource: Resource) -> String:
	if resource == null:
		return ""
	return String(resource.resource_name)


func _get_resource_path(resource: Resource) -> String:
	if resource == null:
		return ""
	return resource.resource_path


func _get_resource_type(resource: Resource) -> String:
	if resource == null:
		return ""
	return resource.get_class()


func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _variant_to_mesh_instance_with_mesh(value: Variant) -> MeshInstance3D:
	if value is MeshInstance3D:
		var mesh_instance: MeshInstance3D = value
		if mesh_instance.mesh != null:
			return mesh_instance
	return null


func _get_mesh_cache_key(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	return mesh.get_rid().get_id()
