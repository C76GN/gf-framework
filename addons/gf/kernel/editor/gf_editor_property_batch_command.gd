@tool

## GFEditorPropertyBatchCommand: 通用多目标属性事务命令。
##
## 对调用方显式提供的 Object 属性先做全量零写入预检，再按稳定顺序提交。
## 任一写入或最终状态验证失败时，会按相反顺序恢复本次尝试前的全部目标属性。
## 命令只保证显式属性值边界，不代理 setter 的外部副作用、文件保存或业务事务。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 10.0.0
## [br]
## @layer kernel/editor
class_name GFEditorPropertyBatchCommand
extends GFEditorCommand


# --- 常量 ---

## 尚未验证或执行。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_PENDING: StringName = &"pending"

## 全量预检通过。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_READY: StringName = &"ready"

## 属性事务已提交。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_COMMITTED: StringName = &"committed"

## 属性事务已撤销。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_REVERTED: StringName = &"reverted"

## 未完整补偿的事务已恢复到该次操作开始前状态。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_RECOVERED: StringName = &"recovered"

## 全量预检失败，未开始写入。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_PREFLIGHT_FAILED: StringName = &"preflight_failed"

## 提交失败，且已恢复本次尝试前状态。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_APPLY_FAILED: StringName = &"apply_failed"

## 撤销失败，且已恢复撤销前状态。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_REVERT_FAILED: StringName = &"revert_failed"

## 补偿写入未完整恢复属性状态。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"

## 事务条目中用于标记直接属性选择器的内部模式值。
## [br]
## @api private
const _SELECTOR_DIRECT: StringName = &"direct"

## 事务条目中用于标记 NodePath 索引属性选择器的内部模式值。
## [br]
## @api private
const _SELECTOR_PATH: StringName = &"indexed_path"

## 检查属性声明并读写 Object 属性的工具脚本。
## [br]
## @api private
const _GF_OBJECT_PROPERTY_TOOLS_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_object_property_tools.gd"
)

## 对 Variant 选项进行类型化访问、复制和值比较的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_variant_access.gd"
)


# --- 私有变量 ---

## configure 收到并规范复制后的变更输入。
## [br]
## @api private
var _changes: Array[Dictionary] = []

## 首次成功预检时保存的执行条目，用于后续重做和撤销定位相同属性。
## [br]
## @api private
var _execution_entries: Array[Dictionary] = []

## 首次成功执行前各条目的旧值，作为命令撤销目标。
## [br]
## @api private
var _first_snapshots: Array = []

## 是否在 configure 时请求复制新值中的 Resource。
## [br]
## @api private
var _duplicate_resources: bool = false

## 是否已捕获首次执行前快照并封存配置。
## [br]
## @api private
var _has_first_snapshot: bool = false

## 上次事务操作是否仍需显式恢复 attempt guard。
## [br]
## @api private
var _recovery_required: bool = false

## 阻止同一命令在事务执行或恢复期间再次进入操作。
## [br]
## @api private
var _operation_in_progress: bool = false

## 最近一次未完整补偿时需要写回的 attempt guard 值。
## [br]
## @api private
var _pending_recovery_values: Array = []

## 恢复 attempt guard 时是否按索引逆序写入。
## [br]
## @api private
var _pending_recovery_reverse_order: bool = true

## 最近一次预检、提交、撤销或恢复报告的深复制副本。
## [br]
## @api private
var _last_transaction_report: Dictionary = {}


# --- 公共方法 ---

## 配置属性事务。
##
## changes 必须至少包含一项。每个 change 必须包含 target、new_value，以及且仅包含 property_name 或
## property_path。property_name 表示精确直接属性名；property_path 使用 Godot
## indexed path 语义。可选 metadata 会复制到条目和错误报告。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param changes: 非空属性变更数组。
## [br]
## @param options: 配置选项。
## [br]
## @schema changes: 非空 Array[Dictionary]，每项包含 target: Object、new_value: Variant、property_name: StringName/String 或 property_path: NodePath/String，以及可选 metadata: Dictionary。
## [br]
## @schema options: Dictionary，可包含 command_name、metadata 和 duplicate_resources。
## [br]
## @return 当前命令。
func configure(
	changes: Array[Dictionary],
	options: Dictionary = {}
) -> GFEditorPropertyBatchCommand:
	if not _can_change_configuration("configure"):
		return self
	_duplicate_resources = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		options,
		"duplicate_resources",
		false
	)
	_changes = _copy_configured_changes(changes)
	command_name = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		options,
		"command_name",
		"Edit Object Properties"
	)
	metadata = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
	_execution_entries.clear()
	_first_snapshots.clear()
	_has_first_snapshot = false
	_recovery_required = false
	_pending_recovery_values.clear()
	_pending_recovery_reverse_order = true
	_last_transaction_report.clear()
	return self


