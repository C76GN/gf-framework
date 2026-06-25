## GFViewportUtility: 通用 SubViewport 布局管理工具。
##
## 用于本地多人、调试监视器、小地图或多视角预览等场景。它只管理 Viewport
## 容器、相机挂载和后处理材质，不接管玩家、场景切换或输入规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFViewportUtility
extends GFUtility


# --- 信号 ---

## 分屏布局创建完成后发出。
## [br]
## @api public
## [br]
## @param viewports: 当前 SubViewport 列表副本。
## [br]
## @schema viewports: Array，由分屏布局创建的 SubViewport 实例。
signal split_screen_configured(viewports: Array)

## 分屏布局被清理后发出。
## [br]
## @api public
signal split_screen_cleared


# --- 公共变量 ---

## 子 viewport 渲染尺寸缩放。1 表示使用配置尺寸。
## [br]
## @api public
var viewport_resolution_scale: float = 1.0:
	set(value):
		viewport_resolution_scale = maxf(value, 0.01)

## 新建 SubViewport 是否禁用 3D。
## [br]
## @api public
var default_disable_3d: bool = false

## 新建 SubViewport 是否启用透明背景。
## [br]
## @api public
var default_transparent_bg: bool = false


# --- 私有变量 ---

var _root_ref: WeakRef = null
var _grid: GridContainer = null
var _containers: Array[SubViewportContainer] = []
var _viewports: Array[SubViewport] = []
var _cameras: Array[Node] = []


# --- 公共方法 ---

## 创建 1 到 4 个 SubViewport 的分屏布局。
## [br]
## @api public
## [br]
## @param root: 承载布局的 Control。
## [br]
## @param viewport_count: 目标 viewport 数量；小于等于 0 时只清理。
## [br]
## @param options: 可选设置，支持 viewport_size、columns、disable_3d、transparent_bg、stretch。
## [br]
## @return 当前 SubViewport 列表副本。
## [br]
## @schema options: Dictionary，包含 viewport_size: Vector2i 或 Vector2、columns: int、disable_3d: bool、transparent_bg: bool 和 stretch: bool。
func setup_split_screen(root: Control, viewport_count: int, options: Dictionary = {}) -> Array[SubViewport]:
	clear_split_screen(false)
	if not is_instance_valid(root) or viewport_count <= 0:
		return []

	var count: int = clampi(viewport_count, 1, 4)
	_root_ref = weakref(root)
	_grid = GridContainer.new()
	_grid.name = "GFViewportGrid"
	var default_columns: int = _get_default_columns(count)
	_grid.columns = GFVariantData.get_option_int(options, "columns", default_columns)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_grid)

	for index: int in range(count):
		_create_viewport_slot(index, options)

	split_screen_configured.emit(get_viewports())
	return get_viewports()


## 清理当前分屏布局。
## [br]
## @api public
## [br]
## @param free_cameras: 是否连同已挂载相机一起释放。
func clear_split_screen(free_cameras: bool = false) -> void:
	for camera: Node in _cameras:
		if not is_instance_valid(camera):
			continue
		var camera_parent: Node = camera.get_parent()
		if camera_parent != null and (camera_parent in _viewports or free_cameras):
			camera_parent.remove_child(camera)
		if free_cameras:
			camera.queue_free()

	if is_instance_valid(_grid):
		var grid_parent: Node = _grid.get_parent()
		if grid_parent != null:
			grid_parent.remove_child(_grid)
		_grid.queue_free()

	_root_ref = null
	_grid = null
	_containers.clear()
	_viewports.clear()
	_cameras.clear()
	split_screen_cleared.emit()


## 获取当前 SubViewport 数量。
## [br]
## @api public
## [br]
## @return viewport 数量。
func get_viewport_count() -> int:
	return _viewports.size()


## 获取当前 SubViewport 列表副本。
## [br]
## @api public
## [br]
## @return viewport 列表。
func get_viewports() -> Array[SubViewport]:
	return _viewports.duplicate()


## 获取指定索引的 SubViewport。
## [br]
## @api public
## [br]
## @param index: viewport 索引。
## [br]
## @return SubViewport；不存在时返回 null。
func get_viewport(index: int) -> SubViewport:
	if index < 0 or index >= _viewports.size():
		return null
	return _viewports[index]


## 获取指定索引的 SubViewportContainer。
## [br]
## @api public
## [br]
## @param index: viewport 索引。
## [br]
## @return SubViewportContainer；不存在时返回 null。
func get_container(index: int) -> SubViewportContainer:
	if index < 0 or index >= _containers.size():
		return null
	return _containers[index]


