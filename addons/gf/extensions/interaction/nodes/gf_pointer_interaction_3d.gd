## GFPointerInteraction3D: 将 3D 指针事件桥接为 GFInteractionContext。
##
## 监听 CollisionObject3D 的 hover、鼠标按钮与滚轮事件，构建通用交互上下文。
## 节点只传递位置、法线、按钮、标签和元数据，不解释点击对象的业务含义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFPointerInteraction3D
extends Node


# --- 信号 ---

## 指针进入绑定的 3D 碰撞对象。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
signal pointer_entered(context: GFInteractionContext)

## 指针离开绑定的 3D 碰撞对象。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
signal pointer_exited(context: GFInteractionContext)

## 指针按钮按下。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param event: 原始输入事件。
signal pointer_pressed(context: GFInteractionContext, event: InputEventMouseButton)

## 指针按钮释放。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param event: 原始输入事件。
signal pointer_released(context: GFInteractionContext, event: InputEventMouseButton)

## 指针完成一次点击。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param event: 原始输入事件。
signal pointer_clicked(context: GFInteractionContext, event: InputEventMouseButton)

## 指针滚轮事件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param event: 原始输入事件。
signal pointer_wheel(context: GFInteractionContext, event: InputEventMouseButton)

## 已向接收器发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal pointer_interaction_sent(context: GFInteractionContext, receiver: Object, report: Dictionary)


# --- 常量 ---

const _MESSAGE_DISPATCH_SUPPORT = preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")
const _PICKABLE_OWNER_COUNT_META: StringName = &"_gf_pointer_interaction_3d_pickable_owner_count"
const _PICKABLE_ORIGINAL_META: StringName = &"_gf_pointer_interaction_3d_pickable_original"
const _RESERVED_POINTER_PAYLOAD_KEYS: Array[String] = [
	"pointer_event",
	"pointer_tags",
	"pointer_metadata",
]


# --- 导出变量 ---

## 是否启用指针桥接。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_reset_pointer_state(true)

## 默认交互 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var interaction_id: StringName = &""

## 默认交互分组。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var group_name: StringName = &""

## 默认 payload；发送时会深拷贝并附加 pointer_* 字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema payload: 默认交互载荷 Dictionary；发送时会复制并附加 pointer_event、pointer_tags、pointer_metadata 等 pointer_* 字段。
@export var payload: Dictionary = {}

## 指针标签。框架不解释标签含义。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var tags: PackedStringArray = PackedStringArray()

## 自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: 指针交互自定义元数据 Dictionary；会写入 payload.pointer_metadata 并复制到结果报告。
@export var metadata: Dictionary = {}

## 可选 3D 碰撞对象路径；为空时优先使用父节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("CollisionObject3D") var collision_object_path: NodePath = NodePath("")

## 可选交互接收器路径；为空时从碰撞对象向父级解析 receive_interaction()。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var receiver_path: NodePath = NodePath("")

## 可选发送者路径；为空时使用当前节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var sender_path: NodePath = NodePath("")

## 是否在点击完成时发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var send_on_clicked: bool = true

## 是否在按钮按下时发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var send_on_pressed: bool = false

## 是否在按钮释放时发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var send_on_released: bool = false

## 是否在滚轮事件时发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var send_on_wheel: bool = false

## 是否在 hover 进入和离开时发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var send_on_hover: bool = false

## 绑定碰撞对象时是否确保 input_ray_pickable 为 true。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var ensure_input_ray_pickable: bool = true:
	set(value):
		if ensure_input_ray_pickable == value:
			return
		ensure_input_ray_pickable = value
		_refresh_current_collision_object_binding(get_collision_object())

## hover 时是否临时切换鼠标光标。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var change_cursor_on_hover: bool = false

## hover 时使用的鼠标光标。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var cursor_shape: Input.CursorShape = Input.CURSOR_ARROW


# --- 私有变量 ---

var _collision_object_ref: WeakRef = null
var _is_hovered: bool = false
var _pressed_button: int = 0
var _pressed_shape_idx: int = -1
var _bound_input_ray_pickable_original: bool = false
var _bound_input_ray_pickable_changed: bool = false
var _has_previous_cursor_shape: bool = false
static var _cursor_owner_stack: Array[Dictionary] = []
static var _cursor_base_shape: Input.CursorShape = Input.CURSOR_ARROW
static var _has_cursor_base_shape: bool = false


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_collision_object()


