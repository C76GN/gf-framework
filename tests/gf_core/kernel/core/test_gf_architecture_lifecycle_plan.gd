## 测试 GFArchitectureLifecyclePlan 的确定性 DAG 与关闭快照。
extends GutTest


const GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_architecture_lifecycle_plan.gd"
)


func test_independent_modules_use_kind_priority_and_registration_ordinal() -> void:
	var first_model: PlanModel = PlanModel.new()
	var second_model: SecondPlanModel = SecondPlanModel.new()
	var utility: PlanUtility = PlanUtility.new()
	var system: PlanSystem = PlanSystem.new()
	first_model.lifecycle_priority = 2
	second_model.lifecycle_priority = 2
	utility.lifecycle_priority = 100
	system.lifecycle_priority = 200
	var models: Dictionary = {
		PlanModel: first_model,
		SecondPlanModel: second_model,
	}
	var utilities: Dictionary = {PlanUtility: utility}
	var systems: Dictionary = {PlanSystem: system}
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()

	assert_true(plan.compile(models, utilities, systems))
	assert_eq(
		plan.get_activation_order(),
		[first_model, second_model, utility, system],
		"无依赖节点应按 kind、priority、注册 ordinal 稳定排序。"
	)


func test_dependencies_override_ready_queue_tie_breakers() -> void:
	var model: ModelDependingOnSystem = ModelDependingOnSystem.new()
	var system: PlanSystem = PlanSystem.new()
	model.required_systems = [PlanSystem]
	model.lifecycle_priority = 100
	system.lifecycle_priority = -100
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()

	assert_true(
		plan.compile(
			{ModelDependingOnSystem: model},
			{},
			{PlanSystem: system}
		)
	)
	assert_eq(plan.get_activation_order(), [system, model], "依赖必须先于声明者激活。")


func test_unique_assignable_local_dependency_is_a_dag_edge() -> void:
	var model: DerivedPlanModel = DerivedPlanModel.new()
	var system: SystemDependingOnBaseModel = SystemDependingOnBaseModel.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()

	assert_true(
		plan.compile(
			{DerivedPlanModel: model},
			{},
			{SystemDependingOnBaseModel: system}
		)
	)
	assert_eq(plan.get_activation_order(), [model, system])
	assert_eq(plan.get_external_dependency_count(), 0)


func test_authoritative_resolver_can_satisfy_parent_dependency_as_external() -> void:
	var parent_model: PlanModel = PlanModel.new()
	var system: SystemDependingOnPlanModel = SystemDependingOnPlanModel.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	var resolvers: Dictionary = {
		&"models": func(required_script: Script) -> Dictionary:
			if required_script != PlanModel:
				return { "status": &"missing" }
			return {
				"status": &"external",
				"scope": &"parent",
				"architecture_depth": 1,
				"instance": parent_model,
			}
	}

	assert_true(plan.compile({}, {}, {SystemDependingOnPlanModel: system}, resolvers))
	assert_eq(plan.get_activation_order(), [system])
	assert_eq(plan.get_external_dependency_count(), 1)
	assert_true(plan.get_dependency_closure(system).has(system))
	assert_false(plan.get_dependency_closure(system).has(parent_model))


func test_missing_dependency_fails_closed_with_typed_diagnostic() -> void:
	var system: SystemDependingOnPlanModel = SystemDependingOnPlanModel.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()

	assert_false(plan.compile({}, {}, {SystemDependingOnPlanModel: system}))
	assert_false(plan.is_valid())
	assert_true(plan.get_activation_order().is_empty())
	assert_true(plan.get_shutdown_order().is_empty())
	assert_eq(_diagnostic_codes(plan), [&"missing_dependency"])


