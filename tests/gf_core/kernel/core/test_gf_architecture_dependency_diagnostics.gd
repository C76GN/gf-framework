## 测试 GFArchitecture 的声明式依赖诊断报告。
extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


func test_dependency_diagnostics_reports_registered_dependencies_as_ok() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_model_instance(DiagnosticModel.new())
	await arch.register_utility_instance(DiagnosticUtility.new())
	var _registered_factory: bool = arch.register_factory(DiagnosticFactoryObject, func() -> DiagnosticFactoryObject:
		return DiagnosticFactoryObject.new()
	)
	await arch.register_system_instance(CompleteDiagnosticSystem.new())

	var report: Dictionary = arch.get_dependency_diagnostics()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "所有声明依赖已注册时诊断应通过。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "missing_dependencies").size(), 0, "不应报告缺失依赖。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies").size(), 3, "应报告已解析的声明依赖。")
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
	await child_arch.register_system_instance(MissingModelSystem.new())

	var report: Dictionary = child_arch.get_dependency_diagnostics()
	var resolved: Array = GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies")
	var first_dependency: Dictionary = GF_VARIANT_ACCESS.as_dictionary(resolved[0])

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "默认允许父级回退时，父级依赖应视为已解析。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_dependency, "scope"), "parent", "父级解析应标记 scope。")
	child_arch.dispose()
	parent_arch.dispose()


func test_dependency_diagnostics_can_disable_parent_lookup() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	await parent_arch.register_model_instance(DiagnosticModel.new())
	await child_arch.register_system_instance(MissingModelSystem.new())

	var report: Dictionary = child_arch.get_dependency_diagnostics({ "include_parent_lookup": false })

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "关闭父级查找后，本地缺失依赖应报告错误。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "missing_dependencies").size(), 1, "应报告本地缺失依赖。")
	child_arch.dispose()
	parent_arch.dispose()


func test_dependency_diagnostics_warns_about_invalid_hook_values() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_system_instance(InvalidDiagnosticSystem.new())

	var report: Dictionary = arch.get_dependency_diagnostics()
	var issue_counts_by_kind: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "issue_counts_by_kind")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "无缺失依赖时，非法声明项只应产生警告。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "healthy"), "非法声明项应让报告不健康。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue_counts_by_kind, "invalid_dependency_type"), 1, "应报告非 Script 依赖声明。")
	arch.dispose()


func test_dependency_diagnostics_reads_dictionary_hook() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_model_instance(DiagnosticModel.new())
	await arch.register_utility_instance(DiagnosticUtility.new())
	await arch.register_system_instance(DictionaryDiagnosticSystem.new())

	var report: Dictionary = arch.get_dependency_diagnostics()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "字典式依赖声明应能被解析。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "resolved_dependencies").size(), 2, "字典式声明应汇总 Model 和 Utility。")
	arch.dispose()


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


class DiagnosticFactoryObject extends RefCounted:
	pass


class CompleteDiagnosticSystem extends GFSystem:
	func get_required_models() -> Array[Script]:
		var models: Array[Script] = [DiagnosticModel]
		return models

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


class DictionaryDiagnosticSystem extends GFSystem:
	func get_required_dependencies() -> Dictionary:
		return {
			"models": [DiagnosticModel],
			"utilities": [DiagnosticUtility],
		}


class InvalidDiagnosticSystem extends GFSystem:
	func get_required_models() -> Array:
		return ["not a script"]
