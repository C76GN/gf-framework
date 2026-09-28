## GFInventoryTransferTransaction: 两个槽位库存之间的一次性原子转移句柄。
##
## `prepare()` 只构建有界隔离候选；`commit()` 会重新取得稳定顺序锁、校验
## model identity 与 revision，并重新规划后才执行无回调的内存替换。跨模型成功
## 时先同时写入两边状态，再依次派发来源、目标和事务终态通知。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFInventoryTransferTransaction
extends RefCounted


# --- 信号 ---

## 事务提交尝试进入终态时发出一次。成功提交时，该信号只在所有参与库存的
## 内存状态提交且库存通知派发完成后发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result: 不保留模型或候选堆叠的隔离终态结果。
signal completed(result: GFInventoryTransferResult)


# --- 私有变量 ---

## 来源库存模型的弱引用。
## [br]
## @api private
var _source_ref: WeakRef = null

## 目标库存模型的弱引用。
## [br]
## @api private
var _target_ref: WeakRef = null

## prepare 时记录的来源模型实例 ID。
## [br]
## @api private
var _source_instance_id: int = 0

## prepare 时记录的目标模型实例 ID。
## [br]
## @api private
var _target_instance_id: int = 0

## prepare 时记录的来源库存 revision。
## [br]
## @api private
var _source_revision: int = -1

## prepare 时记录的目标库存 revision。
## [br]
## @api private
var _target_revision: int = -1

## 转移来源槽位索引。
## [br]
## @api private
var _source_slot: int = -1

## 目标槽位索引；-1 表示自动选择。
## [br]
## @api private
var _target_slot: int = -1

## prepare 收到的原始数量参数。
## [br]
## @api private
var _requested_amount_input: int = 0

## 是否允许来源或目标容量不足时部分转移。
## [br]
## @api private
var _allow_partial: bool = false

## 标记来源和目标是否为同一库存模型。
## [br]
## @api private
var _same_model: bool = false

## prepare 阶段来源库存快照摘要。
## [br]
## @api private
var _prepared_source_sha: String = ""

## prepare 阶段完整转移计划摘要。
## [br]
## @api private
var _prepared_plan_sha: String = ""

## prepare 阶段接受的转移数量。
## [br]
## @api private
var _prepared_amount: int = 0

## 标记 commit 是否正在执行。
## [br]
## @api private
var _commit_in_progress: bool = false

## prepare 阶段的隔离结果。
## [br]
## @api private
var _prepare_result: GFInventoryTransferResult = null

## commit 完成后的唯一终态结果。
## [br]
## @api private
var _result: GFInventoryTransferResult = null

## 标记 completed 信号是否已经发出。
## [br]
## @api private
var _completion_emitted: bool = false


# --- 公共方法 ---

## 构建一次不写入模型的有界转移计划。
##
## `target_slot == -1` 复用目标库存 `add_item()` 的合并、空槽和增长顺序；
## 非负目标槽复用 `add_item_to_slot()` 的单槽规则。`amount <= 0` 请求来源
## 堆叠全部数量。同一模型只接受显式目标槽，并按 `move_between_slots()`
## 规则生成候选后经框架内部原子替换提交，不动态调用可重写公共方法。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source: 来源槽位库存。
## [br]
## @param target: 目标槽位库存。
## [br]
## @param source_slot: 来源槽位索引。
## [br]
## @param target_slot: 目标槽位索引；-1 表示按目标库存自动选择。
## [br]
## @param amount: 请求数量；小于等于 0 表示来源堆叠全部数量。
## [br]
## @param allow_partial: 来源或目标容量不足时是否允许部分转移。
## [br]
## @return: 一次性事务句柄；使用 `get_prepare_result()` 检查规划结果。
static func prepare(
	source: GFSlotInventoryModel,
	target: GFSlotInventoryModel,
	source_slot: int,
	target_slot: int = -1,
	amount: int = 0,
	allow_partial: bool = false
) -> GFInventoryTransferTransaction:
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.new()
	transaction._prepare(
		source,
		target,
		source_slot,
		target_slot,
		amount,
		allow_partial
	)
	return transaction


