## GFCameraRig3D: 通用 3D 相机姿态提供节点。
##
## Rig 只计算期望 Camera3D Transform，不直接控制 Camera3D。
## 项目可用多个 Rig 表达不同视角，再交给 GFCameraDirector3D 按优先级选择。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFCameraRig3D
extends Node3D


const _GF_CAMERA_FINITE_MATH = preload("res://addons/gf/extensions/camera/core/gf_camera_finite_math.gd")


# --- 信号 ---

## Rig 激活状态变化后发出。
## [br]
## @api public
## [br]
## @param active: 当前是否激活。
signal active_changed(active: bool)

## Rig 优先级变化后发出。
## [br]
## @api public
## [br]
## @param priority: 当前优先级。
signal priority_changed(priority: int)


# --- 导出变量 ---

## 是否参与 Director 选择。
## [br]
## @api public
@export var active: bool = true:
	set(value):
		if active == value:
			return
		active = value
		active_changed.emit(active)

## 选择优先级。数值越大越优先。
## [br]
## @api public
@export var priority: int = 0:
	set(value):
		if priority == value:
			return
		priority = value
		priority_changed.emit(priority)

## 可选跟随目标。为空时使用 Rig 自身的全局姿态。
## [br]
## @api public
@export_node_path("Node3D") var target_path: NodePath = NodePath("")

## 可选朝向目标。look_at_enabled 为 true 时生效。
## [br]
## @api public
@export_node_path("Node3D") var look_at_target_path: NodePath = NodePath("")

## 位置偏移。
## [br]
## @api public
@export var offset: Vector3 = Vector3.ZERO

## 偏移是否跟随目标旋转。
## [br]
## @api public
@export var offset_follows_rotation: bool = false

## 是否读取目标旋转。
## [br]
## @api public
@export var use_target_rotation: bool = true

## 是否朝向 look_at_target_path。
## [br]
## @api public
@export var look_at_enabled: bool = false

## look_at 使用的上方向。为零向量时会回退到 Vector3.UP。
## [br]
## @api public
@export var up_axis: Vector3 = Vector3.UP

## 额外旋转偏移，单位度。
## [br]
## @api public
@export var rotation_degrees_offset: Vector3 = Vector3.ZERO

## 进入该 Rig 时使用的过渡。为空时使用 Director 默认过渡。
## [br]
## @api public
@export var blend: GFCameraBlend = null

## 自动加入的分组名。Director 可按该分组收集候选。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var group_name: StringName = &"gf_camera_rig_3d":
	get:
		return _group_name
	set(value):
		_set_group_name(value)

## 相机选择作用域。为空时使用 Rig 父节点；Director 只会从相同作用域收集分组 Rig。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_node_path("Node") var camera_scope_path: NodePath = NodePath("")

## 相机选择频道。为空表示默认频道；Director 配置非空频道时只收集同频道 Rig。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var camera_channel: StringName = &""

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义元数据；框架不会读取或改写其中字段。
@export var metadata: Dictionary = {}


# --- 私有变量 ---

var _group_name: StringName = &"gf_camera_rig_3d"
var _registered_group_name: StringName = &""


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_update_group_registration()


func _exit_tree() -> void:
	_unregister_group()


# --- 公共方法 ---

## 获取跟随目标。
## [br]
## @api public
## [br]
## @return 目标 Node3D；不存在时返回 null。
func get_target_node() -> Node3D:
	if target_path.is_empty():
		return null
	return _get_node_3d_value(get_node_or_null(target_path))


## 获取朝向目标。
## [br]
## @api public
## [br]
## @return 目标 Node3D；不存在时返回 null。
func get_look_at_target_node() -> Node3D:
	if look_at_target_path.is_empty():
		return null
	return _get_node_3d_value(get_node_or_null(look_at_target_path))


