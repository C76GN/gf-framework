## GFShaderParameterAction: 通用 ShaderMaterial 参数动作。
##
## 将 ShaderMaterial 的某个 uniform 参数写入或缓动到目标值。
## 它只处理参数写入、Tween 宿主和可选材质实例化，不绑定具体 shader、特效或业务语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 4.2.0
class_name GFShaderParameterAction
extends GFVisualAction


# --- 公共变量 ---

## 目标对象。可以直接是 ShaderMaterial，也可以是持有材质属性的对象。
## [br]
## @api public
var target: Object

## Shader uniform 参数名。
## [br]
## @api public
var parameter_name: StringName = &""

## 要写入的目标参数值。
## [br]
## @api public
## [br]
## @schema target_value: Variant，可被 Tween 插值并写入 parameter_name 的目标值。
var target_value: Variant = null

## Tween 持续时间。小于等于 0 时立即写入。
## [br]
## @api public
var duration: float = 0.2

## 当 target 不是 ShaderMaterial 时，用于读取材质的属性路径。
## [br]
## @api public
var material_property: NodePath = ^"material"

## 可选 Tween 宿主节点。target 不是 Node 时，带时长动作必须提供。
## [br]
## @api public
var host_node: Node

## Tween 过渡类型。
## [br]
## @api public
var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

## Tween 缓动类型。
## [br]
## @api public
var ease_type: Tween.EaseType = Tween.EASE_OUT

## 执行前是否复制材质并写回 material_property，避免修改共享材质资源。
## [br]
## @api public
var duplicate_material_on_execute: bool = false

## 取消动作时是否恢复执行前捕获的参数值。
## [br]
## @api public
var restore_initial_value_on_cancel: bool = false

## 动作自然结束或 finish() 时是否恢复执行前捕获的参数值。
## [br]
## @api public
var restore_initial_value_on_finish: bool = false


# --- 私有变量 ---

var _active_tween: Tween = null
var _active_material: ShaderMaterial = null
var _initial_value: Variant = null
var _has_initial_value: bool = false


# --- Godot 生命周期方法 ---

func _init(
	p_target: Object = null,
	p_parameter_name: StringName = &"",
	p_target_value: Variant = null,
	p_duration: float = 0.2,
	p_host_node: Node = null
) -> void:
	target = p_target
	parameter_name = p_parameter_name
	target_value = p_target_value
	duration = maxf(p_duration, 0.0)
	host_node = p_host_node


# --- 公共方法 ---

