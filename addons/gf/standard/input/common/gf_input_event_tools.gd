# GFInputEventTools: 标准输入模块内部 InputEvent 辅助。
#
# 集中承载 InputEvent 子类收窄和复制逻辑，避免格式化、运行时和触控模块重复实现同一语义。
extends RefCounted


# --- 常量 ---

const _EVENT_CLASS_FIELD: String = "event_class"
const _EVENT_PROPERTIES_FIELD: String = "properties"
const _LEGACY_EVENT_FIELD: String = "event"

const _ALLOWED_INPUT_EVENT_CLASSES: Dictionary = {
	"InputEventAction": true,
	"InputEventJoypadButton": true,
	"InputEventJoypadMotion": true,
	"InputEventKey": true,
	"InputEventMIDI": true,
	"InputEventMagnifyGesture": true,
	"InputEventMouseButton": true,
	"InputEventMouseMotion": true,
	"InputEventPanGesture": true,
	"InputEventScreenDrag": true,
	"InputEventScreenTouch": true,
}

const _SKIPPED_EVENT_PROPERTIES: Dictionary = {
	"resource_local_to_scene": true,
	"resource_name": true,
	"resource_path": true,
	"script": true,
}


# --- 公共方法 ---

## 复制输入事件，并在复制失败或类型不匹配时返回 null。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param event: 输入事件。
## [br]
## @return 输入事件副本。
static func duplicate_input_event(event: InputEvent) -> InputEvent:
	if event == null:
		return null

	var duplicated: Resource = event.duplicate(true)
	return get_input_event(duplicated)


## 将输入事件转换为可写入配置或存档的记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param event: 输入事件；null 表示显式解绑。
## [br]
## @return 事件记录。
## [br]
## @schema return: Dictionary with unbound, event_class, and properties fields.
static func input_event_to_record(event: InputEvent) -> Dictionary:
	if event == null:
		return {"unbound": true}

	var event_class: String = event.get_class()
	if not _ALLOWED_INPUT_EVENT_CLASSES.has(event_class):
		return {"unbound": true}

	return {
		"unbound": false,
		_EVENT_CLASS_FIELD: event_class,
		_EVENT_PROPERTIES_FIELD: _event_properties_to_record(event),
	}


## 从事件记录恢复输入事件。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param record: 事件记录。
## [br]
## @schema record: Dictionary created by input_event_to_record(), or legacy dictionary with event text.
## [br]
## @return 输入事件；显式解绑或记录无效时返回 null。
static func input_event_from_record(record: Dictionary) -> InputEvent:
	if is_event_record_unbound(record):
		return null

	var event_class: String = GFVariantData.get_option_string(record, _EVENT_CLASS_FIELD)
	if not event_class.is_empty():
		return _event_from_structured_record(event_class, record)

	var event_text: String = GFVariantData.get_option_string(record, _LEGACY_EVENT_FIELD)
	if event_text.is_empty():
		return null
	var value: Variant = str_to_var(event_text)
	var event: InputEvent = get_input_event(value)
	if event == null or not _ALLOWED_INPUT_EVENT_CLASSES.has(event.get_class()):
		return null
	return event


## 判断事件记录是否表示显式解绑。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param record: 事件记录。
## [br]
## @schema record: Dictionary input event record.
## [br]
## @return 记录明确为 unbound 时返回 true。
static func is_event_record_unbound(record: Dictionary) -> bool:
	return GFVariantData.get_option_bool(record, "unbound")


## 将 Variant 收窄为 InputEvent。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEvent 或其派生事件对象。
## [br]
## @return 输入事件或 null。
static func get_input_event(value: Variant) -> InputEvent:
	if value is InputEvent:
		var event: InputEvent = value
		return event
	return null


## 将 Variant 收窄为 InputEventAction。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventAction 对象。
## [br]
## @return 输入事件或 null。
static func get_action_event(value: Variant) -> InputEventAction:
	if value is InputEventAction:
		var event: InputEventAction = value
		return event
	return null


## 将 Variant 收窄为 InputEventKey。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventKey 对象。
## [br]
## @return 输入事件或 null。
static func get_key_event(value: Variant) -> InputEventKey:
	if value is InputEventKey:
		var event: InputEventKey = value
		return event
	return null


## 将 Variant 收窄为 InputEventMouseButton。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventMouseButton 对象。
## [br]
## @return 输入事件或 null。
static func get_mouse_button_event(value: Variant) -> InputEventMouseButton:
	if value is InputEventMouseButton:
		var event: InputEventMouseButton = value
		return event
	return null


## 将 Variant 收窄为 InputEventMouseMotion。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventMouseMotion 对象。
## [br]
## @return 输入事件或 null。
static func get_mouse_motion_event(value: Variant) -> InputEventMouseMotion:
	if value is InputEventMouseMotion:
		var event: InputEventMouseMotion = value
		return event
	return null


