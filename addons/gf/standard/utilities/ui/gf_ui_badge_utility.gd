## GFUIBadgeUtility: 显式树结构的叶子计数与父级聚合。
##
## 主线程、只维护派生显示状态，不保存业务事实。结构在首次有效 configure 后冻结；
## 最多 4096 节点、64 层、4096 个绑定，每个叶子计数为 0 到 1000000000。
## 通知队列最多 4096 批；每次排空最多发送 256 批，其余在 tick 中继续。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFUIBadgeUtility
extends GFUtility


# --- 信号 ---

## 一次叶子更新所影响的节点计数；状态先完整提交，再按更新顺序通知。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param changes: 仅包含数值改变的叶子与祖先。
## [br]
## @schema changes: Dictionary[StringName, int]，节点 ID 对应新的非负聚合值。
signal counts_changed(changes: Dictionary)


# --- 私有变量 ---

## 冻结的单父级映射，空父级表示根。
## [br]
## @api private
var _parents: Dictionary[StringName, StringName] = {}

## 直接子节点数量，用于拒绝向聚合节点写入计数。
## [br]
## @api private
var _children: Dictionary[StringName, int] = {}

## 所有节点的当前计数，整数上限由结构与叶子限制保证。
## [br]
## @api private
var _counts: Dictionary[StringName, int] = {}

## 多个控件可独立订阅同一个节点。
## [br]
## @api private
var _bindings: Dictionary[int, _Binding] = {}

## 绑定身份不复用，解除旧 token 不会影响新绑定。
## [br]
## @api private
var _next_binding_id: int = 1

## 重入更新排队通知，避免新值通知后又收到旧值。
## [br]
## @api private
var _notifications: Array[Dictionary] = []

## 已提交更新序号，使新绑定忽略其初始值之前的排队通知。
## [br]
## @api private
var _change_sequence: int = 0

## 通知期间的重入写入只排队，不递归分发。
## [br]
## @api private
var _notifying: bool = false

## 每个实例只接受一次有效结构发布。
## [br]
## @api private
var _configured: bool = false

## 释放后拒绝全部写入与绑定。
## [br]
## @api private
var _disposed: bool = false


# --- GF 生命周期方法 ---

## 清理已销毁的普通 Object owner 与失效回调。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 未使用的帧间隔。
func tick(_delta: float) -> void:
	for binding: _Binding in _bindings.values():
		if not binding._token.is_active() or not binding._callback.is_valid():
			_unbind(binding._identity)
	_drain_notifications()


## 使全部 token 失效，丢弃等待通知并释放树数据。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for binding: _Binding in _bindings.values():
		var _deactivated: bool = binding._token._deactivate_from_source()
	_bindings.clear()
	_notifications.clear()
	_parents.clear()
	_children.clear()
	_counts.clear()
	super.dispose()


# --- 公共方法 ---

## 原子验证并冻结树；无效输入不会占用配置机会。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param parents: ID 到父级 ID；允许多个根，不允许缺失父级、自环或环。
## [br]
## @schema parents: Dictionary[String or StringName, String or StringName]。空父级为根；节点 ID 非空、无首尾空白且不超过 256 字符，规范化重复 ID 被拒绝。
## [br]
## @return 首次有效配置为 true；失败不改变状态。
func configure(parents: Dictionary) -> bool:
	var prepared: Dictionary = _prepare_configuration(parents)
	var report: Dictionary = prepared["report"]
	if not GFVariantData.get_option_bool(report, "ok"):
		return false
	var candidate: Dictionary[StringName, StringName] = prepared["parents"]
	_parents = candidate
	for identity: StringName in candidate:
		_counts[identity] = 0
		_children[identity] = 0
	for parent: StringName in candidate.values():
		if parent != &"":
			_children[parent] += 1
	_configured = true
	return true


