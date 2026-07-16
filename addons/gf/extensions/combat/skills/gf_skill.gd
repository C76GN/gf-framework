## GFSkill: 技能基类。
##
## 负责冷却、施放校验与目标解析入口，
## 具体技能逻辑通过子类重写 `_on_execute()` 实现。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFSkill
extends RefCounted


# --- 信号 ---

## 当技能开始进入冷却时发出。
## [br]
## @api public
## [br]
## @param skill: 进入冷却的技能实例。
signal cooldown_started(skill: GFSkill)

## 当技能激活失败时发出。
## [br]
## @api public
## [br]
## @param skill: 激活失败的技能实例。
## [br]
## @param context: 技能激活上下文。
signal activation_failed(skill: GFSkill, context: RefCounted)

## 当技能完成激活提交并进入冷却时发出。
## [br]
## @api public
## [br]
## @param skill: 已提交的技能实例。
## [br]
## @param context: 技能激活上下文。
signal activation_committed(skill: GFSkill, context: RefCounted)


# --- 常量 ---

const _GF_SKILL_ACTIVATION_CONTEXT = preload("res://addons/gf/extensions/combat/skills/gf_skill_activation_context.gd")
const _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT = preload("res://addons/gf/extensions/combat/skills/gf_skill_targeting_utility_2d.gd")


# --- 公共变量 ---

## 技能 ID。
## [br]
## @api public
var id: StringName = &""

## 最大冷却时间。
## [br]
## @api public
var cooldown_max: float = 0.0

## 当前剩余冷却时间。
## [br]
## @api public
var cooldown_left: float = 0.0

## 释放技能所需标签。
## [br]
## @api public
var require_tags: Array[StringName] = []

## 释放技能时禁止存在的标签。
## [br]
## @api public
var ignore_tags: Array[StringName] = []

## 技能拥有者。
## [br]
## @api public
var owner: Object = null

## 2D 技能索敌规则。
## [br]
## @api public
## [br]
## @since 3.17.0
var targeting_rule: GFSkillTargetingRule2D = null

## 可选标签查询。为空时使用 require_tags / ignore_tags。
## [br]
## @api public
var activation_query: GFTagQuery = null

## 激活检查回调。每个回调接收 GFSkillActivationContext，可返回 bool 或 { ok, reason, metadata }。
## [br]
## @api public
## [br]
## @schema activation_checks: Array[Callable]，用于项目自定义成本、状态或上下文检查。
var activation_checks: Array[Callable] = []

## 激活事务步骤。步骤按顺序验证和应用，失败时按逆序回滚已应用步骤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema activation_steps: Array[GFSkillActivationStep]，用于项目自定义成本、预留或其他可补偿副作用。
var activation_steps: Array[GFSkillActivationStep] = []


# --- 私有变量 ---

var _architecture_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _init(p_owner: Object = null) -> void:
	owner = p_owner


# --- 公共方法 ---