## 检查 prepare 是否生成可提交计划。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 当前未完成且 prepare 状态有效时返回 true。
func is_prepared() -> bool:
	return (
		_result == null
		and _prepare_result != null
		and _prepare_result.get_status() == GFInventoryTransferResult.STATUS_PREPARED
	)


## 检查句柄是否已进入唯一终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: `commit()` 已被消费时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取 prepare 阶段结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 隔离规划结果；配置尚未完成时返回 null。
func get_prepare_result() -> GFInventoryTransferResult:
	return _prepare_result.duplicate_result() if _prepare_result != null else null


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: `commit()` 后的隔离结果；尚未提交时返回 null。
func get_result() -> GFInventoryTransferResult:
	return _result.duplicate_result() if _result != null else null


## 一次性提交已准备计划。
##
## 跨模型提交重新规划并完成全部验证后，最终阶段只替换已验证内存候选，
## 不调用规则或项目回调，因此没有需要补偿或表示 unknown state 的失败阶段。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 唯一终态结果；重复调用返回首次终态的隔离副本。
func commit() -> GFInventoryTransferResult:
	if _result != null:
		return _result.duplicate_result()
	if _commit_in_progress:
		return _complete_reentrant_commit()
	if not is_prepared():
		_complete(_prepare_result if _prepare_result != null else _make_result(
			GFInventoryTransferResult.STATUS_INVALID_REQUEST,
			&"",
			0,
			0,
			-1,
			-1
		))
		_emit_completed()
		return _result.duplicate_result()
	var source: GFSlotInventoryModel = _get_source()
	var target: GFSlotInventoryModel = _get_target()
	if (
		source == null
		or target == null
		or source.get_instance_id() != _source_instance_id
		or target.get_instance_id() != _target_instance_id
	):
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_STALE_REVISION,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			-1,
			-1
		))
		_emit_completed()
		return _result.duplicate_result()
	_commit_in_progress = true
	var committed_result: GFInventoryTransferResult
	if _same_model:
		committed_result = _commit_same_model(source)
	else:
		committed_result = _commit_cross_model(source, target)
	_commit_in_progress = false
	return committed_result


# --- 私有/辅助方法 ---

## 保存请求状态，取得模型锁并构建初始同模型或跨模型计划。
## [br]
## @api private
func _prepare(
	source: GFSlotInventoryModel,
	target: GFSlotInventoryModel,
	source_slot: int,
	target_slot: int,
	amount: int,
	allow_partial: bool
) -> void:
	_source_slot = source_slot
	_target_slot = target_slot
	_requested_amount_input = amount
	_allow_partial = allow_partial
	if source == null or target == null or source_slot < 0 or target_slot < -1:
		_prepare_result = _make_result(
			GFInventoryTransferResult.STATUS_INVALID_REQUEST,
			&"",
			maxi(amount, 0),
			0,
			-1,
			-1
		)
		return
	_same_model = source == target
	if _same_model and target_slot < 0:
		_prepare_result = _make_result(
			GFInventoryTransferResult.STATUS_INVALID_REQUEST,
			&"",
			maxi(amount, 0),
			0,
			source.get_revision(),
			target.get_revision()
		)
		return
	_source_ref = weakref(source)
	_target_ref = weakref(target)
	_source_instance_id = source.get_instance_id()
	_target_instance_id = target.get_instance_id()
	if not _lock_models(source, target):
		_prepare_result = _make_result(
			GFInventoryTransferResult.STATUS_BUSY,
			&"",
			maxi(amount, 0),
			0,
			source.get_revision(),
			target.get_revision()
		)
		return
	_source_revision = source.get_revision()
	_target_revision = target.get_revision()
	var bundle: Dictionary = (
		_build_same_plan(source)
		if _same_model
		else _build_cross_plan(source, target)
	)
	_unlock_models(source, target)
	var status: StringName = GFVariantData.get_option_string_name(
		bundle,
		"status",
		GFInventoryTransferResult.STATUS_INVALID_REQUEST
	)
	var item_id: StringName = GFVariantData.get_option_string_name(bundle, "item_id")
	var requested_amount: int = GFVariantData.get_option_int(
		bundle,
		"requested_amount",
		maxi(amount, 0)
	)
	var accepted_amount: int = GFVariantData.get_option_int(bundle, "accepted_amount")
	if status == GFInventoryTransferResult.STATUS_PREPARED:
		_prepared_amount = accepted_amount
		_prepared_source_sha = GFVariantData.get_option_string(bundle, "source_sha")
		_prepared_plan_sha = GFVariantData.get_option_string(bundle, "plan_sha")
	_prepare_result = _make_result(
		status,
		item_id,
		requested_amount,
		accepted_amount,
		_source_revision,
		_target_revision
	)


