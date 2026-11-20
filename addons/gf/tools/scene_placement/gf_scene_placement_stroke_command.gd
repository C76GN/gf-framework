@tool

## GFScenePlacementStrokeCommand: 同一场景内一笔摆放的预览样本和单条创建历史。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFScenePlacementStrokeCommand
extends GFEditorCommand


# --- 常量 ---

## 每笔最多保留的代理和场景实例数。
## [br]
## @api framework_internal
## [br]
## @since unreleased
const MAX_SAMPLES: int = 256


# --- 私有变量 ---

## 笔画使用的唯一场景资源。
## [br]
## @api private
var _source: PackedScene = null

## 目标父节点的弱引用。
## [br]
## @api private
var _parent_ref: WeakRef = null

## 原场景历史上下文的弱引用。
## [br]
## @api private
var _root_ref: WeakRef = null

## 世界空间的最小样本距离。
## [br]
## @api private
var _spacing: float = 1.0

## 上个采样位置，使用吸附后的世界锚点。
## [br]
## @api private
var _last_position: Vector3 = Vector3.ZERO

## 是否仍与上个样本处于同一有效命中段。
## [br]
## @api private
var _connected: bool = false

## 顺序与笔画采样一致的创建命令，拥有已实例化的节点。
## [br]
## @api private
var _items: Array[GFScenePlacementCreateCommand] = []

## 开始提交后冻结样本。
## [br]
## @api private
var _closed: bool = false

## 阻止同步节点回调嵌套执行或撤销历史。
## [br]
## @api private
var _running: bool = false

## 原生历史独立回调失败时由命令输出诊断，首次提交由面板处理。
## [br]
## @api private
var _registered: bool = false

## 只在首次提交栈内持有的上下文校验，历史不保留插件。
## [br]
## @api private
var _current: Callable = Callable()

## 失败的样本下标，成功或整笔失败为 -1。
## [br]
## @api private
var _failed_index: int = -1

## 最近一次操作的语义错误。
## [br]
## @api private
var _reason: StringName = &""

## 补偿失败的节点身份、位置与错误。
## [br]
## @api private
var _residuals: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

## 捕获笔画目标，历史只通过弱引用定位编辑场景。
## [br]
## @api private
func _init(
	source: PackedScene,
	parent: Node3D,
	root: Node,
	spacing: float
) -> void:
	_source = source
	_parent_ref = weakref(parent)
	_root_ref = weakref(root)
	_spacing = spacing
	command_name = "Brush 3D Scenes"


# --- 可重写钩子 / 虚方法 ---

## 按原顺序首次创建或重挂；中途失败仅撤回这次执行的节点。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 首个失败或上下文中断的错误码。
func _do_it() -> Error:
	if (
		_running
		or not _closed
		or is_executed()
	):
		return ERR_BUSY
	_running = true
	_reason = &""
	_failed_index = -1
	_residuals.clear()
	var error: Error = OK
	for index: int in range(_items.size()):
		var item: GFScenePlacementCreateCommand = _items[index]
		error = _check_detached_instance(item) if _registered else OK
		if error == OK:
			error = item.execute()
		if error != OK:
			_reason = &"creation_failed"
			_failed_index = index
			_rollback_created(index + 1)
			break
		if (
			not _current.is_null()
			and (
				not _current.is_valid()
				or not _current.call()
			)
		):
			_reason = &"operation_interrupted"
			_failed_index = index
			error = ERR_UNAVAILABLE
			_rollback_created(index + 1)
			break
	if error == OK:
		# 后创建节点的工具脚本也可能同步移动先前创建的实例。
		for index: int in range(_items.size()):
			if not _items[index].matches_placement():
				_failed_index = index
				_reason = &"operation_interrupted"
				error = ERR_UNAVAILABLE
				_rollback_created(_items.size())
				break
	_running = false
	if error != OK and _registered:
		_report_history_failure(error)
	return error


## 倒序撤销，如果中途失败则尽量恢复本次已撤销的后缀。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 首个子命令的撤销错误。
func _undo_it() -> Error:
	if _running:
		return ERR_BUSY
	_running = true
	_failed_index = -1
	_reason = &""
	_residuals.clear()
	var error: Error = OK
	for index: int in range(
		_items.size() - 1,
		-1,
		-1
	):
		error = _items[index].revert()
		if error != OK:
			_failed_index = index
			break
	if error == OK:
		for index: int in range(_items.size()):
			error = _check_detached_instance(_items[index])
			if error != OK:
				_failed_index = index
				break
	if error != OK:
		_reason = &"undo_failed"
		_restore_failed_undo()
	_running = false
	if error != OK and _registered:
		_report_history_failure(error)
	return error


## 选择笔画起始场景的原生历史。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 原编辑场景根。
func _get_undo_context() -> Object:
	return _root_ref.get_ref()


## 只允许把同一场景的父节点登记为结构写入目标。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 原父节点。
func _get_undo_targets() -> Array[Object]:
	var parent: Object = _parent_ref.get_ref()
	return [parent] if parent != null else []


# --- 框架内部方法 ---