## 零写入验证全部属性变更。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 结构化事务报告。
## [br]
## @schema return: Dictionary，包含 ok、status、phase、error、requested_count、applied_count、unchanged_count、attempted_count、rollback_count、failed_count、failed_index、rolled_back、recovery_required、entries、issues 和 metadata。
func validate() -> Dictionary:
	var report: Dictionary = _build_config_preflight()
	_set_last_report(report)
	return _copy_report(report)


## 获取最近一次预检、提交、撤销或恢复报告。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 结构化事务报告副本。
## [br]
## @schema return: Dictionary，形状与 validate() 返回值相同。
func get_transaction_report() -> Dictionary:
	if _last_transaction_report.is_empty():
		return _make_report(
			true,
			STATUS_PENDING,
			&"pending",
			OK,
			[],
			[]
		)
	return _copy_report(_last_transaction_report)


## 恢复最近一次未完整补偿的操作。
##
## 恢复目标是该次失败 apply、redo 或 undo 开始前的 attempt guard，而不是固定的
## 首次 undo 基线。undo 补偿失败时，恢复成功后命令仍保持 executed，调用方可再
## 次调用 revert() 完成真正撤销。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Godot 错误码。
func recover() -> Error:
	if _operation_in_progress or not _recovery_required:
		return ERR_UNAVAILABLE
	_operation_in_progress = true
	var error: Error = _recover_pending_guard()
	_operation_in_progress = false
	return error


## 当前命令是否允许执行。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 配置完整、目标可写且没有待恢复残余状态时返回 true。
func can_execute() -> bool:
	if _operation_in_progress:
		_set_last_report(_make_unavailable_report(&"busy", "Property transaction is busy."))
		return false
	if is_executed():
		_set_last_report(
			_make_unavailable_report(
				&"already_executed",
				"Property transaction is already executed."
			)
		)
		return false
	if _recovery_required:
		_set_last_report(
			_make_unavailable_report(
				&"recovery_required",
				"Property transaction must be recovered before execute."
			)
		)
		return false
	var report: Dictionary = _build_config_preflight()
	_set_last_report(report)
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok")


## 首次执行未成功但留下残余状态时，允许显式调用 revert() 重试恢复。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 存在首次快照且需要恢复时返回 true。
func can_revert_before_execute() -> bool:
	return _has_first_snapshot and _recovery_required


# --- 可重写钩子 / 虚方法 ---

## 执行属性事务。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @return Godot 错误码。
func _do_it() -> Error:
	if _operation_in_progress:
		return ERR_UNAVAILABLE
	_operation_in_progress = true
	var error: Error = _execute_transaction()
	_operation_in_progress = false
	return error


## 返回第一个有效属性目标，作为 EditorUndoRedoManager 的 history 上下文。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @return: 第一个有效属性目标。
func _get_undo_context() -> Object:
	for change: Dictionary in _changes:
		var target_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			change,
			"target"
		)
		if target_value is Object and is_instance_valid(target_value):
			var target: Object = target_value
			return target
	return null


## 返回全部唯一属性目标，供基类拒绝跨 UndoRedo history 的混合事务。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @return: 全部唯一属性目标。
func _get_undo_targets() -> Array[Object]:
	var targets: Array[Object] = []
	var seen_instance_ids: Dictionary = {}
	for change: Dictionary in _changes:
		var target_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			change,
			"target"
		)
		if not target_value is Object or not is_instance_valid(target_value):
			continue
		var target: Object = target_value
		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		targets.append(target)
	return targets