## 执行 Shader 参数写入或 Tween。
## [br]
## @api public
## [br]
## @return 需要等待时返回内部完成 Signal；目标、材质或参数无效时返回 null。
## [br]
## @schema return: Variant，返回内部完成 Signal 或 null。
func execute() -> Variant:
	_clear_active_tween()
	_reset_completion_state()
	_active_material = _resolve_shader_material()
	if _active_material == null or not _has_shader_parameter(_active_material):
		return null

	_capture_initial_value()
	if duration <= 0.0:
		_set_shader_parameter(target_value)
		_restore_initial_value_on_finish()
		return null

	if not _can_tween_parameter_value():
		return null

	var tween_host: Node = _get_tween_host()
	if tween_host == null:
		push_warning("[GFShaderParameterAction] 缺少有效 Tween 宿主节点。")
		return null

	_active_tween = tween_host.create_tween()
	var tweener: MethodTweener = _active_tween.tween_method(
		Callable(self, "_set_shader_parameter"),
		_initial_value,
		target_value,
		duration
	)
	var _set_ease_result_128: Variant = tweener.set_trans(transition_type).set_ease(ease_type)
	var _finished_connected: Error = _active_tween.finished.connect(
		_on_active_tween_finished,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return _action_completed


## 取消当前 Tween，并按配置恢复参数值。
## [br]
## @api public
func cancel() -> void:
	_clear_active_tween()
	_restore_initial_value_on_cancel()
	_emit_completed_once()


## 暂停当前 Tween。
## [br]
## @api public
func pause() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.pause()


## 恢复当前 Tween。
## [br]
## @api public
func resume() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.play()


## 立即完成当前 Tween，并按配置恢复参数值。
## [br]
## @api public
func finish() -> void:
	if is_instance_valid(_active_tween):
		var _custom_step_result_165: Variant = _active_tween.custom_step(INF)
	_clear_active_tween()
	_restore_initial_value_on_finish()
	_emit_completed_once()


## 获取用于保护等待生命周期的 Tween 宿主节点。
## [br]
## @api public
## [br]
## @return 有效宿主节点；无效时返回 null。
func get_wait_guard_node() -> Node:
	var tween_host: Node = _get_tween_host()
	return tween_host if is_instance_valid(tween_host) else null


# --- 私有/辅助方法 ---

func _clear_active_tween() -> void:
	if is_instance_valid(_active_tween):
		if _active_tween.finished.is_connected(_on_active_tween_finished):
			_active_tween.finished.disconnect(_on_active_tween_finished)
		_active_tween.kill()
	_active_tween = null


func _resolve_shader_material() -> ShaderMaterial:
	if target is ShaderMaterial:
		return _get_shader_material_value(target)
	if not is_instance_valid(target):
		return null
	if material_property.is_empty():
		push_warning("[GFShaderParameterAction] 材质属性路径为空。")
		return null
	if not _has_target_property_path():
		push_warning("[GFShaderParameterAction] 目标材质属性不存在：%s。" % String(material_property))
		return null

	var material_value: Variant = target.get_indexed(material_property)
	if not (material_value is ShaderMaterial):
		push_warning("[GFShaderParameterAction] 目标材质属性不是 ShaderMaterial：%s。" % String(material_property))
		return null

	var material: ShaderMaterial = _get_shader_material_value(material_value)
	if duplicate_material_on_execute:
		var duplicated_value: Variant = material.duplicate(true)
		if duplicated_value is ShaderMaterial:
			var duplicated_material: ShaderMaterial = _get_shader_material_value(duplicated_value)
			target.set_indexed(material_property, duplicated_material)
			return duplicated_material
	return material


func _has_shader_parameter(material: ShaderMaterial) -> bool:
	if parameter_name == &"":
		push_warning("[GFShaderParameterAction] Shader 参数名为空。")
		return false
	if material.shader == null:
		push_warning("[GFShaderParameterAction] ShaderMaterial 缺少 Shader。")
		return false

	for uniform_value: Variant in material.shader.get_shader_uniform_list():
		if not (uniform_value is Dictionary):
			continue
		var uniform: Dictionary = uniform_value
		if GFVariantData.get_option_string(uniform, "name") == String(parameter_name):
			return true

	push_warning("[GFShaderParameterAction] Shader 参数不存在：%s。" % String(parameter_name))
	return false


func _capture_initial_value() -> void:
	_initial_value = GFVariantData.duplicate_variant(_active_material.get_shader_parameter(parameter_name))
	_has_initial_value = true


func _can_tween_parameter_value() -> bool:
	if not _has_initial_value:
		return false
	if _values_are_tween_compatible(_initial_value, target_value):
		return true
	push_warning("[GFShaderParameterAction] Shader 参数值类型不兼容：%s。" % String(parameter_name))
	return false


func _set_shader_parameter(value: Variant) -> void:
	if _active_material == null:
		return
	_active_material.set_shader_parameter(parameter_name, value)


func _restore_initial_value_on_cancel() -> void:
	if restore_initial_value_on_cancel:
		_restore_initial_value()


func _restore_initial_value_on_finish() -> void:
	if restore_initial_value_on_finish:
		_restore_initial_value()


func _restore_initial_value() -> void:
	if _active_material == null or not _has_initial_value:
		return
	_active_material.set_shader_parameter(parameter_name, GFVariantData.duplicate_variant(_initial_value))


func _get_tween_host() -> Node:
	if is_instance_valid(host_node):
		return host_node
	if target is Node and is_instance_valid(target):
		return _get_node_value(target)
	return null


func _has_target_property_path() -> bool:
	var base_name: String = _get_property_base_name(material_property)
	if base_name.is_empty():
		return false

	for property: Dictionary in target.get_property_list():
		if GFVariantData.get_option_string(property, "name") == base_name:
			return true
	return false


func _get_property_base_name(path: NodePath) -> String:
	if path.get_name_count() > 0:
		return String(path.get_name(0))

	var text: String = String(path)
	var separator_index: int = text.find(":")
	if separator_index >= 0:
		text = text.substr(0, separator_index)
	return text


func _values_are_tween_compatible(current_value: Variant, next_value: Variant) -> bool:
	if _is_numeric_value(current_value) and _is_numeric_value(next_value):
		return true
	if current_value is Vector2 and next_value is Vector2:
		return true
	if current_value is Vector3 and next_value is Vector3:
		return true
	if current_value is Vector4 and next_value is Vector4:
		return true
	if current_value is Color and next_value is Color:
		return true
	return false


func _is_numeric_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _get_node_value(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _get_shader_material_value(value: Variant) -> ShaderMaterial:
	if value is ShaderMaterial:
		var material: ShaderMaterial = value
		return material
	return null


# --- 信号处理函数 ---

func _on_active_tween_finished() -> void:
	_active_tween = null
	_restore_initial_value_on_finish()
	_emit_completed_once()