## 重新锁定并验证两侧模型及计划，再原子替换两侧候选和派发通知。
## [br]
## @api private
func _commit_cross_model(
	source: GFSlotInventoryModel,
	target: GFSlotInventoryModel
) -> GFInventoryTransferResult:
	if not _lock_models(source, target):
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_BUSY,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			source.get_revision(),
			target.get_revision()
		))
		_emit_completed()
		return _result.duplicate_result()
	if source.get_revision() != _source_revision or target.get_revision() != _target_revision:
		_unlock_models(source, target)
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_STALE_REVISION,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			source.get_revision(),
			target.get_revision()
		))
		_emit_completed()
		return _result.duplicate_result()
	var bundle: Dictionary = _build_cross_plan(source, target)
	if _result != null:
		_unlock_models(source, target)
		return _result.duplicate_result()
	if (
		GFVariantData.get_option_string_name(bundle, "status")
		!= GFInventoryTransferResult.STATUS_PREPARED
		or GFVariantData.get_option_int(bundle, "accepted_amount") != _prepared_amount
		or GFVariantData.get_option_string(bundle, "source_sha") != _prepared_source_sha
		or GFVariantData.get_option_string(bundle, "plan_sha") != _prepared_plan_sha
	):
		_unlock_models(source, target)
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_STALE_PLAN,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			source.get_revision(),
			target.get_revision()
		))
		_emit_completed()
		return _result.duplicate_result()
	var source_plan: Dictionary = GFVariantData.get_option_dictionary(bundle, "source_plan")
	var target_plan: Dictionary = GFVariantData.get_option_dictionary(bundle, "target_plan")
	source.apply_inventory_transfer_plan_for_framework(self, source_plan, true)
	target.apply_inventory_transfer_plan_for_framework(self, target_plan, false)
	_complete(_make_result(
		GFInventoryTransferResult.STATUS_COMMITTED,
		_prepare_result.get_item_id(),
		_prepare_result.get_requested_amount(),
		_prepared_amount,
		source.get_revision(),
		target.get_revision()
	))
	source.flush_inventory_transfer_events_for_framework(self)
	target.flush_inventory_transfer_events_for_framework(self)
	_emit_completed()
	_unlock_models(source, target)
	return _result.duplicate_result()