func _ready() -> void:
	bind_collision_object(_resolve_collision_object())


func _exit_tree() -> void:
	_disconnect_collision_object()


# --- 公共方法 ---

## 绑定 3D 碰撞对象。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param collision_object: 要监听的碰撞对象。
func bind_collision_object(collision_object: CollisionObject3D) -> void:
	var current_collision_object: CollisionObject3D = get_collision_object()
	if collision_object != null and current_collision_object == collision_object:
		_refresh_current_collision_object_binding(collision_object)
		return

	_disconnect_collision_object()
	if collision_object == null:
		return

	_collision_object_ref = weakref(collision_object)
	_retain_input_ray_pickable(collision_object)
	if not collision_object.mouse_entered.is_connected(_on_collision_mouse_entered):
		var _mouse_entered_connected: Error = collision_object.mouse_entered.connect(_on_collision_mouse_entered) as Error
	if not collision_object.mouse_exited.is_connected(_on_collision_mouse_exited):
		var _mouse_exited_connected: Error = collision_object.mouse_exited.connect(_on_collision_mouse_exited) as Error
	if not collision_object.input_event.is_connected(_on_collision_input_event):
		var _input_event_connected: Error = collision_object.input_event.connect(_on_collision_input_event) as Error


## 获取当前绑定的 3D 碰撞对象。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 碰撞对象；不存在时返回 null。
func get_collision_object() -> CollisionObject3D:
	if _collision_object_ref == null:
		return null
	return _get_collision_object_value(_collision_object_ref.get_ref())


## 构建指针交互上下文。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param pointer_event: 指针事件标识。
## [br]
## @param pointer_data: 指针事件数据。
## [br]
## @schema pointer_data: 指针事件数据 Dictionary；常见字段包括 pointer_position、pointer_normal、pointer_shape_idx、pointer_camera_path 和 pointer_input_event_class。
## [br]
## @param receiver: 可选接收对象；为空时自动解析。
## [br]
## @return: 交互上下文。
func build_context(
	pointer_event: StringName,
	pointer_data: Dictionary = {},
	receiver: Object = null
) -> GFInteractionContext:
	var effective_receiver: Object = receiver if receiver != null else _resolve_receiver()
	var context_payload: Dictionary = payload.duplicate(true)
	context_payload["pointer_event"] = pointer_event
	context_payload["pointer_tags"] = tags.duplicate()
	context_payload["pointer_metadata"] = metadata.duplicate(true)
	for key: Variant in pointer_data.keys():
		if _is_reserved_pointer_payload_key(key):
			continue
		context_payload[key] = GFVariantData.duplicate_variant(pointer_data[key])

	return GFInteractionContext.new(_resolve_sender(), effective_receiver, context_payload, group_name)


## 发送一次指针交互。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param pointer_event: 指针事件标识。
## [br]
## @param pointer_data: 指针事件数据。
## [br]
## @schema pointer_data: 指针事件数据 Dictionary；常见字段包括 pointer_position、pointer_normal、pointer_shape_idx、pointer_camera_path 和 pointer_input_event_class。
## [br]
## @param interaction_id_override: 可选交互 ID 覆盖。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func send_pointer_interaction(
	pointer_event: StringName,
	pointer_data: Dictionary = {},
	interaction_id_override: StringName = &""
) -> Dictionary:
	var receiver: Object = _resolve_receiver()
	var context: GFInteractionContext = build_context(pointer_event, pointer_data, receiver)
	var effective_interaction_id: StringName = interaction_id_override if interaction_id_override != &"" else interaction_id
	var report: Dictionary = _MESSAGE_DISPATCH_SUPPORT._dispatch_to_receiver(
		enabled,
		metadata,
		receiver,
		&"receive_interaction",
		[context, effective_interaction_id],
		"interaction_id",
		effective_interaction_id,
		"Pointer interaction bridge is disabled.",
		"Pointer interaction receiver is null.",
		"Receiver does not expose receive_interaction().",
		"Receiver returned an invalid interaction report."
	)
	pointer_interaction_sent.emit(context, receiver, report)
	return report