## 将相机挂载到指定 SubViewport。
## [br]
## @api public
## [br]
## @param index: viewport 索引。
## [br]
## @param camera: Camera2D 或 Camera3D 节点。
## [br]
## @return 挂载成功返回 true。
func set_viewport_camera(index: int, camera: Node) -> bool:
	var viewport: SubViewport = get_viewport(index)
	if viewport == null or not is_instance_valid(camera):
		return false
	if camera.get_parent() != null and camera.get_parent() != viewport:
		push_warning("[GFViewportUtility] 相机已在其他父节点下，未自动重挂。")
		return false

	var previous: Node = _get_camera_at(index)
	if is_instance_valid(previous) and previous != camera and previous.get_parent() == viewport:
		viewport.remove_child(previous)

	if camera.get_parent() == null:
		viewport.add_child(camera)
	_cameras[index] = camera
	_activate_camera(camera)
	return true


## 设置指定 SubViewportContainer 的后处理材质。
## [br]
## @api public
## [br]
## @param index: viewport 索引。
## [br]
## @param material: 材质；传 null 可清除。
## [br]
## @return 设置成功返回 true。
func set_postprocess_material(index: int, material: Material) -> bool:
	var container: SubViewportContainer = get_container(index)
	if container == null:
		return false
	container.material = material
	return true


## 从屏幕/Viewport 坐标构建 3D 射线。
## [br]
## @api public
## [br]
## @param camera: 用于投射的 Camera3D。
## [br]
## @param screen_position: Viewport 内的屏幕坐标。
## [br]
## @param length: 射线长度。
## [br]
## @return 包含 ok、origin、direction、end 的字典。
## [br]
## @schema return: Dictionary，包含 ok: bool、origin: Vector3、direction: Vector3 和 end: Vector3。
func screen_to_world_ray_3d(
	camera: Camera3D,
	screen_position: Vector2,
	length: float = 1000.0
) -> Dictionary:
	if not is_instance_valid(camera) or length <= 0.0:
		return {
			"ok": false,
			"origin": Vector3.ZERO,
			"direction": Vector3.ZERO,
			"end": Vector3.ZERO,
		}

	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position).normalized()
	return {
		"ok": true,
		"origin": origin,
		"direction": direction,
		"end": origin + direction * length,
	}


## 从屏幕/Viewport 坐标执行 3D 射线检测。
## [br]
## @api public
## [br]
## @param camera: 用于投射的 Camera3D。
## [br]
## @param screen_position: Viewport 内的屏幕坐标。
## [br]
## @param collision_mask: 物理碰撞层掩码。
## [br]
## @param length: 射线长度。
## [br]
## @param exclude: 要排除的 RID 列表。
## [br]
## @return 包含射线信息、hit 标记和 result 的字典。
## [br]
## @schema return: Dictionary，包含物理射线检测得到的 ok、origin、direction、end、hit 和 result。
func raycast_from_screen_3d(
	camera: Camera3D,
	screen_position: Vector2,
	collision_mask: int = 0xffffffff,
	length: float = 1000.0,
	exclude: Array[RID] = []
) -> Dictionary:
	var ray: Dictionary = screen_to_world_ray_3d(camera, screen_position, length)
	ray["hit"] = false
	ray["result"] = {}
	if not GFVariantData.get_option_bool(ray, "ok"):
		return ray

	var world: World3D = camera.get_world_3d()
	if world == null:
		return ray

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		GFVariantData.get_option_vector3(ray, "origin"),
		GFVariantData.get_option_vector3(ray, "end"),
		collision_mask,
		exclude
	)
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	ray["hit"] = not result.is_empty()
	ray["result"] = result
	return ray


## 将 3D 世界坐标转换为屏幕/Viewport 坐标。
## [br]
## @api public
## [br]
## @param camera: 用于投影的 Camera3D。
## [br]
## @param world_position: 3D 世界坐标。
## [br]
## @return 屏幕坐标；camera 无效时返回 INF 坐标。
func world_to_screen_3d(camera: Camera3D, world_position: Vector3) -> Vector2:
	if not is_instance_valid(camera):
		return Vector2(INF, INF)
	return camera.unproject_position(world_position)


## 将 CanvasItem 所在世界坐标转换为屏幕/Viewport 坐标。
## [br]
## @api public
## [br]
## @param canvas_item: 参考 CanvasItem。
## [br]
## @param world_position: 2D 世界坐标。
## [br]
## @return 屏幕坐标。
func world_to_screen_2d(canvas_item: CanvasItem, world_position: Vector2) -> Vector2:
	if not is_instance_valid(canvas_item):
		return world_position
	return canvas_item.get_global_transform_with_canvas() * world_position


