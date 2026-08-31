## GFBindBuilder: 声明式装配链，用于把脚本绑定为模块或短生命周期工厂。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFBindBuilder
extends RefCounted


# --- 枚举 ---

## 绑定目标类别。
## [br]
## @api framework_internal
enum TargetKind {
	MODEL,
	SYSTEM,
	UTILITY,
	FACTORY,
}

## 绑定来源类别。
## [br]
## @api framework_internal
enum SourceKind {
	SELF,
	FACTORY,
	INSTANCE,
}


# --- 常量 ---

## 绑定生命周期枚举脚本缓存。
## [br]
## @api framework_internal
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")
const _GF_BINDING_PLAN_RESULT_SCRIPT = preload("res://addons/gf/kernel/core/gf_binding_plan_result.gd")


# --- 私有变量 ---

var _architecture: GFArchitecture = null
var _target_kind: TargetKind = TargetKind.FACTORY
var _script_cls: Script = null
var _source_kind: SourceKind = SourceKind.SELF
var _factory: Callable = Callable()
var _instance: Object = null
var _alias_cls: Script = null


# --- Godot 生命周期方法 ---

func _init(architecture: GFArchitecture, target_kind: TargetKind, script_cls: Script) -> void:
	_architecture = architecture
	_target_kind = target_kind
	_script_cls = script_cls


# --- 公共方法 ---

## 使用 Callable 作为绑定来源。
## [br]
## @api public
## [br]
## @param factory: 返回 Object 实例的工厂。
## [br]
## @return 当前 Builder，便于继续声明生命周期。
func from_factory(factory: Callable) -> GFBindBuilder:
	_source_kind = SourceKind.FACTORY
	_factory = factory
	return self


## 使用已有实例作为绑定来源。
## [br]
## @api public
## [br]
## @param instance: 要注册或暴露的实例。
## [br]
## @return 当前 Builder，便于继续声明生命周期。
func from_instance(instance: Object) -> GFBindBuilder:
	_source_kind = SourceKind.INSTANCE
	_instance = instance
	return self


## 额外登记一个查询别名。仅对 Model/System/Utility 有效。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_* 时使用的抽象脚本类型。
## [br]
## @return 当前 Builder，便于继续声明生命周期。
func with_alias(alias_cls: Script) -> GFBindBuilder:
	if _target_kind == TargetKind.FACTORY:
		push_warning("[GFBindBuilder] with_alias() 仅对 Model/System/Utility 有效，Factory 绑定会忽略 alias。")
		return self
	_alias_cls = alias_cls
	return self


## 以单例语义完成绑定。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 绑定成功时返回 true。
func as_singleton() -> bool:
	if _architecture == null:
		push_error("[GFBindBuilder] 架构为空，无法完成绑定。")
		return false

	if _target_kind == TargetKind.FACTORY:
		return _bind_factory(GFBindingLifetimesBase.Lifetime.SINGLETON)

	var candidate: Variant = _create_instance_from_source()
	if not _candidate_is_live(candidate):
		return false
	var instance: Object = candidate

	var registered: bool = await _register_lifecycle_instance(instance)
	if not registered:
		return false
	return _register_alias_if_needed(instance)


## 以瞬态语义完成绑定。仅短生命周期工厂支持 transient。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 绑定成功时返回 true。
func as_transient() -> bool:
	if _architecture == null:
		push_error("[GFBindBuilder] 架构为空，无法完成绑定。")
		return false

	if _target_kind != TargetKind.FACTORY:
		push_error("[GFBindBuilder] Model/System/Utility 是生命周期模块，不支持 as_transient()；请改用 bind_factory()。")
		return false

	return _bind_factory(GFBindingLifetimesBase.Lifetime.TRANSIENT)


# --- 框架内部方法 ---

## 为 required binding plan 冻结构建器配置。
## [br]
## @api framework_internal
## [br]
## @param expected_architecture: Plan 拥有的架构；必须与当前 Builder 精确相同。
## [br]
## @return 配置隔离的新 Builder；ownership 不匹配时返回 null。
func duplicate_for_required_plan_for_framework(
	expected_architecture: GFArchitecture
) -> GFBindBuilder:
	if expected_architecture == null or _architecture != expected_architecture:
		return null
	var duplicate: GFBindBuilder = GFBindBuilder.new(
		_architecture,
		_target_kind,
		_script_cls
	)
	duplicate._source_kind = _source_kind
	duplicate._factory = _factory
	duplicate._instance = _instance
	duplicate._alias_cls = _alias_cls
	return duplicate