# --- 私有/辅助方法 ---

func _resolve_collision_object() -> CollisionObject3D:
	if collision_object_path != NodePath(""):
		return _get_collision_object_value(get_node_or_null(collision_object_path))
	return _get_collision_object_value(get_parent())


func _disconnect_collision_object() -> void:
	var collision_object: CollisionObject3D = get_collision_object()
	if collision_object == null:
		_reset_pointer_state(true)
		_clear_collision_binding_state()
		_collision_object_ref = null
		return
	_reset_pointer_state(true)
	if collision_object.mouse_entered.is_connected(_on_collision_mouse_entered):
		collision_object.mouse_entered.disconnect(_on_collision_mouse_entered)
	if collision_object.mouse_exited.is_connected(_on_collision_mouse_exited):
		collision_object.mouse_exited.disconnect(_on_collision_mouse_exited)
	if collision_object.input_event.is_connected(_on_collision_input_event):
		collision_object.input_event.disconnect(_on_collision_input_event)
	_restore_input_ray_pickable(collision_object)
	_clear_collision_binding_state()
	_collision_object_ref = null


func _refresh_current_collision_object_binding(collision_object: CollisionObject3D) -> void:
	_reset_pointer_state(true)
	if collision_object == null:
		return
	if not ensure_input_ray_pickable:
		_restore_input_ray_pickable(collision_object)
		_clear_collision_binding_state()
		return
	if not _bound_input_ray_pickable_changed:
		_retain_input_ray_pickable(collision_object)
		return
	if not collision_object.input_ray_pickable and _get_pickable_owner_count(collision_object) <= 1:
		_bound_input_ray_pickable_original = false
		collision_object.set_meta(_PICKABLE_ORIGINAL_META, false)
	collision_object.input_ray_pickable = true


func _resolve_receiver() -> Object:
	if receiver_path != NodePath(""):
		var receiver: Node = get_node_or_null(receiver_path)
		if receiver != null:
			return receiver
	return _MESSAGE_DISPATCH_SUPPORT._resolve_receiver(get_collision_object(), &"receive_interaction")


func _resolve_sender() -> Object:
	if sender_path != NodePath(""):
		var sender: Node = get_node_or_null(sender_path)
		if sender != null:
			return sender
	return self


func _make_pointer_data(
	event_name: StringName,
	camera: Camera3D = null,
	input_event: InputEvent = null,
	position: Vector3 = Vector3.ZERO,
	normal: Vector3 = Vector3.ZERO,
	shape_idx: int = -1
) -> Dictionary:
	var collision_object: CollisionObject3D = get_collision_object()
	var data: Dictionary = {
		"pointer_event": event_name,
		"pointer_position": position,
		"pointer_normal": normal,
		"pointer_shape_idx": shape_idx,
		"pointer_camera_instance_id": camera.get_instance_id() if camera != null and is_instance_valid(camera) else 0,
		"pointer_camera_path": camera.get_path() if camera != null and camera.is_inside_tree() else NodePath(""),
		"pointer_input_device": input_event.device if input_event != null else 0,
		"pointer_input_event_class": input_event.get_class() if input_event != null else "",
		"pointer_collision_path": collision_object.get_path() if collision_object != null and collision_object.is_inside_tree() else NodePath(""),
	}
	if input_event is InputEventFromWindow:
		var window_event: InputEventFromWindow = input_event
		data["pointer_input_window_id"] = window_event.window_id
	return data


func _make_mouse_button_data(
	event_name: StringName,
	camera: Camera3D,
	event: InputEventMouseButton,
	position: Vector3,
	normal: Vector3,
	shape_idx: int
) -> Dictionary:
	var data: Dictionary = _make_pointer_data(event_name, camera, event, position, normal, shape_idx)
	data["pointer_button_index"] = event.button_index
	data["pointer_pressed"] = event.pressed
	data["pointer_factor"] = event.factor
	return data


func _emit_or_send_hover(event_name: StringName) -> void:
	var data: Dictionary = _make_pointer_data(event_name)
	var context: GFInteractionContext = build_context(event_name, data)
	if event_name == &"entered":
		pointer_entered.emit(context)
	else:
		pointer_exited.emit(context)
	if send_on_hover:
		var _send_pointer_interaction_result_379: Variant = send_pointer_interaction(event_name, data)