## 将 Variant 收窄为 InputEventMagnifyGesture。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventMagnifyGesture 对象。
## [br]
## @return 输入事件或 null。
static func get_magnify_gesture_event(value: Variant) -> InputEventMagnifyGesture:
	if value is InputEventMagnifyGesture:
		var event: InputEventMagnifyGesture = value
		return event
	return null


## 将 Variant 收窄为 InputEventPanGesture。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventPanGesture 对象。
## [br]
## @return 输入事件或 null。
static func get_pan_gesture_event(value: Variant) -> InputEventPanGesture:
	if value is InputEventPanGesture:
		var event: InputEventPanGesture = value
		return event
	return null


## 将 Variant 收窄为 InputEventJoypadButton。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventJoypadButton 对象。
## [br]
## @return 输入事件或 null。
static func get_joypad_button_event(value: Variant) -> InputEventJoypadButton:
	if value is InputEventJoypadButton:
		var event: InputEventJoypadButton = value
		return event
	return null


## 将 Variant 收窄为 InputEventJoypadMotion。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventJoypadMotion 对象。
## [br]
## @return 输入事件或 null。
static func get_joypad_motion_event(value: Variant) -> InputEventJoypadMotion:
	if value is InputEventJoypadMotion:
		var event: InputEventJoypadMotion = value
		return event
	return null


## 将 Variant 收窄为 InputEventScreenTouch。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventScreenTouch 对象。
## [br]
## @return 输入事件或 null。
static func get_screen_touch_event(value: Variant) -> InputEventScreenTouch:
	if value is InputEventScreenTouch:
		var event: InputEventScreenTouch = value
		return event
	return null


## 将 Variant 收窄为 InputEventScreenDrag。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param value: 待收窄值。
## [br]
## @schema value: InputEventScreenDrag 对象。
## [br]
## @return 输入事件或 null。
static func get_screen_drag_event(value: Variant) -> InputEventScreenDrag:
	if value is InputEventScreenDrag:
		var event: InputEventScreenDrag = value
		return event
	return null


# --- 私有/辅助方法 ---

static func _event_from_structured_record(event_class: String, record: Dictionary) -> InputEvent:
	if not _ALLOWED_INPUT_EVENT_CLASSES.has(event_class):
		return null
	if not ClassDB.can_instantiate(event_class):
		return null

	var event: InputEvent = get_input_event(ClassDB.instantiate(event_class))
	if event == null:
		return null

	var writable_properties: Dictionary = _get_event_writable_properties(event)
	var properties: Dictionary = GFVariantData.get_option_dictionary(record, _EVENT_PROPERTIES_FIELD)
	for property_key: Variant in properties.keys():
		var property_name: String = GFVariantData.to_text(property_key)
		if property_name.is_empty() or not writable_properties.has(property_name):
			continue
		event.set(property_name, GFVariantJsonCodec.json_compatible_to_variant(properties[property_key]))
	return event


static func _event_properties_to_record(event: InputEvent) -> Dictionary:
	var result: Dictionary = {}
	for property_info: Dictionary in event.get_property_list():
		var property_name: String = GFVariantData.get_option_string(property_info, "name")
		if property_name.is_empty() or _SKIPPED_EVENT_PROPERTIES.has(property_name):
			continue
		if not _is_stored_event_property(property_info):
			continue

		var value: Variant = GFObjectPropertyTools.read_property(event, NodePath(property_name))
		if _can_store_event_property(value):
			result[property_name] = GFVariantJsonCodec.variant_to_json_compatible(value)
	return result


static func _get_event_writable_properties(event: InputEvent) -> Dictionary:
	var result: Dictionary = {}
	for property_info: Dictionary in event.get_property_list():
		var property_name: String = GFVariantData.get_option_string(property_info, "name")
		if property_name.is_empty() or _SKIPPED_EVENT_PROPERTIES.has(property_name):
			continue
		if _is_stored_event_property(property_info):
			result[property_name] = true
	return result


static func _is_stored_event_property(property_info: Dictionary) -> bool:
	var usage: int = GFVariantData.get_option_int(property_info, "usage")
	return (usage & PROPERTY_USAGE_STORAGE) != 0


static func _can_store_event_property(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return (
		value_type == TYPE_NIL
		or value_type == TYPE_BOOL
		or value_type == TYPE_INT
		or value_type == TYPE_FLOAT
		or value_type == TYPE_STRING
		or value_type == TYPE_STRING_NAME
		or value_type == TYPE_NODE_PATH
		or value_type == TYPE_VECTOR2
		or value_type == TYPE_VECTOR2I
	)
