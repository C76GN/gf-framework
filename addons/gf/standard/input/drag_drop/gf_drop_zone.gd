## GFDropZone: 通用拖拽落点规则。
##
## 落点只描述“某个位置是否命中、某个会话是否可接收、接收时如何返回结果”。
## 它不移动节点、不修改业务数据，也不规定任何具体 UI 或玩法语义。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFDropZone
extends RefCounted


# --- 公共变量 ---

## 落点 ID。
## [br]
## @api public
var zone_id: StringName = &""

## 可接收的拖拽类型。为空表示不限制类型。
## [br]
## @api public
var accepted_types: PackedStringArray = PackedStringArray()

## 匹配优先级。数值越大越优先。
## [br]
## @api public
var priority: int = 0

## 是否启用。
## [br]
## @api public
var enabled: bool = true

## 命中检测回调，签名为 func(position: Variant, session: GFDragSession) -> bool。
## [br]
## @api public
var contains_callable: Callable = Callable()

## 可接收检测回调，签名为 func(session: GFDragSession, zone: GFDropZone) -> bool。
## [br]
## @api public
var can_accept_callable: Callable = Callable()

## 接收回调，签名为 func(session: GFDragSession, zone: GFDropZone, position: Variant) -> Variant。
## [br]
## @api public
var drop_callable: Callable = Callable()

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，关联到 drop zone 的项目侧元数据。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _control_ref: WeakRef = null


# --- 公共方法 ---

## 检查落点是否包含位置。
## [br]
## @api public
## [br]
## @param position: 位置，通常是屏幕或画布坐标。
## [br]
## @param session: 当前拖拽会话。
## [br]
## @return 命中时返回 true。
## [br]
## @schema position: Variant，zone contains 回调接受的位置值。
func contains(position: Variant, session: GFDragSession) -> bool:
	if not enabled:
		return false
	if contains_callable.is_valid():
		return GFVariantData.to_bool(contains_callable.call(position, session))
	return false


## 检查落点是否接收会话。
## [br]
## @api public
## [br]
## @param session: 当前拖拽会话。
## [br]
## @return 可接收时返回 true。
func can_accept(session: GFDragSession) -> bool:
	if not enabled or session == null:
		return false
	if not _accepts_type(session.drag_type):
		return false
	if can_accept_callable.is_valid():
		return GFVariantData.to_bool(can_accept_callable.call(session, self))
	return true


## 执行落点接收回调。
## [br]
## @api public
## [br]
## @param session: 当前拖拽会话。
## [br]
## @param position: 释放位置。
## [br]
## @return 回调返回值；未设置回调时返回成功字典。
## [br]
## @schema position: Variant release position passed to the drop callback.
## [br]
## @schema return: Variant，由 drop 回调返回；Dictionary 会由 GFDragDropUtility 规范化。
func drop(session: GFDragSession, position: Variant) -> Variant:
	if drop_callable.is_valid():
		return drop_callable.call(session, self, position)
	return {
		"ok": true,
		"zone_id": zone_id,
	}


## 转换为调试字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param json_compatible: 为 true 时返回可直接 JSON.stringify() 的值。
## [br]
## @return 落点快照。
## [br]
## @schema return: Dictionary，包含 zone_id、accepted_types、priority、enabled、回调标记和 metadata。
func to_dictionary(json_compatible: bool = true) -> Dictionary:
	var result: Dictionary = {
		"zone_id": zone_id,
		"accepted_types": accepted_types,
		"priority": priority,
		"enabled": enabled,
		"has_contains_callable": contains_callable.is_valid(),
		"has_can_accept_callable": can_accept_callable.is_valid(),
		"has_drop_callable": drop_callable.is_valid(),
		"metadata": metadata.duplicate(true),
	}
	if json_compatible:
		var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(result)
		if encoded is Dictionary:
			var encoded_dictionary: Dictionary = encoded
			return encoded_dictionary
	return result


## 检查落点是否引用了已经失效的对象。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 引用对象失效时返回 true。
func is_stale() -> bool:
	if _control_ref == null:
		return false
	return _get_live_control_from_ref(_control_ref) == null