## 只读检查当前服务能否接受树配置，不占用配置机会、不创建绑定或发布计数。
##
## configure 在执行时重新校验；有效报告不会为后来修改的树提供准入资格。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param parents: 与 configure 相同的 ID 到父级映射。
## [br]
## @schema parents: 与 configure.parents 相同；错误路径中的节点 ID 按 / 分段路径转义。
## [br]
## @return 当前服务与输入的独立校验报告；不输出错误日志。
## [br]
## @schema return: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。 depth_limit 的 observed 为已确认链长度下界。
func validate_configuration(parents: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare_configuration(parents)
	var report: Dictionary = prepared["report"]
	return report


## 写入项目计算出的一个叶子计数，沿唯一父链增量更新。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param badge_id: 已声明的叶子 ID。
## [br]
## @param count: 0 到 1000000000 的计数。
## [br]
## @return 写入有效时为 true；相同值不发通知。
func set_leaf_count(badge_id: StringName, count: int) -> bool:
	if (
		_disposed
		or not is_leaf(badge_id)
		or count < 0
		or count > 1000000000
		or _notifications.size() >= 4096
	):
		return false
	var difference: int = count - _counts[badge_id]
	if difference == 0:
		return true
	var changes: Dictionary[StringName, int] = {}
	var cursor: StringName = badge_id
	while cursor != &"":
		_counts[cursor] += difference
		changes[cursor] = _counts[cursor]
		cursor = _parents[cursor]
	_change_sequence += 1
	_notifications.append({ "sequence": _change_sequence, "changes": changes })
	_drain_notifications()
	return true


## 判断节点能否接受业务计数输入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param badge_id: 节点 ID。
## [br]
## @return 已声明且没有子节点时为 true。
func is_leaf(badge_id: StringName) -> bool:
	return _children.has(badge_id) and _children[badge_id] == 0


## 查询当前计数，不把未知 ID 当作没有红点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param badge_id: 节点 ID。
## [br]
## @return 聚合值；未知节点或已释放服务返回 -1。
func get_count(badge_id: StringName) -> int:
	return _counts.get(badge_id, -1)


## 为一个控件建立独立绑定，并立即发送当前计数。
##
## 回调接收一个 int；可以在回调中更新其他叶子或解除绑定。
## 无 owner 时必须显式 cancel；回调自身不得强持有期望自动释放的 owner。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param badge_id: 已声明节点 ID。
## [br]
## @param callback: 接收 count:int 的有效 Callable。
## [br]
## @param owner: 可选弱生命周期 owner；Node 必须在树中。
## [br]
## @return 独立取消 token；无效参数、超限或已释放返回 null。
func bind_count(
	badge_id: StringName,
	callback: Callable,
	owner: Object = null
) -> GFSubscriptionToken:
	if (
		_disposed
		or not _counts.has(badge_id)
		or not callback.is_valid()
		or callback.get_argument_count() != 1
		or _bindings.size() >= 4096
		or _next_binding_id == 9223372036854775807
	):
		return null
	if owner != null:
		if not is_instance_valid(owner):
			return null
		if owner is Node:
			var node: Node = owner
			if not node.is_inside_tree():
				return null
	var identity: int = _next_binding_id
	_next_binding_id += 1
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_unbind")
	var cleanup: Callable = func() -> void:
		var _cleanup_result: Dictionary = invocation.invoke([identity])
	var binding: _Binding = _Binding.new()
	binding._identity = identity
	binding._badge_id = badge_id
	binding._callback = callback
	binding._after_sequence = _change_sequence
	binding._token = GFLifetimeSubscription.new(owner, cleanup) if owner != null else GFSubscriptionToken.new(cleanup)
	_bindings[identity] = binding
	var _result: Variant = callback.call(_counts[badge_id])
	return binding._token


# --- 私有/辅助方法 ---

## 在独立候选中完成结构验证，公开报告不暴露候选或保留输入引用。
## [br]
## @api private
func _prepare_configuration(parents: Dictionary) -> Dictionary:
	if _disposed:
		return { "report": _validation_report("service_disposed") }
	if _configured:
		return { "report": _validation_report("already_configured") }
	if parents.is_empty():
		return { "report": _validation_report("required", "/parents") }
	if parents.size() > 4096:
		return {
			"report": _validation_report(
				"node_limit",
				"/parents",
				4096,
				parents.size()
			),
		}
	var candidate: Dictionary[StringName, StringName] = {}
	for key: Variant in parents:
		var report: Dictionary = _validate_badge_id(
			key,
			false,
			"/parents"
		)
		if not GFVariantData.get_option_bool(report, "ok"):
			return { "report": report }
		var identity: StringName = StringName(GFVariantData.to_text(key))
		var path: String = "/parents/" + String(identity).replace("~", "~0").replace("/", "~1")
		report = _validate_badge_id(
			parents[key],
			true,
			path
		)
		if not GFVariantData.get_option_bool(report, "ok"):
			return { "report": report }
		if candidate.has(identity):
			return { "report": _validation_report("duplicate_id", path) }
		candidate[identity] = StringName(GFVariantData.to_text(parents[key]))
	for identity: StringName in candidate:
		var cursor: StringName = identity
		var visited: Dictionary[StringName, bool] = {}
		while cursor != &"":
			var path: String = "/parents/" + String(identity).replace("~", "~0").replace("/", "~1")
			if not candidate.has(cursor):
				return { "report": _validation_report("missing_parent", path) }
			if visited.has(cursor):
				return { "report": _validation_report("cycle", path) }
			if visited.size() >= 64:
				var report: Dictionary = _validation_report(
					"depth_limit",
					path,
					64,
					visited.size() + 1
				)
				report["observed_is_lower_bound"] = true
				return { "report": report }
			visited[cursor] = true
			cursor = candidate[cursor]
	return { "report": _validation_report(), "parents": candidate }


## 保留 String/StringName 身份兼容性，区分长度超限和格式错误。
## [br]
## @api private
static func _validate_badge_id(
	value: Variant,
	allow_empty: bool,
	path: String
) -> Dictionary:
	if not value is String and not value is StringName:
		return _validation_report("invalid_type", path)
	var text: String = GFVariantData.to_text(value)
	if text.length() > 256:
		return _validation_report(
			"length_limit",
			path,
			256,
			text.length()
		)
	if not _is_valid_id(value, allow_empty):
		return _validation_report("invalid_id", path)
	return _validation_report()


## 每次创建独立纯数据报告，不保存全局错误或可复用的准入资格。
## [br]
## @api private
static func _validation_report(
	error_kind: String = "",
	path: String = "",
	limit: int = -1,
	observed: int = -1
) -> Dictionary:
	var report: Dictionary = {
		"ok": error_kind.is_empty(),
		"error_kind": error_kind,
		"path": path,
	}
	if limit >= 0:
		report["limit"] = limit
		report["observed"] = observed
	return report


## 在转换为 StringName 前拒绝非文本与隐式空白规范化。
## [br]
## @api private
static func _is_valid_id(value: Variant, allow_empty: bool) -> bool:
	if not value is String and not value is StringName:
		return false
	var text: String = GFVariantData.to_text(value)
	return (
		text.length() <= 256
		and text == text.strip_edges()
		and (
			allow_empty
			or not text.is_empty()
		)
	)


## 精确移除一个绑定并使 token 失效；重复解除不影响其他控件。
## [br]
## @api private
func _unbind(identity: int) -> void:
	var binding: _Binding = _bindings.get(identity)
	if binding == null:
		return
	var _removed: bool = _bindings.erase(identity)
	var _deactivated: bool = binding._token._deactivate_from_source()


## 队列顺序发布每个已提交更新；回调移除的绑定不会再收到本批通知。
## [br]
## @api private
func _drain_notifications() -> void:
	if _notifying:
		return
	_notifying = true
	var sent: int = 0
	while (
		not _notifications.is_empty()
		and not _disposed
		and sent < 256
	):
		sent += 1
		var pending_change: Dictionary = _notifications.pop_front()
		var sequence: int = GFVariantData.get_option_int(pending_change, "sequence")
		var changes: Dictionary = GFVariantData.get_option_dictionary(pending_change, "changes")
		var bindings: Array[_Binding] = _bindings.values()
		counts_changed.emit(changes.duplicate())
		for binding: _Binding in bindings:
			if _bindings.get(binding._identity) != binding:
				continue
			if not binding._token.is_active() or not binding._callback.is_valid():
				_unbind(binding._identity)
				continue
			if sequence > binding._after_sequence and changes.has(binding._badge_id):
				var _result: Variant = binding._callback.call(changes[binding._badge_id])
	_notifying = false


# --- 内部类 ---

## 保存一个绑定的精确身份与生命周期，不持有显示控件。
## [br]
## @api private
class _Binding extends RefCounted:


	# --- 私有变量 ---

	## 服务内不复用的绑定 ID。
	## [br]
	## @api private
	var _identity: int = 0

	## 被观察的单个节点 ID。
	## [br]
	## @api private
	var _badge_id: StringName = &""

	## 初始计数对应的提交序号，不消费更早已排队的值。
	## [br]
	## @api private
	var _after_sequence: int = 0

	## 项目提供的计数接收者。
	## [br]
	## @api private
	var _callback: Callable = Callable()

	## 取消与 owner 生命周期的统一句柄。
	## [br]
	## @api private
	var _token: GFSubscriptionToken = null
