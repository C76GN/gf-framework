## GFDragSession: 通用拖拽会话数据。
##
## 描述一次拖拽从开始到释放的稳定上下文，不绑定具体 UI、背包、棋盘、
## 关卡编辑器或任何业务对象。项目可把任意 payload 放入会话，再由落点规则解释。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFDragSession
extends RefCounted


# --- 公共变量 ---

## 会话 ID，由 GFDragDropUtility 分配。
## [br]
## @api public
var session_id: int = -1

## 拖拽类型。落点可用它做通用接收过滤。
## [br]
## @api public
var drag_type: StringName = &""

## 项目自定义载荷。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema payload: Variant，透传给 drop zone 的项目侧拖拽载荷。
var payload: Variant = null

## 起始位置，通常是屏幕或画布坐标。
## [br]
## @api public
var start_position: Vector2 = Vector2.ZERO

## 当前指针位置。
## [br]
## @api public
var current_position: Vector2 = Vector2.ZERO

## 上一次位置。
## [br]
## @api public
var previous_position: Vector2 = Vector2.ZERO

## 项目自定义元数据。框架只负责复制和透传。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，复制到拖拽会话中的项目侧元数据。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _source_ref: WeakRef = null


# --- 公共方法 ---

## 初始化会话。
## [br]
## @param new_session_id: 会话 ID。
## [br]
## @param new_drag_type: 拖拽类型。
## [br]
## @param new_payload: 项目自定义载荷。
## [br]
## @param position: 起始位置。
## [br]
## @param source: 可选来源对象。
## [br]
## @param new_metadata: 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema new_payload: Variant，透传给 drop zone 的项目侧拖拽载荷。
## [br]
## @schema new_metadata: Dictionary，复制到拖拽会话中的项目侧元数据。
func setup(
	new_session_id: int,
	new_drag_type: StringName,
	new_payload: Variant,
	position: Vector2,
	source: Object = null,
	new_metadata: Dictionary = {}
) -> void:
	session_id = new_session_id
	drag_type = new_drag_type
	payload = new_payload
	start_position = position
	current_position = position
	previous_position = position
	_source_ref = weakref(source) if is_instance_valid(source) else null
	metadata = new_metadata.duplicate(true)


## 更新当前拖拽位置。
## [br]
## @api public
## [br]
## @param position: 新位置。
func update_position(position: Vector2) -> void:
	previous_position = current_position
	current_position = position


## 获取本次更新的位移。
## [br]
## @api public
## [br]
## @return 当前和上一次位置的差值。
func get_delta() -> Vector2:
	return current_position - previous_position


## 获取来源对象。
## [br]
## @api public
## [br]
## @return 来源仍有效时返回对象，否则返回 null。
func get_source() -> Object:
	if _source_ref == null:
		return null
	var source: Object = _get_object(_source_ref.get_ref())
	return source if is_instance_valid(source) else null


## 转换为调试字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param json_compatible: 为 true 时返回可直接 JSON.stringify() 的值。
## [br]
## @return 会话快照。
## [br]
## @schema return: Dictionary，包含 session_id、drag_type、start_position、current_position、previous_position、delta、has_source 和 metadata。
func to_dictionary(json_compatible: bool = true) -> Dictionary:
	var source: Object = get_source()
	var result: Dictionary = {
		"session_id": session_id,
		"drag_type": drag_type,
		"start_position": start_position,
		"current_position": current_position,
		"previous_position": previous_position,
		"delta": get_delta(),
		"has_source": source != null,
		"metadata": metadata.duplicate(true),
	}
	if json_compatible:
		var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(result)
		if encoded is Dictionary:
			var encoded_dictionary: Dictionary = encoded
			return encoded_dictionary
	return result


# --- 私有/辅助方法 ---

func _get_object(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null