## 接收一个有效拾取，按世界锚点间距去重，提交前不实例化场景。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param position: 已吸附及偏移的世界锚点。
## [br]
## @param world_transform: 同一次拾取的完整世界变换。
## [br]
## @return 已接受样本时为 true。
func add_sample(position: Vector3, world_transform: Transform3D) -> bool:
	if (
		_closed
		or _items.size() >= MAX_SAMPLES
		or not position.is_finite()
		or not world_transform.is_finite()
	):
		return false
	if not _items.is_empty() and position == _last_position:
		return false
	if _connected and position.distance_to(_last_position) < _spacing:
		return false
	var parent_value: Variant = _parent_ref.get_ref()
	var root_value: Variant = _root_ref.get_ref()
	if not parent_value is Node3D or not root_value is Node:
		return false
	var parent: Node3D = parent_value
	var root: Node = root_value
	var item: GFScenePlacementCreateCommand = GFScenePlacementCreateCommand.new()
	item.configure(
		_source,
		parent,
		root,
		world_transform
	)
	_items.append(item)
	_last_position = position
	_connected = true
	return true


## 断开连续采样距离，不跨越未命中区域插点。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func break_segment() -> void:
	_connected = false


## 查询当前已接收的实例数量。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 单笔样本数。
func get_sample_count() -> int:
	return _items.size()


## 首次执行并登记整笔历史，拒绝注册时补偿已创建实例。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param manager: 本次编辑场景的原生撤销管理器或等价适配器。
## [br]
## @param current: 首次创建期间检查上下文身份的无参回调。
## [br]
## @return 包含真实创建、注册和失败补偿情况的报告。
## [br]
## @schema return: Dictionary，包含 ok: bool、reason: StringName、error_code/failed_index: int、residuals: PackedStringArray。
func commit_stroke(manager: Object, current: Callable) -> Dictionary:
	if _closed:
		return _report(ERR_BUSY, &"apply_in_progress")
	_closed = true
	if manager == null:
		return _report(ERR_UNCONFIGURED, &"undo_manager_required")
	for method: StringName in [
		&"create_action",
		&"add_do_method",
		&"add_undo_method",
		&"commit_action",
	]:
		if not manager.has_method(method):
			return _report(ERR_INVALID_PARAMETER, &"undo_manager_incompatible")
	if (
		_items.is_empty()
		or not current.is_valid()
		or not current.call()
	):
		return _report(ERR_UNAVAILABLE, &"operation_interrupted")
	_current = current
	var error: Error = execute()
	_current = Callable()
	if error == OK:
		error = add_to_undo_manager(manager, false)
		if error != OK:
			_reason = &"history_rejected"
			_rollback_created(_items.size())
		else:
			_registered = true
	return _report(error, _reason)


# --- 私有/辅助方法 ---

## 撤销后须保留可重挂的原节点；外部已释放或排队删除的实例无法用于重做。
## [br]
## @api private
func _check_detached_instance(item: GFScenePlacementCreateCommand) -> Error:
	var node: Node3D = item.get_instance()
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return ERR_UNAVAILABLE
	return OK if node.get_parent() == null else ERR_ALREADY_IN_USE


## 即使单个对象被外部回调移动，也继续补偿本笔其他已挂接对象。
## [br]
## @api private
func _rollback_created(count: int) -> void:
	for index: int in range(
		count - 1,
		-1,
		-1
	):
		if _items[index].is_executed():
			var _reverted: Error = _items[index].revert()
	# 先前脱树的节点可能被后续移除回调重新挂接，须以整笔结束时的归属为准。
	for index: int in range(count):
		var item: GFScenePlacementCreateCommand = _items[index]
		var node: Node3D = item.get_instance()
		if is_instance_valid(node) and node.get_parent() != null:
			var error: Error = item.get_last_revert_error()
			_note_residual(
				index,
				error if error != OK else ERR_ALREADY_IN_USE
			)


## 仅重挂仍存活、已脱树的原实例，全部回调完成后再报告未恢复的样本。
## [br]
## @api private
func _restore_failed_undo() -> void:
	for item: GFScenePlacementCreateCommand in _items:
		if not item.is_executed() and _check_detached_instance(item) == OK:
			var _restored: Error = item.execute()
	for index: int in range(_items.size()):
		var item: GFScenePlacementCreateCommand = _items[index]
		if not item.is_executed() or not item.matches_placement():
			var error: Error = item.get_last_execute_error()
			_note_residual(
				index,
				error if error != OK else ERR_UNAVAILABLE
			)


## 记录未恢复的样本及其存活节点，供工具显示和人工定位。
## [br]
## @api private
func _note_residual(index: int, error: Error) -> void:
	var node: Node3D = _items[index].get_instance()
	var identity: String = "freed instance"
	if is_instance_valid(node):
		identity = (
			"%s #%d"
			% [str(node.get_path()) if node.is_inside_tree() else str(node.name), node.get_instance_id()]
		)
	var _recorded: bool = _residuals.append(
		"sample %d %s (%s)"
		% [
			index + 1,
			identity,
			error_string(error),
		]
	)


## 原生历史不会传播回调返回码，在编辑器输出中保留失败原因和补偿结果。
## [br]
## @api private
func _report_history_failure(error: Error) -> void:
	var residuals: String = ", ".join(_residuals) if not _residuals.is_empty() else "none"
	push_error(
		"[GFScenePlacementStrokeCommand][scene_placement_stroke_command.history_failed] Brush history failed at sample %d (%s). Unrestored samples: %s."
		% [
			_failed_index + 1,
			error_string(error),
			residuals,
		]
	)


## 复制补偿信息，避免历史对象和界面共享可写状态。
## [br]
## @api private
func _report(error: Error, reason: StringName) -> Dictionary:
	return {
		"ok": error == OK,
		"reason": reason,
		"error_code": error,
		"failed_index": _failed_index,
		"residuals": _residuals.duplicate(),
	}
