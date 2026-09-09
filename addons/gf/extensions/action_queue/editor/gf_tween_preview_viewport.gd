@tool

## GFTweenPreviewViewport: 配置化 Tween 的独立编辑器样机与手动播放会话。
## 只创建原生节点与工具自有资源，不接收真实场景目标；时间由调用方显式推进。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFTweenPreviewViewport
extends SubViewport


# --- 信号 ---

## 播放状态或错误信息更新后发出。
## [br]
## @api framework_internal
signal state_changed


# --- 常量 ---

const _PREVIEW_SIZE: Vector2i = Vector2i(480, 320)
const _SAMPLE_COLOR: Color = Color(0.35, 0.72, 1.0)


# --- 私有变量 ---

var _config: Resource = null
var _target_kind: int = 0
var _sample_root: Node = null
var _target: Node = null
var _initial_values: Dictionary = {}
var _tween: Tween = null
var _restore_on_finish: bool = false
var _state: StringName = &"idle"
var _error: String = ""


# --- Godot 生命周期方法 ---

func _init() -> void:
	size = _PREVIEW_SIZE
	transparent_bg = true
	world_2d = World2D.new()
	world_3d = World3D.new()
	render_target_update_mode = SubViewport.UPDATE_ONCE
	gui_disable_input = true
	var _size_changed_connected: int = size_changed.connect(_on_size_changed)


func _ready() -> void:
	_on_size_changed()


func _exit_tree() -> void:
	dispose_preview()


# --- 框架内部方法 ---

## 更换来源配置和样机类型，取消旧播放并重建默认初值。
## [br]
## @api framework_internal
## [br]
## @param config: 待预览资源；播放时由 GFTweenPreviewPlan 验证并冻结。
## [br]
## @param kind: 0 为二维图形，1 为 UI 色块，2 为三维方块。
func configure(config: Resource, kind: int = 0) -> void:
	_clear_tween()
	_restore_initial_values()
	_release_sample()
	_config = config
	_target_kind = kind
	_initial_values = GFTweenPreviewPlan.get_initial_values(kind)
	_error = ""
	_restore_on_finish = false
	if _initial_values.is_empty():
		_fail("Unsupported preview target kind.")
		return
	_build_sample()
	_restore_initial_values()
	_set_state(&"idle")


## 从暂停继续；其他状态从初值开始读取并播放最新配置快照。
## 独立编辑器时钟不采用来源配置的 process、pause 或 time scale 设置。
## [br]
## @api framework_internal
## [br]
## @return: 配置与目标有效且本次播放或恢复被接受时返回 true。
func play() -> bool:
	if _state == &"paused" and is_instance_valid(_tween):
		_error = ""
		_set_state(&"playing")
		return true
	_clear_tween()
	_restore_initial_values()
	if not is_inside_tree() or not is_instance_valid(_target):
		_fail("Preview must be inside the scene tree with a configured sample.")
		return false
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(_config, _target_kind)
	if not plan.error.is_empty():
		_fail(plan.error)
		return false
	_restore_on_finish = plan.restore_on_finish
	_error = ""
	if not _has_timed_steps(plan.steps):
		for step: Dictionary in plan.steps:
			_apply_instant_step(step)
		_finish_playback()
		return true
	_tween = create_tween()
	_tween.pause()
	var _ignore_time_scale_result: Tween = _tween.set_ignore_time_scale(true)
	var _loop_result: Tween = _tween.set_loops(plan.loop_count)
	for step: Dictionary in plan.steps:
		var tweener: PropertyTweener = GFTweenActionStep.append_property_tweener(
			_tween,
			_target,
			_step_path(step),
			step.get("target_value"),
			_step_float(step, "duration"),
			_step_float(step, "delay"),
			_step_bool(step, "as_relative"),
			_step_bool(step, "parallel"),
			_step_int(step, "transition_type") as Tween.TransitionType,
			_step_int(step, "ease_type") as Tween.EaseType
		)
		if tweener == null:
			_fail("Unable to construct the validated preview step.")
			return false
	_set_state(&"playing")
	return true