func test_defensive_capture_rejects_invalid_return_and_entry() -> void:
	var provider: InvalidDependencyProvider = InvalidDependencyProvider.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	var node: Dictionary = _make_capture_node(provider)
	var declarations: Dictionary = _make_dependency_declarations()

	var _invalid_return_capture: Variant = plan.call(
		&"_capture_dependency_hook",
		node,
		declarations,
		&"models",
		&"get_required_models"
	)
	var _invalid_entry_capture: Variant = plan.call(
		&"_capture_dependency_hook",
		node,
		declarations,
		&"systems",
		&"get_required_systems"
	)

	var codes: Array[StringName] = _diagnostic_codes(plan)
	assert_has(codes, &"invalid_dependency_hook_return")
	assert_has(codes, &"invalid_dependency_type")


func test_cycle_fails_closed_with_stable_cycle_members() -> void:
	var first: FirstCycleSystem = FirstCycleSystem.new()
	var second: SecondCycleSystem = SecondCycleSystem.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()

	assert_false(
		plan.compile(
			{},
			{},
			{
				FirstCycleSystem: first,
				SecondCycleSystem: second,
			}
		)
	)
	var diagnostics: Array[Dictionary] = plan.get_diagnostics()
	assert_eq(diagnostics.size(), 1)
	assert_eq(
		_get_dictionary_string_name(diagnostics[0], "code"),
		&"dependency_cycle"
	)
	assert_eq(
		_get_dictionary_int(diagnostics[0], "cycle_member_count"),
		2
	)
	var cycle_members_variant: Variant = diagnostics[0].get("cycle_members")
	assert_true(cycle_members_variant is Array)
	var cycle_members: Array = cycle_members_variant
	assert_eq(cycle_members.size(), 2)


func test_shutdown_order_is_exact_reverse_compile_snapshot_and_defensive() -> void:
	var model: PlanModel = PlanModel.new()
	var utility: UtilityDependingOnPlanModel = UtilityDependingOnPlanModel.new()
	var system: SystemDependingOnUtility = SystemDependingOnUtility.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()

	assert_true(
		plan.compile(
			{PlanModel: model},
			{UtilityDependingOnPlanModel: utility},
			{SystemDependingOnUtility: system}
		)
	)
	var activation: Array[Object] = plan.get_activation_order()
	var shutdown: Array[Object] = plan.get_shutdown_order()
	assert_eq(activation, [model, utility, system])
	assert_eq(shutdown, [system, utility, model])
	activation.clear()
	shutdown.clear()
	assert_eq(plan.get_activation_order(), [model, utility, system])
	assert_eq(plan.get_shutdown_order(), [system, utility, model])


func test_dependency_closure_is_transitive_local_new_and_can_exclude_self() -> void:
	var model: PlanModel = PlanModel.new()
	var utility: UtilityDependingOnPlanModel = UtilityDependingOnPlanModel.new()
	var system: SystemDependingOnUtility = SystemDependingOnUtility.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	assert_true(
		plan.compile(
			{PlanModel: model},
			{UtilityDependingOnPlanModel: utility},
			{SystemDependingOnUtility: system}
		)
	)

	var closure: Dictionary = plan.get_dependency_closure(system, false)
	assert_eq(closure.size(), 2)
	assert_true(closure.has(model))
	assert_true(closure.has(utility))
	assert_false(closure.has(system))
	closure.clear()
	assert_eq(plan.get_dependency_closure(system, false).size(), 2, "每次必须返回新 Dictionary。")
	assert_true(plan.get_dependency_closure(PlanSystem.new()).is_empty())


