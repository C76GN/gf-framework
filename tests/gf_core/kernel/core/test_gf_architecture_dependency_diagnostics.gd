## 测试 GFArchitecture 的声明式依赖诊断报告。
extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


func test_dependency_diagnostics_reads_only_four_typed_hooks() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var factory_provider: CountingFactoryProvider = CountingFactoryProvider.new()
	await arch.register_model_instance(DiagnosticModel.new())
	await arch.register_utility_instance(DiagnosticUtility.new())
	await arch.register_system_instance(DiagnosticDependencySystem.new())
	var _registered_factory: bool = arch.register_factory(
		DiagnosticFactoryObject,
		Callable(factory_provider, "create")
	)
	await arch.register_system_instance(CompleteDiagnosticSystem.new())

	var report: Dictionary = arch.get_dependency_diagnostics()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "所有声明依赖已注册时诊断应通过。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "missing_dependencies").size(), 0, "不应报告缺失依赖。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies").size(), 4, "四类 typed hook 都应成为唯一声明来源。")
	assert_eq(factory_provider.call_count, 0, "Factory 依赖诊断只能校验 binding，不得实例化对象。")
	arch.dispose()


func test_dependency_diagnostics_reports_missing_dependencies() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_system_instance(MissingModelSystem.new())

	var report: Dictionary = arch.get_dependency_diagnostics()
	var issue_counts_by_kind: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "缺失依赖时诊断不应通过。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "missing_dependencies").size(), 1, "应报告一个缺失依赖。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue_counts_by_kind, "missing_model_dependency"), 1, "问题类别应标记缺失 Model。")
	arch.dispose()


func test_dependency_diagnostics_can_resolve_parent_dependencies() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await parent_arch.register_model_instance(DiagnosticModel.new())
	assert_true(await parent_arch.init())
	await child_arch.register_system_instance(MissingModelSystem.new())

	var report: Dictionary = child_arch.get_dependency_diagnostics()
	var resolved: Array = GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies")
	var first_dependency: Dictionary = GF_VARIANT_ACCESS.as_dictionary(resolved[0])

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "默认允许父级回退时，父级依赖应视为已解析。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_dependency, "scope"), "parent", "父级解析应标记 scope。")
	child_arch.dispose()
	parent_arch.dispose()


func test_dependency_diagnostics_rejects_dependency_from_parent_that_is_not_ready() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await parent_arch.register_model_instance(DiagnosticModel.new())
	await child_arch.register_system_instance(MissingModelSystem.new())

	var report: Dictionary = child_arch.get_dependency_diagnostics()

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "未 READY 父架构不能满足子架构依赖。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "missing_dependencies").size(), 1, "未 READY parent 依赖应保持缺失。")
	child_arch.dispose()
	parent_arch.dispose()


func test_dependency_diagnostics_treats_corrupt_registry_entries_as_hard_errors() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var invalid_item: InvalidHookItemDiagnosticObject = (
		InvalidHookItemDiagnosticObject.new()
	)
	var invalid_return: InvalidHookReturnDiagnosticObject = (
		InvalidHookReturnDiagnosticObject.new()
	)
	arch._system_registry.instances[InvalidHookItemDiagnosticObject] = (
		invalid_item
	)
	arch._system_registry.instances[InvalidHookReturnDiagnosticObject] = (
		invalid_return
	)

	var report: Dictionary = arch.get_dependency_diagnostics()
	var issue_counts_by_kind: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "损坏的注册表条目必须 hard fail。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "healthy"), "损坏的注册表条目应让报告不健康。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "error_count"), 2, "两个损坏条目都应计入 error。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(
			issue_counts_by_kind,
			"invalid_registration_instance"
		),
		2,
		"非 GFSystem 实例应在强类型注册表边界被拒绝。"
	)
	arch.dispose()