## 撤销属性事务，或恢复首次执行失败留下的残余状态。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @return Godot 错误码。
func _undo_it() -> Error:
	if _operation_in_progress:
		return ERR_UNAVAILABLE
	if not _has_first_snapshot:
		return ERR_UNAVAILABLE
	_operation_in_progress = true
	if _recovery_required:
		if is_executed():
			_set_last_report(
				_make_unavailable_report(
					&"recover_before_revert",
					"Recover the failed undo attempt before retrying revert."
				)
			)
			_operation_in_progress = false
			return ERR_UNAVAILABLE
		var recovery_error: Error = _recover_pending_guard()
		_operation_in_progress = false
		return recovery_error
	var preparation: Dictionary = _prepare_execution_values(
		_first_snapshots,
		&"revert"
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(preparation, "ok"):
		var failed_report: Dictionary = _copy_report(preparation)
		failed_report["status"] = STATUS_REVERT_FAILED
		failed_report["recovery_required"] = _recovery_required
		_set_last_report(failed_report)
		_operation_in_progress = false
		return ERR_INVALID_DATA
	var entries: Array[Dictionary] = _get_report_entries(preparation)
	var error: Error = _run_transition(
		entries,
		STATUS_REVERTED,
		STATUS_REVERT_FAILED,
		&"revert",
		true
	)
	_operation_in_progress = false
	return error


# --- 私有/辅助方法 ---

## 执行首次配置预检或重做值预检，首次通过后捕获旧值并封存配置，再提交事务。
## 预检失败时保存报告并返回 ERR_INVALID_DATA。
## [br]
## @api private
func _execute_transaction() -> Error:
	var preparation: Dictionary
	if _has_first_snapshot:
		preparation = _prepare_execution_values(
			_get_execution_new_values(),
			&"apply"
		)
	else:
		preparation = _build_config_preflight()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(preparation, "ok"):
		_set_last_report(preparation)
		return ERR_INVALID_DATA

	var entries: Array[Dictionary] = _get_report_entries(preparation)
	if not _has_first_snapshot:
		_capture_first_snapshot(entries)
		_seal_configuration_for_execution()
	return _run_transition(
		entries,
		STATUS_COMMITTED,
		STATUS_APPLY_FAILED,
		&"apply",
		false
	)


## 按保存的方向和目标值重新预检并恢复最近一次操作开始前的 attempt guard。
## 恢复仍失败时保留恢复值与顺序，供后续再次显式调用 recover。
## [br]
## @api private
func _recover_pending_guard() -> Error:
	if not _recovery_required or _pending_recovery_values.is_empty():
		return ERR_UNAVAILABLE
	var desired_values: Array = _duplicate_value_array(
		_pending_recovery_values
	)
	var recovery_reverse_order: bool = _pending_recovery_reverse_order
	var preparation: Dictionary = _prepare_execution_values(
		desired_values,
		&"recovery"
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(preparation, "ok"):
		var failed_report: Dictionary = _copy_report(preparation)
		failed_report["status"] = STATUS_ROLLBACK_FAILED
		failed_report["recovery_required"] = true
		_set_last_report(failed_report)
		return ERR_INVALID_DATA
	var entries: Array[Dictionary] = _get_report_entries(preparation)
	var error: Error = _run_transition(
		entries,
		STATUS_RECOVERED,
		STATUS_ROLLBACK_FAILED,
		&"recovery",
		recovery_reverse_order
	)
	if error != OK:
		_set_pending_recovery(
			desired_values,
			recovery_reverse_order
		)
		var failure_report: Dictionary = get_transaction_report()
		failure_report["recovery_required"] = true
		_set_last_report(failure_report)
	return error


## 对全部配置变更执行零写入预检，并汇总无效项及目标属性选择器重叠问题。
## 只有 issue 集合为空时报告 STATUS_READY。
## [br]
## @api private
func _build_config_preflight() -> Dictionary:
	var entries: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	if _changes.is_empty():
		issues.append(
			_make_issue(
				-1,
				&"missing_changes",
				"Property transaction has no changes.",
				&"preflight"
			)
		)
	for index: int in range(_changes.size()):
		var prepared: Dictionary = _prepare_configured_change(
			_changes[index],
			index,
			&"preflight"
		)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(prepared, "ok"):
			var entry_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
				prepared,
				"entry"
			)
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				entries.append(entry)
		else:
			var issue_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
				prepared,
				"issue"
			)
			if issue_value is Dictionary:
				var issue: Dictionary = issue_value
				issues.append(issue)
	_append_overlap_issues(entries, issues)
	var ok: bool = issues.is_empty()
	return _make_report(
		ok,
		STATUS_READY if ok else STATUS_PREFLIGHT_FAILED,
		&"preflight",
		OK if ok else ERR_INVALID_DATA,
		entries,
		issues
	)