## 重新锁定并验证同一模型的计划，再替换候选、派发通知并返回终态。
## [br]
## @api private
func _commit_same_model(model: GFSlotInventoryModel) -> GFInventoryTransferResult:
	if not _lock_models(model, model):
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_BUSY,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			model.get_revision(),
			model.get_revision()
		))
		_emit_completed()
		return _result.duplicate_result()
	if model.get_revision() != _source_revision:
		_unlock_models(model, model)
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_STALE_REVISION,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			model.get_revision(),
			model.get_revision()
		))
		_emit_completed()
		return _result.duplicate_result()
	var bundle: Dictionary = _build_same_plan(model)
	if _result != null:
		_unlock_models(model, model)
		return _result.duplicate_result()
	if (
		GFVariantData.get_option_string_name(bundle, "status")
		!= GFInventoryTransferResult.STATUS_PREPARED
		or GFVariantData.get_option_int(bundle, "accepted_amount") != _prepared_amount
		or GFVariantData.get_option_string(bundle, "source_sha") != _prepared_source_sha
		or GFVariantData.get_option_string(bundle, "plan_sha") != _prepared_plan_sha
	):
		_unlock_models(model, model)
		_complete(_make_result(
			GFInventoryTransferResult.STATUS_STALE_PLAN,
			_prepare_result.get_item_id(),
			_prepare_result.get_requested_amount(),
			0,
			model.get_revision(),
			model.get_revision()
		))
		_emit_completed()
		return _result.duplicate_result()
	var plan: Dictionary = GFVariantData.get_option_dictionary(bundle, "same_plan")
	model.apply_inventory_transfer_plan_for_framework(self, plan, true)
	_complete(_make_result(
		GFInventoryTransferResult.STATUS_COMMITTED,
		_prepare_result.get_item_id(),
		_prepare_result.get_requested_amount(),
		_prepared_amount,
		model.get_revision(),
		model.get_revision()
	))
	model.flush_inventory_transfer_events_for_framework(self)
	_emit_completed()
	_unlock_models(model, model)
	return _result.duplicate_result()


## 组合来源和目标候选，并复核接受数量及最终计划摘要。
## [br]
## @api private
func _build_cross_plan(
	source: GFSlotInventoryModel,
	target: GFSlotInventoryModel
) -> Dictionary:
	var initial_budget: Dictionary = _make_budget()
	var initial_source: Dictionary = GFInventoryTransferPlanner.plan_source(
		source,
		self,
		_source_slot,
		_requested_amount_input,
		_allow_partial,
		initial_budget
	)
	var source_status: StringName = GFVariantData.get_option_string_name(
		initial_source,
		"status",
		GFInventoryTransferResult.STATUS_INVALID_REQUEST
	)
	if source_status != GFInventoryTransferResult.STATUS_PREPARED:
		return _failure_bundle(initial_source, source_status)
	var requested_amount: int = GFVariantData.get_option_int(
		initial_source,
		"requested_amount"
	)
	var transferable_amount: int = GFVariantData.get_option_int(
		initial_source,
		"transferable_amount"
	)
	var initial_target: Dictionary = GFInventoryTransferPlanner.plan_target(
		target,
		self,
		GFVariantData.get_option_string_name(initial_source, "item_id"),
		transferable_amount,
		GFVariantData.get_option_dictionary(initial_source, "instance_data"),
		_target_slot,
		_allow_partial,
		initial_budget
	)
	if _result != null:
		return {}
	var target_status: StringName = GFVariantData.get_option_string_name(
		initial_target,
		"status",
		GFInventoryTransferResult.STATUS_INVALID_REQUEST
	)
	if target_status != GFInventoryTransferResult.STATUS_PREPARED:
		var failed_target: Dictionary = _failure_bundle(initial_target, target_status)
		failed_target["item_id"] = GFVariantData.get_option_string_name(
			initial_source,
			"item_id"
		)
		failed_target["requested_amount"] = requested_amount
		return failed_target
	var accepted_amount: int = GFVariantData.get_option_int(initial_target, "accepted_amount")
	var final_budget: Dictionary = _make_budget()
	var target_plan: Dictionary = GFInventoryTransferPlanner.plan_target(
		target,
		self,
		GFVariantData.get_option_string_name(initial_source, "item_id"),
		accepted_amount,
		GFVariantData.get_option_dictionary(initial_source, "instance_data"),
		_target_slot,
		false,
		final_budget
	)
	if _result != null:
		return {}
	var source_plan: Dictionary = GFInventoryTransferPlanner.plan_source(
		source,
		self,
		_source_slot,
		accepted_amount,
		true,
		final_budget
	)
	if (
		GFVariantData.get_option_string_name(source_plan, "status")
		!= GFInventoryTransferResult.STATUS_PREPARED
		or GFVariantData.get_option_string_name(target_plan, "status")
		!= GFInventoryTransferResult.STATUS_PREPARED
	):
		return {
			"status": GFInventoryTransferResult.STATUS_STALE_PLAN,
			"item_id": GFVariantData.get_option_string_name(initial_source, "item_id"),
			"requested_amount": requested_amount,
			"accepted_amount": 0,
		}
	var plan_sha: String = _plan_sha([
		GFVariantData.get_option_string(source_plan, "before_sha"),
		GFVariantData.get_option_string(source_plan, "after_sha"),
		GFVariantData.get_option_string(source_plan, "config_sha"),
		GFVariantData.get_option_string(target_plan, "before_sha"),
		GFVariantData.get_option_string(target_plan, "after_sha"),
		GFVariantData.get_option_string(target_plan, "config_sha"),
		accepted_amount,
	])
	return {
		"status": GFInventoryTransferResult.STATUS_PREPARED,
		"item_id": GFVariantData.get_option_string_name(source_plan, "item_id"),
		"requested_amount": requested_amount,
		"accepted_amount": accepted_amount,
		"source_plan": source_plan,
		"target_plan": target_plan,
		"source_sha": GFVariantData.get_option_string(source_plan, "before_sha"),
		"plan_sha": plan_sha,
	}