## 创建矩形落点。
## [br]
## @api public
## [br]
## @param new_zone_id: 落点 ID。
## [br]
## @param rect: 全局矩形区域。
## [br]
## @param new_accepted_types: 可接收类型；为空表示不限制。
## [br]
## @param options: 可选参数，支持 priority、enabled、metadata、can_accept、drop。
## [br]
## @return 新落点。
## [br]
## @schema options: Dictionary，包含 priority: int、enabled: bool、metadata: Dictionary、can_accept: Callable 和 drop: Callable。
static func from_rect(
	new_zone_id: StringName,
	rect: Rect2,
	new_accepted_types: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFDropZone:
	var zone: GFDropZone = GFDropZone.new()
	zone.zone_id = new_zone_id
	zone.accepted_types = new_accepted_types
	zone.priority = GFVariantData.get_option_int(options, "priority", 0)
	zone.enabled = GFVariantData.get_option_bool(options, "enabled", true)
	zone.metadata = GFVariantData.get_option_dictionary(options, "metadata")
	zone.can_accept_callable = _get_option_callable(options, "can_accept")
	zone.drop_callable = _get_option_callable(options, "drop")
	zone.contains_callable = func(position: Variant, _session: GFDragSession) -> bool:
		if typeof(position) != TYPE_VECTOR2:
			return false
		var local_position: Vector2 = position
		return rect.has_point(local_position)
	return zone


## 创建 Control 全局矩形落点。
## [br]
## @api public
## [br]
## @param new_zone_id: 落点 ID。
## [br]
## @param control: 用于读取 get_global_rect() 的 Control。
## [br]
## @param new_accepted_types: 可接收类型；为空表示不限制。
## [br]
## @param options: 可选参数，支持 priority、enabled、metadata、can_accept、drop。
## [br]
## @return 新落点。
## [br]
## @schema options: Dictionary，包含 priority: int、enabled: bool、metadata: Dictionary、can_accept: Callable 和 drop: Callable。
static func from_control(
	new_zone_id: StringName,
	control: Control,
	new_accepted_types: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFDropZone:
	var zone: GFDropZone = GFDropZone.new()
	zone.zone_id = new_zone_id
	zone.accepted_types = new_accepted_types
	zone.priority = GFVariantData.get_option_int(options, "priority", 0)
	zone.enabled = GFVariantData.get_option_bool(options, "enabled", true)
	zone.metadata = GFVariantData.get_option_dictionary(options, "metadata")
	zone.can_accept_callable = _get_option_callable(options, "can_accept")
	zone.drop_callable = _get_option_callable(options, "drop")
	var control_ref: WeakRef = weakref(control) if is_instance_valid(control) else null
	zone._control_ref = control_ref
	zone.contains_callable = func(position: Variant, _session: GFDragSession) -> bool:
		if typeof(position) != TYPE_VECTOR2 or control_ref == null:
			return false
		var local_position: Vector2 = position
		var current: Control = GFDropZone._get_live_control_from_ref(control_ref)
		if current == null:
			return false
		if not current.is_inside_tree() or not current.is_visible_in_tree():
			return false
		if not GFDropZone._control_accepts_pointer(current):
			return false
		return current.get_global_rect().has_point(local_position)
	return zone


# --- 私有/辅助方法 ---

func _accepts_type(drag_type: StringName) -> bool:
	if accepted_types.is_empty():
		return true
	return accepted_types.has(String(drag_type))


static func _get_option_callable(options: Dictionary, key: Variant) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, key, Callable())
	if value is Callable:
		var callable: Callable = value
		return callable
	return Callable()


static func _get_live_control_from_ref(control_ref: WeakRef) -> Control:
	if control_ref == null:
		return null
	var value: Variant = control_ref.get_ref()
	if not (value is Control):
		return null
	if not is_instance_valid(value):
		return null
	var control: Control = value
	return control


static func _control_accepts_pointer(control: Control) -> bool:
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if control is BaseButton:
		var button: BaseButton = control
		return not button.disabled
	return true