## 校验单条输入变更，要求有效 Object、new_value 和且仅一个属性选择器。
## 委托属性工具做写入预检，并生成带 old/new 值、目标、metadata 和选择器信息的条目。
## [br]
## @api private
func _prepare_configured_change(
	change: Dictionary,
	index: int,
	phase: StringName
) -> Dictionary:
	var metadata_value: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		change,
		"metadata"
	)
	var target_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		change,
		"target"
	)
	if not (target_value is Object):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"invalid_target",
				"Property transaction target is not an Object.",
				phase,
				change
			)
		)
	var target: Object = target_value
	if not is_instance_valid(target):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"invalid_target",
				"Property transaction target is no longer valid.",
				phase,
				change
			)
		)
	if not _has_option_key(change, &"new_value"):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"missing_new_value",
				"Property transaction change is missing new_value.",
				phase,
				change
			)
		)

	var has_property_name: bool = _has_option_key(change, &"property_name")
	var has_property_path: bool = _has_option_key(change, &"property_path")
	if has_property_name == has_property_path:
		return _make_prepare_failure(
			_make_issue(
				index,
				&"invalid_selector",
				"Change must contain exactly one of property_name or property_path.",
				phase,
				change
			)
		)

	var new_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		change,
		"new_value"
	)
	var preparation: Dictionary
	var entry: Dictionary = {
		"index": index,
		"target": target,
		"metadata": metadata_value.duplicate(true),
		"status": STATUS_READY,
	}
	if has_property_name:
		var property_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			change,
			"property_name",
			&""
		)
		if property_name == &"":
			return _make_prepare_failure(
				_make_issue(
					index,
					&"invalid_selector",
					"Direct property name is empty.",
					phase,
					change
				)
			)
		preparation = _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.prepare_direct_property_write(
			target,
			property_name,
			new_value
		)
		entry["selector_mode"] = _SELECTOR_DIRECT
		entry["property_name"] = property_name
		entry["root_property"] = property_name
		entry["root_selector"] = true
	else:
		var raw_path: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			change,
			"property_path"
		)
		var property_path: NodePath = NodePath("")
		if raw_path is NodePath:
			property_path = raw_path
		elif raw_path is String or raw_path is StringName:
			property_path = NodePath(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_path))
		if property_path.is_empty():
			return _make_prepare_failure(
				_make_issue(
					index,
					&"invalid_selector",
					"Indexed property path is empty or invalid.",
					phase,
					change
				)
			)
		preparation = _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.prepare_property_write(
			target,
			property_path,
			new_value
		)
		entry["selector_mode"] = _SELECTOR_PATH
		entry["property_path"] = property_path
		var selector_components: PackedStringArray = (
			_make_property_selector_components(property_path)
		)
		entry["selector_components"] = selector_components
		entry["root_property"] = (
			_GF_OBJECT_PROPERTY_TOOLS_SCRIPT.get_root_property_name(property_path)
		)
		entry["root_selector"] = selector_components.size() == 1

	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(preparation, "ok"):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"property_preflight_failed",
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					preparation,
					"error",
					"Property preflight failed."
				),
				phase,
				entry
			)
		)
	entry["old_value"] = _duplicate_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(preparation, "old_value"),
		false
	)
	entry["new_value"] = _duplicate_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(preparation, "new_value"),
		false
	)
	return {
		"ok": true,
		"entry": entry,
	}


## 按已保存执行条目预检一组重做、撤销或恢复目标值。
## 目标值数量与条目数不一致时返回 snapshot_mismatch issue。
## [br]
## @api private
func _prepare_execution_values(
	desired_values: Array,
	phase: StringName
) -> Dictionary:
	var entries: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	if desired_values.size() != _execution_entries.size():
		issues.append(
			_make_issue(
				-1,
				&"snapshot_mismatch",
				"Property transaction snapshot count does not match entries.",
				phase
			)
		)
	else:
		for index: int in range(_execution_entries.size()):
			var prepared: Dictionary = _prepare_execution_entry(
				_execution_entries[index],
				desired_values[index],
				phase
			)
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(prepared, "ok"):
				var entry_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
					prepared,
					"entry"
				)
				if entry_value is Dictionary:
					var entry: Dictionary = entry_value
					entries.append(entry)
			else:
				var issue_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
					prepared,
					"issue"
				)
				if issue_value is Dictionary:
					var issue: Dictionary = issue_value
					issues.append(issue)
	var ok: bool = issues.is_empty()
	return _make_report(
		ok,
		STATUS_READY if ok else STATUS_PREFLIGHT_FAILED,
		phase,
		OK if ok else ERR_INVALID_DATA,
		entries,
		issues
	)


## 对保存的单条执行模板重新验证目标和原选择器，并构造当前 old/new 值的执行条目。
## 预检失败时保留 phase、原索引及条目上下文生成 issue。
## [br]
## @api private
func _prepare_execution_entry(
	template: Dictionary,
	desired_value: Variant,
	phase: StringName
) -> Dictionary:
	var target_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		template,
		"target"
	)
	var index: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		template,
		"index",
		-1
	)
	if not (target_value is Object):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"invalid_target",
				"Property transaction target is not an Object.",
				phase,
				template
			)
		)
	var target: Object = target_value
	if not is_instance_valid(target):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"invalid_target",
				"Property transaction target is no longer valid.",
				phase,
				template
			)
		)

	var selector_mode: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
		template,
		"selector_mode"
	)
	var preparation: Dictionary
	if selector_mode == _SELECTOR_DIRECT:
		preparation = _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.prepare_direct_property_write(
			target,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				template,
				"property_name"
			),
			desired_value
		)
	else:
		var property_path_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			template,
			"property_path"
		)
		if not (property_path_value is NodePath):
			return _make_prepare_failure(
				_make_issue(
					index,
					&"invalid_selector",
					"Stored indexed property path is invalid.",
					phase,
					template
				)
			)
		var property_path: NodePath = property_path_value
		preparation = _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.prepare_property_write(
			target,
			property_path,
			desired_value
		)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(preparation, "ok"):
		return _make_prepare_failure(
			_make_issue(
				index,
				&"property_preflight_failed",
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					preparation,
					"error",
					"Property preflight failed."
				),
				phase,
				template
			)
		)
	var entry: Dictionary = template.duplicate(true)
	entry["old_value"] = _duplicate_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(preparation, "old_value"),
		false
	)
	entry["new_value"] = _duplicate_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(preparation, "new_value"),
		false
	)
	entry["status"] = STATUS_READY
	return {
		"ok": true,
		"entry": entry,
	}


