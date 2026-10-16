extends GutTest


func test_active_fixed_utility_rejects_replacement_before_candidate_initialization() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: FixedUtility = FixedUtility.new()
	var candidate: FixedUtility = FixedUtility.new()
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	assert_false(await architecture.replace_utility(FixedUtility, candidate))
	assert_push_error("[GFArchitecture][architecture.active_module_removal_refused]")
	assert_same(
		architecture.get_local_utility(FixedUtility),
		previous
	)
	assert_eq(previous.quiesce_count, 0)
	assert_eq(previous.dispose_count, 0)
	assert_eq(candidate.init_count, 0)
	assert_eq(
		candidate.dispose_count,
		0,
		"拒绝发生在候选所有权接管前。"
	)
	assert_true(architecture.is_inited())
	architecture.dispose()
	assert_eq(
		previous.dispose_count,
		1,
		"整体关闭不受单实例移除策略阻碍。"
	)


func test_unregister_cannot_bypass_stable_utility_policy() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: FixedUtility = FixedUtility.new()
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	assert_false(await architecture.unregister_utility(FixedUtility))
	assert_push_error("[GFArchitecture][architecture.active_module_removal_refused]")
	assert_same(
		architecture.get_local_utility(FixedUtility),
		previous
	)
	assert_eq(previous.quiesce_count, 0)
	architecture.dispose()


func test_same_instance_replacement_is_idempotent_and_cold_configuration_can_change() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: FixedUtility = FixedUtility.new()
	var candidate: FixedUtility = FixedUtility.new()
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.replace_utility(FixedUtility, candidate))
	assert_true(await architecture.init())
	assert_true(await architecture.replace_utility(FixedUtility, candidate))
	assert_eq(candidate.policy_count, 0)
	architecture.dispose()


func test_bound_utility_same_instance_replacement_is_idempotent_before_and_after_activation() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: UnboundOnlyUtility = UnboundOnlyUtility.new()
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(utility.is_bound_to_architecture_for_framework())
	assert_true(await architecture.replace_utility(UnboundOnlyUtility, utility))
	assert_same(
		architecture.get_local_utility(UnboundOnlyUtility),
		utility
	)
	assert_eq(utility.init_count, 0)
	assert_eq(utility.dispose_count, 0)

	assert_true(await architecture.init())
	assert_true(await architecture.replace_utility(UnboundOnlyUtility, utility))
	assert_same(
		architecture.get_local_utility(UnboundOnlyUtility),
		utility
	)
	assert_eq(utility.init_count, 1)
	assert_eq(utility.policy_count, 0)
	assert_eq(utility.quiesce_count, 0)
	assert_eq(utility.dispose_count, 0)
	assert_true(architecture.is_inited())
	architecture.dispose()
	assert_eq(utility.dispose_count, 1)


func test_bound_utility_registration_and_replacement_in_another_architecture_remain_rejected() -> void:
	var owner_architecture: GFArchitecture = GFArchitecture.new()
	var other_architecture: GFArchitecture = GFArchitecture.new()
	var utility: UnboundOnlyUtility = UnboundOnlyUtility.new()
	assert_true(await owner_architecture.register_utility_instance(utility))
	assert_true(await owner_architecture.init())
	assert_true(await other_architecture.init())

	assert_false(await other_architecture.register_utility_instance(utility))
	assert_push_error("[GFArchitecture][architecture.utility_registration_ownership_refused]")
	assert_false(await other_architecture.replace_utility(UnboundOnlyUtility, utility))
	assert_push_error("[GFArchitecture][architecture.utility_registration_ownership_refused]")
	assert_null(other_architecture.get_local_utility(UnboundOnlyUtility))
	assert_same(
		owner_architecture.get_local_utility(UnboundOnlyUtility),
		utility
	)
	assert_true(utility.is_bound_to_architecture_for_framework())
	assert_eq(utility.init_count, 1)
	assert_eq(utility.quiesce_count, 0)
	assert_eq(utility.dispose_count, 0)
	other_architecture.dispose()
	assert_eq(utility.dispose_count, 0)
	owner_architecture.dispose()
	assert_eq(utility.dispose_count, 1)


func test_policy_callback_shutdown_invalidates_outer_transaction_before_candidate_use() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: ReentrantUtility = ReentrantUtility.new()
	var candidate: ReentrantUtility = ReentrantUtility.new()
	previous.architecture_ref = weakref(architecture)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	assert_false(await architecture.replace_utility(ReentrantUtility, candidate))
	assert_eq(previous.dispose_count, 1)
	assert_eq(candidate.init_count, 0)
	assert_null(architecture.get_local_utility(ReentrantUtility))


func test_registration_policy_shutdown_cannot_publish_candidate_into_disposed_registry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var candidate: RegistrationPolicyUtility = RegistrationPolicyUtility.new()
	candidate.architecture_ref = weakref(architecture)
	candidate.dispose_from_policy = true
	assert_false(await architecture.register_utility_instance(candidate))
	assert_null(architecture.get_local_utility(RegistrationPolicyUtility))
	assert_eq(candidate.init_count, 0)
	assert_eq(
		candidate.dispose_count,
		0,
		"准入回调中止时架构尚未取得候选所有权。"
	)
	assert_false(candidate.is_bound_to_architecture_for_framework())


func test_registration_policy_cannot_publish_nested_alias() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: FixedUtility = FixedUtility.new()
	assert_true(await architecture.register_utility_instance(previous))
	var candidate: RegistrationPolicyUtility = RegistrationPolicyUtility.new()
	candidate.architecture_ref = weakref(architecture)
	assert_true(await architecture.register_utility_instance(candidate))
	assert_push_error("[GFArchitecture][architecture.registry_write_lifecycle_reentry]")
	assert_null(architecture.get_local_utility(NestedAliasUtility))
	assert_same(
		architecture.get_local_utility(RegistrationPolicyUtility),
		candidate
	)
	architecture.dispose()


class FixedUtility extends GFUtility:
	var init_count: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0
	var policy_count: int = 0

	func init() -> void:
		init_count += 1


	func can_remove_from_active_lifecycle() -> bool:
		policy_count += 1
		return false


	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion


	func dispose() -> void:
		dispose_count += 1


class ReentrantUtility extends FixedUtility:
	var architecture_ref: WeakRef = null

	func can_remove_from_active_lifecycle() -> bool:
		var value: Object = architecture_ref.get_ref()
		if value is GFArchitecture:
			var architecture: GFArchitecture = value
			architecture.dispose()
		return true


class UnboundOnlyUtility extends FixedUtility:
	func can_register_in_architecture() -> bool:
		return not is_bound_to_architecture_for_framework()


class NestedAliasUtility extends GFUtility:
	pass


class RegistrationPolicyUtility extends FixedUtility:
	var architecture_ref: WeakRef = null
	var dispose_from_policy: bool = false

	func can_register_in_architecture() -> bool:
		var value: Variant = architecture_ref.get_ref()
		if value is GFArchitecture:
			var architecture: GFArchitecture = value
			if dispose_from_policy:
				architecture.dispose()
			else:
				architecture.register_utility_alias(NestedAliasUtility, FixedUtility)
		return true