func test_compile_captures_each_typed_hook_once_and_returns_defensive_snapshot() -> void:
	var model: PlanModel = PlanModel.new()
	var utility: PlanUtility = PlanUtility.new()
	var provider_system: PlanSystem = PlanSystem.new()
	var dependent: CountingDependenciesSystem = CountingDependenciesSystem.new()
	var factory_resolver_calls: CallCounter = CallCounter.new()
	var resolvers: Dictionary = {
		&"factories": func(required_script: Script) -> Dictionary:
			factory_resolver_calls.value += 1
			return {
				"status": (
					&"local"
					if required_script == PlanFactoryProduct
					else &"missing"
				),
				"resolution_kind": &"exact",
			}
	}
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = (
		GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	)

	assert_true(
		plan.compile(
			{PlanModel: model},
			{PlanUtility: utility},
			{
				PlanSystem: provider_system,
				CountingDependenciesSystem: dependent,
			},
			resolvers
		)
	)
	assert_eq(
		dependent.get_hook_call_counts(),
		{
			"models": 1,
			"utilities": 1,
			"systems": 1,
			"factories": 1,
		},
		"一次 compile 对每个模块的四类声明都只能捕获一次。"
	)
	assert_eq(factory_resolver_calls.value, 1)
	assert_eq(
		plan.get_activation_order(),
		[model, utility, provider_system, dependent]
	)
	var closure: Dictionary = plan.get_dependency_closure(dependent)
	assert_eq(closure.size(), 4, "Factory availability 不能成为本地 DAG 节点。")

	var snapshot: Array[Dictionary] = plan.get_dependency_snapshot()
	var dependent_snapshot: Dictionary = _find_module_snapshot(
		snapshot,
		dependent
	)
	var declarations: Dictionary = dependent_snapshot.get(
		"dependencies",
		{}
	)
	var factory_dependencies: Array = declarations.get("factories", [])
	assert_eq(factory_dependencies, [PlanFactoryProduct])
	factory_dependencies.clear()
	snapshot.clear()

	var fresh_snapshot: Dictionary = _find_module_snapshot(
		plan.get_dependency_snapshot(),
		dependent
	)
	var fresh_declarations: Dictionary = fresh_snapshot.get(
		"dependencies",
		{}
	)
	var fresh_factory_dependencies: Array = fresh_declarations.get(
		"factories",
		[]
	)
	assert_eq(
		fresh_factory_dependencies,
		[PlanFactoryProduct],
		"调用方不得修改 plan 内部 dependency snapshot。"
	)

	var records: Array[Dictionary] = plan.get_dependency_records()
	assert_eq(_records_for_module(records, dependent).size(), 4)
	var factory_record: Dictionary = _find_dependency_record(
		records,
		dependent,
		&"factories"
	)
	assert_eq(
		_get_dictionary_string_name(factory_record, "status"),
		&"local"
	)
	assert_true(_get_dictionary_bool(factory_record, "resolved"))
	assert_null(_get_dictionary_object(factory_record, "resolved_instance"))
	records.clear()
	assert_eq(plan.get_dependency_records().size(), 4)


func test_factory_dependency_is_required_but_never_becomes_a_dag_edge() -> void:
	var dependent: FactoryDependentSystem = FactoryDependentSystem.new()
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = (
		GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	)

	assert_false(
		plan.compile(
			{},
			{},
			{FactoryDependentSystem: dependent}
		)
	)
	assert_eq(_diagnostic_codes(plan), [&"missing_dependency"])
	var missing_record: Dictionary = plan.get_dependency_records()[0]
	assert_eq(
		_get_dictionary_string_name(missing_record, "dependency_kind"),
		&"factories"
	)
	assert_eq(
		_get_dictionary_string_name(missing_record, "status"),
		&"missing"
	)

	var resolver_calls: CallCounter = CallCounter.new()
	var resolvers: Dictionary = {
		&"factories": func(required_script: Script) -> Dictionary:
			resolver_calls.value += 1
			return {
				"status": (
					&"external"
					if required_script == PlanFactoryProduct
					else &"missing"
				),
				"scope": &"parent",
				"architecture_depth": 1,
			}
	}
	assert_true(
		plan.compile(
			{},
			{},
			{FactoryDependentSystem: dependent},
			resolvers
		)
	)
	assert_eq(resolver_calls.value, 1)
	assert_eq(plan.get_activation_order(), [dependent])
	assert_eq(plan.get_dependency_closure(dependent).size(), 1)
	assert_eq(plan.get_external_dependency_count(), 1)


