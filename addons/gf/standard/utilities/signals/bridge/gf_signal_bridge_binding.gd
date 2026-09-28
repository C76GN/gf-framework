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

## 信号参数捕获缓冲区支持的最大参数数。
## [br]
## @api private
## [br]
const _MAX_SIGNAL_ARGUMENTS: int = 16

## 校验弱引用节点是否仍为存活实例的内部工具。
## [br]
## @api private
## [br]
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

## 场景根节点的弱引用；根节点释放后解析为空。
## [br]
## @api private
## [br]
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




# --- 框架内部方法 ---

## 通过弱引用取得根节点，根或桥已失效时断开绑定；有效时整理实际信号参数并同步调用桥，忽略其返回值。
## GFSignalBridge 按名称创建此捕获入口；已知签名按实参个数截取，未知签名仅去掉末尾 null。
## [br]
## @api framework_internal
## [br]
## @param arg1: 源信号的第一个实参，未占用槽位默认 null。
## [br]
## @param arg2: 源信号的第二个实参。
## [br]
## @param arg3: 源信号的第三个实参。
## [br]
## @param arg4: 源信号的第四个实参。
## [br]
## @param arg5: 源信号的第五个实参。
## [br]
## @param arg6: 源信号的第六个实参。
## [br]
## @param arg7: 源信号的第七个实参。
## [br]
## @param arg8: 源信号的第八个实参。
## [br]
## @param arg9: 源信号的第九个实参。
## [br]
## @param arg10: 源信号的第十个实参。
## [br]
## @param arg11: 源信号的第十一个实参。
## [br]
## @param arg12: 源信号的第十二个实参。
## [br]
## @param arg13: 源信号的第十三个实参。
## [br]
## @param arg14: 源信号的第十四个实参。
## [br]
## @param arg15: 源信号的第十五个实参。
## [br]
## @param arg16: 源信号的第十六个实参，捕获上限为十六项。
## [br]
## @schema arg1: Variant，类型与含义由 bridge.source 的信号定义。
## [br]
## @schema arg2: Variant，源信号第二项或未占用槽位的 null。
## [br]
## @schema arg3: Variant，源信号第三项或未占用槽位的 null。
## [br]
## @schema arg4: Variant，源信号第四项或未占用槽位的 null。
## [br]
## @schema arg5: Variant，源信号第五项或未占用槽位的 null。
## [br]
## @schema arg6: Variant，源信号第六项或未占用槽位的 null。
## [br]
## @schema arg7: Variant，源信号第七项或未占用槽位的 null。
## [br]
## @schema arg8: Variant，源信号第八项或未占用槽位的 null。
## [br]
## @schema arg9: Variant，源信号第九项或未占用槽位的 null。
## [br]
## @schema arg10: Variant，源信号第十项或未占用槽位的 null。
## [br]
## @schema arg11: Variant，源信号第十一项或未占用槽位的 null。
## [br]
## @schema arg12: Variant，源信号第十二项或未占用槽位的 null。
## [br]
## @schema arg13: Variant，源信号第十三项或未占用槽位的 null。
## [br]
## @schema arg14: Variant，源信号第十四项或未占用槽位的 null。
## [br]
## @schema arg15: Variant，源信号第十五项或未占用槽位的 null。
## [br]
## @schema arg16: Variant，源信号第十六项或未占用槽位的 null。
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


# --- 私有/辅助方法 ---



## 按来源信号参数数裁剪回调参数；无法读取元数据时移除末尾 null 占位项。
## [br]
## @api private
## [br]
func _collect_args(root: Node, raw_args: Array) -> Array:
	if bridge == null or bridge.source == null:
		return _trim_trailing_null_args(raw_args)

	var argument_count: int = bridge.source.get_signal_argument_count(root)
	if argument_count >= 0:
		if argument_count > _MAX_SIGNAL_ARGUMENTS:
			push_warning("[GFSignalBridgeBinding][signal_bridge_binding.signal_argument_limit] Signal bridge capture supports at most %d arguments." % _MAX_SIGNAL_ARGUMENTS)
		return raw_args.slice(0, mini(argument_count, raw_args.size()))
	return _trim_trailing_null_args(raw_args)


## 复制参数数组并移除末尾连续的 null 占位项。
## [br]
## @api private
## [br]
func _trim_trailing_null_args(raw_args: Array) -> Array:
	var result: Array = raw_args.duplicate()
	while not result.is_empty() and result.back() == null:
		result.pop_back()
	return result


## 通过 InstanceGuard 从弱引用解析仍存活的场景根节点。
## [br]
## @api private
## [br]
func _get_root() -> Node:
	if _root_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(_root_ref)