func _emit_or_send_button_event(
	event_name: StringName,
	camera: Camera3D,
	event: InputEventMouseButton,
	position: Vector3,
	normal: Vector3,
	shape_idx: int,
	should_send: bool
) -> GFInteractionContext:
	var data: Dictionary = _make_mouse_button_data(event_name, camera, event, position, normal, shape_idx)
	var context: GFInteractionContext = build_context(event_name, data)
	match event_name:
		&"pressed":
			pointer_pressed.emit(context, event)
		&"released":
			pointer_released.emit(context, event)
		&"clicked":
			pointer_clicked.emit(context, event)
		&"wheel":
			pointer_wheel.emit(context, event)
	if should_send:
		var _send_pointer_interaction_result_403: Variant = send_pointer_interaction(event_name, data)
	return context


func _is_wheel_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_WHEEL_UP or button_index == MOUSE_BUTTON_WHEEL_DOWN or button_index == MOUSE_BUTTON_WHEEL_LEFT or button_index == MOUSE_BUTTON_WHEEL_RIGHT


func _set_hover_cursor(active: bool) -> void:
	if active and not change_cursor_on_hover:
		return
	var owner_id: int = get_instance_id()
	if active:
		if not _cursor_stack_has_owner(owner_id):
			if _cursor_owner_stack.is_empty():
				_cursor_base_shape = Input.get_current_cursor_shape()
				_has_cursor_base_shape = true
			_cursor_owner_stack.append({
				"owner_id": owner_id,
				"shape": cursor_shape,
			})
			_has_previous_cursor_shape = true
		Input.set_default_cursor_shape(cursor_shape)
		return
	var removed_entry: Dictionary = _remove_cursor_stack_owner(owner_id)
	_has_previous_cursor_shape = false
	if not _cursor_owner_stack.is_empty():
		Input.set_default_cursor_shape(_get_cursor_shape_from_entry(_cursor_owner_stack[_cursor_owner_stack.size() - 1], Input.CURSOR_ARROW))
	elif not removed_entry.is_empty() and _has_cursor_base_shape:
		Input.set_default_cursor_shape(_cursor_base_shape)
		_has_cursor_base_shape = false
		_cursor_base_shape = Input.CURSOR_ARROW


func _reset_pointer_state(reset_cursor: bool) -> void:
	var should_reset_cursor: bool = reset_cursor and (_is_hovered or _has_previous_cursor_shape)
	_is_hovered = false
	_pressed_button = 0
	_pressed_shape_idx = -1
	if should_reset_cursor:
		_set_hover_cursor(false)


func _restore_input_ray_pickable(collision_object: CollisionObject3D) -> void:
	if collision_object == null or not _bound_input_ray_pickable_changed:
		return
	_release_input_ray_pickable(collision_object)


func _clear_collision_binding_state() -> void:
	_bound_input_ray_pickable_original = false
	_bound_input_ray_pickable_changed = false


func _retain_input_ray_pickable(collision_object: CollisionObject3D) -> void:
	if collision_object == null or not ensure_input_ray_pickable:
		_bound_input_ray_pickable_original = collision_object.input_ray_pickable if collision_object != null else false
		_bound_input_ray_pickable_changed = false
		return
	var owner_count: int = _get_pickable_owner_count(collision_object)
	if owner_count <= 0:
		collision_object.set_meta(_PICKABLE_ORIGINAL_META, collision_object.input_ray_pickable)
	_bound_input_ray_pickable_original = _get_pickable_original(collision_object, collision_object.input_ray_pickable)
	_bound_input_ray_pickable_changed = true
	collision_object.set_meta(_PICKABLE_OWNER_COUNT_META, owner_count + 1)
	collision_object.input_ray_pickable = true


func _release_input_ray_pickable(collision_object: CollisionObject3D) -> void:
	var owner_count: int = _get_pickable_owner_count(collision_object)
	if owner_count <= 1:
		collision_object.input_ray_pickable = _get_pickable_original(collision_object, _bound_input_ray_pickable_original)
		if collision_object.has_meta(_PICKABLE_OWNER_COUNT_META):
			collision_object.remove_meta(_PICKABLE_OWNER_COUNT_META)
		if collision_object.has_meta(_PICKABLE_ORIGINAL_META):
			collision_object.remove_meta(_PICKABLE_ORIGINAL_META)
		return
	collision_object.set_meta(_PICKABLE_OWNER_COUNT_META, owner_count - 1)