func test_structured_resolver_failure_statuses_are_preserved() -> void:
	var expected_codes: Dictionary = {
		&"stale_alias": &"stale_alias_dependency",
		&"ambiguous": &"ambiguous_dependency",
		&"parent_cycle": &"parent_dependency_cycle",
	}
	for status_variant: Variant in expected_codes.keys():
		var status: StringName = status_variant
		var dependent: SystemDependingOnPlanModel = (
			SystemDependingOnPlanModel.new()
		)
		var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = (
			GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
		)
		var resolvers: Dictionary = {
			&"models": func(_required_script: Script) -> Dictionary:
				return {
					"status": status,
					"scope": status,
					"parent_chain_cycle_detected": (
						status == &"parent_cycle"
					),
					"cycle_architecture": "fixture-parent",
					"cycle_depth": 2,
					"cycle_start_depth": 0,
				}
		}

		assert_false(
			plan.compile(
				{},
				{},
				{SystemDependingOnPlanModel: dependent},
				resolvers
			)
		)
		assert_eq(
			_diagnostic_codes(plan),
			[_get_dictionary_string_name(expected_codes, status)]
		)
		var record: Dictionary = plan.get_dependency_records()[0]
		assert_eq(
			_get_dictionary_string_name(record, "status"),
			status
		)
		assert_false(
			_get_dictionary_bool(record, "resolved", true)
		)


func test_invalid_structured_resolver_result_fails_closed() -> void:
	var dependent: SystemDependingOnPlanModel = (
		SystemDependingOnPlanModel.new()
	)
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = (
		GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	)
	var resolvers: Dictionary = {
		&"models": func(_required_script: Script) -> Variant:
			return "not a resolution"
	}

	assert_false(
		plan.compile(
			{},
			{},
			{SystemDependingOnPlanModel: dependent},
			resolvers
		)
	)
	assert_eq(
		_diagnostic_codes(plan),
		[&"invalid_dependency_resolution"]
	)
	assert_eq(
		_get_dictionary_string_name(
			plan.get_dependency_records()[0],
			"status"
		),
		&"invalid"
	)


func test_diagnostics_are_bounded_and_report_truncation() -> void:
	var provider: ManyInvalidDependenciesProvider = (
		ManyInvalidDependenciesProvider.new()
	)
	var plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	var _capture_result: Variant = plan.call(
		&"_capture_dependency_hook",
		_make_capture_node(provider),
		_make_dependency_declarations(),
		&"models",
		&"get_required_models"
	)

	assert_eq(
		plan.get_diagnostics().size(),
		64
	)
	assert_true(plan.were_diagnostics_truncated())


# --- 辅助方法 ---

func _diagnostic_codes(
	plan: GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT
) -> Array[StringName]:
	var result: Array[StringName] = []
	for diagnostic: Dictionary in plan.get_diagnostics():
		result.append(_get_dictionary_string_name(diagnostic, "code"))
	return result


func _get_dictionary_string_name(
	source: Dictionary,
	key: Variant,
	default_value: StringName = &""
) -> StringName:
	var value: Variant = source.get(key)
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	return default_value


func _get_dictionary_int(
	source: Dictionary,
	key: Variant,
	default_value: int = 0
) -> int:
	var value: Variant = source.get(key)
	if value is int:
		var int_value: int = value
		return int_value
	return default_value


func _get_dictionary_bool(
	source: Dictionary,
	key: Variant,
	default_value: bool = false
) -> bool:
	var value: Variant = source.get(key)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return default_value


func _get_dictionary_object(source: Dictionary, key: Variant) -> Object:
	var value: Variant = source.get(key)
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _make_capture_node(provider: Object) -> Dictionary:
	return {
		"instance": provider,
		"kind": &"System",
		"module_key": "hostile-provider",
	}


