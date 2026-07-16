## GFEventListener: 显式描述事件监听回调、参数契约与可选 owner 的监听器记录。
##
## 事件系统不再把裸 Callable 当作稳定契约；项目代码需要通过该类型声明监听器可接收的派发参数数量。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFEventListener
extends RefCounted


# --- 私有变量 ---

var _callback: Callable = Callable()
var _dispatch_argument_count: int = -1
var _debug_label: String = ""
var _owner_ref: WeakRef = null
var _owner_id: int = 0


# --- 公共方法 ---

## 创建显式声明派发参数数量的监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param callback: 事件触发时执行的回调。
## [br]
## @param dispatch_argument_count: 事件系统会主动传入的参数数量；类型事件和简单事件均为 1。
## [br]
## @param debug_label: 可选诊断标签，错误报告为空时会回退到 Callable 方法名。
## [br]
## @return 新监听器契约。
static func from_callable(
	callback: Callable,
	dispatch_argument_count: int,
	debug_label: String = ""
) -> GFEventListener:
	var listener: GFEventListener = GFEventListener.new()
	listener._callback = callback
	listener._dispatch_argument_count = maxi(dispatch_argument_count, 0)
	listener._debug_label = debug_label
	return listener


## 通过 owner 与方法名创建监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 监听方法所属对象，同时作为监听 owner。
## [br]
## @param method_name: 监听方法名。
## [br]
## @param dispatch_argument_count: 事件系统会主动传入的参数数量；类型事件和简单事件均为 1。
## [br]
## @param debug_label: 可选诊断标签，错误报告为空时会回退到 Callable 方法名。
## [br]
## @return 新监听器契约。
static func from_method(
	owner: Object,
	method_name: StringName,
	dispatch_argument_count: int,
	debug_label: String = ""
) -> GFEventListener:
	var callback: Callable = Callable(owner, method_name) if owner != null else Callable()
	return GFEventListener.from_callable(callback, dispatch_argument_count, debug_label).with_owner(owner)


## 返回带 owner 的监听器副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 监听器 owner；释放后事件系统会清理该监听器。
## [br]
## @return 当前监听器的带 owner 副本。
func with_owner(owner: Object) -> GFEventListener:
	var listener: GFEventListener = duplicate_listener()
	listener._set_owner(owner)
	return listener


## 返回监听器副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前监听器副本。
func duplicate_listener() -> GFEventListener:
	var listener: GFEventListener = GFEventListener.new()
	listener._callback = _callback
	listener._dispatch_argument_count = _dispatch_argument_count
	listener._debug_label = _debug_label
	listener._owner_ref = _owner_ref
	listener._owner_id = _owner_id
	return listener


## 返回监听回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 监听回调。
func get_callback() -> Callable:
	return _callback


## 返回监听 owner；未设置或已释放时返回 null。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 监听 owner 或 null。
func get_owner() -> Object:
	if _owner_ref == null:
		return null
	return _owner_ref.get_ref()


## 返回监听 owner 的实例 ID；未设置时为 0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return owner 实例 ID。
func get_owner_id() -> int:
	return _owner_id


## 返回事件系统会主动传入的参数数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 派发参数数量。
func get_dispatch_argument_count() -> int:
	return _dispatch_argument_count


## 返回诊断标签。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 诊断标签。
func get_debug_label() -> String:
	if not _debug_label.is_empty():
		return _debug_label
	return String(_callback.get_method())


## 返回监听器当前是否有基本有效的 Callable 和参数契约。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 监听器是否有效。
func is_valid() -> bool:
	return _callback.is_valid() and _dispatch_argument_count >= 0 and not _owner_is_released()


# --- 框架内部方法 ---

## 校验监听器是否可用于指定事件派发形态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param dispatch_argument_count: 事件系统会传入的参数数量。
## [br]
## @param callback_label: 错误报告中的回调类型标签。
## [br]
## @param argument_label: 错误报告中的事件参数标签。
## [br]
## @return 校验是否通过。
func validate_for_dispatch(
	dispatch_argument_count: int,
	callback_label: String,
	argument_label: String
) -> bool:
	if not _callback.is_valid():
		push_error("[GFEventListener] 注册的%s无效。" % callback_label)
		return false
	if _dispatch_argument_count != dispatch_argument_count:
		push_error("[GFEventListener] 注册的%s %s 声明接收 %d 个派发参数，但当前事件会传入 %d 个。" % [
			callback_label,
			get_debug_label(),
			_dispatch_argument_count,
			dispatch_argument_count,
		])
		return false
	if _owner_is_released():
		push_error("[GFEventListener] 注册的%s %s 的 owner 已释放。" % [callback_label, get_debug_label()])
		return false

	var target_obj: Object = _callback.get_object()
	if target_obj == null:
		return true
	if not is_instance_valid(target_obj):
		push_error("[GFEventListener] 注册的%s %s 的目标对象已失效。" % [callback_label, get_debug_label()])
		return false

	var method_name: StringName = _callback.get_method()
	var methods: Array[Dictionary] = target_obj.get_method_list()
	for method: Dictionary in methods:
		if method["name"] == String(method_name):
			return _validate_method_arguments(method, dispatch_argument_count, callback_label, argument_label)
	return true


# --- 私有/辅助方法 ---

func _set_owner(owner: Object) -> void:
	if owner == null:
		_owner_ref = null
		_owner_id = 0
		return
	_owner_ref = weakref(owner)
	_owner_id = owner.get_instance_id()


func _owner_is_released() -> bool:
	return _owner_id != 0 and get_owner() == null


func _validate_method_arguments(
	method: Dictionary,
	dispatch_argument_count: int,
	callback_label: String,
	argument_label: String
) -> bool:
	var args: Array = _get_dictionary_array(method, "args")
	var default_args: Array = _get_dictionary_array(method, "default_args")
	var required_arg_count: int = maxi(args.size() - default_args.size(), 0)
	var provided_arg_count: int = dispatch_argument_count + _callback.get_bound_arguments_count()
	var flags: int = _get_dictionary_int(method, "flags", 0)
	var accepts_varargs: bool = (flags & METHOD_FLAG_VARARG) != 0
	var method_name: StringName = _callback.get_method()
	if args.size() < dispatch_argument_count:
		push_error("[GFEventListener] 注册的%s %s 必须至少包含 %d 个参数用于接收%s。" % [
			callback_label,
			method_name,
			dispatch_argument_count,
			argument_label,
		])
		return false
	if not accepts_varargs and args.size() < provided_arg_count:
		push_error("[GFEventListener] 注册的%s %s 最多接收 %d 个参数，当前会传入 %d 个。" % [
			callback_label,
			method_name,
			args.size(),
			provided_arg_count,
		])
		return false
	if required_arg_count > provided_arg_count:
		push_error("[GFEventListener] 注册的%s %s 不能要求超过 %d 个未绑定参数，当前必填 %d 个。" % [
			callback_label,
			method_name,
			dispatch_argument_count,
			required_arg_count - _callback.get_bound_arguments_count(),
		])
		return false
	return true


func _get_dictionary_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		var result: Array = value
		return result
	return []


func _get_dictionary_int(source: Dictionary, key: String, default_value: int) -> int:
	var value: Variant = source.get(key, default_value)
	if value is int:
		var result: int = value
		return result
	return default_value