## 按指定顺序写入目标值，跳过相等值，并验证所有目标的最终状态。
## 任一写入或状态核对失败时按相反方向恢复 attempt guard；补偿仍失败则保存显式恢复状态。
## [br]
## @api private
func _run_transition(
	entries: Array[Dictionary],
	success_status: StringName,
	failure_status: StringName,
	phase: StringName,
	reverse_order: bool
) -> Error:
	var recovery_before: bool = _recovery_required
	var attempt_guard: Array = []
	var desired_values: Array = []
	var report_entries: Array[Dictionary] = _copy_dictionary_array(entries)
	for entry: Dictionary in entries:
		attempt_guard.append(
			_duplicate_value(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "old_value"),
				false
			)
		)
		desired_values.append(
			_duplicate_value(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "new_value"),
				false
			)
		)

	var issues: Array[Dictionary] = []
	var attempted_count: int = 0
	var changed_count: int = 0
	var unchanged_count: int = 0
	var order: Array[int] = _make_index_order(entries.size(), reverse_order)
	for entry_index: int in order:
		var entry: Dictionary = entries[entry_index]
		if _values_equal(attempt_guard[entry_index], desired_values[entry_index]):
			report_entries[entry_index]["status"] = &"unchanged"
			unchanged_count += 1
			continue
		attempted_count += 1
		var write_result: Dictionary = _write_entry(
			entry,
			desired_values[entry_index]
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(write_result, "ok"):
			report_entries[entry_index]["status"] = &"failed"
			issues.append(
				_make_issue(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "index", -1),
					&"property_write_failed",
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						write_result,
						"error",
						"Property write failed."
					),
					phase,
					entry
				)
			)
			break
		report_entries[entry_index]["status"] = (
			&"reverted" if phase == &"revert" else &"applied"
		)
		changed_count += 1

	if issues.is_empty():
		issues.append_array(
			_collect_state_issues(
				entries,
				desired_values,
				phase,
				&"final_state_mismatch"
			)
		)
	if not issues.is_empty():
		var rollback: Dictionary = _restore_attempt_guard(
			entries,
			attempt_guard,
			not reverse_order
		)
		var rollback_issues: Array[Dictionary] = _get_report_issues(rollback)
		issues.append_array(rollback_issues)
		var rolled_back: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			rollback,
			"ok"
		)
		if rolled_back:
			if recovery_before:
				_recovery_required = true
			else:
				_clear_pending_recovery()
			for entry_index: int in range(report_entries.size()):
				if (
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
						report_entries[entry_index],
						"status"
					)
					in [&"applied", &"reverted"]
				):
					report_entries[entry_index]["status"] = &"rolled_back"
		else:
			_set_pending_recovery(
				attempt_guard,
				not reverse_order
			)
		_set_last_report(
			_make_report(
				false,
				failure_status if rolled_back else STATUS_ROLLBACK_FAILED,
				phase,
				FAILED,
				report_entries,
				issues,
				{
					"applied_count": 0,
					"unchanged_count": unchanged_count,
					"attempted_count": attempted_count,
					"rollback_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
						rollback,
						"rollback_count"
					),
					"rolled_back": rolled_back,
					"recovery_required": _recovery_required,
				}
			)
		)
		return FAILED

	_clear_pending_recovery()
	_set_last_report(
		_make_report(
			true,
			success_status,
			phase,
			OK,
			report_entries,
			[],
			{
				"applied_count": changed_count,
				"unchanged_count": unchanged_count,
				"attempted_count": attempted_count,
				"rollback_count": 0,
				"rolled_back": false,
				"recovery_required": false,
			}
		)
	)
	return OK


## 按指定顺序逐项读取并恢复 attempt guard，只写入当前值不同的属性。
## 最后重新读取全部条目；读取、写入或恢复后状态不符都会进入返回 issues。
## [br]
## @api private
func _restore_attempt_guard(
	entries: Array[Dictionary],
	attempt_guard: Array,
	reverse_order: bool
) -> Dictionary:
	var issues: Array[Dictionary] = []
	var rollback_count: int = 0
	var order: Array[int] = _make_index_order(entries.size(), reverse_order)
	for entry_index: int in order:
		var entry: Dictionary = entries[entry_index]
		var read_result: Dictionary = _read_entry(entry)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(read_result, "ok"):
			issues.append(
				_make_issue(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "index", -1),
					&"rollback_read_failed",
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						read_result,
						"error",
						"Rollback could not read property."
					),
					&"rollback",
					entry
				)
			)
			continue
		if _values_equal(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(read_result, "value"),
			attempt_guard[entry_index]
		):
			continue
		var write_result: Dictionary = _write_entry(
			entry,
			attempt_guard[entry_index]
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(write_result, "ok"):
			issues.append(
				_make_issue(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "index", -1),
					&"rollback_write_failed",
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						write_result,
						"error",
						"Rollback property write failed."
					),
					&"rollback",
					entry
				)
			)
			continue
		rollback_count += 1
	issues.append_array(
		_collect_state_issues(
			entries,
			attempt_guard,
			&"rollback",
			&"rollback_state_mismatch"
		)
	)
	return {
		"ok": issues.is_empty(),
		"rollback_count": rollback_count,
		"issues": issues,
	}