## 返回 required plan 使用的公共绑定类别。
## [br]
## @api framework_internal
## [br]
## @return GFBindingPlanResult.BindingKind 枚举值。
func get_required_binding_kind_for_framework() -> int:
	match _target_kind:
		TargetKind.MODEL:
			return _GF_BINDING_PLAN_RESULT_SCRIPT.BindingKind.MODEL
		TargetKind.SYSTEM:
			return _GF_BINDING_PLAN_RESULT_SCRIPT.BindingKind.SYSTEM
		TargetKind.UTILITY:
			return _GF_BINDING_PLAN_RESULT_SCRIPT.BindingKind.UTILITY
		TargetKind.FACTORY:
			return _GF_BINDING_PLAN_RESULT_SCRIPT.BindingKind.FACTORY
	return _GF_BINDING_PLAN_RESULT_SCRIPT.BindingKind.NONE


## 返回 required plan 使用的稳定目标路径。
## [br]
## @api framework_internal
## [br]
## @return 目标脚本的 res:// 路径；目标为空时返回空字符串。
func get_required_target_path_for_framework() -> String:
	if _script_cls == null:
		return ""
	return _script_cls.resource_path


## 执行一次已冻结的 required binding attempt。
## Architecture 精确结算 candidate ownership：SELF/FACTORY 来源在拒绝后只释放一次；
## 生命周期模块的 from_instance() 在移交前被拒时仍归调用方，进入 injection 后由
## Architecture 结算；对象工厂的 from_instance() 永久沿用 legacy caller-owned
## 语义。框架只撤销自身注入与监听，不会在 required singleton 成功、失败回滚或
## Architecture dispose 时调用外部实例的 dispose() 或 free()。
## [br]
## @api framework_internal
## [br]
## @param lifetime: GFBindingLifetimes.Lifetime 枚举值。
## [br]
## @return 精确 attempt 结果。
func execute_required_binding_for_framework(lifetime: int) -> RequiredBindingAttempt:
	if _architecture == null:
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.ARCHITECTURE_UNAVAILABLE,
			"Required binding architecture is unavailable."
		)
	if not _architecture.can_accept_required_binding_plan_for_framework():
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.ARCHITECTURE_UNAVAILABLE,
			"Architecture admission is closed for required bindings."
		)
	if _script_cls == null:
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INVALID_ENTRY,
			"Required binding target script is null."
		)
	if (
		lifetime != GFBindingLifetimesBase.Lifetime.SINGLETON
		and lifetime != GFBindingLifetimesBase.Lifetime.TRANSIENT
	):
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INVALID_LIFETIME,
			"Required binding lifetime is invalid."
		)
	if (
		_target_kind != TargetKind.FACTORY
		and lifetime != GFBindingLifetimesBase.Lifetime.SINGLETON
	):
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INVALID_LIFETIME,
			"Lifecycle modules require singleton binding semantics."
		)
	if (
		_target_kind == TargetKind.FACTORY
		and _source_kind == SourceKind.INSTANCE
		and lifetime == GFBindingLifetimesBase.Lifetime.TRANSIENT
	):
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INVALID_LIFETIME,
			"Instance-backed factories require singleton binding semantics."
		)

	if _target_kind == TargetKind.FACTORY:
		return _execute_required_factory_binding(lifetime)
	var attempt_variant: Variant = (
		_architecture.run_required_binding_attempt_for_framework(
			_execute_required_lifecycle_binding
		)
	)
	if attempt_variant is RequiredBindingAttempt:
		var lifecycle_attempt: RequiredBindingAttempt = attempt_variant
		return lifecycle_attempt
	return _make_required_attempt(
		false,
		_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.REGISTRATION,
		_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.REGISTRATION_REJECTED,
		"Required lifecycle attempt did not return a terminal result."
	)


# --- 私有/辅助方法 ---