## 使用同模型规划器创建候选并计算来源与计划摘要。
## [br]
## @api private
func _build_same_plan(model: GFSlotInventoryModel) -> Dictionary:
	var plan: Dictionary = GFInventoryTransferPlanner.plan_same_model(
		model,
		self,
		_source_slot,
		_target_slot,
		_requested_amount_input,
		_allow_partial,
		_make_budget()
	)
	var status: StringName = GFVariantData.get_option_string_name(
		plan,
		"status",
		GFInventoryTransferResult.STATUS_INVALID_REQUEST
	)
	if status != GFInventoryTransferResult.STATUS_PREPARED:
		return _failure_bundle(plan, status)
	return {
		"status": status,
		"item_id": GFVariantData.get_option_string_name(plan, "item_id"),
		"requested_amount": GFVariantData.get_option_int(plan, "requested_amount"),
		"accepted_amount": GFVariantData.get_option_int(plan, "accepted_amount"),
		"same_plan": plan,
		"source_sha": GFVariantData.get_option_string(plan, "before_sha"),
		"plan_sha": _plan_sha([
			GFVariantData.get_option_string(plan, "before_sha"),
			GFVariantData.get_option_string(plan, "after_sha"),
			GFVariantData.get_option_string(plan, "config_sha"),
			GFVariantData.get_option_int(plan, "accepted_amount"),
		]),
	}


## 将失败计划规范为状态、物品 ID、请求数量和零接受量的结果。
## [br]
## @api private
func _failure_bundle(plan: Dictionary, status: StringName) -> Dictionary:
	return {
		"status": status,
		"item_id": GFVariantData.get_option_string_name(plan, "item_id"),
		"requested_amount": GFVariantData.get_option_int(
			plan,
			"requested_amount",
			maxi(_requested_amount_input, 0)
		),
		"accepted_amount": 0,
	}


## 将 commit 重入尝试封闭为 BUSY 终态并发出一次完成信号。
## [br]
## @api private
func _complete_reentrant_commit() -> GFInventoryTransferResult:
	var source: GFSlotInventoryModel = _get_source()
	var target: GFSlotInventoryModel = _get_target()
	var source_revision: int = -1
	var target_revision: int = -1
	if source != null and target != null:
		source_revision = source.get_revision()
		target_revision = target.get_revision()
	_complete(_make_result(
		GFInventoryTransferResult.STATUS_BUSY,
		_prepare_result.get_item_id(),
		_prepare_result.get_requested_amount(),
		0,
		source_revision,
		target_revision
	))
	_emit_completed()
	return _result.duplicate_result()


