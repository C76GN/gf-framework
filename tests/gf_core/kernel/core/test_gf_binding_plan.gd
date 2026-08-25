# GFBindingPlan 的 fail-fast、不可变声明与 Installer 事务回归测试。
extends GutTest


# --- 常量 ---

const INSTALLERS_SETTING: String = "gf/project/installers"
const INSTALLER_PATH: String = (
	"res://tests/gf_core/fixtures/installers/gf_required_binding_plan_installer.gd"
)
const NEXT_INSTALLER_PATH: String = (
	"res://tests/gf_core/fixtures/installers/gf_required_binding_plan_next_installer.gd"
)
const RESULT_SETTING: String = "gf/test/required_binding_plan_result"
const CLEANUP_COUNT_SETTING: String = "gf/test/required_binding_plan_cleanup_count"
const DISPOSE_COUNT_SETTING: String = "gf/test/required_binding_plan_utility_dispose_count"
const NEXT_INSTALLER_RAN_SETTING: String = "gf/test/required_binding_plan_next_installer_ran"
const REQUIRED_BINDING_PLAN_UTILITY_FIXTURE_SCRIPT: Script = preload(
	"res://tests/gf_core/fixtures/installers/required_binding_plan_utility_fixture.gd"
)
const IDENTITY_UNRELATED_UTILITY_SCRIPT = preload(
	"res://tests/gf_core/fixtures/required_binding_plan_unrelated_utility.gd"
)
const IDENTITY_UNRELATED_FACTORY_COMMAND_SCRIPT = preload(
	"res://tests/gf_core/fixtures/required_binding_plan_unrelated_factory_command.gd"
)
const RESULT_KEYS: Array[String] = [
	"status",
	"is_successful",
	"binding_kind",
	"failed_phase",
	"reason",
	"entry_index",
	"binding_id",
	"target_path",
	"lifetime",
	"executed_count",
	"detail",
]
const MANAGED_SETTINGS: Array[String] = [
	INSTALLERS_SETTING,
	RESULT_SETTING,
	CLEANUP_COUNT_SETTING,
	DISPOSE_COUNT_SETTING,
	NEXT_INSTALLER_RAN_SETTING,
]


# --- 私有变量 ---

var _previous_settings: Dictionary = {}


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_previous_settings.clear()
	for setting_name: String in MANAGED_SETTINGS:
		_previous_settings[setting_name] = {
			"had_setting": ProjectSettings.has_setting(setting_name),
			"value": ProjectSettings.get_setting(setting_name, null),
		}
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	ProjectSettings.set_setting(RESULT_SETTING, {})
	ProjectSettings.set_setting(CLEANUP_COUNT_SETTING, 0)
	ProjectSettings.set_setting(DISPOSE_COUNT_SETTING, 0)
	ProjectSettings.set_setting(NEXT_INSTALLER_RAN_SETTING, false)
	GFAutoload.reset_tree_exit_state()
	_dispose_current_architecture()


func after_each() -> void:
	_dispose_current_architecture()
	GFAutoload.reset_tree_exit_state()
	for setting_name: String in MANAGED_SETTINGS:
		var state_value: Variant = _previous_settings.get(setting_name, {})
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value
		if _dictionary_bool(state, "had_setting"):
			ProjectSettings.set_setting(setting_name, state.get("value"))
		elif ProjectSettings.has_setting(setting_name):
			ProjectSettings.clear(setting_name)
	_previous_settings.clear()


# --- 测试用例 ---