## 暂停显式推进；下一次 play 从当前位置继续。
## [br]
## @api framework_internal
func pause() -> void:
	if _state == &"playing":
		_set_state(&"paused")


## 停止会话并保留当前样机画面；下次播放仍从初值开始。
## [br]
## @api framework_internal
func stop() -> void:
	_clear_tween()
	_error = ""
	_set_state(&"idle")


## 停止会话并强制恢复当前初值。
## [br]
## @api framework_internal
func reset_preview() -> void:
	_clear_tween()
	_restore_initial_values()
	_error = ""
	_set_state(&"idle")


## 手动推进正在播放的原生 Tween；暂停及终态不推进。
## [br]
## @api framework_internal
## [br]
## @param delta: 有限且非负的独立编辑器时间增量，单位为秒。
func advance(delta: float) -> void:
	if _state != &"playing":
		return
	if not is_finite(delta) or delta < 0.0:
		_fail("Preview time delta must be finite and non-negative.")
		return
	if not is_instance_valid(_target) or not is_instance_valid(_tween):
		_fail("Preview sample or playback session is no longer available.")
		return
	var still_playing: bool = _tween.custom_step(delta)
	_request_render()
	if not still_playing or _tween.get_loops_left() == 0:
		_finish_playback()


## 设置完整属性的工具侧初值，成功时取消播放并恢复全部初值。
## [br]
## @api framework_internal
## [br]
## @param property_name: 当前样机允许的完整属性名，不接受分量路径。
## [br]
## @param value: 与该属性匹配的有限纯值。
## [br]
## @schema value: int、float、Vector2、Vector3 或 Color，具体类型由样机属性白名单确定。
## [br]
## @return: 初值通过验证且已应用时返回 true；拒绝时保留原初值。
func set_initial_value(property_name: StringName, value: Variant) -> bool:
	var validation_error: String = GFTweenPreviewPlan.validate_initial_value(
		property_name, value, _target_kind
	)
	if not validation_error.is_empty():
		_fail(validation_error)
		return false
	if not is_instance_valid(_target):
		_fail("Preview sample is not configured.")
		return false
	_clear_tween()
	_initial_values[String(property_name)] = value
	_restore_initial_values()
	_error = ""
	_set_state(&"idle")
	return true


## 返回不共享容器的初值快照。
## [br]
## @api framework_internal
## [br]
## @return: 当前样机完整属性名到纯值的映射；已释放时为空。
## [br]
## @schema return: Dictionary，String 属性名映射到 int、float、Vector2、Vector3 或 Color。
func get_initial_values() -> Dictionary:
	return _initial_values.duplicate()


## 返回当前样机的完整属性值，不暴露目标节点或内部 Tween。
## [br]
## @api framework_internal
## [br]
## @return: 当前值快照；样机失效或已释放时为空。
## [br]
## @schema return: Dictionary，String 属性名映射到 int、float、Vector2、Vector3 或 Color。
func get_current_values() -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(_target):
		return result
	for key: Variant in _initial_values:
		if key is String:
			var property_name: String = key
			result[property_name] = _target.get(property_name)
	return result


## 返回当前播放状态。
## [br]
## @api framework_internal
## [br]
## @return: idle、playing、paused、finished 或 error。
func get_state() -> StringName:
	return _state


## 返回最近一次操作错误；成功操作后为空。
## [br]
## @api framework_internal
## [br]
## @return: 可供编辑器呈现的错误说明。
func get_error() -> String:
	return _error


## 取消会话、恢复并释放样机和来源引用；允许重复调用。
## [br]
## @api framework_internal
func dispose_preview() -> void:
	_clear_tween()
	_restore_initial_values()
	_release_sample()
	_config = null
	_initial_values.clear()
	_restore_on_finish = false
	_error = ""
	_set_state(&"idle")


# --- 私有/辅助方法 ---