func _execute_required_lifecycle_binding() -> RequiredBindingAttempt:
	var candidate: Variant = _create_instance_from_source()
	if not _candidate_is_live(candidate):
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.INSTANCE_CREATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INSTANCE_CREATION_FAILED,
			"Required binding candidate creation failed."
		)
	var instance: Object = candidate
	var registration_error: Error = _register_required_lifecycle_instance(instance)
	if registration_error != OK:
		if (
			registration_error == ERR_INVALID_PARAMETER
			or registration_error == ERR_INVALID_DATA
		):
			return _make_required_attempt(
				false,
				_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.INSTANCE_CREATION,
				_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INSTANCE_CREATION_FAILED,
				"Required binding candidate does not match the declared target."
			)
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.REGISTRATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.REGISTRATION_REJECTED,
			"Required lifecycle registration was rejected."
		)
	if not _register_alias_checked_for_required_plan(instance):
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.ALIAS,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.ALIAS_REJECTED,
			"Required binding alias registration was rejected."
		)
	return _make_required_attempt(
		true,
		_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.NONE,
		_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.NONE,
		""
	)


func _create_instance_from_source() -> Variant:
	match _source_kind:
		SourceKind.SELF:
			if _script_cls == null or not _script_cls.can_instantiate():
				push_error("[GFBindBuilder] SELF 绑定需要可实例化的脚本类型。")
				return null
			return _instantiate_script_as_object(_script_cls)

		SourceKind.FACTORY:
			if not _factory.is_valid():
				push_error("[GFBindBuilder] from_factory() 收到无效 Callable。")
				return null
			var value: Variant = _factory.call()
			if typeof(value) != TYPE_OBJECT:
				push_error("[GFBindBuilder] from_factory() 必须返回 Object 实例。")
				return null
			if not _candidate_is_live(value):
				return null
			return value

		SourceKind.INSTANCE:
			if _instance == null:
				push_error("[GFBindBuilder] from_instance() 收到空实例。")
				return null
			return _instance

		_:
			return null


func _register_lifecycle_instance(instance: Object) -> bool:
	match _target_kind:
		TargetKind.MODEL:
			return await _architecture.register_model_instance(instance)

		TargetKind.SYSTEM:
			return await _architecture.register_system_instance(instance)

		TargetKind.UTILITY:
			return await _architecture.register_utility_instance(instance)
	return false


func _register_required_lifecycle_instance(instance: Object) -> Error:
	var release_owned_candidate_on_rejection: bool = (
		_source_kind != SourceKind.INSTANCE
	)
	match _target_kind:
		TargetKind.MODEL:
			return _architecture.register_model_instance_for_required_plan_for_framework(
				_script_cls,
				instance,
				release_owned_candidate_on_rejection
			)

		TargetKind.SYSTEM:
			return _architecture.register_system_instance_for_required_plan_for_framework(
				_script_cls,
				instance,
				release_owned_candidate_on_rejection
			)

		TargetKind.UTILITY:
			return _architecture.register_utility_instance_for_required_plan_for_framework(
				_script_cls,
				instance,
				release_owned_candidate_on_rejection
			)
	return ERR_INVALID_PARAMETER


func _register_alias_if_needed(instance: Object) -> bool:
	if _alias_cls == null or instance == null:
		return true

	var script: Script = _get_instance_script(instance)
	if script == null:
		return false

	match _target_kind:
		TargetKind.MODEL:
			_architecture.register_model_alias(_alias_cls, script)
			return true

		TargetKind.SYSTEM:
			_architecture.register_system_alias(_alias_cls, script)
			return true

		TargetKind.UTILITY:
			_architecture.register_utility_alias(_alias_cls, script)
			return true
	return false


func _register_alias_checked_for_required_plan(instance: Object) -> bool:
	if _alias_cls == null:
		return true
	if instance == null or _script_cls == null:
		return false
	match _target_kind:
		TargetKind.MODEL:
			return _architecture.register_model_alias_for_framework(_alias_cls, _script_cls)
		TargetKind.SYSTEM:
			return _architecture.register_system_alias_for_framework(_alias_cls, _script_cls)
		TargetKind.UTILITY:
			return _architecture.register_utility_alias_for_framework(_alias_cls, _script_cls)
	return false


func _bind_factory(lifetime: int) -> bool:
	match _source_kind:
		SourceKind.SELF:
			if _script_cls == null or not _script_cls.can_instantiate():
				push_error("[GFBindBuilder] bind_factory() 需要可实例化的脚本类型。")
				return false
			var self_factory: Callable = func() -> Variant:
				return _instantiate_script_as_object(_script_cls)
			return _architecture.register_factory(_script_cls, self_factory, lifetime)

		SourceKind.FACTORY:
			return _architecture.register_factory(_script_cls, _factory, lifetime)

		SourceKind.INSTANCE:
			if lifetime == GFBindingLifetimesBase.Lifetime.TRANSIENT:
				push_error("[GFBindBuilder] from_instance() 不支持 as_transient()；请改用 from_factory()。")
				return false
			return _architecture.register_factory_instance(_script_cls, _instance)
	return false