## 读取每个条目并报告无法读取或与对应 expected value 不相等的状态。
## 值不符的 issue 同时带有 actual_value 和 expected_value。
## [br]
## @api private
func _collect_state_issues(
	entries: Array[Dictionary],
	expected_values: Array,
	phase: StringName,
	kind: StringName
) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for entry_index: int in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var read_result: Dictionary = _read_entry(entry)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(read_result, "ok"):
			issues.append(
				_make_issue(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "index", -1),
					kind,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						read_result,
						"error",
						"Property state could not be verified."
					),
					phase,
					entry
				)
			)
			continue
		var actual_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			read_result,
			"value"
		)
		if _values_equal(actual_value, expected_values[entry_index]):
			continue
		var issue: Dictionary = _make_issue(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "index", -1),
			kind,
			"Property state does not match the transaction expectation.",
			phase,
			entry
		)
		issue["actual_value"] = _duplicate_value(actual_value, false)
		issue["expected_value"] = _duplicate_value(
			expected_values[entry_index],
			false
		)
		issues.append(issue)
	return issues


## 检查目标仍有效后，按条目模式写直接属性或 NodePath 属性。
## 写入值先经 `_duplicate_value` 处理；目标或保存路径无效时返回失败字典。
## [br]
## @api private
func _write_entry(entry: Dictionary, value: Variant) -> Dictionary:
	var target_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		entry,
		"target"
	)
	if not (target_value is Object):
		return {
			"ok": false,
			"error": "Property transaction target is invalid.",
		}
	var target: Object = target_value
	if not is_instance_valid(target):
		return {
			"ok": false,
			"error": "Property transaction target is no longer valid.",
		}
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			entry,
			"selector_mode"
		)
		== _SELECTOR_DIRECT
	):
		return _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.write_direct_property(
			target,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				entry,
				"property_name"
			),
			_duplicate_value(value, false)
		)
	var property_path_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		entry,
		"property_path"
	)
	if not (property_path_value is NodePath):
		return {
			"ok": false,
			"error": "Stored indexed property path is invalid.",
		}
	var property_path: NodePath = property_path_value
	return _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.write_property(
		target,
		property_path,
		_duplicate_value(value, false)
	)


## 检查目标和选择器仍有效后读取直接属性或 NodePath 属性。
## indexed path 以临时 RefCounted 标记区分缺失值，并将成功结果包装为 value 字段。
## [br]
## @api private
func _read_entry(entry: Dictionary) -> Dictionary:
	var target_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		entry,
		"target"
	)
	if not (target_value is Object):
		return {
			"ok": false,
			"error": "Property transaction target is invalid.",
		}
	var target: Object = target_value
	if not is_instance_valid(target):
		return {
			"ok": false,
			"error": "Property transaction target is no longer valid.",
		}
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			entry,
			"selector_mode"
		)
		== _SELECTOR_DIRECT
	):
		var property_name: StringName = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				entry,
				"property_name"
			)
		)
		if not _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.has_property(
			target,
			property_name
		):
			return {
				"ok": false,
				"error": "Direct property is no longer available.",
			}
		return {
			"ok": true,
			"value": target.get(property_name),
		}
	var property_path_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		entry,
		"property_path"
	)
	if not (property_path_value is NodePath):
		return {
			"ok": false,
			"error": "Stored indexed property path is invalid.",
		}
	var property_path: NodePath = property_path_value
	var missing_marker: RefCounted = RefCounted.new()
	var value: Variant = _GF_OBJECT_PROPERTY_TOOLS_SCRIPT.read_property(
		target,
		property_path,
		missing_marker
	)
	if is_same(value, missing_marker):
		return {
			"ok": false,
			"error": "Indexed property path is no longer available.",
		}
	return {
		"ok": true,
		"value": value,
	}


## 保存首次执行条目副本及其 old_value 顺序快照，并标记快照已建立。
## [br]
## @api private
func _capture_first_snapshot(entries: Array[Dictionary]) -> void:
	_execution_entries = _copy_dictionary_array(entries)
	_first_snapshots.clear()
	for entry: Dictionary in entries:
		_first_snapshots.append(
			_duplicate_value(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "old_value"),
				false
			)
		)
	_has_first_snapshot = true


