## GFMoveTweenAction: 通用节点移动 Tween 动作。
##
## 将目标节点的指定位置属性缓动到目标值，适合卡牌、棋子、UI 面板等
## 常见表现动作。默认等待 Tween 完成后队列才会继续。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFMoveTweenAction
extends GFVisualAction


# --- 公共变量 ---

## 被移动的目标节点。
## [br]
## @api public
var target: Node

## 要写入的位置值，通常为 Vector2 或 Vector3。
## [br]
## @api public
## [br]
## @schema target_position: Variant，可写入 property_name 的目标位置值，通常为 Vector2、Vector3 或 float。
var target_position: Variant

## Tween 持续时间。
## [br]
## @api public
## [br]
## @since 3.17.0
var duration: float:
	get:
		return _duration
	set(value):
		_duration = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(value)

## 要缓动的属性名。
## [br]
## @api public
var property_name: NodePath = ^"position"

## Tween 过渡类型。
## [br]
## @api public
var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

## Tween 缓动类型。
## [br]
## @api public
var ease_type: Tween.EaseType = Tween.EASE_OUT


# --- 私有变量 ---

## 当前驱动属性缓动的 Tween。
## [br]
## @api private
var _active_tween: Tween = null

## 经时间策略归一化后的 Tween 时长。
## [br]
## @api private
var _duration: float = 0.2


# --- Godot 生命周期方法 ---

func _init(
	p_target: Node = null,
	p_target_position: Variant = null,
	p_duration: float = 0.2,
	p_property_name: NodePath = ^"position"
) -> void:
	target = p_target
	target_position = p_target_position
	duration = p_duration
	property_name = p_property_name


# --- 公共方法 ---

## 执行移动 Tween。
## [br]
## @api public
## [br]
## @return 需要等待时返回内部完成 Signal；目标无效、配置无效或瞬时写入时返回 null。
## [br]
## @schema return: Variant，返回内部完成 Signal 或 null。
func execute() -> Variant:
	if not is_instance_valid(target):
		return null

	_clear_active_tween()
	_reset_completion_state()
	if not _can_tween_target_property():
		return null

	if duration <= 0.0:
		target.set_indexed(property_name, target_position)
		return null
	if not target.is_inside_tree():
		push_warning("[GFMoveTweenAction][move_tween_action.target_outside_tree] Cannot create a Tween: the target node is outside the scene tree.")
		return null

	_active_tween = target.create_tween()
	var _set_ease_result_92: Variant = _active_tween.tween_property(target, property_name, target_position, duration).set_trans(transition_type).set_ease(ease_type)
	var _finished_connected: Error = _active_tween.finished.connect(
		_on_active_tween_finished,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return _action_completed


## 取消当前 Tween 并释放等待者。
## [br]
## @api public
func cancel() -> void:
	_clear_active_tween()
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


## 立即推进并完成当前 Tween。
## [br]
## @api public
func finish() -> void:
	if is_instance_valid(_active_tween):
		_clear_active_tween()
		if is_instance_valid(target):
			target.set_indexed(property_name, target_position)
		_emit_completed_once()
		return
	_clear_active_tween()
	_emit_completed_once()


## 获取用于保护等待生命周期的目标节点。
## [br]
## @api public
## [br]
## @return 有效目标节点；无效时返回 null。
func get_wait_guard_node() -> Node:
	return target if is_instance_valid(target) else null


# --- 私有/辅助方法 ---

## 断开当前 Tween 的完成回调、终止 Tween 并清空引用。
## [br]
## @api private
func _clear_active_tween() -> void:
	if is_instance_valid(_active_tween):
		if _active_tween.finished.is_connected(_on_active_tween_finished):
			_active_tween.finished.disconnect(_on_active_tween_finished)
		_active_tween.kill()
	_active_tween = null


## 检查目标属性路径存在且当前值与目标值属于支持的缓动类型。
## 检查失败时按具体原因发出警告。
## [br]
## @api private
func _can_tween_target_property() -> bool:
	if not _has_target_property_path():
		push_warning("[GFMoveTweenAction][move_tween_action.missing_property] Target property does not exist: %s." % String(property_name))
		return false

	var current_value: Variant = target.get_indexed(property_name)
	if current_value == null:
		push_warning("[GFMoveTweenAction][move_tween_action.missing_property] Target property does not exist: %s." % String(property_name))
		return false
	if _values_are_tween_compatible(current_value, target_position):
		return true

	push_warning("[GFMoveTweenAction][move_tween_action.incompatible_property_value] Target property and value types are incompatible: %s." % String(property_name))
	return false


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


## 通过目标属性列表确认 NodePath 根属性名称存在。
## [br]
## @api private
func _has_target_property_path() -> bool:
	var base_name: String = _get_property_base_name(property_name)
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


# --- 信号处理函数 ---

## Tween 完成后清空活动句柄并释放动作等待者。
## [br]
## @api private
func _on_active_tween_finished() -> void:
	_active_tween = null
	_emit_completed_once()