## 更新冷却时间。
## [br]
## @api public
## [br]
## @param p_delta: 本次更新经过的时间。
func update(p_delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = max(0.0, cooldown_left - p_delta)


## 注入当前技能执行所在的架构实例。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 检查技能当前是否允许施放。
## [br]
## @api public
## [br]
## @return 可施放时返回 `true`。
func can_execute() -> bool:
	return _report_ok(get_activation_report())


## 创建技能激活上下文。
## [br]
## @api public
## [br]
## @param manual_target: 可选的手动目标。
## [br]
## @param cast_center: 可选施法中心；传入 `null` 时回退到施法者位置。
## [br]
## @param activation_metadata: 项目自定义激活元数据。
## [br]
## @return 技能激活上下文。
## [br]
## @schema cast_center: Variant，可为 null 或 Vector2；为 null 时从 owner.global_position 推导。
## [br]
## @schema activation_metadata: Dictionary，复制到上下文中供项目检查、提交或诊断使用。
func build_activation_context(
	manual_target: Object = null,
	cast_center: Variant = null,
	activation_metadata: Dictionary = {}
) -> RefCounted:
	var context: RefCounted = _GF_SKILL_ACTIVATION_CONTEXT.new()
	context.call(
		"configure",
		self,
		_get_valid_owner(),
		manual_target,
		cast_center,
		_resolve_cast_center(cast_center),
		activation_metadata
	)
	return context


## 获取技能激活报告。
## [br]
## @api public
## [br]
## @param context: 可选激活上下文；为空时创建默认上下文。
## [br]
## @return 激活报告。
## [br]
## @schema return: Dictionary，包含 ok、reason、skill_id、target_count 和 metadata。
func get_activation_report(context: RefCounted = null) -> Dictionary:
	var activation_context: RefCounted = context if context != null else build_activation_context()
	var report: Dictionary = _validate_activation_context(activation_context, false)
	if not _report_ok(report):
		return report
	if not _resolve_activation_targets(activation_context):
		return _context_to_report(activation_context)
	report = _run_activation_callbacks(activation_context, activation_checks, &"activation_check_failed")
	if not _report_ok(report):
		return report

	var transaction: GFActivationTransaction = _build_activation_transaction(activation_context)
	if transaction == null:
		return _context_to_report(activation_context)
	var transaction_report: Dictionary = transaction.prepare(_make_transaction_context(activation_context))
	if not _report_ok(transaction_report):
		return _fail_from_transaction(activation_context, transaction_report, &"activation_prepare_failed")
	return _context_to_report(activation_context)


## 执行技能。
## [br]
## @api public
## [br]
## @param manual_target: 可选的手动目标。
## [br]
## @param cast_center: 可选施法中心；传入 `null` 时回退到施法者位置。
## [br]
## @param activation_metadata: 项目自定义激活元数据。
## [br]
## @return 技能实际执行并进入冷却时返回 `true`。
## [br]
## @schema cast_center: Variant，可为 null 或 Vector2；为 null 时从 owner.global_position 推导。
## [br]
## @schema activation_metadata: Dictionary，复制到上下文中供项目检查、提交或诊断使用。
func execute(
	manual_target: Object = null,
	cast_center: Variant = null,
	activation_metadata: Dictionary = {}
) -> bool:
	var context: RefCounted = build_activation_context(manual_target, cast_center, activation_metadata)
	var report: Dictionary = _validate_activation_context(context, false)
	if not _report_ok(report):
		activation_failed.emit(self, context)
		return false

	if not _resolve_activation_targets(context):
		activation_failed.emit(self, context)
		return false

	report = _run_activation_callbacks(context, activation_checks, &"activation_check_failed")
	if not _report_ok(report):
		activation_failed.emit(self, context)
		return false

	var transaction: GFActivationTransaction = _build_activation_transaction(context)
	if transaction == null:
		activation_failed.emit(self, context)
		return false
	var transaction_context: Dictionary = _make_transaction_context(context)
	var transaction_report: Dictionary = transaction.commit(transaction_context)
	if not _report_ok(transaction_report):
		var _transaction_failure_report: Dictionary = _fail_from_transaction(
			context,
			transaction_report,
			&"activation_commit_failed"
		)
		activation_failed.emit(self, context)
		return false

	if not _try_activate(context):
		var rollback_report: Dictionary = transaction.rollback(transaction_context)
		var _execute_failed_report: Dictionary = _fail_activation_context(context, &"execute_failed", {
			"activation_transaction": rollback_report,
		})
		activation_failed.emit(self, context)
		return false
	cooldown_left = cooldown_max
	cooldown_started.emit(self)
	activation_committed.emit(self, context)
	return true


# --- 可重写钩子 / 虚方法 ---

## 自定义施放检查。
## [br]
## @api protected
## [br]
## @return 允许施放时返回 `true`。
func _custom_can_execute() -> bool:
	return true


## 具体技能逻辑入口。
## [br]
## @api protected
## [br]
## @param _targets: 经过筛选后的最终目标数组。
## [br]
## @schema _targets: Array[Object]，经过 targeting_rule 或手动目标校验后的最终目标列表。
func _on_execute(_targets: Array[Object]) -> void:
	pass


## 可报告成功/失败的技能执行入口。默认调用旧的 `_on_execute()` 钩子并视为成功。
## [br]
## @api protected
## [br]
## @param targets: 经过筛选后的最终目标数组。
## [br]
## @return 技能真正生效时返回 `true`。
## [br]
## @schema targets: Array[Object]，经过 targeting_rule 或手动目标校验后的最终目标列表。
func _try_execute(targets: Array[Object]) -> bool:
	_on_execute(targets)
	return true


## 基于激活上下文执行技能。默认桥接到旧的 `_try_execute()`。
## [br]
## @api protected
## [br]
## @param context: 技能激活上下文。
## [br]
## @return 技能真正生效时返回 `true`。
func _try_activate(context: RefCounted) -> bool:
	var targets: Array = _get_context_array(context, "targets")
	var typed_targets: Array[Object] = []
	for target: Variant in targets:
		if target is Object:
			var target_object: Object = target
			typed_targets.append(target_object)
	return _try_execute(typed_targets)


# --- 私有/辅助方法 ---

func _validate_activation_context(context: RefCounted, include_callbacks: bool) -> Dictionary:
	if context == null:
		return {
			"ok": false,
			"reason": &"invalid_context",
			"metadata": {},
		}
	if cooldown_left > 0.0:
		return _fail_activation_context(context, &"cooldown")

	var valid_owner: Object = _get_context_object(context, "owner")
	if valid_owner == null or not is_instance_valid(valid_owner):
		return _fail_activation_context(context, &"invalid_owner")

	var tag_source: Variant = _get_owner_tag_source(valid_owner)
	if not _validate_required_tags(context, tag_source):
		return _context_to_report(context)
	if not _validate_blocked_tags(context, tag_source):
		return _context_to_report(context)
	if activation_query != null and not activation_query.matches(tag_source):
		var query_report: Dictionary = activation_query.get_match_report(tag_source)
		return _fail_activation_context(context, &"activation_query_failed", {
			"query_report": query_report,
		})
	if not _custom_can_execute():
		return _fail_activation_context(context, &"custom_check_failed")
	if include_callbacks:
		return _run_activation_callbacks(context, activation_checks, &"activation_check_failed")
	return _context_to_report(context)


func _validate_required_tags(context: RefCounted, tag_source: Variant) -> bool:
	for tag: StringName in require_tags:
		if not GFTagSourceAdapter.source_has_tag(tag_source, tag):
			var _missing_tag_report: Dictionary = _fail_activation_context(context, &"missing_required_tag", {
				"tag": tag,
			})
			return false
	return true


func _validate_blocked_tags(context: RefCounted, tag_source: Variant) -> bool:
	for tag: StringName in ignore_tags:
		if GFTagSourceAdapter.source_has_tag(tag_source, tag):
			var _blocked_tag_report: Dictionary = _fail_activation_context(context, &"blocked_tag", {
				"tag": tag,
			})
			return false
	return true


func _resolve_activation_targets(context: RefCounted) -> bool:
	var final_targets: Array[Object] = []
	var manual_target: Object = _get_context_object(context, "manual_target")
	var resolved_center: Vector2 = _get_context_vector2(context, "resolved_center", Vector2.ZERO)

	if manual_target != null:
		if targeting_rule != null:
			var utility: _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT = _get_targeting_utility_2d()
			if utility == null:
				push_error("[GFCombat] GFSkillTargetingUtility2D 尚未在架构中注册。")
				var _missing_utility_report: Dictionary = _fail_activation_context(context, &"targeting_utility_missing")
				return false

			var valid_targets: Array[Object] = utility.find_targets(resolved_center, targeting_rule, [manual_target])
			if not valid_targets.is_empty():
				final_targets.append(manual_target)
			else:
				var _invalid_manual_target_report: Dictionary = _fail_activation_context(context, &"invalid_manual_target")
				return false
		else:
			final_targets.append(manual_target)
	elif targeting_rule != null:
		var candidates: Array = []
		var valid_owner: Object = _get_valid_owner()
		if valid_owner != null and valid_owner.has_method(&"get_targeting_candidates"):
			candidates = GFVariantData.as_array(valid_owner.call(&"get_targeting_candidates"))
		elif has_method(&"get_targeting_candidates"):
			candidates = GFVariantData.as_array(call(&"get_targeting_candidates"))

		var utility: _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT = _get_targeting_utility_2d()
		if utility == null:
			push_error("[GFCombat] GFSkillTargetingUtility2D 尚未在架构中注册。")
			var _missing_utility_report: Dictionary = _fail_activation_context(context, &"targeting_utility_missing")
			return false

		final_targets = utility.find_targets(resolved_center, targeting_rule, candidates)

	if targeting_rule != null and targeting_rule.max_count > 0 and final_targets.is_empty():
		var _no_targets_report: Dictionary = _fail_activation_context(context, &"no_targets")
		return false

	context.set("targets", final_targets)
	return true


func _run_activation_callbacks(
	context: RefCounted,
	callbacks: Array[Callable],
	default_reason: StringName
) -> Dictionary:
	for callback: Callable in callbacks:
		if not callback.is_valid():
			continue
		var result: Variant = callback.call(context)
		var report: Dictionary = _apply_activation_callback_result(context, result, default_reason)
		if not _report_ok(report):
			return report
	return _context_to_report(context)


func _build_activation_transaction(context: RefCounted) -> GFActivationTransaction:
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var transaction_id: StringName = StringName("skill_activation:%s" % String(id))
	var _configured_transaction: GFActivationTransaction = transaction.configure(
		transaction_id,
		"Skill activation",
		{ "skill_id": id }
	)
	var used_step_ids: Dictionary = {}
	for step: GFSkillActivationStep in activation_steps:
		if step == null or step.step_id == &"" or used_step_ids.has(step.step_id):
			var _invalid_step_report: Dictionary = _fail_activation_context(context, &"invalid_activation_step", {
				"step_id": step.step_id if step != null else &"",
			})
			return null
		used_step_ids[step.step_id] = true
		var rollback_callback: Callable = Callable()
		if step.rollback_required:
			rollback_callback = _invoke_activation_step.bind(step, &"rollback")
		var added: bool = transaction.add_step(
			step.step_id,
			_invoke_activation_step.bind(step, &"apply"),
			rollback_callback,
			{
				"validate_callback": _invoke_activation_step.bind(step, &"validate"),
				"rollback_required": step.rollback_required,
			}
		)
		if not added:
			var _step_add_failed_report: Dictionary = _fail_activation_context(context, &"invalid_activation_step", {
				"step_id": step.step_id,
			})
			return null
	return transaction


func _invoke_activation_step(
	transaction_context: Dictionary,
	step: GFSkillActivationStep,
	phase: StringName
) -> Variant:
	var context: GFSkillActivationContext = _get_transaction_activation_context(transaction_context)
	if context == null or step == null:
		return {
			"ok": false,
			"reason": &"invalid_activation_context",
		}
	var result: Variant = null
	match phase:
		&"validate":
			result = step._validate_activation(context)
		&"apply":
			result = step._apply_activation(context)
		&"rollback":
			result = step._rollback_activation(context)
		_:
			return {
				"ok": false,
				"reason": &"invalid_activation_phase",
			}
	return _normalize_activation_step_result(context, result)


func _normalize_activation_step_result(context: RefCounted, result: Variant) -> Variant:
	if not (result is Dictionary):
		return result
	var result_dictionary: Dictionary = result
	var normalized: Dictionary = result_dictionary.duplicate(true)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(normalized, "metadata")
	if not metadata.is_empty():
		_merge_activation_metadata(context, metadata)
	if not GFVariantData.get_option_bool(normalized, "ok", true) and not normalized.has("kind"):
		normalized["kind"] = GFVariantData.get_option_string_name(
			normalized,
			"reason",
			&"activation_step_failed"
		)
	return normalized


func _make_transaction_context(context: RefCounted) -> Dictionary:
	return {
		"activation_context": context,
	}


func _get_transaction_activation_context(transaction_context: Dictionary) -> GFSkillActivationContext:
	var value: Variant = GFVariantData.get_option_value(transaction_context, "activation_context")
	if value is GFSkillActivationContext:
		return value
	return null


func _fail_from_transaction(
	context: RefCounted,
	transaction_report: Dictionary,
	default_reason: StringName
) -> Dictionary:
	var reason: StringName = default_reason
	var issues: Array = GFVariantData.get_option_array(transaction_report, "issues")
	if not issues.is_empty():
		var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
		reason = GFVariantData.get_option_string_name(first_issue, "kind", default_reason)
	return _fail_activation_context(context, reason, {
		"activation_transaction": transaction_report,
	})


func _apply_activation_callback_result(
	context: RefCounted,
	result: Variant,
	default_reason: StringName
) -> Dictionary:
	if result is Dictionary:
		var result_data: Dictionary = result
		var metadata_value: Variant = GFVariantData.get_option_value(result_data, "metadata", {})
		var metadata: Dictionary = GFVariantData.as_dictionary(metadata_value)
		if GFVariantData.get_option_bool(result_data, "ok", true):
			_merge_activation_metadata(context, metadata)
			return _context_to_report(context)
		var reason: StringName = GFVariantData.get_option_string_name(result_data, "reason", default_reason)
		return _fail_activation_context(context, reason, metadata)
	if result is bool and not GFVariantData.to_bool(result):
		return _fail_activation_context(context, default_reason)
	return _context_to_report(context)


func _merge_activation_metadata(context: RefCounted, extra_metadata: Dictionary) -> void:
	var metadata_value: Variant = GFObjectPropertyTools.read_property(context, NodePath("metadata"), {})
	var metadata: Dictionary = GFVariantData.as_dictionary(metadata_value)
	for key: Variant in extra_metadata.keys():
		metadata[key] = GFVariantData.duplicate_variant(extra_metadata[key])
	context.set("metadata", metadata)


func _fail_activation_context(
	context: RefCounted,
	reason: StringName,
	extra_metadata: Dictionary = {}
) -> Dictionary:
	if context != null and context.has_method("fail"):
		context.call("fail", reason, extra_metadata)
	if context != null and context.has_method("to_report"):
		return _context_to_report(context)
	return {
		"ok": false,
		"reason": reason,
		"metadata": extra_metadata.duplicate(true),
	}


func _get_owner_tag_source(valid_owner: Object) -> Variant:
	if valid_owner.has_method("get_tag_component"):
		return valid_owner.call("get_tag_component")
	if valid_owner.has_method("get_tags") or valid_owner.has_method("has_tag") or valid_owner.has_method("get_tag_count"):
		return valid_owner
	return null

func _resolve_cast_center(cast_center: Variant) -> Vector2:
	if cast_center is Vector2:
		return cast_center

	var valid_owner: Object = _get_valid_owner()
	if valid_owner != null:
		var owner_position: Variant = GFObjectPropertyTools.read_property(valid_owner, NodePath("global_position"))
		if owner_position is Vector2:
			return owner_position

	return Vector2.ZERO


func _get_valid_owner() -> Object:
	if owner == null or not is_instance_valid(owner):
		return null
	return owner


func _get_targeting_utility_2d() -> _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null

	return _variant_to_targeting_utility_2d(architecture.get_utility(_GF_SKILL_TARGETING_UTILITY_2D_SCRIPT))


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture: GFArchitecture = _variant_to_architecture(_architecture_ref.get_ref())
		if architecture != null:
			return architecture
	return GFAutoload.get_architecture_or_null()


func _report_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok", false)


func _context_to_report(context: RefCounted) -> Dictionary:
	if context == null or not context.has_method("to_report"):
		return {}
	return GFVariantData.as_dictionary(context.call("to_report"))


func _get_context_object(context: RefCounted, key: String) -> Object:
	if context == null:
		return null
	return _variant_to_object(GFObjectPropertyTools.read_property(context, NodePath(key)))


func _get_context_vector2(context: RefCounted, key: String, default_value: Vector2) -> Vector2:
	if context == null:
		return default_value
	var value: Variant = GFObjectPropertyTools.read_property(context, NodePath(key), default_value)
	if value is Vector2:
		return value
	return default_value


func _get_context_array(context: RefCounted, key: String) -> Array:
	if context == null:
		return []
	return GFVariantData.as_array(GFObjectPropertyTools.read_property(context, NodePath(key), []))


func _variant_to_object(value: Variant) -> Object:
	if is_instance_valid(value) and value is Object:
		return value
	return null


func _variant_to_architecture(value: Variant) -> GFArchitecture:
	if is_instance_valid(value) and value is GFArchitecture:
		return value
	return null


func _variant_to_targeting_utility_2d(value: Variant) -> _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT:
	if is_instance_valid(value) and value is _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT:
		return value
	return null