## 按首次执行条目顺序复制 new_value，供重做前重新预检。
## [br]
## @api private
func _get_execution_new_values() -> Array:
	var values: Array = []
	for entry: Dictionary in _execution_entries:
		values.append(
			_duplicate_value(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "new_value"),
				false
			)
		)
	return values


## 复制待恢复值、记录恢复顺序，并设置需要显式恢复的状态标志。
## [br]
## @api private
func _set_pending_recovery(values: Array, reverse_order: bool) -> void:
	_pending_recovery_values = _duplicate_value_array(values)
	_pending_recovery_reverse_order = reverse_order
	_recovery_required = true


## 清空待恢复值，将方向复位为逆序并清除恢复必需标志。
## [br]
## @api private
func _clear_pending_recovery() -> void:
	_pending_recovery_values.clear()
	_pending_recovery_reverse_order = true
	_recovery_required = false


## 逐项复制数组中的 Variant 值，Resource 不请求专门复制。
## [br]
## @api private
func _duplicate_value_array(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		result.append(_duplicate_value(value, false))
	return result


## 对每个条目检查此前条目，发现首个重叠选择器时为后项追加一个预检 issue。
## [br]
## @api private
func _append_overlap_issues(
	entries: Array[Dictionary],
	issues: Array[Dictionary]
) -> void:
	for right_index: int in range(entries.size()):
		var right: Dictionary = entries[right_index]
		for left_index: int in range(right_index):
			var left: Dictionary = entries[left_index]
			if not _selectors_overlap(left, right):
				continue
			issues.append(
				_make_issue(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "index", -1),
					&"overlapping_selector",
					"Property transaction selectors overlap on the same target.",
					&"preflight",
					right
				)
			)
			break


## 仅当两个选择器指向同一对象和根属性，且整根属性或路径分量前缀相交时返回 true。
## [br]
## @api private
func _selectors_overlap(left: Dictionary, right: Dictionary) -> bool:
	var left_target: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		left,
		"target"
	)
	var right_target: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		right,
		"target"
	)
	if not (left_target is Object) or not (right_target is Object):
		return false
	var left_object: Object = left_target
	var right_object: Object = right_target
	if left_object.get_instance_id() != right_object.get_instance_id():
		return false
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(left, "root_property")
		!= _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			right,
			"root_property"
		)
	):
		return false
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(left, "root_selector")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(right, "root_selector")
	):
		return true
	var left_components: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			left,
			"selector_components"
		)
	)
	var right_components: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			right,
			"selector_components"
		)
	)
	if left_components.is_empty() or right_components.is_empty():
		return false
	var shared_component_count: int = mini(
		left_components.size(),
		right_components.size()
	)
	for component_index: int in range(shared_component_count):
		if left_components[component_index] != right_components[component_index]:
			return false
	return true


## 按 NodePath 顺序将首个 name 和全部 subname 转为属性选择器分量。
## [br]
## @api private
func _make_property_selector_components(
	property_path: NodePath
) -> PackedStringArray:
	var components: PackedStringArray = PackedStringArray()
	if property_path.get_name_count() > 0:
		var _append_root_name: bool = components.append(
			String(property_path.get_name(0))
		)
	for subname_index: int in range(property_path.get_subname_count()):
		var _append_subname: bool = components.append(
			String(property_path.get_subname(subname_index))
		)
	return components


## 复制配置中的 target、选择器和 metadata，并按 duplicate_resources 选项复制 new_value。
## 未提供的字段不会写入输出条目。
## [br]
## @api private
func _copy_configured_changes(changes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for change: Dictionary in changes:
		var copied: Dictionary = {}
		if _has_option_key(change, &"target"):
			copied["target"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
				change,
				"target"
			)
		if _has_option_key(change, &"property_name"):
			copied["property_name"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
				change,
				"property_name"
			)
		if _has_option_key(change, &"property_path"):
			copied["property_path"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
				change,
				"property_path"
			)
		if _has_option_key(change, &"new_value"):
			copied["new_value"] = _duplicate_value(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
					change,
					"new_value"
				),
				_duplicate_resources
			)
		copied["metadata"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			change,
			"metadata"
		).duplicate(true)
		result.append(copied)
	return result


## 将单条预检 issue 包装为失败结果，供配置项与执行项预检共享处理路径。
## [br]
## @api private
func _make_prepare_failure(issue: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"issue": issue,
	}


## 组装带索引、阶段、目标和深复制 metadata 的 issue，并附上存在的属性选择器。
## [br]
## @api private
func _make_issue(
	index: int,
	kind: StringName,
	message: String,
	phase: StringName,
	entry: Dictionary = {}
) -> Dictionary:
	var issue: Dictionary = {
		"index": index,
		"kind": kind,
		"message": message,
		"phase": phase,
		"target": _GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "target"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			entry,
			"metadata"
		).duplicate(true),
	}
	if _has_option_key(entry, &"property_name"):
		issue["property_name"] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				entry,
				"property_name"
			)
		)
	if _has_option_key(entry, &"property_path"):
		issue["property_path"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			entry,
			"property_path"
		)
	return issue