## 将屏幕/Viewport 坐标转换为 CanvasItem 所在世界坐标。
## [br]
## @api public
## [br]
## @param canvas_item: 参考 CanvasItem。
## [br]
## @param screen_position: 屏幕坐标。
## [br]
## @return 2D 世界坐标。
func screen_to_world_2d(canvas_item: CanvasItem, screen_position: Vector2) -> Vector2:
	if not is_instance_valid(canvas_item):
		return screen_position
	return canvas_item.get_global_transform_with_canvas().affine_inverse() * screen_position


## 根据物理屏幕安全区计算 Viewport 逻辑坐标中的边距。
##
## extra_margins 使用已经转换到 Viewport 逻辑坐标的 top、left、bottom、right，
## 可用于叠加项目自己的遮挡区域。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param safe_area: DisplayServer 返回的物理像素安全区。
## [br]
## @param window_size: DisplayServer 返回的物理窗口尺寸。
## [br]
## @param viewport_size: 当前 Viewport 可见尺寸。
## [br]
## @param extra_margins: 额外逻辑边距。
## [br]
## @return 安全区边距报告。
## [br]
## @schema extra_margins: Dictionary，可选 top、left、bottom、right，单位为 Viewport 逻辑坐标。
## [br]
## @schema return: Dictionary，包含 ok、top、left、bottom、right、scale_x、scale_y、safe_area、window_size 和 viewport_size。
func calculate_safe_area_margins(
	safe_area: Rect2i,
	window_size: Vector2i,
	viewport_size: Vector2,
	extra_margins: Dictionary = {}
) -> Dictionary:
	var normalized_safe_area: Rect2i = safe_area
	if normalized_safe_area.size.x <= 0 or normalized_safe_area.size.y <= 0:
		normalized_safe_area = Rect2i(Vector2i.ZERO, window_size)

	var report: Dictionary = _make_safe_area_report(normalized_safe_area, window_size, viewport_size)
	if window_size.x <= 0 or window_size.y <= 0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return report

	var scale_x: float = viewport_size.x / float(window_size.x)
	var scale_y: float = viewport_size.y / float(window_size.y)
	var top_margin: float = maxf(float(normalized_safe_area.position.y) * scale_y, 0.0)
	var left_margin: float = maxf(float(normalized_safe_area.position.x) * scale_x, 0.0)
	var bottom_physical: int = window_size.y - (normalized_safe_area.position.y + normalized_safe_area.size.y)
	var right_physical: int = window_size.x - (normalized_safe_area.position.x + normalized_safe_area.size.x)
	var bottom_margin: float = maxf(float(bottom_physical) * scale_y, 0.0)
	var right_margin: float = maxf(float(right_physical) * scale_x, 0.0)

	report["ok"] = true
	report["top"] = top_margin + maxf(GFVariantData.get_option_float(extra_margins, "top"), 0.0)
	report["left"] = left_margin + maxf(GFVariantData.get_option_float(extra_margins, "left"), 0.0)
	report["bottom"] = bottom_margin + maxf(GFVariantData.get_option_float(extra_margins, "bottom"), 0.0)
	report["right"] = right_margin + maxf(GFVariantData.get_option_float(extra_margins, "right"), 0.0)
	report["scale_x"] = scale_x
	report["scale_y"] = scale_y
	return report


## 读取当前 DisplayServer 安全区并转换为 Viewport 逻辑边距。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param viewport: 可选 Viewport；为空时使用物理窗口尺寸作为逻辑尺寸。
## [br]
## @param extra_margins: 额外逻辑边距。
## [br]
## @return 安全区边距报告。
## [br]
## @schema extra_margins: Dictionary，可选 top、left、bottom、right，单位为 Viewport 逻辑坐标。
## [br]
## @schema return: Dictionary，包含 ok、top、left、bottom、right、scale_x、scale_y、safe_area、window_size 和 viewport_size。
func get_display_safe_area_margins(viewport: Viewport = null, extra_margins: Dictionary = {}) -> Dictionary:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var viewport_size: Vector2 = Vector2(window_size)
	if is_instance_valid(viewport):
		viewport_size = viewport.get_visible_rect().size
	return calculate_safe_area_margins(safe_area, window_size, viewport_size, extra_margins)


## 将边距字典应用到 MarginContainer。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param container: 目标 MarginContainer。
## [br]
## @param margins: 边距字典。
## [br]
## @return 应用成功返回 true。
## [br]
## @schema margins: Dictionary，包含 top、left、bottom、right，单位为 Viewport 逻辑坐标。
func apply_safe_area_margins(container: MarginContainer, margins: Dictionary) -> bool:
	if not is_instance_valid(container):
		return false
	container.add_theme_constant_override("margin_top", maxi(roundi(GFVariantData.get_option_float(margins, "top")), 0))
	container.add_theme_constant_override("margin_left", maxi(roundi(GFVariantData.get_option_float(margins, "left")), 0))
	container.add_theme_constant_override("margin_bottom", maxi(roundi(GFVariantData.get_option_float(margins, "bottom")), 0))
	container.add_theme_constant_override("margin_right", maxi(roundi(GFVariantData.get_option_float(margins, "right")), 0))
	return true


