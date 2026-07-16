## GFCameraRig2D: 通用 2D 相机姿态提供节点。
##
## Rig 只计算期望相机位置、旋转和缩放，不直接控制 Camera2D。
## 项目可用多个 Rig 表达不同视角，再交给 GFCameraDirector2D 按优先级选择。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFCameraRig2D
extends Node2D


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
@export_node_path("Node2D") var target_path: NodePath = NodePath("")

## 位置偏移。
## [br]
## @api public
@export var offset: Vector2 = Vector2.ZERO

## 偏移是否跟随目标旋转。
## [br]
## @api public
@export var offset_follows_rotation: bool = false

## 是否读取目标旋转。
## [br]
## @api public
@export var use_target_rotation: bool = true

## 额外旋转偏移，单位度。
## [br]
## @api public
@export var rotation_degrees_offset: float = 0.0

## 期望相机缩放。
## [br]
## @api public
@export var zoom: Vector2 = Vector2.ONE

## 进入该 Rig 时使用的过渡。为空时使用 Director 默认过渡。
## [br]
## @api public
@export var blend: GFCameraBlend = null

## 自动加入的分组名。Director 可按该分组收集候选。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var group_name: StringName = &"gf_camera_rig_2d":
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

var _group_name: StringName = &"gf_camera_rig_2d"
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
## @return 目标 Node2D；不存在时返回 null。
func get_target_node() -> Node2D:
	if target_path.is_empty():
		return null
	return _get_node_2d_value(get_node_or_null(target_path))


## 获取当前期望相机姿态。
## [br]
## @api public
## [br]
## @return 包含 position、rotation、zoom 和 rig 的字典。
## [br]
## @schema return: Dictionary，包含 position: Vector2、rotation: float、zoom: Vector2 与 rig: GFCameraRig2D。
func get_camera_pose() -> Dictionary:
	var target: Node2D = get_target_node()
	var base_position: Vector2 = _sanitize_vector2(global_position, Vector2.ZERO)
	var base_rotation: float = _sanitize_float(global_rotation, 0.0)
	if target != null:
		base_position = _sanitize_vector2(target.global_position, base_position)
		if use_target_rotation:
			base_rotation = _sanitize_float(target.global_rotation, base_rotation)

	var safe_offset: Vector2 = _sanitize_vector2(offset, Vector2.ZERO)
	var effective_offset: Vector2 = safe_offset.rotated(base_rotation) if offset_follows_rotation else safe_offset
	return {
		"position": _sanitize_vector2(base_position + effective_offset, base_position),
		"rotation": _sanitize_float(
			base_rotation + deg_to_rad(_sanitize_float(rotation_degrees_offset, 0.0)),
			base_rotation
		),
		"zoom": _sanitize_vector2(zoom, Vector2.ONE),
		"rig": self,
	}


## 获取 JSON-safe 的当前期望相机姿态数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 不包含 Object 引用的姿态数据。
## [br]
## @schema return: Dictionary，包含 position、rotation、zoom、rig_path 和 rig_instance_id；Vector2 字段使用 GFVariantJsonCodec typed marker。
func get_camera_pose_data() -> Dictionary:
	var pose: Dictionary = get_camera_pose()
	var _rig_erased: bool = pose.erase("rig")
	pose["rig_path"] = String(get_path()) if is_inside_tree() else ""
	pose["rig_instance_id"] = get_instance_id()
	return GFVariantData.as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(pose))


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
	return active and is_inside_tree() and (target_path.is_empty() or get_target_node() != null)


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


func _get_node_2d_value(value: Variant) -> Node2D:
	if value is Node2D:
		var node: Node2D = value
		return node
	return null


func _sanitize_float(value: float, fallback: float) -> float:
	return _GF_CAMERA_FINITE_MATH.sanitize_float(value, fallback)


func _sanitize_vector2(value: Vector2, fallback: Vector2) -> Vector2:
	return _GF_CAMERA_FINITE_MATH.sanitize_vector2(value, fallback)