## 按实例 ID 顺序取得一个或两个模型锁；第二把锁失败时回滚第一把。
## [br]
## @api private
func _lock_models(
	source: GFSlotInventoryModel,
	target: GFSlotInventoryModel
) -> bool:
	if source == target:
		return source.lock_inventory_transfer_for_framework(self)
	var first: GFSlotInventoryModel = source
	var second: GFSlotInventoryModel = target
	if first.get_instance_id() > second.get_instance_id():
		first = target
		second = source
	if not first.lock_inventory_transfer_for_framework(self):
		return false
	if not second.lock_inventory_transfer_for_framework(self):
		first.unlock_inventory_transfer_for_framework(self)
		return false
	return true


## 按加锁时相反的顺序释放一个或两个模型锁。
## [br]
## @api private
func _unlock_models(
	source: GFSlotInventoryModel,
	target: GFSlotInventoryModel
) -> void:
	if source == target:
		source.unlock_inventory_transfer_for_framework(self)
		return
	var first: GFSlotInventoryModel = source
	var second: GFSlotInventoryModel = target
	if first.get_instance_id() > second.get_instance_id():
		first = target
		second = source
	second.unlock_inventory_transfer_for_framework(self)
	first.unlock_inventory_transfer_for_framework(self)


## 从弱引用取得来源库存，并检查其脚本类型。
## [br]
## @api private
func _get_source() -> GFSlotInventoryModel:
	if _source_ref == null:
		return null
	var value: Object = _source_ref.get_ref()
	if value is GFSlotInventoryModel:
		var source: GFSlotInventoryModel = value
		return source
	return null


## 从弱引用取得目标库存，并检查其脚本类型。
## [br]
## @api private
func _get_target() -> GFSlotInventoryModel:
	if _target_ref == null:
		return null
	var value: Object = _target_ref.get_ref()
	if value is GFSlotInventoryModel:
		var target: GFSlotInventoryModel = value
		return target
	return null


## 构造闭合的类型化结果，先规范数量再调用一次性配置接口。
## [br]
## @api private
func _make_result(
	status: StringName,
	item_id: StringName,
	requested_amount: int,
	transferred_amount: int,
	source_revision: int,
	target_revision: int
) -> GFInventoryTransferResult:
	var result: GFInventoryTransferResult = GFInventoryTransferResult.new()
	var configured: bool = result.configure_for_framework(
		status,
		item_id,
		maxi(requested_amount, 0),
		clampi(transferred_amount, 0, maxi(requested_amount, 0)),
		_source_slot,
		_target_slot,
		source_revision,
		target_revision
	)
	assert(configured, "GFInventoryTransferTransaction 只能构造闭合结果。")
	return result


## 保存终态结果的隔离副本；重复完成会触发断言。
## [br]
## @api private
func _complete(result: GFInventoryTransferResult) -> void:
	assert(_result == null)
	_result = result.duplicate_result()


## 仅在已有终态且尚未发出时派发 completed 信号。
## [br]
## @api private
func _emit_completed() -> void:
	if _result == null or _completion_emitted:
		return
	_completion_emitted = true
	completed.emit(_result.duplicate_result())


## 创建包含槽位、值项、字节、递归路径及失败标记的规划预算。
## [br]
## @api private
func _make_budget() -> Dictionary:
	return {
		"slots": 0,
		"items": 0,
		"bytes": 0,
		"active": [],
		"failed": false,
	}


## 对计划摘要组成项的序列化文本计算 SHA-256。
## [br]
## @api private
func _plan_sha(parts: Array) -> String:
	return var_to_str(parts).sha256_text()