func _make_dependency_declarations() -> Dictionary:
	return {
		&"models": [],
		&"utilities": [],
		&"systems": [],
		&"factories": [],
	}


func _find_module_snapshot(
	snapshot: Array[Dictionary],
	module_instance: Object
) -> Dictionary:
	for entry: Dictionary in snapshot:
		if entry.get("module_instance") == module_instance:
			return entry
	return {}


func _records_for_module(
	records: Array[Dictionary],
	module_instance: Object
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		if record.get("module_instance") == module_instance:
			result.append(record)
	return result


func _find_dependency_record(
	records: Array[Dictionary],
	module_instance: Object,
	dependency_kind: StringName
) -> Dictionary:
	for record: Dictionary in records:
		if (
			record.get("module_instance") == module_instance
			and record.get("dependency_kind") == dependency_kind
		):
			return record
	return {}


# --- 辅助类型 ---

class PlanModel extends GFModel:
	pass


class SecondPlanModel extends GFModel:
	pass


class BasePlanModel extends GFModel:
	pass


class DerivedPlanModel extends BasePlanModel:
	pass


class PlanUtility extends GFUtility:
	pass


class PlanSystem extends GFSystem:
	pass


class PlanFactoryProduct extends RefCounted:
	pass


class CallCounter extends RefCounted:
	var value: int = 0


class CountingDependenciesSystem extends GFSystem:
	var model_hook_calls: int = 0
	var utility_hook_calls: int = 0
	var system_hook_calls: int = 0
	var factory_hook_calls: int = 0

	func get_required_models() -> Array[Script]:
		model_hook_calls += 1
		return [PlanModel]

	func get_required_utilities() -> Array[Script]:
		utility_hook_calls += 1
		return [PlanUtility]

	func get_required_systems() -> Array[Script]:
		system_hook_calls += 1
		return [PlanSystem]

	func get_required_factories() -> Array[Script]:
		factory_hook_calls += 1
		return [PlanFactoryProduct]

	func get_hook_call_counts() -> Dictionary:
		return {
			"models": model_hook_calls,
			"utilities": utility_hook_calls,
			"systems": system_hook_calls,
			"factories": factory_hook_calls,
		}


class FactoryDependentSystem extends GFSystem:
	func get_required_factories() -> Array[Script]:
		return [PlanFactoryProduct]


class ModelDependingOnSystem extends GFModel:
	var required_systems: Array[Script] = []

	func get_required_systems() -> Array[Script]:
		return required_systems


class SystemDependingOnBaseModel extends GFSystem:
	func get_required_models() -> Array[Script]:
		var dependencies: Array[Script] = [BasePlanModel]
		return dependencies


class SystemDependingOnPlanModel extends GFSystem:
	func get_required_models() -> Array[Script]:
		var dependencies: Array[Script] = [PlanModel]
		return dependencies


class UtilityDependingOnPlanModel extends GFUtility:
	func get_required_models() -> Array[Script]:
		var dependencies: Array[Script] = [PlanModel]
		return dependencies


class SystemDependingOnUtility extends GFSystem:
	func get_required_utilities() -> Array[Script]:
		var dependencies: Array[Script] = [UtilityDependingOnPlanModel]
		return dependencies


class InvalidDependencyProvider extends RefCounted:
	func get_required_models() -> Variant:
		return "invalid"

	func get_required_systems() -> Array:
		return [42]


class FirstCycleSystem extends GFSystem:
	func get_required_systems() -> Array[Script]:
		var dependencies: Array[Script] = [SecondCycleSystem]
		return dependencies


class SecondCycleSystem extends GFSystem:
	func get_required_systems() -> Array[Script]:
		var dependencies: Array[Script] = [FirstCycleSystem]
		return dependencies


class ManyInvalidDependenciesProvider extends RefCounted:
	func get_required_models() -> Array:
		var result: Array = []
		for index: int in range(69):
			result.append(index)
		return result