## 读取当前 DisplayServer 安全区并应用到 MarginContainer。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param container: 目标 MarginContainer。
## [br]
## @param viewport: 可选 Viewport；为空时优先使用 container 所在 Viewport。
## [br]
## @param extra_margins: 额外逻辑边距。
## [br]
## @return 安全区边距报告，applied 表示是否成功写入 container。
## [br]
## @schema extra_margins: Dictionary，可选 top、left、bottom、right，单位为 Viewport 逻辑坐标。
## [br]
## @schema return: Dictionary，包含 ok、applied、top、left、bottom、right、scale_x、scale_y、safe_area、window_size 和 viewport_size。
func apply_display_safe_area_margins(
	container: MarginContainer,
	viewport: Viewport = null,
	extra_margins: Dictionary = {}
) -> Dictionary:
	var target_viewport: Viewport = viewport
	if target_viewport == null and is_instance_valid(container):
		target_viewport = container.get_viewport()
	var report: Dictionary = get_display_safe_area_margins(target_viewport, extra_margins)
	report["applied"] = GFVariantData.get_option_bool(report, "ok") and apply_safe_area_margins(container, report)
	return report


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 viewport_count、container_count、has_root、has_grid 和 resolution_scale。
func get_debug_snapshot() -> Dictionary:
	return {
		"viewport_count": _viewports.size(),
		"container_count": _containers.size(),
		"has_root": _root_ref != null and _root_ref.get_ref() != null,
		"has_grid": is_instance_valid(_grid),
		"resolution_scale": viewport_resolution_scale,
	}


## 驱动布局生命周期清理。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量。
func tick(_delta: float) -> void:
	if _root_ref != null and _root_ref.get_ref() == null:
		clear_split_screen(false)


# --- 私有/辅助方法 ---

func _create_viewport_slot(index: int, options: Dictionary) -> void:
	var resolved_size: Vector2i = _resolve_viewport_size(options)
	var container: SubViewportContainer = SubViewportContainer.new()
	container.name = "ViewportContainer%d" % index
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(resolved_size)
	_grid.add_child(container)

	var viewport: SubViewport = SubViewport.new()
	viewport.size = resolved_size
	container.stretch = GFVariantData.get_option_bool(options, "stretch")
	viewport.name = "Viewport%d" % index
	viewport.disable_3d = GFVariantData.get_option_bool(options, "disable_3d", default_disable_3d)
	viewport.transparent_bg = GFVariantData.get_option_bool(options, "transparent_bg", default_transparent_bg)
	container.add_child(viewport)
	viewport.size = resolved_size

	_containers.append(container)
	_viewports.append(viewport)
	_cameras.append(null)


func _get_camera_at(index: int) -> Node:
	if index < 0 or index >= _cameras.size():
		return null
	return _cameras[index]


func _resolve_viewport_size(options: Dictionary) -> Vector2i:
	var configured_size: Variant = GFVariantData.get_option_value(options, "viewport_size", Vector2i.ZERO)
	if configured_size is Vector2i:
		var size_2i: Vector2i = configured_size
		if size_2i.x > 0 and size_2i.y > 0:
			return _scale_size(size_2i)
	if configured_size is Vector2:
		var size_2: Vector2 = configured_size
		if size_2.x > 0.0 and size_2.y > 0.0:
			return _scale_size(Vector2i(roundi(size_2.x), roundi(size_2.y)))
	return _scale_size(Vector2i(640, 360))


func _scale_size(size: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(roundi(float(size.x) * viewport_resolution_scale), 1),
		maxi(roundi(float(size.y) * viewport_resolution_scale), 1)
	)


func _get_default_columns(count: int) -> int:
	return 1 if count <= 1 else 2


func _activate_camera(camera: Node) -> void:
	if camera is Camera2D:
		var camera_2d: Camera2D = camera
		camera_2d.enabled = true
	elif camera is Camera3D:
		var camera_3d: Camera3D = camera
		camera_3d.current = true


func _make_safe_area_report(safe_area: Rect2i, window_size: Vector2i, viewport_size: Vector2) -> Dictionary:
	return {
		"ok": false,
		"top": 0.0,
		"left": 0.0,
		"bottom": 0.0,
		"right": 0.0,
		"scale_x": 0.0,
		"scale_y": 0.0,
		"safe_area": safe_area,
		"window_size": window_size,
		"viewport_size": viewport_size,
	}