func test_stale_local_alias_blocks_ready_parent_fallback_without_output_side_effects() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	await parent_arch.register_utility_instance(DiagnosticUtility.new())
	assert_true(await parent_arch.init())
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await child_arch.register_system_instance(UtilityDependentSystem.new())
	child_arch._utility_registry.aliases[DiagnosticUtility] = (
		MissingDiagnosticUtility
	)

	var report: Dictionary = child_arch.get_dependency_diagnostics()
	var issue_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		report,
		"issue_counts_by_kind"
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "本地 stale alias 必须阻断 READY parent fallback。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue_counts, "stale_alias_dependency"), 1)
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies").size(), 0)
	child_arch.dispose()
	parent_arch.dispose()


func test_multiple_local_assignable_matches_block_ready_parent_fallback_without_output_side_effects() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	await parent_arch.register_utility_instance(DiagnosticUtility.new())
	assert_true(await parent_arch.init())
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await child_arch.register_utility_instance(DiagnosticUtilityAlias.new())
	await child_arch.register_utility_instance(SecondDiagnosticUtilityAlias.new())
	await child_arch.register_system_instance(UtilityDependentSystem.new())

	var report: Dictionary = child_arch.get_dependency_diagnostics()
	var issue_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		report,
		"issue_counts_by_kind"
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "多个本地 assignable 匹配必须阻断 parent fallback。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue_counts, "ambiguous_dependency"), 1)
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies").size(), 0)
	child_arch.dispose()
	parent_arch.dispose()


func test_factory_dependency_requires_exact_binding_without_instantiation() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var derived_provider: CountingDerivedFactoryProvider = (
		CountingDerivedFactoryProvider.new()
	)
	var exact_provider: CountingFactoryProvider = CountingFactoryProvider.new()
	assert_true(
		arch.register_factory(
			DerivedDiagnosticFactoryObject,
			Callable(derived_provider, "create")
		)
	)
	await arch.register_system_instance(FactoryDependentSystem.new())

	var missing_report: Dictionary = arch.get_dependency_diagnostics()
	assert_false(GF_VARIANT_ACCESS.get_option_bool(missing_report, "ok"), "可赋值 Factory binding 不得冒充 exact binding。")
	assert_eq(derived_provider.call_count, 0)

	assert_true(
		arch.register_factory(
			DiagnosticFactoryObject,
			Callable(exact_provider, "create")
		)
	)
	var resolved_report: Dictionary = arch.get_dependency_diagnostics()
	assert_true(GF_VARIANT_ACCESS.get_option_bool(resolved_report, "ok"), "exact Factory binding 应满足声明。")
	assert_eq(derived_provider.call_count, 0)
	assert_eq(exact_provider.call_count, 0, "Factory 诊断不得调用 exact provider。")
	arch.dispose()