## 为忙碌、已执行或待恢复等不可用状态生成 preflight 失败报告。
## 报告包含 ERR_UNAVAILABLE 和当前 recovery_required 标志。
## [br]
## @api private
func _make_unavailable_report(kind: StringName, message: String) -> Dictionary:
	return _make_report(
		false,
		STATUS_PREFLIGHT_FAILED,
		&"preflight",
		ERR_UNAVAILABLE,
		[],
		[_make_issue(-1, kind, message, &"preflight")],
		{
			"recovery_required": _recovery_required,
		}
	)


## 汇总事务状态、计数、首个失败索引、条目、issues 和 metadata。
## entries 与 issues 深复制；requested_count 默认取当前配置变更数。
## [br]
## @api private
func _make_report(
	ok: bool,
	status: StringName,
	phase: StringName,
	error: Error,
	entries: Array[Dictionary],
	issues: Array[Dictionary],
	details: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"phase": phase,
		"error": error,
		"requested_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			details,
			"requested_count",
			_changes.size()
		),
		"applied_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			details,
			"applied_count"
		),
		"unchanged_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			details,
			"unchanged_count"
		),
		"attempted_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			details,
			"attempted_count"
		),
		"rollback_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			details,
			"rollback_count"
		),
		"failed_count": _count_failed_indices(issues),
		"failed_index": _get_first_failed_index(issues),
		"rolled_back": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			details,
			"rolled_back"
		),
		"recovery_required": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			details,
			"recovery_required",
			_recovery_required
		),
		"entries": _copy_dictionary_array(entries),
		"issues": _copy_dictionary_array(issues),
		"metadata": metadata.duplicate(true),
	}


## 统计 issues 中不同 index 的数量，同一索引的多条诊断只计一次。
## [br]
## @api private
func _count_failed_indices(issues: Array[Dictionary]) -> int:
	var failed_indices: Dictionary = {}
	for issue: Dictionary in issues:
		var index: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			issue,
			"index",
			-1
		)
		failed_indices[index] = true
	return failed_indices.size()


## 返回首条 issue 的 index；issue 数组为空时返回 -1。
## [br]
## @api private
func _get_first_failed_index(issues: Array[Dictionary]) -> int:
	if issues.is_empty():
		return -1
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(issues[0], "index", -1)


## 从报告 entries 数组中筛出字典项并返回其原引用；类型不符时返回空数组。
## [br]
## @api private
func _get_report_entries(report: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		report,
		"entries"
	)
	if not (entries_value is Array):
		return result
	var entries: Array = entries_value
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			result.append(entry)
	return result


## 从报告 issues 数组中筛出字典项并返回其原引用；类型不符时返回空数组。
## [br]
## @api private
func _get_report_issues(report: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var issues_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		report,
		"issues"
	)
	if not (issues_value is Array):
		return result
	var issues: Array = issues_value
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			result.append(issue)
	return result


## 根据 reverse_order 生成从零起始的升序或降序索引数组。
## [br]
## @api private
func _make_index_order(count: int, reverse_order: bool) -> Array[int]:
	var result: Array[int] = []
	if reverse_order:
		for index: int in range(count - 1, -1, -1):
			result.append(index)
	else:
		for index: int in range(count):
			result.append(index)
	return result


## 深复制字典数组中的每个元素。
## [br]
## @api private
func _copy_dictionary_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


## 深复制事务报告字典。
## [br]
## @api private
func _copy_report(report: Dictionary) -> Dictionary:
	return report.duplicate(true)


## 将最近报告保存为深复制，隔离后续对传入字典的修改。
## [br]
## @api private
func _set_last_report(report: Dictionary) -> void:
	_last_transaction_report = _copy_report(report)


## 深复制 Variant；仅在参数为 true 时额外请求复制 Resource。
## [br]
## @api private
func _duplicate_value(value: Variant, duplicate_resources: bool) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(
		value,
		true,
		duplicate_resources
	)


## 使用 Variant 工具比较值，并启用 StringName 与 String 匹配。
## [br]
## @api private
func _values_equal(left: Variant, right: Variant) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.values_equal(
		left,
		right,
		{
			"match_string_names": true,
		}
	)


## 检查字典中是否存在原键；StringName 与 String 键还会互查文本等价形式。
## [br]
## @api private
func _has_option_key(options: Dictionary, key: Variant) -> bool:
	if options.has(key):
		return true
	if key is StringName:
		var string_name_key: StringName = key
		return options.has(String(string_name_key))
	if key is String:
		var string_key: String = key
		return options.has(StringName(string_key))
	return false