func _get_pickable_owner_count(collision_object: CollisionObject3D) -> int:
	if collision_object == null or not collision_object.has_meta(_PICKABLE_OWNER_COUNT_META):
		return 0
	return GFVariantData.to_int(collision_object.get_meta(_PICKABLE_OWNER_COUNT_META), 0)


func _get_pickable_original(collision_object: CollisionObject3D, fallback: bool) -> bool:
	if collision_object == null or not collision_object.has_meta(_PICKABLE_ORIGINAL_META):
		return fallback
	return GFVariantData.to_bool(collision_object.get_meta(_PICKABLE_ORIGINAL_META), fallback)


func _is_reserved_pointer_payload_key(key: Variant) -> bool:
	return _RESERVED_POINTER_PAYLOAD_KEYS.has(GFVariantData.to_text(key))


func _cursor_stack_has_owner(owner_id: int) -> bool:
	for entry: Dictionary in _cursor_owner_stack:
		if GFVariantData.get_option_int(entry, "owner_id", 0) == owner_id:
			return true
	return false


func _remove_cursor_stack_owner(owner_id: int) -> Dictionary:
	for index: int in range(_cursor_owner_stack.size() - 1, -1, -1):
		var entry: Dictionary = _cursor_owner_stack[index]
		if GFVariantData.get_option_int(entry, "owner_id", 0) != owner_id:
			continue
		_cursor_owner_stack.remove_at(index)
		return entry
	return {}


func _get_cursor_shape_from_entry(
	entry: Dictionary,
	fallback: Input.CursorShape
) -> Input.CursorShape:
	var shape: int = GFVariantData.get_option_int(entry, "shape", fallback)
	return shape as Input.CursorShape


func _get_collision_object_value(value: Variant) -> CollisionObject3D:
	if value is CollisionObject3D:
		var collision_object: CollisionObject3D = value
		return collision_object
	return null


func _get_mouse_button_event(value: Variant) -> InputEventMouseButton:
	if value is InputEventMouseButton:
		var event: InputEventMouseButton = value
		return event
	return null


# --- 信号处理函数 ---

func _on_collision_mouse_entered() -> void:
	if not enabled:
		return
	_is_hovered = true
	_set_hover_cursor(true)
	_emit_or_send_hover(&"entered")


func _on_collision_mouse_exited() -> void:
	if not enabled:
		return
	_is_hovered = false
	_pressed_button = 0
	_pressed_shape_idx = -1
	_set_hover_cursor(false)
	_emit_or_send_hover(&"exited")


func _on_collision_input_event(
	camera: Camera3D,
	event: InputEvent,
	position: Vector3,
	normal: Vector3,
	shape_idx: int
) -> void:
	if not enabled or not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = _get_mouse_button_event(event)
	if _is_wheel_button(mouse_event.button_index):
		if mouse_event.pressed:
			var _emit_or_send_button_event_result_464: Variant = _emit_or_send_button_event(&"wheel", camera, mouse_event, position, normal, shape_idx, send_on_wheel)
		return

	if mouse_event.pressed:
		_pressed_button = mouse_event.button_index
		_pressed_shape_idx = shape_idx
		var _emit_or_send_button_event_result_470: Variant = _emit_or_send_button_event(&"pressed", camera, mouse_event, position, normal, shape_idx, send_on_pressed)
		return

	var was_matching_press: bool = _pressed_button == mouse_event.button_index and _pressed_shape_idx == shape_idx
	_pressed_button = 0
	_pressed_shape_idx = -1
	var _emit_or_send_button_event_result_476: Variant = _emit_or_send_button_event(&"released", camera, mouse_event, position, normal, shape_idx, send_on_released)
	if was_matching_press:
		var _emit_or_send_button_event_result_478: Variant = _emit_or_send_button_event(&"clicked", camera, mouse_event, position, normal, shape_idx, send_on_clicked)