func test_success_runs_in_order_keeps_scope_active_and_reports_exact_schema() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var execution_order: Array[String] = []
	var first_builder: GFBindBuilder = binder.bind_utility(PlanFirstUtility).from_factory(
		func() -> Object:
			execution_order.append("first")
			return PlanFirstUtility.new()
	)
	var second_builder: GFBindBuilder = binder.bind_utility(PlanSecondUtility).from_factory(
		func() -> Object:
			execution_order.append("second")
			return PlanSecondUtility.new()
	)
	var factory_builder: GFBindBuilder = binder.bind_factory(PlanFactoryCommand).from_factory(
		func() -> Object:
			execution_order.append("factory_resolve")
			return PlanFactoryCommand.new()
	)

	var first_declaration: GFBindingPlan = plan.require_singleton(
		&"success.first",
		first_builder
	)
	var second_declaration: GFBindingPlan = plan.require_singleton(
		&"success.second",
		second_builder
	)
	var factory_declaration: GFBindingPlan = plan.require_transient(
		&"success.factory",
		factory_builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var result: GFBindingPlanResult = plan.execute(scope)

	assert_same(first_declaration, plan)
	assert_same(second_declaration, plan)
	assert_same(factory_declaration, plan)
	assert_eq(execution_order, ["first", "second"])
	assert_true(scope.is_active(), "成功执行不得替 Installer 提前 complete 或 cancel scope。")
	assert_not_null(architecture.get_local_utility(PlanFirstUtility))
	assert_not_null(architecture.get_local_utility(PlanSecondUtility))
	assert_true(architecture.has_factory(PlanFactoryCommand))
	_assert_result(
		result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		3,
		true
	)
	var duplicated_result: GFBindingPlanResult = result.duplicate_result()
	assert_not_same(duplicated_result, result)
	assert_eq(duplicated_result.to_dict(), result.to_dict())

	assert_true(await architecture.init())
	var created: Object = architecture.create_instance(PlanFactoryCommand)
	assert_true(created is PlanFactoryCommand)
	assert_eq(execution_order, ["first", "second", "factory_resolve"])
	architecture.dispose()


func test_result_rejects_detail_with_whitespace_only_bounded_prefix() -> void:
	var result: GFBindingPlanResult = GFBindingPlanResult.new()
	var default_state: Dictionary = result.to_dict()
	var detail: String = " ".repeat(512) + "x"

	var configure_error: Error = result.configure_for_framework(
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_PLAN,
		-1,
		&"",
		"",
		-1,
		0,
		detail
	)

	assert_eq(configure_error, ERR_INVALID_PARAMETER)
	assert_eq(result.to_dict(), default_state, "无效配置不得污染默认闭合状态。")
	var valid_error: Error = result.configure_for_framework(
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_PLAN,
		-1,
		&"",
		"",
		-1,
		0,
		"valid bounded detail"
	)
	assert_eq(valid_error, OK, "前一次无效配置不得把 Result 错误地标记为 configured。")


func test_result_rejects_incomplete_entry_tuple_and_closes_valid_duplicate() -> void:
	var target_path: String = _script_path(PlanFirstUtility)
	var none_kind_result: GFBindingPlanResult = GFBindingPlanResult.new()
	var none_kind_default: Dictionary = none_kind_result.to_dict()
	var none_kind_error: Error = none_kind_result.configure_for_framework(
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"result.none_kind",
		target_path,
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		"entry kind is missing"
	)
	assert_eq(none_kind_error, ERR_INVALID_PARAMETER)
	assert_eq(none_kind_result.to_dict(), none_kind_default)

	var missing_lifetime_result: GFBindingPlanResult = GFBindingPlanResult.new()
	var missing_lifetime_default: Dictionary = missing_lifetime_result.to_dict()
	var missing_lifetime_error: Error = missing_lifetime_result.configure_for_framework(
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"result.missing_lifetime",
		target_path,
		-1,
		1,
		"entry lifetime is missing"
	)
	assert_eq(missing_lifetime_error, ERR_INVALID_PARAMETER)
	assert_eq(missing_lifetime_result.to_dict(), missing_lifetime_default)

	var valid_result: GFBindingPlanResult = GFBindingPlanResult.new()
	var valid_error: Error = valid_result.configure_for_framework(
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"result.valid_entry",
		target_path,
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		"valid entry failure"
	)
	assert_eq(valid_error, OK)
	var duplicate_result_copy: GFBindingPlanResult = valid_result.duplicate_result()
	assert_not_same(duplicate_result_copy, valid_result)
	assert_eq(duplicate_result_copy.to_dict(), valid_result.to_dict())
	var duplicate_reconfigure_error: Error = duplicate_result_copy.configure_for_framework(
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_PLAN,
		-1,
		&"",
		"",
		-1,
		0,
		"must stay closed"
	)
	assert_eq(duplicate_reconfigure_error, ERR_ALREADY_IN_USE)


func test_registration_failure_stops_before_third_entry_and_settles_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var existing_duplicate: PlanDuplicateUtility = PlanDuplicateUtility.new()
	assert_true(await architecture.register_utility_instance(existing_duplicate))
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var execution_order: Array[String] = []
	var cleanup_count: Array[int] = [0]
	var scope: GFAsyncScope = GFAsyncScope.new()
	var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
		cleanup_count[0] += 1
	)

	var _first_entry: GFBindingPlan = plan.require_singleton(
		&"failure.first",
		binder.bind_utility(PlanFirstUtility).from_factory(func() -> Object:
			execution_order.append("first")
			return PlanFirstUtility.new()
	)
	)
	var _duplicate_entry: GFBindingPlan = plan.require_singleton(
		&"failure.duplicate",
		binder.bind_utility(PlanDuplicateUtility).from_factory(func() -> Object:
			execution_order.append("duplicate")
			return PlanDuplicateUtility.new()
	)
	)
	var _third_entry: GFBindingPlan = plan.require_singleton(
		&"failure.must_not_run",
		binder.bind_utility(PlanThirdUtility).from_factory(func() -> Object:
			execution_order.append("third")
			return PlanThirdUtility.new()
	)
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		1,
		&"failure.duplicate",
		_script_path(PlanDuplicateUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		2,
		false
	)
	assert_eq(execution_order, ["first", "duplicate"])
	assert_true(scope.is_cancel_requested())
	assert_eq(String(scope.get_cancel_reason()), result.get_detail())
	assert_eq(cleanup_count[0], 1)
	assert_false(scope.cancel("second reason"), "Plan 已结算后不得重复触发 scope cleanup。")
	assert_eq(cleanup_count[0], 1)
	assert_true(architecture.has_initialization_failed())
	assert_null(architecture.get_local_utility(PlanFirstUtility), "失败结算必须回滚先前成功 entry。")
	assert_null(architecture.get_local_utility(PlanDuplicateUtility), "失败结算必须清空候选架构注册表。")
	assert_push_warning(
		"[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。"
	)
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_duplicate_binding_id_fails_validation_before_any_entry_runs() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var call_order: Array[String] = []
	var _first_entry: GFBindingPlan = plan.require_singleton(
		&"duplicate.id",
		binder.bind_utility(PlanFirstUtility).from_factory(func() -> Object:
			call_order.append("first")
			return PlanFirstUtility.new()
	)
	)
	var _second_entry: GFBindingPlan = plan.require_singleton(
		&"duplicate.id",
		binder.bind_utility(PlanSecondUtility).from_factory(func() -> Object:
			call_order.append("second")
			return PlanSecondUtility.new()
	)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.DUPLICATE_BINDING_ID,
		1,
		&"duplicate.id",
		_script_path(PlanSecondUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		0,
		false
	)
	assert_true(call_order.is_empty(), "Plan validation 必须早于任何 builder side effect。")
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_invalid_binding_ids_fail_before_execution_with_no_entry_shape() -> void:
	var invalid_ids: Array[StringName] = [
		&"",
		StringName("x".repeat(129)),
	]
	for invalid_id: StringName in invalid_ids:
		var architecture: GFArchitecture = GFArchitecture.new()
		var binder: GFBinder = architecture.create_binder()
		var plan: GFBindingPlan = binder.create_required_plan()
		var factory_calls: Array[int] = [0]
		var _entry: GFBindingPlan = plan.require_singleton(
			invalid_id,
			binder.bind_utility(PlanInvalidIdUtility).from_factory(func() -> Object:
				factory_calls[0] += 1
				return PlanInvalidIdUtility.new()
		)
		)
		var scope: GFAsyncScope = GFAsyncScope.new()
		var cleanup_count: Array[int] = [0]
		var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
			cleanup_count[0] += 1
		)

		var result: GFBindingPlanResult = plan.execute(scope)

		_assert_result(
			result,
			GFBindingPlanResult.Status.INVALID_REQUEST,
			GFBindingPlanResult.BindingKind.NONE,
			GFBindingPlanResult.Phase.VALIDATION,
			GFBindingPlanResult.Reason.INVALID_ENTRY,
			-1,
			&"",
			"",
			-1,
			0,
			false
		)
		assert_eq(factory_calls[0], 0, "无效 binding_id 不得执行 builder source。")
		assert_true(architecture.has_initialization_failed())
		assert_true(scope.is_cancel_requested())
		assert_eq(cleanup_count[0], 1)
		assert_false(scope.cancel("second invalid-id cancellation"))
		assert_eq(cleanup_count[0], 1)
		assert_push_error(result.get_detail())
		architecture.dispose()


func test_null_builder_fails_before_execution_with_no_entry_shape() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var valid_builder: GFBindBuilder = binder.bind_utility(PlanInvalidIdUtility).from_factory(
		func() -> Object:
			factory_calls[0] += 1
			return PlanInvalidIdUtility.new()
	)
	var _valid_entry: GFBindingPlan = plan.require_singleton(
		&"invalid.before_null",
		valid_builder
	)
	var null_declaration: GFBindingPlan = plan.require_singleton(
		&"invalid.null_builder",
		null
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var cleanup_count: Array[int] = [0]
	var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
		cleanup_count[0] += 1
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	assert_same(null_declaration, plan)
	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_ENTRY,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(factory_calls[0], 0, "null builder 必须在任何已声明 entry 运行前失败。")
	assert_true(architecture.has_initialization_failed())
	assert_true(scope.is_cancel_requested())
	assert_eq(cleanup_count[0], 1)
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_oversized_target_path_fails_before_execution_with_no_entry_shape() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var long_target_script: GDScript = GDScript.new()
	long_target_script.resource_path = "res://" + "x".repeat(504) + ".gd"
	assert_gt(long_target_script.resource_path.length(), 512)
	var factory_calls: Array[int] = [0]
	var long_target_builder: GFBindBuilder = binder.bind_utility(
		long_target_script
	).from_factory(func() -> Object:
		factory_calls[0] += 1
		return PlanInvalidIdUtility.new()
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"invalid.long_target_path",
		long_target_builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var cleanup_count: Array[int] = [0]
	var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
		cleanup_count[0] += 1
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_ENTRY,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(factory_calls[0], 0, "超长 target_path 不得执行 builder source。")
	assert_true(architecture.has_initialization_failed())
	assert_true(scope.is_cancel_requested())
	assert_eq(cleanup_count[0], 1)
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_alias_rejection_reports_alias_phase_and_rolls_back_module() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var utility: PlanAliasUtility = PlanAliasUtility.new()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"alias.invalid",
		binder.bind_utility(PlanAliasUtility).from_instance(utility).with_alias(
			PlanUnrelatedModel
		)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.ALIAS,
		GFBindingPlanResult.Reason.ALIAS_REJECTED,
		0,
		&"alias.invalid",
		_script_path(PlanAliasUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_null(architecture.get_local_utility(PlanAliasUtility))
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_required_alias_rejects_existing_direct_registration() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(
		await architecture.register_utility_instance(PlanSnapshotAliasBase.new())
	)
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"alias.direct_conflict",
		binder.bind_utility(PlanSnapshotUtility).with_alias(
			PlanSnapshotAliasBase
		)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.ALIAS,
		GFBindingPlanResult.Reason.ALIAS_REJECTED,
		0,
		&"alias.direct_conflict",
		_script_path(PlanSnapshotUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_null(architecture.get_local_utility(PlanSnapshotAliasBase))
	assert_null(architecture.get_local_utility(PlanSnapshotUtility))
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_required_alias_rejects_reuse_for_different_targets() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _first_entry: GFBindingPlan = plan.require_singleton(
		&"alias.first_target",
		binder.bind_utility(PlanSnapshotUtility).with_alias(
			PlanSnapshotAliasBase
		)
	)
	var _second_entry: GFBindingPlan = plan.require_singleton(
		&"alias.second_target",
		binder.bind_utility(PlanSnapshotSecondUtility).with_alias(
			PlanSnapshotAliasBase
		)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.ALIAS,
		GFBindingPlanResult.Reason.ALIAS_REJECTED,
		1,
		&"alias.second_target",
		_script_path(PlanSnapshotSecondUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		2,
		false
	)
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_null(architecture.get_local_utility(PlanSnapshotAliasBase))
	assert_null(architecture.get_local_utility(PlanSnapshotUtility))
	assert_null(architecture.get_local_utility(PlanSnapshotSecondUtility))
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_required_alias_accepts_existing_idempotent_mapping() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	architecture.register_utility_alias(
		PlanSnapshotAliasBase,
		PlanSnapshotUtility
	)
	assert_push_warning(
		"[GFArchitecture] register_utility_alias：目标类型尚未注册，仍会记录别名。"
	)
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"alias.idempotent",
		binder.bind_utility(PlanSnapshotUtility).with_alias(
			PlanSnapshotAliasBase
		)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		1,
		true
	)
	assert_true(scope.is_active())
	var utility: Object = architecture.get_local_utility(PlanSnapshotUtility)
	assert_not_null(utility)
	assert_same(architecture.get_local_utility(PlanSnapshotAliasBase), utility)
	assert_true(await architecture.init())
	architecture.dispose()


func test_instance_creation_failure_reports_exact_first_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"creation.invalid",
		binder.bind_utility(PlanCreationUtility).from_factory(func() -> Object:
			return null
	)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"creation.invalid",
		_script_path(PlanCreationUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_push_error("[GFBindBuilder] from_factory() 必须返回 Object 实例。")
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_self_constructor_returning_freed_node_fails_creation_without_disposal() -> void:
	PlanSelfFreeingLifecycleNode.initialization_count = 0
	PlanSelfFreeingLifecycleNode.dispose_count = 0
	PlanSelfFreeingLifecycleNode.last_instance = null
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"liveness.self_constructor_freed",
		binder.bind_utility(PlanSelfFreeingLifecycleNode)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"liveness.self_constructor_freed",
		_script_path(PlanSelfFreeingLifecycleNode),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(PlanSelfFreeingLifecycleNode.initialization_count, 1)
	assert_not_null(PlanSelfFreeingLifecycleNode.last_instance)
	assert_true(PlanSelfFreeingLifecycleNode.last_instance.get_ref() == null)
	assert_eq(PlanSelfFreeingLifecycleNode.dispose_count, 0)
	assert_null(architecture.get_local_utility(PlanSelfFreeingLifecycleNode))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	PlanSelfFreeingLifecycleNode.last_instance = null
	architecture.dispose()


func test_legacy_self_constructor_returning_freed_node_rejects_without_registry() -> void:
	PlanSelfFreeingLifecycleNode.initialization_count = 0
	PlanSelfFreeingLifecycleNode.dispose_count = 0
	PlanSelfFreeingLifecycleNode.last_instance = null
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()

	var registered: bool = await binder.bind_utility(
		PlanSelfFreeingLifecycleNode
	).as_singleton()

	assert_false(registered)
	assert_eq(PlanSelfFreeingLifecycleNode.initialization_count, 1)
	assert_not_null(PlanSelfFreeingLifecycleNode.last_instance)
	assert_true(PlanSelfFreeingLifecycleNode.last_instance.get_ref() == null)
	assert_eq(PlanSelfFreeingLifecycleNode.dispose_count, 0)
	assert_null(architecture.get_local_utility(PlanSelfFreeingLifecycleNode))
	PlanSelfFreeingLifecycleNode.last_instance = null
	architecture.dispose()


func test_self_factory_constructor_returning_freed_node_fails_resolution() -> void:
	PlanSelfFreeingLifecycleNode.initialization_count = 0
	PlanSelfFreeingLifecycleNode.dispose_count = 0
	PlanSelfFreeingLifecycleNode.last_instance = null
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"liveness.self_factory_constructor_freed",
		binder.bind_factory(PlanSelfFreeingLifecycleNode)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		1,
		true
	)
	assert_eq(PlanSelfFreeingLifecycleNode.initialization_count, 0)
	assert_true(scope.is_active(), "deferred SELF provider 不得在 Plan 执行期求值。")
	assert_true(await architecture.init())
	var created: Object = architecture.create_instance(PlanSelfFreeingLifecycleNode)
	assert_null(created)
	assert_eq(PlanSelfFreeingLifecycleNode.initialization_count, 1)
	assert_not_null(PlanSelfFreeingLifecycleNode.last_instance)
	assert_true(PlanSelfFreeingLifecycleNode.last_instance.get_ref() == null)
	assert_eq(PlanSelfFreeingLifecycleNode.dispose_count, 0)
	assert_true(architecture.has_factory(PlanSelfFreeingLifecycleNode))
	assert_push_error("[GFBinding] 绑定来源返回了已失效的 Object 实例。")
	PlanSelfFreeingLifecycleNode.last_instance = null
	architecture.dispose()


func test_factory_resolution_preserves_topology_error_before_freed_provider_value() -> void:
	PlanSelfFreeingLifecycleNode.initialization_count = 0
	PlanSelfFreeingLifecycleNode.dispose_count = 0
	PlanSelfFreeingLifecycleNode.last_instance = null
	var architecture: GFArchitecture = GFArchitecture.new()
	var provider_calls: Array[int] = [0]
	var mutation_results: Array[bool] = []
	var provider: Callable = func() -> Variant:
		provider_calls[0] += 1
		var nested_provider: Callable = func() -> Object:
			return PlanExternalFactoryCommand.new()
		mutation_results.append(
			architecture.register_factory(
				PlanExternalFactoryCommand,
				nested_provider
			)
		)
		return PlanSelfFreeingLifecycleNode.new()
	assert_true(
		architecture.register_factory(
			PlanFactoryCommand,
			provider
		)
	)
	assert_true(await architecture.init())

	var created: Object = architecture.create_instance(PlanFactoryCommand)

	assert_null(created)
	assert_eq(provider_calls[0], 1)
	assert_eq(mutation_results, [false])
	assert_eq(PlanSelfFreeingLifecycleNode.initialization_count, 1)
	assert_not_null(PlanSelfFreeingLifecycleNode.last_instance)
	assert_true(PlanSelfFreeingLifecycleNode.last_instance.get_ref() == null)
	assert_eq(PlanSelfFreeingLifecycleNode.dispose_count, 0)
	assert_true(architecture.has_factory(PlanFactoryCommand))
	assert_false(architecture.has_factory(PlanExternalFactoryCommand))
	assert_push_error(
		"[GFArchitecture] register_factory 失败：工厂解析期间禁止重入修改模块拓扑。"
	)
	PlanSelfFreeingLifecycleNode.last_instance = null
	architecture.dispose()


func test_rejected_from_instance_candidate_remains_caller_owned() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var existing: PlanExternalInstanceUtility = PlanExternalInstanceUtility.new()
	assert_true(await architecture.register_utility_instance(existing))
	var rejected_external: PlanExternalInstanceUtility = PlanExternalInstanceUtility.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.external",
		binder.bind_utility(PlanExternalInstanceUtility).from_instance(rejected_external)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.external",
		_script_path(PlanExternalInstanceUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(rejected_external.dispose_count, 0, "from_instance() 被拒对象仍归调用方。")
	assert_eq(existing.dispose_count, 1, "已注册候选由 Architecture 失败回滚。")
	assert_push_warning(
		"[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。"
	)
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_from_factory_returning_registered_instance_is_disposed_only_by_rollback() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var existing: PlanExternalInstanceUtility = PlanExternalInstanceUtility.new()
	assert_true(await architecture.register_utility_instance(existing))
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var builder: GFBindBuilder = binder.bind_utility(
		PlanExternalInstanceUtility
	).from_factory(func() -> Object:
		factory_calls[0] += 1
		return existing
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.registered_factory_result",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.registered_factory_result",
		_script_path(PlanExternalInstanceUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(factory_calls[0], 1)
	assert_eq(existing.dispose_count, 1, "重复返回的已注册实例只能由 Plan rollback 释放一次。")
	assert_null(architecture.get_local_utility(PlanExternalInstanceUtility))
	assert_true(architecture.has_initialization_failed())
	assert_true(scope.is_cancel_requested())
	assert_push_warning(
		"[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。"
	)
	assert_push_error(result.get_detail())
	architecture.dispose()
	assert_eq(existing.dispose_count, 1)


func test_duplicate_target_with_candidate_registered_under_other_key_rolls_back_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var target_owner: PlanIdentityBaseUtility = PlanIdentityBaseUtility.new()
	var compatible_other_key: PlanIdentitySubclassUtility = (
		PlanIdentitySubclassUtility.new()
	)
	assert_true(await architecture.register_utility_instance(target_owner))
	assert_true(await architecture.register_utility_instance(compatible_other_key))
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_factory(func() -> Object:
		factory_calls[0] += 1
		return compatible_other_key
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.duplicate_target_other_key",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.duplicate_target_other_key",
		_script_path(PlanIdentityBaseUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(factory_calls[0], 1)
	assert_eq(target_owner.dispose_count, 1, "target key owner 只能由 rollback 释放一次。")
	assert_eq(compatible_other_key.dispose_count, 1, "另一 key 的 candidate 只能由 rollback 释放一次。")
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_null(architecture.get_local_utility(PlanIdentitySubclassUtility))
	assert_true(architecture.has_initialization_failed())
	assert_true(scope.is_cancel_requested())
	assert_push_warning(
		"[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。"
	)
	assert_push_error(result.get_detail())
	architecture.dispose()
	assert_eq(target_owner.dispose_count, 1)
	assert_eq(compatible_other_key.dispose_count, 1)


func test_later_mismatch_cannot_predispose_module_registered_by_earlier_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var compatible: PlanIdentitySubclassUtility = PlanIdentitySubclassUtility.new()
	var execution_order: Array[String] = []
	var compatible_builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_factory(func() -> Object:
		execution_order.append("registered")
		return compatible
	)
	var mismatch_builder: GFBindBuilder = binder.bind_utility(
		PlanExternalInstanceUtility
	).from_factory(func() -> Object:
		execution_order.append("mismatch")
		return compatible
	)
	var _compatible_entry: GFBindingPlan = plan.require_singleton(
		&"ownership.earlier_registered",
		compatible_builder
	)
	var _mismatch_entry: GFBindingPlan = plan.require_singleton(
		&"ownership.later_mismatch",
		mismatch_builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		1,
		&"ownership.later_mismatch",
		_script_path(PlanExternalInstanceUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		2,
		false
	)
	assert_eq(execution_order, ["registered", "mismatch"])
	assert_eq(compatible.dispose_count, 1, "已由前一 entry 注册的 B 只能由 rollback 释放一次。")
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_null(architecture.get_local_utility(PlanExternalInstanceUtility))
	assert_true(architecture.has_initialization_failed())
	assert_true(scope.is_cancel_requested())
	assert_push_error(result.get_detail())
	architecture.dispose()
	assert_eq(compatible.dispose_count, 1)


func test_from_instance_candidate_is_architecture_owned_after_injection_begins() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var candidate: PlanDisposeDuringInjectionUtility = (
		PlanDisposeDuringInjectionUtility.new()
	)
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var builder: GFBindBuilder = binder.bind_utility(
		PlanDisposeDuringInjectionUtility
	).from_instance(candidate)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.injected_external",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.injected_external",
		_script_path(PlanDisposeDuringInjectionUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_true(architecture.is_disposed())
	assert_true(candidate.dependencies_released, "进入 injection 后应由 Architecture 释放依赖。")
	assert_eq(candidate.dispose_count, 1, "进入 injection 后的外部候选必须且只结算一次。")
	assert_true(scope.is_cancel_requested())
	architecture.dispose()


func test_factory_candidate_changing_script_during_injection_is_rejected_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var injection_calls: Array[int] = [0]
	var typed_candidate: PlanScriptMutatingInjectionUtility = (
		PlanScriptMutatingInjectionUtility.new()
	)
	typed_candidate.replacement_script = IDENTITY_UNRELATED_UTILITY_SCRIPT
	typed_candidate.injection_callback = func() -> void:
		injection_calls[0] += 1
	var candidate: Object = typed_candidate
	var builder: GFBindBuilder = binder.bind_utility(
		PlanScriptMutatingInjectionUtility
	).from_factory(func() -> Object:
		return candidate
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"liveness.script_changed_during_injection",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"liveness.script_changed_during_injection",
		_script_path(PlanScriptMutatingInjectionUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(injection_calls[0], 1)
	assert_true(is_instance_valid(candidate))
	assert_same(_object_script(candidate), IDENTITY_UNRELATED_UTILITY_SCRIPT)
	assert_eq(_object_int_property(candidate, &"dispose_count"), 1, "post-injection rejection 必须结算一次。")
	assert_null(architecture.get_local_utility(PlanScriptMutatingInjectionUtility))
	assert_null(architecture.get_local_utility(IDENTITY_UNRELATED_UTILITY_SCRIPT))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()
	assert_eq(_object_int_property(candidate, &"dispose_count"), 1)


func test_reentrant_registration_then_script_change_disposes_candidate_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var callback_calls: Array[int] = [0]
	var reentrant_attempts: Array[int] = [0]
	var reentrant_errors: Array[int] = []
	var typed_candidate: PlanReentrantInjectionUtility = (
		PlanReentrantInjectionUtility.new()
	)
	var candidate: Object = typed_candidate
	typed_candidate.mutate_after_outer_injection = true
	typed_candidate.replacement_script = IDENTITY_UNRELATED_UTILITY_SCRIPT
	typed_candidate.injection_callback = func() -> void:
		callback_calls[0] += 1
		if reentrant_attempts[0] == 0:
			reentrant_attempts[0] += 1
			var registration_error: Error = (
				architecture.register_utility_instance_for_required_plan_for_framework(
					PlanReentrantInjectionUtility,
					candidate,
					false
				)
			)
			reentrant_errors.append(registration_error)
	var builder: GFBindBuilder = binder.bind_utility(
		PlanReentrantInjectionUtility
	).from_factory(func() -> Object:
		return candidate
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.reentrant_then_script_change",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.reentrant_then_script_change",
		_script_path(PlanReentrantInjectionUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(callback_calls[0], 2, "outer 与 nested registration 应各注入一次。")
	assert_eq(reentrant_attempts[0], 1)
	assert_eq(reentrant_errors, [OK])
	assert_true(is_instance_valid(candidate))
	assert_same(_object_script(candidate), IDENTITY_UNRELATED_UTILITY_SCRIPT)
	assert_eq(_object_int_property(candidate, &"dispose_count"), 1, "重入保留的候选最终只能结算一次。")
	assert_null(architecture.get_local_utility(PlanReentrantInjectionUtility))
	assert_null(architecture.get_local_utility(IDENTITY_UNRELATED_UTILITY_SCRIPT))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()
	assert_eq(_object_int_property(candidate, &"dispose_count"), 1)


func test_reentrant_registration_then_initialization_failure_disposes_candidate_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var callback_calls: Array[int] = [0]
	var reentrant_attempts: Array[int] = [0]
	var reentrant_errors: Array[int] = []
	var candidate: PlanReentrantInjectionUtility = PlanReentrantInjectionUtility.new()
	candidate.injection_callback = func() -> void:
		callback_calls[0] += 1
		if reentrant_attempts[0] == 0:
			reentrant_attempts[0] += 1
			var registration_error: Error = (
				architecture.register_utility_instance_for_required_plan_for_framework(
					PlanReentrantInjectionUtility,
					candidate,
					false
				)
			)
			reentrant_errors.append(registration_error)
			architecture.fail_initialization("reentrant injection failure")
	var builder: GFBindBuilder = binder.bind_utility(
		PlanReentrantInjectionUtility
	).from_factory(func() -> Object:
		return candidate
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.reentrant_then_failure",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.reentrant_then_failure",
		_script_path(PlanReentrantInjectionUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(callback_calls[0], 2, "outer 与 nested registration 应各注入一次。")
	assert_eq(reentrant_attempts[0], 1)
	assert_eq(reentrant_errors, [OK])
	assert_eq(candidate.dispose_count, 1, "失败结算与 outer cleanup 必须共享 disposal claim。")
	assert_null(architecture.get_local_utility(PlanReentrantInjectionUtility))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error("reentrant injection failure")
	candidate.injection_callback = Callable()
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_reentrant_registration_then_unregister_cannot_recommit_candidate() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var callback_calls: Array[int] = [0]
	var reentrant_attempts: Array[int] = [0]
	var reentrant_errors: Array[int] = []
	var unregister_results: Array[bool] = []
	var candidate: PlanReentrantInjectionUtility = PlanReentrantInjectionUtility.new()
	candidate.injection_callback = func() -> void:
		callback_calls[0] += 1
		if reentrant_attempts[0] == 0:
			reentrant_attempts[0] += 1
			var registration_error: Error = (
				architecture.register_utility_instance_for_required_plan_for_framework(
					PlanReentrantInjectionUtility,
					candidate,
					false
				)
			)
			reentrant_errors.append(registration_error)
			var unregister_result: bool = await architecture.unregister_utility(
				PlanReentrantInjectionUtility
			)
			unregister_results.append(unregister_result)
	var builder: GFBindBuilder = binder.bind_utility(
		PlanReentrantInjectionUtility
	).from_factory(func() -> Object:
		return candidate
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.reentrant_then_unregister",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.reentrant_then_unregister",
		_script_path(PlanReentrantInjectionUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(callback_calls[0], 2, "outer 与 nested registration 应各注入一次。")
	assert_eq(reentrant_attempts[0], 1)
	assert_eq(reentrant_errors, [OK])
	assert_eq(unregister_results, [true])
	assert_eq(candidate.dispose_count, 1, "nested unregister 与 outer cleanup 只能结算一次。")
	assert_null(architecture.get_local_utility(PlanReentrantInjectionUtility))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	candidate.injection_callback = Callable()
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_factory_callback_register_then_unregister_prevents_outer_recommit() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var injection_calls: Array[int] = [0]
	var nested_registration_errors: Array[int] = []
	var unregister_results: Array[bool] = []
	var candidate: PlanReentrantInjectionUtility = PlanReentrantInjectionUtility.new()
	candidate.injection_callback = func() -> void:
		injection_calls[0] += 1
	var builder: GFBindBuilder = binder.bind_utility(
		PlanReentrantInjectionUtility
	).from_factory(func() -> Object:
		factory_calls[0] += 1
		var registration_error: Error = (
			architecture.register_utility_instance_for_required_plan_for_framework(
				PlanReentrantInjectionUtility,
				candidate,
				false
			)
		)
		nested_registration_errors.append(registration_error)
		var unregister_result: bool = await architecture.unregister_utility(
			PlanReentrantInjectionUtility
		)
		unregister_results.append(unregister_result)
		return candidate
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.factory_callback_claimed",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		0,
		&"ownership.factory_callback_claimed",
		_script_path(PlanReentrantInjectionUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(factory_calls[0], 1)
	assert_eq(nested_registration_errors, [OK])
	assert_eq(unregister_results, [true])
	assert_eq(injection_calls[0], 1, "outer wrapper 不得再次注入已结算 candidate。")
	assert_eq(candidate.dispose_count, 1, "whole-attempt disposal reservation 必须阻止二次结算。")
	assert_null(architecture.get_local_utility(PlanReentrantInjectionUtility))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	candidate.injection_callback = Callable()
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_factory_created_unrelated_lifecycle_candidate_is_released_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var unrelated: Object = IDENTITY_UNRELATED_UTILITY_SCRIPT.new()
	unrelated.set("hostile_architecture", architecture)
	assert_ne(
		_script_path(PlanIdentityBaseUtility),
		_script_path(IDENTITY_UNRELATED_UTILITY_SCRIPT)
	)
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_factory(func() -> Object:
		return unrelated
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.lifecycle_factory_mismatch",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"identity.lifecycle_factory_mismatch",
		_script_path(PlanIdentityBaseUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(_object_int_property(unrelated, &"dispose_count"), 1, "from_factory() 创建的不匹配候选由 Plan 释放一次。")
	assert_eq(_object_int_property(unrelated, &"reentrant_registration_attempts"), 1)
	assert_false(_object_bool_property(unrelated, &"reentrant_registration_result"))
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_null(architecture.get_local_utility(IDENTITY_UNRELATED_UTILITY_SCRIPT))
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_factory_created_wrong_kind_node_is_disposed_and_freed_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var dispose_calls: Array[int] = [0]
	var wrong_kind: PlanWrongKindOwnedNode = PlanWrongKindOwnedNode.new()
	wrong_kind.dispose_callback = func() -> void:
		dispose_calls[0] += 1
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_factory(func() -> Object:
		return wrong_kind
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.lifecycle_wrong_kind_node",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"identity.lifecycle_wrong_kind_node",
		_script_path(PlanIdentityBaseUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(dispose_calls[0], 1, "source-owned wrong-kind Node 必须且只 dispose 一次。")
	assert_false(is_instance_valid(wrong_kind), "被拒绝的无父 Node 不得成为 orphan。")
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_lifecycle_from_instance_rejects_node_freed_after_declaration() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var dispose_calls: Array[int] = [0]
	var external: PlanFreedLifecycleNode = PlanFreedLifecycleNode.new()
	external.dispose_callback = func() -> void:
		dispose_calls[0] += 1
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_instance(external)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"liveness.lifecycle_instance_freed",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	external.free()
	assert_false(is_instance_valid(external))

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"liveness.lifecycle_instance_freed",
		_script_path(PlanIdentityBaseUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(dispose_calls[0], 0, "caller-owned freed Node 不得被框架调用。")
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error("[GFBindBuilder] from_instance() 收到空实例。")
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_lifecycle_from_factory_rejects_already_freed_object() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var dispose_calls: Array[int] = [0]
	var typed_candidate: PlanFreedLifecycleNode = PlanFreedLifecycleNode.new()
	typed_candidate.dispose_callback = func() -> void:
		dispose_calls[0] += 1
	PlanFreedCandidateHolder.candidate = typed_candidate
	typed_candidate.free()
	assert_false(is_instance_valid(PlanFreedCandidateHolder.candidate))
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_factory(func() -> Variant:
		factory_calls[0] += 1
		return PlanFreedCandidateHolder.candidate
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"liveness.lifecycle_factory_freed",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"liveness.lifecycle_factory_freed",
		_script_path(PlanIdentityBaseUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(factory_calls[0], 1)
	assert_eq(dispose_calls[0], 0, "source-owned 但已释放的 Object 不得被框架调用。")
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	PlanFreedCandidateHolder.candidate = null
	architecture.dispose()


func test_external_unrelated_lifecycle_candidate_remains_caller_owned() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var unrelated: Object = IDENTITY_UNRELATED_UTILITY_SCRIPT.new()
	assert_ne(
		_script_path(PlanIdentityBaseUtility),
		_script_path(IDENTITY_UNRELATED_UTILITY_SCRIPT)
	)
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_instance(unrelated)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.lifecycle_instance_mismatch",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"identity.lifecycle_instance_mismatch",
		_script_path(PlanIdentityBaseUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(_object_int_property(unrelated, &"dispose_count"), 0, "不匹配的 from_instance() 候选始终归调用方。")
	assert_null(architecture.get_local_utility(PlanIdentityBaseUtility))
	assert_null(architecture.get_local_utility(IDENTITY_UNRELATED_UTILITY_SCRIPT))
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_declared_base_accepts_subclass_from_instance() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var compatible: PlanIdentitySubclassUtility = PlanIdentitySubclassUtility.new()
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_instance(compatible)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.compatible_instance",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		1,
		true
	)
	assert_same(architecture.get_local_utility(PlanIdentityBaseUtility), compatible)
	assert_true(scope.is_active())
	architecture.dispose()
	assert_eq(compatible.dispose_count, 1, "成功移交的生命周期实例由 Architecture 释放。")


func test_declared_base_accepts_subclass_from_factory() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var compatible: PlanIdentitySubclassUtility = PlanIdentitySubclassUtility.new()
	var builder: GFBindBuilder = binder.bind_utility(
		PlanIdentityBaseUtility
	).from_factory(func() -> Object:
		return compatible
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.compatible_factory",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		1,
		true
	)
	assert_same(architecture.get_local_utility(PlanIdentityBaseUtility), compatible)
	assert_true(scope.is_active())
	architecture.dispose()
	assert_eq(compatible.dispose_count, 1, "成功移交的 factory 候选由 Architecture 释放。")


func test_transient_factory_from_instance_is_an_invalid_lifetime_attempt() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var external_command: PlanExternalFactoryCommand = PlanExternalFactoryCommand.new()
	var _entry: GFBindingPlan = plan.require_transient(
		&"lifetime.external_transient",
		binder.bind_factory(PlanExternalFactoryCommand).from_instance(external_command)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var cleanup_count: Array[int] = [0]
	var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
		cleanup_count[0] += 1
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.FACTORY,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_LIFETIME,
		0,
		&"lifetime.external_transient",
		_script_path(PlanExternalFactoryCommand),
		GFBindingLifetimes.Lifetime.TRANSIENT,
		1,
		false
	)
	assert_false(architecture.has_factory(PlanExternalFactoryCommand))
	assert_eq(external_command.dispose_count, 0, "无效 from_instance 仍归调用方。")
	assert_true(scope.is_cancel_requested())
	assert_eq(cleanup_count[0], 1)
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_factory_from_instance_remains_caller_owned_after_architecture_dispose() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var external: PlanExternalFactoryCommand = PlanExternalFactoryCommand.new()
	var builder: GFBindBuilder = binder.bind_factory(
		PlanExternalFactoryCommand
	).from_instance(external)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ownership.factory_dispose",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		1,
		true
	)
	assert_true(await architecture.init())
	assert_same(architecture.create_instance(PlanExternalFactoryCommand), external)
	architecture.dispose()
	assert_eq(external.dispose_count, 0, "对象 factory 的外部实例始终归调用方。")


func test_factory_from_instance_remains_caller_owned_after_later_plan_rollback() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var success_plan: GFBindingPlan = binder.create_required_plan()
	var external: PlanExternalFactoryCommand = PlanExternalFactoryCommand.new()
	var builder: GFBindBuilder = binder.bind_factory(
		PlanExternalFactoryCommand
	).from_instance(external)
	var _entry: GFBindingPlan = success_plan.require_singleton(
		&"ownership.factory_rollback",
		builder
	)
	var success_scope: GFAsyncScope = GFAsyncScope.new()
	var success_result: GFBindingPlanResult = success_plan.execute(success_scope)
	assert_true(success_result.is_successful())
	assert_true(architecture.has_factory(PlanExternalFactoryCommand))

	var rollback_plan: GFBindingPlan = binder.create_required_plan()
	var rollback_scope: GFAsyncScope = GFAsyncScope.new()
	var rollback_result: GFBindingPlanResult = rollback_plan.execute(rollback_scope)

	_assert_result(
		rollback_result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.INVALID_PLAN,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_false(architecture.has_factory(PlanExternalFactoryCommand))
	assert_eq(external.dispose_count, 0, "后续 Plan rollback 不得释放外部 factory 实例。")
	assert_true(success_scope.is_active())
	assert_true(rollback_scope.is_cancel_requested())
	assert_push_error(rollback_result.get_detail())
	architecture.dispose()
	assert_eq(external.dispose_count, 0)


func test_factory_from_instance_rejects_unrelated_external_candidate() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var unrelated: Object = IDENTITY_UNRELATED_FACTORY_COMMAND_SCRIPT.new()
	assert_ne(
		_script_path(PlanFactoryCommand),
		_script_path(IDENTITY_UNRELATED_FACTORY_COMMAND_SCRIPT)
	)
	var builder: GFBindBuilder = binder.bind_factory(
		PlanFactoryCommand
	).from_instance(unrelated)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.factory_instance_mismatch",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.FACTORY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"identity.factory_instance_mismatch",
		_script_path(PlanFactoryCommand),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_false(architecture.has_factory(PlanFactoryCommand))
	var dispose_count_value: Variant = unrelated.get("dispose_count")
	assert_true(dispose_count_value is int)
	if dispose_count_value is int:
		var dispose_count: int = dispose_count_value
		assert_eq(dispose_count, 0, "不匹配的 factory from_instance() 仍归调用方。")
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_factory_from_instance_rejects_node_freed_after_declaration() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var dispose_calls: Array[int] = [0]
	var external: PlanFreedFactoryNode = PlanFreedFactoryNode.new()
	external.dispose_callback = func() -> void:
		dispose_calls[0] += 1
	var builder: GFBindBuilder = binder.bind_factory(
		PlanFreedFactoryNode
	).from_instance(external)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.factory_freed_node",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	external.free()
	assert_false(is_instance_valid(external))

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.FACTORY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"identity.factory_freed_node",
		_script_path(PlanFreedFactoryNode),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(dispose_calls[0], 0, "Plan 不得调用已经释放的 Node。")
	assert_false(architecture.has_factory(PlanFreedFactoryNode))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_factory_from_instance_rejects_node_queued_after_declaration() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var dispose_calls: Array[int] = [0]
	var external: PlanFreedFactoryNode = PlanFreedFactoryNode.new()
	external.dispose_callback = func() -> void:
		dispose_calls[0] += 1
	var builder: GFBindBuilder = binder.bind_factory(
		PlanFreedFactoryNode
	).from_instance(external)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"identity.factory_queued_node",
		builder
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	external.queue_free()
	assert_true(is_instance_valid(external))
	assert_true(external.is_queued_for_deletion())

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.FACTORY,
		GFBindingPlanResult.Phase.INSTANCE_CREATION,
		GFBindingPlanResult.Reason.INSTANCE_CREATION_FAILED,
		0,
		&"identity.factory_queued_node",
		_script_path(PlanFreedFactoryNode),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(dispose_calls[0], 0, "queued from_instance Node 仍归调用方。")
	assert_true(is_instance_valid(external))
	assert_true(external.is_queued_for_deletion())
	assert_false(architecture.has_factory(PlanFreedFactoryNode))
	assert_true(scope.is_cancel_requested())
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	await get_tree().process_frame
	assert_false(is_instance_valid(external))
	architecture.dispose()


func test_hostile_scope_cleanup_cannot_replace_architecture_first_cause() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.register_utility_instance(PlanDuplicateUtility.new()))
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"first.cause",
		binder.bind_utility(PlanDuplicateUtility)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var nested_scope: GFAsyncScope = GFAsyncScope.new()
	var nested_results: Array[GFBindingPlanResult] = []
	var cleanup_count: Array[int] = [0]
	var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
		cleanup_count[0] += 1
		nested_results.append(plan.execute(nested_scope))
		architecture.fail_initialization("hostile cleanup must not win")
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	assert_eq(result.get_reason(), GFBindingPlanResult.Reason.REGISTRATION_REJECTED)
	assert_eq(architecture.last_initialization_error, result.get_detail())
	assert_ne(architecture.last_initialization_error, "hostile cleanup must not win")
	assert_eq(cleanup_count[0], 1)
	assert_eq(nested_results.size(), 1)
	_assert_result(
		nested_results[0],
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.ALREADY_EXECUTED,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_true(nested_scope.is_active(), "SETTLING nested execute 不得 claim 第二个 scope。")
	assert_push_warning(
		"[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。"
	)
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_builder_snapshot_is_immutable_after_declaration() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var primary: PlanSnapshotUtility = PlanSnapshotUtility.new()
	var late_mutation: PlanSnapshotUtility = PlanSnapshotUtility.new()
	var calls: Array[int] = [0, 0]
	var builder: GFBindBuilder = binder.bind_utility(PlanSnapshotUtility).from_factory(
		func() -> Object:
			calls[0] += 1
			return primary
	)
	var _entry: GFBindingPlan = plan.require_singleton(&"snapshot", builder)
	var _mutated_builder: GFBindBuilder = builder.from_factory(func() -> Object:
		calls[1] += 1
		return late_mutation
	).with_alias(PlanUnrelatedModel)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	assert_true(result.is_successful())
	assert_eq(calls, [1, 0], "Plan 必须执行 declaration 时冻结的 source。")
	assert_same(architecture.get_local_utility(PlanSnapshotUtility), primary)
	assert_false(architecture.has_initialization_failed())
	assert_true(scope.is_active())
	architecture.dispose()


func test_cross_binder_builder_fails_closed_with_offending_declaration() -> void:
	var owner_architecture: GFArchitecture = GFArchitecture.new()
	var foreign_architecture: GFArchitecture = GFArchitecture.new()
	var owner_binder: GFBinder = owner_architecture.create_binder()
	var foreign_binder: GFBinder = foreign_architecture.create_binder()
	var plan: GFBindingPlan = owner_binder.create_required_plan()
	var _entry: GFBindingPlan = plan.require_singleton(
		&"foreign.builder",
		foreign_binder.bind_utility(PlanForeignUtility)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.BUILDER_OWNERSHIP_MISMATCH,
		0,
		&"foreign.builder",
		_script_path(PlanForeignUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		0,
		false
	)
	assert_true(owner_architecture.has_initialization_failed())
	assert_false(foreign_architecture.has_initialization_failed())
	assert_null(foreign_architecture.get_local_utility(PlanForeignUtility))
	assert_push_error(result.get_detail())
	owner_architecture.dispose()
	foreign_architecture.dispose()


func test_ready_architecture_rejects_plan_without_claiming_scope_or_running_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init())
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var _entry: GFBindingPlan = plan.require_singleton(
		&"ready.rejected",
		binder.bind_utility(PlanReadyRejectedUtility).from_factory(func() -> Object:
			factory_calls[0] += 1
			return PlanReadyRejectedUtility.new()
	)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.ARCHITECTURE_UNAVAILABLE,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(factory_calls[0], 0)
	assert_true(scope.is_active(), "READY rejection 不得 claim、complete 或 cancel 调用方 scope。")
	assert_true(architecture.is_inited())
	assert_false(architecture.has_initialization_failed())
	assert_null(architecture.get_local_utility(PlanReadyRejectedUtility))
	architecture.dispose()


func test_replay_fails_closed_without_new_scope_or_architecture_side_effect() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var _entry: GFBindingPlan = plan.require_singleton(
		&"replay.once",
		binder.bind_utility(PlanReplayUtility).from_factory(func() -> Object:
			factory_calls[0] += 1
			return PlanReplayUtility.new()
	)
	)
	var first_scope: GFAsyncScope = GFAsyncScope.new()
	var first_result: GFBindingPlanResult = plan.execute(first_scope)
	var second_scope: GFAsyncScope = GFAsyncScope.new()

	var replay_result: GFBindingPlanResult = plan.execute(second_scope)

	assert_true(first_result.is_successful())
	_assert_result(
		replay_result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.ALREADY_EXECUTED,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(factory_calls[0], 1)
	assert_true(first_scope.is_active())
	assert_true(second_scope.is_active(), "Replay 拒绝不得取消一个新的无关 scope。")
	assert_false(architecture.has_initialization_failed())
	assert_not_null(architecture.get_local_utility(PlanReplayUtility))
	architecture.dispose()


func test_nested_execute_from_factory_is_rejected_without_touching_primary() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var primary_scope: GFAsyncScope = GFAsyncScope.new()
	var nested_scope: GFAsyncScope = GFAsyncScope.new()
	var nested_results: Array[GFBindingPlanResult] = []
	var factory_calls: Array[int] = [0]
	var builder: GFBindBuilder = binder.bind_utility(
		PlanNestedExecutionUtility
	).from_factory(func() -> Object:
		factory_calls[0] += 1
		nested_results.append(plan.execute(nested_scope))
		return PlanNestedExecutionUtility.new()
	)
	var _entry: GFBindingPlan = plan.require_singleton(
		&"single_execute.nested",
		builder
	)

	var primary_result: GFBindingPlanResult = plan.execute(primary_scope)

	_assert_result(
		primary_result,
		GFBindingPlanResult.Status.SUCCESS,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.NONE,
		GFBindingPlanResult.Reason.NONE,
		-1,
		&"",
		"",
		-1,
		1,
		true
	)
	assert_eq(nested_results.size(), 1)
	_assert_result(
		nested_results[0],
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.ALREADY_EXECUTED,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(factory_calls[0], 1)
	assert_true(primary_scope.is_active())
	assert_true(nested_scope.is_active(), "EXECUTING nested execute 不得 claim 第二个 scope。")
	assert_false(architecture.has_initialization_failed())
	assert_not_null(architecture.get_local_utility(PlanNestedExecutionUtility))
	architecture.dispose()


func test_pre_cancelled_scope_stops_before_first_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var factory_calls: Array[int] = [0]
	var _entry: GFBindingPlan = plan.require_singleton(
		&"cancel.pre",
		binder.bind_utility(PlanCancelledUtility).from_factory(func() -> Object:
			factory_calls[0] += 1
			return PlanCancelledUtility.new()
	)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	assert_true(scope.cancel("caller_pre_cancel"))

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.CANCELLED,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.CANCELLATION,
		GFBindingPlanResult.Reason.SCOPE_CANCELLED,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(factory_calls[0], 0)
	assert_eq(String(scope.get_cancel_reason()), "caller_pre_cancel")
	assert_true(result.get_detail().contains("caller_pre_cancel"))
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_scope_cancelled_by_awaited_entry_stops_next_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var next_calls: Array[int] = [0]
	var scope: GFAsyncScope = GFAsyncScope.new()
	var cleanup_count: Array[int] = [0]
	var _registered_cleanup: bool = scope.register_cleanup(func() -> void:
		cleanup_count[0] += 1
	)
	var _awaiting_entry: GFBindingPlan = plan.require_singleton(
		&"cancel.awaiting",
		binder.bind_utility(PlanAwaitCancellationUtility).from_factory(
			func() -> Object:
				var _cancelled_scope: bool = scope.cancel(
					"caller_cancelled_while_awaiting"
				)
				return PlanAwaitCancellationUtility.new()
	)
	)
	var _next_entry: GFBindingPlan = plan.require_singleton(
		&"cancel.must_not_run",
		binder.bind_utility(PlanThirdUtility).from_factory(func() -> Object:
			next_calls[0] += 1
			return PlanThirdUtility.new()
	)
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.CANCELLED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.CANCELLATION,
		GFBindingPlanResult.Reason.SCOPE_CANCELLED,
		0,
		&"cancel.awaiting",
		_script_path(PlanAwaitCancellationUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(next_calls[0], 0)
	assert_eq(cleanup_count[0], 1)
	assert_eq(String(scope.get_cancel_reason()), "caller_cancelled_while_awaiting")
	assert_true(result.get_detail().contains("caller_cancelled_while_awaiting"))
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_scope_cancellation_precedes_same_attempt_creation_failure() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var scope: GFAsyncScope = GFAsyncScope.new()
	var next_calls: Array[int] = [0]
	var failing_builder: GFBindBuilder = binder.bind_utility(
		PlanCreationUtility
	).from_factory(func() -> Object:
		var _cancelled_scope: bool = scope.cancel("caller_cancelled_before_null")
		return null
	)
	var _failing_entry: GFBindingPlan = plan.require_singleton(
		&"cancel.precedes_creation_failure",
		failing_builder
	)
	var next_builder: GFBindBuilder = binder.bind_utility(PlanThirdUtility).from_factory(
		func() -> Object:
			next_calls[0] += 1
			return PlanThirdUtility.new()
	)
	var _next_entry: GFBindingPlan = plan.require_singleton(
		&"cancel.precedence_must_not_run",
		next_builder
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.CANCELLED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.CANCELLATION,
		GFBindingPlanResult.Reason.SCOPE_CANCELLED,
		0,
		&"cancel.precedes_creation_failure",
		_script_path(PlanCreationUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(String(scope.get_cancel_reason()), "caller_cancelled_before_null")
	assert_true(result.get_detail().contains("caller_cancelled_before_null"))
	assert_eq(next_calls[0], 0)
	assert_true(architecture.has_initialization_failed())
	assert_push_error("[GFBindBuilder] from_factory() 必须返回 Object 实例。")
	assert_push_error(result.get_detail())
	architecture.dispose()


func test_scope_completed_by_entry_is_unavailable_before_next_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var plan: GFBindingPlan = binder.create_required_plan()
	var scope: GFAsyncScope = GFAsyncScope.new()
	var first_calls: Array[int] = [0]
	var next_calls: Array[int] = [0]
	var first_candidate: PlanExternalInstanceUtility = PlanExternalInstanceUtility.new()
	var first_builder: GFBindBuilder = binder.bind_utility(
		PlanExternalInstanceUtility
	).from_factory(func() -> Object:
		first_calls[0] += 1
		scope.complete()
		return first_candidate
	)
	var next_builder: GFBindBuilder = binder.bind_utility(PlanThirdUtility).from_factory(
		func() -> Object:
			next_calls[0] += 1
			return PlanThirdUtility.new()
	)
	var _first_entry: GFBindingPlan = plan.require_singleton(
		&"scope.completed_by_entry",
		first_builder
	)
	var _next_entry: GFBindingPlan = plan.require_singleton(
		&"scope.completed_must_not_run",
		next_builder
	)

	var result: GFBindingPlanResult = plan.execute(scope)

	_assert_result(
		result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.SCOPE_UNAVAILABLE,
		0,
		&"scope.completed_by_entry",
		_script_path(PlanExternalInstanceUtility),
		GFBindingLifetimes.Lifetime.SINGLETON,
		1,
		false
	)
	assert_eq(first_calls[0], 1)
	assert_eq(next_calls[0], 0)
	assert_true(scope.is_completed())
	assert_eq(first_candidate.dispose_count, 1, "completed scope 仍必须触发 Architecture rollback。")
	assert_null(architecture.get_local_utility(PlanExternalInstanceUtility))
	assert_null(architecture.get_local_utility(PlanThirdUtility))
	assert_true(architecture.has_initialization_failed())
	assert_push_error(result.get_detail())
	architecture.dispose()
	assert_eq(first_candidate.dispose_count, 1)


func test_completed_and_null_scopes_are_invalid_without_entry_execution() -> void:
	var completed_architecture: GFArchitecture = GFArchitecture.new()
	var completed_binder: GFBinder = completed_architecture.create_binder()
	var completed_plan: GFBindingPlan = completed_binder.create_required_plan()
	var completed_calls: Array[int] = [0]
	var _completed_entry: GFBindingPlan = completed_plan.require_singleton(
		&"scope.completed",
		completed_binder.bind_utility(PlanCompletedScopeUtility).from_factory(
			func() -> Object:
				completed_calls[0] += 1
				return PlanCompletedScopeUtility.new()
	)
	)
	var completed_scope: GFAsyncScope = GFAsyncScope.new()
	completed_scope.complete()

	var completed_result: GFBindingPlanResult = completed_plan.execute(completed_scope)

	_assert_result(
		completed_result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.SCOPE_UNAVAILABLE,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(completed_calls[0], 0)
	assert_true(completed_scope.is_completed())
	assert_push_error(completed_result.get_detail())
	completed_architecture.dispose()

	var null_architecture: GFArchitecture = GFArchitecture.new()
	var null_binder: GFBinder = null_architecture.create_binder()
	var null_plan: GFBindingPlan = null_binder.create_required_plan()
	var null_calls: Array[int] = [0]
	var _null_entry: GFBindingPlan = null_plan.require_singleton(
		&"scope.null",
		null_binder.bind_utility(PlanNullScopeUtility).from_factory(func() -> Object:
			null_calls[0] += 1
			return PlanNullScopeUtility.new()
	)
	)

	var null_result: GFBindingPlanResult = null_plan.execute(null)

	_assert_result(
		null_result,
		GFBindingPlanResult.Status.INVALID_REQUEST,
		GFBindingPlanResult.BindingKind.NONE,
		GFBindingPlanResult.Phase.VALIDATION,
		GFBindingPlanResult.Reason.SCOPE_UNAVAILABLE,
		-1,
		&"",
		"",
		-1,
		0,
		false
	)
	assert_eq(null_calls[0], 0)
	assert_push_error(null_result.get_detail())
	null_architecture.dispose()


func test_legacy_fluent_builder_api_remains_source_compatible() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = architecture.create_binder()
	var utility: PlanLegacyUtility = PlanLegacyUtility.new()

	var registered_utility: bool = await binder.bind_utility(
		PlanLegacyUtility
	).from_instance(utility).as_singleton()
	var registered_factory: bool = binder.bind_factory(
		PlanFactoryCommand
	).from_factory(func() -> Object:
		return PlanFactoryCommand.new()
	).as_transient()

	assert_true(registered_utility)
	assert_true(registered_factory)
	assert_same(architecture.get_local_utility(PlanLegacyUtility), utility)
	assert_true(architecture.has_factory(PlanFactoryCommand))
	architecture.dispose()


func test_real_installer_failure_rolls_back_candidate_and_skips_next_installer() -> void:
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	var committed_architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await Gf.set_architecture(committed_architecture))
	ProjectSettings.set_setting(INSTALLERS_SETTING, [INSTALLER_PATH, NEXT_INSTALLER_PATH])
	var candidate: GFArchitecture = GFArchitecture.new()

	var assigned: bool = await Gf.set_architecture(candidate)
	var report: Dictionary = _project_setting_dictionary(RESULT_SETTING)

	assert_false(assigned, "required plan 失败的 candidate 不得发布。")
	assert_same(Gf.get_architecture(), committed_architecture)
	assert_true(candidate.is_disposed(), "未发布 candidate 必须释放。")
	assert_null(Gf._pending_architecture_assignment)
	assert_null(Gf._pending_architecture_assignment_scope)
	assert_eq(_project_setting_int(CLEANUP_COUNT_SETTING), 1, "Installer scope cleanup 必须恰好一次。")
	assert_eq(
		_project_setting_int(DISPOSE_COUNT_SETTING),
		2,
		"accepted rollback 与 rejected owned candidate 必须各释放一次。"
	)
	assert_false(
		_project_setting_bool(NEXT_INSTALLER_RAN_SETTING),
		"首个 required plan 失败后不得运行后继 Installer。"
	)
	_assert_result_dictionary(
		report,
		GFBindingPlanResult.Status.FAILED,
		GFBindingPlanResult.BindingKind.UTILITY,
		GFBindingPlanResult.Phase.REGISTRATION,
		GFBindingPlanResult.Reason.REGISTRATION_REJECTED,
		1,
		"installer.required.duplicate",
		REQUIRED_BINDING_PLAN_UTILITY_FIXTURE_SCRIPT.resource_path,
		GFBindingLifetimes.Lifetime.SINGLETON,
		2,
		false
	)
	assert_push_warning(
		"[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。"
	)
	assert_push_error(_dictionary_string(report, "detail"))


# --- 私有/辅助方法 ---

func _assert_result(
	result: GFBindingPlanResult,
	expected_status: int,
	expected_kind: int,
	expected_phase: int,
	expected_reason: int,
	expected_index: int,
	expected_id: StringName,
	expected_path: String,
	expected_lifetime: int,
	expected_executed_count: int,
	expect_empty_detail: bool
) -> void:
	assert_not_null(result)
	assert_eq(result.get_status(), expected_status)
	assert_eq(result.is_successful(), expected_status == GFBindingPlanResult.Status.SUCCESS)
	assert_eq(result.get_binding_kind(), expected_kind)
	assert_eq(result.get_failed_phase(), expected_phase)
	assert_eq(result.get_reason(), expected_reason)
	assert_eq(result.get_entry_index(), expected_index)
	assert_eq(result.get_binding_id(), expected_id)
	assert_eq(result.get_target_path(), expected_path)
	assert_eq(result.get_lifetime(), expected_lifetime)
	assert_eq(result.get_executed_count(), expected_executed_count)
	_assert_detail(result.get_detail(), expect_empty_detail)
	_assert_result_dictionary(
		result.to_dict(),
		expected_status,
		expected_kind,
		expected_phase,
		expected_reason,
		expected_index,
		String(expected_id),
		expected_path,
		expected_lifetime,
		expected_executed_count,
		expect_empty_detail
	)


func _assert_result_dictionary(
	report: Dictionary,
	expected_status: int,
	expected_kind: int,
	expected_phase: int,
	expected_reason: int,
	expected_index: int,
	expected_id: String,
	expected_path: String,
	expected_lifetime: int,
	expected_executed_count: int,
	expect_empty_detail: bool
) -> void:
	assert_eq(report.size(), RESULT_KEYS.size(), "Result Dictionary 不得增加未声明字段。")
	for key: String in RESULT_KEYS:
		assert_true(report.has(key), "Result Dictionary 缺少字段：%s" % key)
	assert_eq(_dictionary_int(report, "status"), expected_status)
	assert_eq(_dictionary_bool(report, "is_successful"), expected_status == GFBindingPlanResult.Status.SUCCESS)
	assert_eq(_dictionary_int(report, "binding_kind"), expected_kind)
	assert_eq(_dictionary_int(report, "failed_phase"), expected_phase)
	assert_eq(_dictionary_int(report, "reason"), expected_reason)
	assert_eq(_dictionary_int(report, "entry_index"), expected_index)
	assert_eq(_dictionary_string(report, "binding_id"), expected_id)
	assert_eq(_dictionary_string(report, "target_path"), expected_path)
	assert_eq(_dictionary_int(report, "lifetime"), expected_lifetime)
	assert_eq(_dictionary_int(report, "executed_count"), expected_executed_count)
	_assert_detail(_dictionary_string(report, "detail"), expect_empty_detail)


func _assert_detail(detail: String, expect_empty: bool) -> void:
	assert_true(detail.length() <= 512)
	assert_eq(detail.is_empty(), expect_empty)
	assert_false(detail.contains("D:\\"), "Result detail 不得泄漏 Windows 宿主绝对路径。")
	assert_false(detail.contains("/home/"), "Result detail 不得泄漏 POSIX 宿主绝对路径。")
	assert_false(detail.contains("<GDScript#"), "Result detail 不得泄漏对象调试身份。")


func _script_path(script_cls: Script) -> String:
	return script_cls.resource_path


func _dictionary_bool(options: Dictionary, key: String) -> bool:
	var value: Variant = options.get(key, false)
	if value is bool:
		return value
	return false


func _dictionary_int(options: Dictionary, key: String) -> int:
	var value: Variant = options.get(key, 0)
	if value is int:
		return value
	return 0


func _dictionary_string(options: Dictionary, key: String) -> String:
	var value: Variant = options.get(key, "")
	if value is String:
		return value
	if value is StringName:
		var text_name: StringName = value
		return String(text_name)
	return ""


func _object_bool_property(instance: Object, property_name: StringName) -> bool:
	var value: Variant = instance.get(property_name)
	assert_true(value is bool, "对象属性必须是 bool：%s" % property_name)
	if value is bool:
		return value
	return false


func _object_int_property(instance: Object, property_name: StringName) -> int:
	var value: Variant = instance.get(property_name)
	assert_true(value is int, "对象属性必须是 int：%s" % property_name)
	if value is int:
		return value
	return 0


func _object_script(instance: Object) -> Script:
	var value: Variant = instance.get_script()
	assert_true(value is Script, "对象必须保留可识别的 Script。")
	if value is Script:
		return value
	return null


func _project_setting_dictionary(setting_name: String) -> Dictionary:
	var value: Variant = ProjectSettings.get_setting(setting_name, {})
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _project_setting_bool(setting_name: String) -> bool:
	var value: Variant = ProjectSettings.get_setting(setting_name, false)
	if value is bool:
		return value
	return false


func _project_setting_int(setting_name: String) -> int:
	var value: Variant = ProjectSettings.get_setting(setting_name, 0)
	if value is int:
		return value
	return 0


func _dispose_current_architecture() -> void:
	var architecture: GFArchitecture = Gf._architecture
	if architecture != null:
		architecture.dispose()
	Gf._architecture = null


# --- 内部类 ---

class PlanFirstUtility extends GFUtility:
	pass


class PlanSecondUtility extends GFUtility:
	pass


class PlanThirdUtility extends GFUtility:
	pass


class PlanDuplicateUtility extends GFUtility:
	pass


class PlanCreationUtility extends GFUtility:
	pass


class PlanInvalidIdUtility extends GFUtility:
	pass


class PlanExternalInstanceUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class PlanDisposeDuringInjectionUtility extends GFUtility:
	var dependencies_released: bool = false
	var dispose_count: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		architecture.dispose()

	func release_dependencies() -> void:
		dependencies_released = true
		super.release_dependencies()

	func dispose() -> void:
		dispose_count += 1


class PlanScriptMutatingInjectionUtility extends GFUtility:
	var replacement_script: Script = null
	var injection_callback: Callable = Callable()

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		if injection_callback.is_valid():
			var _injection_callback_result: Variant = injection_callback.call()
		set_script(replacement_script)


class PlanReentrantInjectionUtility extends GFUtility:
	var dispose_count: int = 0
	var injection_callback: Callable = Callable()
	var mutate_after_outer_injection: bool = false
	var replacement_script: Script = null
	var _injection_depth: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		_injection_depth += 1
		if injection_callback.is_valid():
			var _injection_callback_result: Variant = injection_callback.call()
		_injection_depth -= 1
		if (
			_injection_depth == 0
			and mutate_after_outer_injection
			and replacement_script != null
		):
			set_script(replacement_script)

	func dispose() -> void:
		dispose_count += 1


class PlanIdentityBaseUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class PlanSelfFreeingLifecycleNode extends Node:
	static var initialization_count: int = 0
	static var dispose_count: int = 0
	static var last_instance: WeakRef = null

	func _init() -> void:
		initialization_count += 1
		last_instance = weakref(self)
		free()

	func dispose() -> void:
		dispose_count += 1


class PlanIdentitySubclassUtility extends PlanIdentityBaseUtility:
	pass


class PlanWrongKindOwnedNode extends Node:
	var dispose_callback: Callable = Callable()

	func dispose() -> void:
		if dispose_callback.is_valid():
			var _dispose_callback_result: Variant = dispose_callback.call()


class PlanFreedLifecycleNode extends Node:
	var dispose_callback: Callable = Callable()

	func dispose() -> void:
		if dispose_callback.is_valid():
			var _dispose_callback_result: Variant = dispose_callback.call()


class PlanFreedCandidateHolder extends RefCounted:
	static var candidate: Variant = null


class PlanAliasUtility extends GFUtility:
	pass


class PlanUnrelatedModel extends GFModel:
	pass


class PlanSnapshotAliasBase extends GFUtility:
	pass


class PlanSnapshotUtility extends PlanSnapshotAliasBase:
	pass


class PlanSnapshotSecondUtility extends PlanSnapshotAliasBase:
	pass


class PlanForeignUtility extends GFUtility:
	pass


class PlanReadyRejectedUtility extends GFUtility:
	pass


class PlanReplayUtility extends GFUtility:
	pass


class PlanNestedExecutionUtility extends GFUtility:
	pass


class PlanCancelledUtility extends GFUtility:
	pass


class PlanCompletedScopeUtility extends GFUtility:
	pass


class PlanNullScopeUtility extends GFUtility:
	pass


class PlanLegacyUtility extends GFUtility:
	pass


class PlanFactoryCommand extends GFCommand:
	pass


class PlanFreedFactoryNode extends Node:
	var dispose_callback: Callable = Callable()

	func dispose() -> void:
		if dispose_callback.is_valid():
			var _dispose_callback_result: Variant = dispose_callback.call()


class PlanExternalFactoryCommand extends GFCommand:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class PlanAwaitCancellationUtility extends GFUtility:
	pass
