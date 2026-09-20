## GFTweenReplacementScope: 配置化 Tween 显式共享的属性替换作用域。
##
## 仅管理主动加入本作用域的动作，不查找目标上的其他 Tween。
## 相同目标的同一顶层属性及其分量互斥；Node2D、Node3D 的 rotation_degrees
## 与 rotation 视为同一属性。其他属性别名和项目 setter 的关联不作推断。
## 作用域只弱引用动作与目标；持有者应在自身生命周期结束时调用 dispose()。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFTweenReplacementScope
extends RefCounted


# --- 私有变量 ---

var _entries: Array[_Registration] = []
var _next_lease: int = 0
var _disposed: bool = false


# --- 公共方法 ---

## 永久关闭作用域并停止仍登记的动作；重复调用无副作用。
## 先撤销全部登记并停止全部动作，再通知动作完成，不恢复被替换动作的初值。
## 完成通知中的重入登记会被拒绝。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	var retired: Array[_Registration] = _entries
	_entries = []
	_retire_entries(retired)


## 查询作用域是否已永久关闭。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: dispose() 调用后返回 true。
func is_disposed() -> bool:
	return _disposed


## 查询仍具有有效动作和目标的登记数，并移除失效的弱引用登记。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前登记的动作数量，不是属性或步骤数量。
func get_active_count() -> int:
	_prune_invalid_entries()
	return _entries.size()


# --- 层内方法 ---

## 读取当前登记的租约，供 claim 通知尚未返回时精确取消或重新执行。
## 必须在任何可重入通知之前捕获返回值，后续释放仍使用精确租约。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 当前执行的动作。
## [br]
## @return: 当前租约；没有有效登记时为 0。
func find_lease(action: Object) -> int:
	_prune_invalid_entries()
	for entry: _Registration in _entries:
		if _get_object(entry._action_ref) == action:
			return entry._lease
	return 0


## 为动作申请属性租约，并通过两阶段协议结束冲突的旧动作。
## 动作须提供接受一个整数的 detach_replacement(lease) 和 notify_replaced(generation)。
## detach_replacement 必须先停止写入且不通知、不恢复属性，返回待通知的正整数世代；
## notify_replaced 负责终态通知。更晚的重入申请获胜，调用方必须在启动前检查返回值。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param action: 符合替换协议的动作；同一动作只保留一个租约。
## [br]
## @param target: 调用方已验证的属性目标。
## [br]
## @param property_names: 已验证步骤使用的非空属性路径集合。
## [br]
## @return: 仍持有的正整数租约；无效输入、作用域关闭或重入失权时返回 0。
func claim(action: Object, target: Object, property_names: Array[NodePath]) -> int:
	if _disposed or not _is_available(action) or not _is_available(target):
		return 0
	if not _accepts_integer_argument(action, &"detach_replacement"):
		return 0
	if not _accepts_integer_argument(action, &"notify_replaced"):
		return 0
	var roots: Array[StringName] = _get_property_roots(target, property_names)
	if roots.is_empty():
		return 0
	_prune_invalid_entries()
	var retired: Array[_Registration] = []
	var retained: Array[_Registration] = []
	for entry: _Registration in _entries:
		if _get_object(entry._action_ref) == action or (
			_get_object(entry._target_ref) == target and _roots_overlap(entry._roots, roots)
		):
			retired.append(entry)
		else:
			retained.append(entry)
	_next_lease += 1
	var registration: _Registration = _Registration.new()
	registration._lease = _next_lease
	registration._action_ref = weakref(action)
	registration._target_ref = weakref(target)
	registration._roots = roots
	retained.append(registration)
	_entries = retained
	_retire_entries(retired)
	return registration._lease if owns(action, registration._lease) else 0


