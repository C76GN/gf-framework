## GFSignalBridgeBinding: 运行中的信号桥接连接。
##
## Binding 持有桥接资源、根节点和底层 GFSignalConnection，用于在运行时断开、
## 检查状态，并把原生信号参数转交给桥接规则。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFSignalBridgeBinding
extends RefCounted


# --- 常量 ---

const _MAX_SIGNAL_ARGUMENTS: int = 16
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 公共变量 ---

## 桥接资源。
## [br]
## @api public
var bridge: GFSignalBridge = null

## 底层信号连接。
## [br]
## @api public
var connection: GFSignalConnection = null


# --- 私有变量 ---

var _root_ref: WeakRef = null


# --- 公共方法 ---

## 初始化绑定。
## [br]
## @api public
## [br]
## @param new_bridge: 桥接资源。
## [br]
## @param root: 路径解析根节点。
## [br]
## @param new_connection: 底层连接。
func setup(new_bridge: GFSignalBridge, root: Node, new_connection: GFSignalConnection) -> void:
	bridge = new_bridge
	connection = new_connection
	_root_ref = weakref(root) if root != null else null


## 断开桥接。
## [br]
## @api public
func disconnect_bridge() -> void:
	if connection != null:
		connection.disconnect_signal()
	connection = null


## 当前绑定是否仍活跃。
## [br]
## @api public
## [br]
## @return 活跃时返回 true。
func is_active() -> bool:
	return connection != null and connection.is_active() and _get_root() != null


# --- 私有/辅助方法 ---

func _invoke_from_signal(
	arg1: Variant = null,
	arg2: Variant = null,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null,
	arg6: Variant = null,
	arg7: Variant = null,
	arg8: Variant = null,
	arg9: Variant = null,
	arg10: Variant = null,
	arg11: Variant = null,
	arg12: Variant = null,
	arg13: Variant = null,
	arg14: Variant = null,
	arg15: Variant = null,
	arg16: Variant = null
) -> void:
	var root: Node = _get_root()
	if bridge == null or root == null:
		disconnect_bridge()
		return
	var _invoke_result_98: Variant = bridge.invoke(root, _collect_args(root, [
		arg1,
		arg2,
		arg3,
		arg4,
		arg5,
		arg6,
		arg7,
		arg8,
		arg9,
		arg10,
		arg11,
		arg12,
		arg13,
		arg14,
		arg15,
		arg16,
	]))


func _collect_args(root: Node, raw_args: Array) -> Array:
	if bridge == null or bridge.source == null:
		return _trim_trailing_null_args(raw_args)

	var argument_count: int = bridge.source.get_signal_argument_count(root)
	if argument_count >= 0:
		if argument_count > _MAX_SIGNAL_ARGUMENTS:
			push_warning("[GFSignalBridgeBinding][signal_bridge_binding.signal_argument_limit] Signal bridge capture supports at most %d arguments." % _MAX_SIGNAL_ARGUMENTS)
		return raw_args.slice(0, mini(argument_count, raw_args.size()))
	return _trim_trailing_null_args(raw_args)


func _trim_trailing_null_args(raw_args: Array) -> Array:
	var result: Array = raw_args.duplicate()
	while not result.is_empty() and result.back() == null:
		result.pop_back()
	return result


func _get_root() -> Node:
	if _root_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(_root_ref)