func _execute_required_factory_binding(lifetime: int) -> RequiredBindingAttempt:
	if (
		_source_kind == SourceKind.INSTANCE
		and (
			not _candidate_is_live(_instance)
			or not _candidate_matches_declared_target(_instance)
		)
	):
		return _make_required_attempt(
			false,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.INSTANCE_CREATION,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INSTANCE_CREATION_FAILED,
			"Required factory instance does not match the declared target."
		)
	var registered: bool = _bind_factory(lifetime)
	if registered:
		return _make_required_attempt(
			true,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Phase.NONE,
			_GF_BINDING_PLAN_RESULT_SCRIPT.Reason.NONE,
			""
		)
	var phase: int = _GF_BINDING_PLAN_RESULT_SCRIPT.Phase.REGISTRATION
	var reason: int = _GF_BINDING_PLAN_RESULT_SCRIPT.Reason.REGISTRATION_REJECTED
	if (
		(_source_kind == SourceKind.SELF and not _script_cls.can_instantiate())
		or (_source_kind == SourceKind.FACTORY and not _factory.is_valid())
		or (_source_kind == SourceKind.INSTANCE and _instance == null)
	):
		phase = _GF_BINDING_PLAN_RESULT_SCRIPT.Phase.INSTANCE_CREATION
		reason = _GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INSTANCE_CREATION_FAILED
	return _make_required_attempt(
		false,
		phase,
		reason,
		"Required factory binding was rejected."
	)


func _make_required_attempt(
	ok: bool,
	phase: int,
	reason: int,
	detail: String
) -> RequiredBindingAttempt:
	return RequiredBindingAttempt.new(ok, phase, reason, detail)


func _candidate_matches_declared_target(instance: Object) -> bool:
	if not _candidate_is_live(instance) or _script_cls == null:
		return false
	var actual_script: Script = _get_instance_script(instance)
	if actual_script == null:
		return false
	return GFScriptTypeInspector.script_extends_or_equals(
		actual_script,
		_script_cls
	)


func _candidate_is_live(candidate: Variant) -> bool:
	if (
		candidate == null
		or typeof(candidate) != TYPE_OBJECT
		or not is_instance_valid(candidate)
	):
		return false
	if not candidate is Object:
		return false
	if candidate is Node:
		var node: Node = candidate
		return not node.is_queued_for_deletion()
	return true


func _get_instance_script(instance: Object) -> Script:
	if not _candidate_is_live(instance):
		return null
	var raw_script: Variant = instance.get_script()
	if raw_script is Script:
		var script: Script = raw_script
		return script
	return null


func _instantiate_script_as_object(script_cls: Script) -> Variant:
	if script_cls == null:
		return null
	return script_cls.call("new")


# --- 内部类（内部状态类型） ---

## Required binding 单次执行的闭合内部终态。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 11.0.0
class RequiredBindingAttempt extends RefCounted:
	var _successful: bool = false
	var _phase: int = _GF_BINDING_PLAN_RESULT_SCRIPT.Phase.VALIDATION
	var _reason: int = _GF_BINDING_PLAN_RESULT_SCRIPT.Reason.INVALID_ENTRY
	var _detail: String = ""


	func _init(
		successful: bool,
		phase: int,
		reason: int,
		detail: String
	) -> void:
		_successful = successful
		_phase = phase
		_reason = reason
		_detail = detail


	## 返回 attempt 是否成功。
	## [br]
	## @api framework_internal
	## [br]
	## @return 注册与别名阶段均成功时返回 true。
	func is_successful_for_framework() -> bool:
		return _successful


	## 返回 attempt 失败阶段。
	## [br]
	## @api framework_internal
	## [br]
	## @return GFBindingPlanResult.Phase 枚举值。
	func get_phase_for_framework() -> int:
		return _phase


	## 返回 attempt 稳定失败原因。
	## [br]
	## @api framework_internal
	## [br]
	## @return GFBindingPlanResult.Reason 枚举值。
	func get_reason_for_framework() -> int:
		return _reason


	## 返回 attempt 有界诊断文本。
	## [br]
	## @api framework_internal
	## [br]
	## @return 成功时为空；失败时为稳定诊断文本。
	func get_detail_for_framework() -> String:
		return _detail