## 查询动作是否仍持有指定租约；旧世代不能观察为新租约的持有者。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param action: 申请租约的动作。
## [br]
## @param lease: claim() 返回的正整数租约。
## [br]
## @return: 动作、目标与租约仍有效且匹配时返回 true。
func owns(action: Object, lease: int) -> bool:
	_prune_invalid_entries()
	if _disposed or lease <= 0 or not _is_available(action):
		return false
	for entry: _Registration in _entries:
		if entry._lease == lease and _get_object(entry._action_ref) == action:
			return true
	return false


## 精确释放指定动作的租约，不停止或通知动作。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param action: 申请租约的动作。
## [br]
## @param lease: 待释放的租约；旧租约或其他动作的租约不影响当前登记。
func release(action: Object, lease: int) -> void:
	_prune_invalid_entries()
	if lease <= 0 or not is_instance_valid(action):
		return
	for index: int in range(_entries.size() - 1, -1, -1):
		var entry: _Registration = _entries[index]
		if entry._lease == lease and _get_object(entry._action_ref) == action:
			_entries.remove_at(index)
			return


# --- 私有/辅助方法 ---

func _retire_entries(retired: Array[_Registration]) -> void:
	for entry: _Registration in retired:
		var action: Object = _get_object(entry._action_ref)
		if not _is_available(action):
			continue
		var stopped_generation: Variant = action.call(&"detach_replacement", entry._lease)
		if stopped_generation is int:
			entry._stopped_generation = stopped_generation
	for entry: _Registration in retired:
		var action: Object = _get_object(entry._action_ref)
		if _is_available(action) and entry._stopped_generation > 0:
			var _notified: Variant = action.call(&"notify_replaced", entry._stopped_generation)


func _prune_invalid_entries() -> void:
	for index: int in range(_entries.size() - 1, -1, -1):
		var entry: _Registration = _entries[index]
		if not _is_available(_get_object(entry._action_ref)) or not _is_available(_get_object(entry._target_ref)):
			_entries.remove_at(index)


func _get_property_roots(target: Object, property_names: Array[NodePath]) -> Array[StringName]:
	var roots: Array[StringName] = []
	for property_name: NodePath in property_names:
		var root: StringName = StringName(String(property_name).get_slice(":", 0))
		if root == &"":
			return []
		if root == &"rotation_degrees" and (target is Node2D or target is Node3D):
			root = &"rotation"
		if not roots.has(root):
			roots.append(root)
	return roots


func _roots_overlap(first: Array[StringName], second: Array[StringName]) -> bool:
	for root: StringName in first:
		if second.has(root):
			return true
	return false


func _accepts_integer_argument(action: Object, method_name: StringName) -> bool:
	if not action.has_method(method_name):
		return false
	for method_info: Dictionary in action.get_method_list():
		if GFVariantData.get_option_string_name(method_info, "name") != method_name:
			continue
		var arguments: Array = GFVariantData.get_option_array(method_info, "args")
		var defaults: Array = GFVariantData.get_option_array(method_info, "default_args")
		var required_count: int = maxi(arguments.size() - defaults.size(), 0)
		var accepts_extra: bool = (GFVariantData.get_option_int(method_info, "flags") & METHOD_FLAG_VARARG) != 0
		if required_count > 1 or (arguments.size() < 1 and not accepts_extra):
			return false
		if arguments.is_empty():
			return true
		var first_argument: Dictionary = GFVariantData.as_dictionary(arguments[0])
		var argument_type: int = GFVariantData.get_option_int(first_argument, "type", -1)
		return argument_type == TYPE_INT or argument_type == TYPE_NIL
	return false


func _is_available(value: Object) -> bool:
	if not is_instance_valid(value):
		return false
	if value is Node:
		var node: Node = value
		return not node.is_queued_for_deletion()
	return true


func _get_object(object_reference: WeakRef) -> Object:
	if object_reference == null:
		return null
	var value: Variant = object_reference.get_ref()
	if value is Object:
		return value
	return null


# --- 内部类 ---

class _Registration extends RefCounted:
	var _lease: int = 0
	var _action_ref: WeakRef = null
	var _target_ref: WeakRef = null
	var _roots: Array[StringName] = []
	var _stopped_generation: int = 0
