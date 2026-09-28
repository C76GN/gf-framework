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
## [br]
## @since 4.2.0
var duration: float:
	get:
		return _duration
	set(value):
		_duration = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(value)

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

## 当前驱动参数缓动的 Tween。
## [br]
## @api private
var _active_tween: Tween = null

## 本次执行实际写入的 ShaderMaterial。
## [br]
## @api private
var _active_material: ShaderMaterial = null

## 本次执行冻结的 uniform 参数名。
## [br]
## @api private
var _active_parameter_name: StringName = &""

## 本次执行冻结的目标参数值。
## [br]
## @api private
var _active_target_value: Variant = null

## 经时间策略归一化后的 Tween 时长。
## [br]
## @api private
var _duration: float = 0.2

## 本次执行捕获的参数初始值。
## [br]
## @api private
var _initial_value: Variant = null

## 标记本次执行是否取得可恢复的初始值。
## [br]
## @api private
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
	duration = p_duration
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
	_active_material = null
	_active_parameter_name = &""
	_active_target_value = null
	var execution_parameter_name: StringName = parameter_name
	var execution_target_value: Variant = GFVariantData.duplicate_variant(
		target_value
	)
	var source_material: ShaderMaterial = _resolve_shader_material()
	if (
		source_material == null
		or not _accepts_shader_parameter(
			source_material,
			execution_parameter_name,
			execution_target_value
		)
	):
		return null

	_active_parameter_name = execution_parameter_name
	_active_target_value = execution_target_value
	_capture_initial_value(source_material)
	var tween_host: Node = null
	if duration > 0.0:
		if not _can_tween_parameter_value():
			return null
		tween_host = _get_tween_host()
		if tween_host == null:
			push_warning("[GFShaderParameterAction][shader_parameter_action.missing_host] Cannot start playback: a valid host node is required.")
			return null

	_active_material = _activate_shader_material(source_material)
	if _active_material == null:
		return null
	if duration <= 0.0:
		_set_shader_parameter(_active_target_value)
		_restore_initial_value_on_finish()
		return null

	_active_tween = tween_host.create_tween()
	var tweener: MethodTweener = _active_tween.tween_method(
		Callable(self, "_set_shader_parameter"),
		_initial_value,
		_active_target_value,
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
		_clear_active_tween()
		_set_shader_parameter(_active_target_value)
		_restore_initial_value_on_finish()
		_emit_completed_once()
		return
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

## 断开当前 Tween 的完成回调、终止 Tween 并清空句柄。
## [br]
## @api private
func _clear_active_tween() -> void:
	if is_instance_valid(_active_tween):
		if _active_tween.finished.is_connected(_on_active_tween_finished):
			_active_tween.finished.disconnect(_on_active_tween_finished)
		_active_tween.kill()
	_active_tween = null


## 从 target 本身或 material_property 解析 ShaderMaterial，并报告无效属性路径。
## [br]
## @api private
func _resolve_shader_material() -> ShaderMaterial:
	if target is ShaderMaterial:
		return _get_shader_material_value(target)
	if not is_instance_valid(target):
		return null
	if material_property.is_empty():
		push_warning("[GFShaderParameterAction][shader_parameter_action.empty_material_property] Material property path is empty.")
		return null
	if not _has_target_property_path():
		push_warning("[GFShaderParameterAction][shader_parameter_action.missing_material_property] Target material property does not exist: %s." % String(material_property))
		return null

	var material_value: Variant = target.get_indexed(material_property)
	if not (material_value is ShaderMaterial):
		push_warning("[GFShaderParameterAction][shader_parameter_action.invalid_material_property] Target material property is not a ShaderMaterial: %s." % String(material_property))
		return null

	return _get_shader_material_value(material_value)


## 按配置选择原材质，或深复制并写回目标属性作为本次执行材质。
## [br]
## @api private
func _activate_shader_material(material: ShaderMaterial) -> ShaderMaterial:
	if not duplicate_material_on_execute or target is ShaderMaterial:
		return material
	var duplicated_value: Variant = material.duplicate(true)
	if not (duplicated_value is ShaderMaterial):
		push_warning("[GFShaderParameterAction][shader_parameter_action.material_duplicate_failed] Could not duplicate the ShaderMaterial.")
		return null
	var duplicated_material: ShaderMaterial = _get_shader_material_value(duplicated_value)
	target.set_indexed(material_property, duplicated_material)
	return duplicated_material


## 验证参数名非空、材质存在 Shader、uniform 已声明且目标值符合接口类型。
## [br]
## @api private
func _accepts_shader_parameter(
	material: ShaderMaterial,
	execution_parameter_name: StringName,
	execution_target_value: Variant
) -> bool:
	if execution_parameter_name == &"":
		push_warning("[GFShaderParameterAction][shader_parameter_action.empty_parameter_name] Shader parameter name is empty.")
		return false
	if material.shader == null:
		push_warning("[GFShaderParameterAction][shader_parameter_action.missing_shader] ShaderMaterial has no Shader.")
		return false

	var interface_snapshot: GFShaderInterfaceSnapshot = (
		GFShaderInterfaceSnapshot.capture(material.shader)
	)
	if (
		interface_snapshot == null
		or not interface_snapshot.has_uniform(execution_parameter_name)
	):
		push_warning(
			"[GFShaderParameterAction][shader_parameter_action.missing_parameter] Shader parameter does not exist: %s."
			% String(execution_parameter_name)
		)
		return false
	if not interface_snapshot.accepts_parameter_value(
		execution_parameter_name,
		execution_target_value
	):
		push_warning(
			"[GFShaderParameterAction][shader_parameter_action.parameter_declaration_mismatch] Shader parameter value does not match its declared type: %s."
			% String(execution_parameter_name)
		)
		return false
	return true


## 复制材质当前参数值到恢复快照并标记快照有效。
## [br]
## @api private
func _capture_initial_value(material: ShaderMaterial) -> void:
	_initial_value = GFVariantData.duplicate_variant(
		material.get_shader_parameter(_active_parameter_name)
	)
	_has_initial_value = true


## 要求已捕获初值且初值与目标值属于受支持的 Tween 类型。
## [br]
## @api private
func _can_tween_parameter_value() -> bool:
	if not _has_initial_value:
		return false
	if _values_are_tween_compatible(_initial_value, _active_target_value):
		return true
	push_warning(
		"[GFShaderParameterAction][shader_parameter_action.incompatible_parameter_value] Shader parameter value types are incompatible: %s."
		% String(_active_parameter_name)
	)
	return false


## 当前执行材质有效时，将值写入冻结的 uniform 参数。
## [br]
## @api private
func _set_shader_parameter(value: Variant) -> void:
	if _active_material == null:
		return
	_active_material.set_shader_parameter(_active_parameter_name, value)


## 仅在取消恢复选项启用时调用初值恢复。
## [br]
## @api private
func _restore_initial_value_on_cancel() -> void:
	if restore_initial_value_on_cancel:
		_restore_initial_value()


## 仅在完成恢复选项启用时调用初值恢复。
## [br]
## @api private
func _restore_initial_value_on_finish() -> void:
	if restore_initial_value_on_finish:
		_restore_initial_value()


## 活动材质和初值均有效时，将初值的复制写回 uniform 参数。
## [br]
## @api private
func _restore_initial_value() -> void:
	if _active_material == null or not _has_initial_value:
		return
	_active_material.set_shader_parameter(
		_active_parameter_name,
		GFVariantData.duplicate_variant(_initial_value)
	)


## 优先返回有效且在树内的显式宿主，否则尝试把 Node target 用作宿主。
## [br]
## @api private
func _get_tween_host() -> Node:
	if is_instance_valid(host_node) and host_node.is_inside_tree():
		return host_node
	if target is Node and is_instance_valid(target):
		var target_node: Node = _get_node_value(target)
		if target_node != null and target_node.is_inside_tree():
			return target_node
	return null


## 通过目标对象属性列表确认材质 NodePath 根属性名称存在。
## [br]
## @api private
func _has_target_property_path() -> bool:
	var base_name: String = _get_property_base_name(material_property)
	if base_name.is_empty():
		return false

	for property: Dictionary in target.get_property_list():
		if GFVariantData.get_option_string(property, "name") == base_name:
			return true
	return false


## 优先取 NodePath 首个名称段；没有名称段时截取冒号前的属性文本。
## [br]
## @api private
func _get_property_base_name(path: NodePath) -> String:
	if path.get_name_count() > 0:
		return String(path.get_name(0))

	var text: String = String(path)
	var separator_index: int = text.find(":")
	if separator_index >= 0:
		text = text.substr(0, separator_index)
	return text


## 接受整数与浮点数混合，或两端同为 Vector2、Vector3、Vector4 或 Color。
## [br]
## @api private
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


## 判断值类型是否为整数或浮点数。
## [br]
## @api private
func _is_numeric_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## 将 Variant 收窄为 Node；类型不符时返回 null。
## [br]
## @api private
func _get_node_value(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


## 将 Variant 收窄为 ShaderMaterial；类型不符时返回 null。
## [br]
## @api private
func _get_shader_material_value(value: Variant) -> ShaderMaterial:
	if value is ShaderMaterial:
		var material: ShaderMaterial = value
		return material
	return null


# --- 信号处理函数 ---

## Tween 结束后清空句柄、按配置恢复参数并通知等待者。
## [br]
## @api private
func _on_active_tween_finished() -> void:
	_active_tween = null
	_restore_initial_value_on_finish()
	_emit_completed_once()