func _build_sample() -> void:
	_sample_root = Node.new()
	_sample_root.name = "PreviewSample"
	add_child(_sample_root)
	if _target_kind == 0:
		var polygon: Polygon2D = Polygon2D.new()
		polygon.polygon = PackedVector2Array([
			Vector2(-24.0, -20.0), Vector2(32.0, 0.0), Vector2(-24.0, 20.0),
		])
		polygon.color = _SAMPLE_COLOR
		_target = polygon
	elif _target_kind == 1:
		var rectangle: ColorRect = ColorRect.new()
		rectangle.color = _SAMPLE_COLOR
		rectangle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_target = rectangle
	else:
		var spatial: Node3D = Node3D.new()
		_target = spatial
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = _SAMPLE_COLOR
		material.roughness = 0.8
		mesh_instance.material_override = material
		spatial.add_child(mesh_instance)
		var camera: Camera3D = Camera3D.new()
		var camera_position: Vector3 = Vector3(3.5, 2.5, 5.0)
		camera.transform = Transform3D(Basis.looking_at(-camera_position), camera_position)
		camera.current = true
		_sample_root.add_child(camera)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
		_sample_root.add_child(light)
	_target.name = "PreviewTarget"
	_sample_root.add_child(_target)


func _release_sample() -> void:
	if is_instance_valid(_sample_root):
		_sample_root.queue_free()
	_sample_root = null
	_target = null


func _clear_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _restore_initial_values() -> void:
	if not is_instance_valid(_target):
		return
	for key: Variant in _initial_values:
		if key is String:
			var property_name: String = key
			_target.set(property_name, _initial_values[property_name])
	_request_render()


func _has_timed_steps(steps: Array[Dictionary]) -> bool:
	for step: Dictionary in steps:
		if _step_float(step, "duration") > 0.0 or _step_float(step, "delay") > 0.0:
			return true
	return false


func _apply_instant_step(step: Dictionary) -> void:
	var property_path: NodePath = _step_path(step)
	var value: Variant = step.get("target_value")
	if _step_bool(step, "as_relative"):
		value = _relative_value(_target.get_indexed(property_path), value)
	_target.set_indexed(property_path, value)


func _relative_value(current: Variant, next: Variant) -> Variant:
	if (current is int or current is float) and (next is int or next is float):
		return _number_value(current) + _number_value(next)
	if current is Vector2 and next is Vector2:
		var current_vector: Vector2 = current
		var next_vector: Vector2 = next
		return current_vector + next_vector
	if current is Vector3 and next is Vector3:
		var current_vector: Vector3 = current
		var next_vector: Vector3 = next
		return current_vector + next_vector
	if current is Color and next is Color:
		var current_color: Color = current
		var next_color: Color = next
		return current_color + next_color
	return next


func _finish_playback() -> void:
	_clear_tween()
	if _restore_on_finish:
		_restore_initial_values()
	_request_render()
	_set_state(&"finished")


func _fail(message: String) -> void:
	_clear_tween()
	_restore_initial_values()
	_error = message
	_set_state(&"error")


func _set_state(state: StringName) -> void:
	_state = state
	state_changed.emit()


func _request_render() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _step_path(step: Dictionary) -> NodePath:
	var value: Variant = step.get("property_name")
	if value is NodePath:
		var result: NodePath = value
		return result
	return NodePath()


func _step_float(step: Dictionary, key: String) -> float:
	var value: Variant = step.get(key)
	if value is float:
		var result: float = value
		return result
	return 0.0


func _step_int(step: Dictionary, key: String) -> int:
	var value: Variant = step.get(key)
	if value is int:
		var result: int = value
		return result
	return 0


func _step_bool(step: Dictionary, key: String) -> bool:
	var value: Variant = step.get(key)
	if value is bool:
		var result: bool = value
		return result
	return false


func _number_value(value: Variant) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return 0.0


# --- 信号处理函数 ---

func _on_size_changed() -> void:
	if not is_inside_tree():
		return
	canvas_transform = Transform2D(0.0, Vector2(size) * 0.5)
	_request_render()