## 获取当前期望相机 Transform。
## [br]
## @api public
## [br]
## @return 期望全局 Transform。
func get_camera_transform() -> Transform3D:
	var target: Node3D = get_target_node()
	var camera_transform: Transform3D = _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
		global_transform,
		Transform3D.IDENTITY
	)
	if target != null:
		var target_transform: Transform3D = _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
			target.global_transform,
			camera_transform
		)
		camera_transform.origin = target_transform.origin
		if use_target_rotation:
			camera_transform.basis = target_transform.basis

	var safe_offset: Vector3 = _sanitize_vector3(offset, Vector3.ZERO)
	var effective_offset: Vector3 = camera_transform.basis * safe_offset if offset_follows_rotation else safe_offset
	camera_transform.origin = _sanitize_vector3(
		camera_transform.origin + effective_offset,
		camera_transform.origin
	)
	if look_at_enabled:
		var look_at_target: Node3D = get_look_at_target_node()
		var look_at_position: Vector3 = (
			_sanitize_vector3(look_at_target.global_position, camera_transform.origin)
			if look_at_target != null
			else camera_transform.origin
		)
		if look_at_target != null and not camera_transform.origin.is_equal_approx(look_at_position):
			var look_direction: Vector3 = look_at_position - camera_transform.origin
			camera_transform = camera_transform.looking_at(
				look_at_position,
				_get_safe_up_axis_for_direction(look_direction)
			)
	return _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
		_apply_rotation_offset(camera_transform),
		camera_transform
	)


## 获取相机选择作用域节点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 作用域节点；显式路径为空时返回父节点。
func get_camera_scope_node() -> Node:
	if not camera_scope_path.is_empty():
		return get_node_or_null(camera_scope_path)
	return get_parent()


## 检查 Rig 是否可被选择。
## [br]
## @api public
## [br]
## @return 可用时返回 true。
func is_available() -> bool:
	return (
		active
		and is_inside_tree()
		and (target_path.is_empty() or get_target_node() != null)
		and (not look_at_enabled or get_look_at_target_node() != null)
	)


# --- 私有/辅助方法 ---

func _set_group_name(value: StringName) -> void:
	if _group_name == value:
		return
	_group_name = value
	_update_group_registration()


func _update_group_registration() -> void:
	if not is_inside_tree():
		return
	if _registered_group_name != &"" and _registered_group_name != _group_name:
		remove_from_group(_registered_group_name)
		_registered_group_name = &""
	if _group_name != &"" and _registered_group_name != _group_name:
		add_to_group(_group_name)
		_registered_group_name = _group_name


func _unregister_group() -> void:
	if _registered_group_name == &"":
		return
	remove_from_group(_registered_group_name)
	_registered_group_name = &""


func _get_safe_up_axis() -> Vector3:
	var safe_axis: Vector3 = _sanitize_vector3(up_axis, Vector3.UP)
	if safe_axis.length_squared() <= 0.000001:
		return Vector3.UP
	return safe_axis.normalized()


func _get_safe_up_axis_for_direction(direction: Vector3) -> Vector3:
	var safe_up: Vector3 = _get_safe_up_axis()
	if direction.length_squared() <= 0.000001:
		return safe_up
	var normalized_direction: Vector3 = direction.normalized()
	if absf(normalized_direction.dot(safe_up)) < 0.999:
		return safe_up
	if absf(normalized_direction.dot(Vector3.UP)) < 0.999:
		return Vector3.UP
	return Vector3.RIGHT


func _get_node_3d_value(value: Variant) -> Node3D:
	if value is Node3D:
		var node: Node3D = value
		return node
	return null


func _apply_rotation_offset(camera_transform: Transform3D) -> Transform3D:
	var safe_rotation_offset: Vector3 = _sanitize_vector3(rotation_degrees_offset, Vector3.ZERO)
	if safe_rotation_offset != Vector3.ZERO:
		camera_transform.basis = camera_transform.basis.rotated(camera_transform.basis.x.normalized(), deg_to_rad(safe_rotation_offset.x))
		camera_transform.basis = camera_transform.basis.rotated(camera_transform.basis.y.normalized(), deg_to_rad(safe_rotation_offset.y))
		camera_transform.basis = camera_transform.basis.rotated(camera_transform.basis.z.normalized(), deg_to_rad(safe_rotation_offset.z))
	camera_transform.basis = camera_transform.basis.orthonormalized()
	return camera_transform


func _sanitize_float(value: float, fallback: float) -> float:
	return _GF_CAMERA_FINITE_MATH.sanitize_float(value, fallback)


func _sanitize_vector3(value: Vector3, fallback: Vector3) -> Vector3:
	return _GF_CAMERA_FINITE_MATH.sanitize_vector3(value, fallback)