func test_parent_factory_dependency_requires_ready_owner_without_instantiation() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var provider: CountingFactoryProvider = CountingFactoryProvider.new()
	assert_true(
		parent_arch.register_factory(
			DiagnosticFactoryObject,
			Callable(provider, "create")
		)
	)
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await child_arch.register_system_instance(FactoryDependentSystem.new())

	var unavailable_report: Dictionary = child_arch.get_dependency_diagnostics()
	assert_false(GF_VARIANT_ACCESS.get_option_bool(unavailable_report, "ok"), "未 READY parent 的 Factory binding 不可用。")
	assert_eq(provider.call_count, 0)

	assert_true(await parent_arch.init())
	var available_report: Dictionary = child_arch.get_dependency_diagnostics()
	var resolved: Array = GF_VARIANT_ACCESS.get_option_array(
		available_report,
		"resolved_dependencies"
	)
	var first_dependency: Dictionary = GF_VARIANT_ACCESS.as_dictionary(
		resolved[0]
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(available_report, "ok"), "READY parent 的 exact Factory binding 应满足声明。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_dependency, "scope"), "parent")
	assert_eq(provider.call_count, 0, "父级 Factory availability 校验不得实例化对象。")
	child_arch.dispose()
	parent_arch.dispose()


func test_binding_diagnostics_reports_registries_aliases_factories_and_parent_chain() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await parent_arch.register_model_instance(DiagnosticModel.new())
	await child_arch.register_utility_instance(DiagnosticUtilityAlias.new())
	child_arch.register_utility_alias(DiagnosticUtility, DiagnosticUtilityAlias)
	var _registered_factory: bool = child_arch.register_factory(
		DiagnosticFactoryObject,
		func() -> DiagnosticFactoryObject:
			return DiagnosticFactoryObject.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var report: Dictionary = child_arch.get_binding_diagnostics()
	var counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "registry_counts")
	var registries: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "registries")
	var utilities: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registries, "utilities")
	var utility_aliases: Array = GF_VARIANT_ACCESS.get_option_array(utilities, "aliases")
	var first_alias: Dictionary = GF_VARIANT_ACCESS.as_dictionary(utility_aliases[0])
	var factories: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "factories")
	var factory_entries: Array = GF_VARIANT_ACCESS.get_option_array(factories, "entries")
	var first_factory: Dictionary = GF_VARIANT_ACCESS.as_dictionary(factory_entries[0])
	var parent_chain: Array = GF_VARIANT_ACCESS.get_option_array(report, "parent_chain")
	var parent_entry: Dictionary = GF_VARIANT_ACCESS.as_dictionary(parent_chain[0])
	var parent_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(parent_entry, "registry_counts")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "有效绑定图诊断应通过。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(counts, "utilities"), 1, "诊断应统计本地 Utility。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(counts, "factories"), 1, "诊断应统计工厂绑定。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(counts, "aliases"), 1, "诊断应统计别名。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_alias, "target_registered"), "有效别名应报告目标已注册。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(first_factory, "lifetime_name"),
		"singleton",
		"工厂诊断应报告生命周期。"
	)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(parent_counts, "models"), 1, "父级链摘要应报告父架构 Model。")
	child_arch.dispose()
	parent_arch.dispose()


# --- 辅助类型 ---

class DiagnosticModel extends GFModel:
	pass


class DiagnosticUtility extends GFUtility:
	pass


class DiagnosticUtilityAlias extends DiagnosticUtility:
	pass


class SecondDiagnosticUtilityAlias extends DiagnosticUtility:
	pass


class MissingDiagnosticUtility extends DiagnosticUtility:
	pass


class DiagnosticFactoryObject extends RefCounted:
	pass


class DerivedDiagnosticFactoryObject extends DiagnosticFactoryObject:
	pass


class CountingFactoryProvider extends RefCounted:
	var call_count: int = 0

	func create() -> DiagnosticFactoryObject:
		call_count += 1
		return DiagnosticFactoryObject.new()


class CountingDerivedFactoryProvider extends RefCounted:
	var call_count: int = 0

	func create() -> DerivedDiagnosticFactoryObject:
		call_count += 1
		return DerivedDiagnosticFactoryObject.new()


class DiagnosticDependencySystem extends GFSystem:
	pass


class CompleteDiagnosticSystem extends GFSystem:
	func get_required_models() -> Array[Script]:
		var models: Array[Script] = [DiagnosticModel]
		return models

	func get_required_systems() -> Array[Script]:
		var systems: Array[Script] = [DiagnosticDependencySystem]
		return systems

	func get_required_utilities() -> Array[Script]:
		var utilities: Array[Script] = [DiagnosticUtility]
		return utilities

	func get_required_factories() -> Array[Script]:
		var factories: Array[Script] = [DiagnosticFactoryObject]
		return factories


class MissingModelSystem extends GFSystem:
	func get_required_models() -> Array[Script]:
		var models: Array[Script] = [DiagnosticModel]
		return models


class UtilityDependentSystem extends GFSystem:
	func get_required_utilities() -> Array[Script]:
		var utilities: Array[Script] = [DiagnosticUtility]
		return utilities


class FactoryDependentSystem extends GFSystem:
	func get_required_factories() -> Array[Script]:
		var factories: Array[Script] = [DiagnosticFactoryObject]
		return factories


class InvalidHookItemDiagnosticObject extends RefCounted:
	func get_required_models() -> Array:
		return ["not a script"]


class InvalidHookReturnDiagnosticObject extends RefCounted:
	func get_required_models() -> Variant:
		return {
			"models": [DiagnosticModel],
		}
