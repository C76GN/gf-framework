## 保留政策跨 Profile、保存确认和事务回滚的集成回归。
extends GutTest


# --- 私有变量 ---

var _storage: GFSaveProfileTransactionTestSupport.ControlledStorage
var _utility: GFSaveProfileUtility
var _coordinator: GFSaveProfileTransactionCoordinator


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_storage = GFSaveProfileTransactionTestSupport.ControlledStorage.new()
	_utility = GFSaveProfileUtility.new().setup(_storage)
	_storage.driver = _utility
	_coordinator = GFSaveProfileTransactionCoordinator.new().setup(_utility)


func after_each() -> void:
	_coordinator.dispose()
	_utility.dispose()
	_storage.driver = null
	_storage.dispose()
	_coordinator = null
	_utility = null
	_storage = null


# --- 测试方法 ---

func test_projection_and_registered_policy_are_isolated() -> void:
	var provider: PayloadProvider = _provider(&"state")
	var profile: GFSaveProfile = _profile(
		&"retained",
		[provider]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_utility.register_profile(profile),
			"registered"
		)
	)
	provider.payload_policy.retained_fields.clear()
	provider.payload_policy.schema.dictionary_schema.fields.clear()
	assert_true(
		_load(
			profile,
			{
				"state": { "value": 2, "future": "keep" },
			}
		).get_result().is_successful()
	)
	assert_false(provider.last_applied.has("future"))
	provider.value = 3
	_save(profile)
	assert_true(
		_matches(
			_saved(),
			{ "value": 3, "future": "keep" }
		)
	)
	_storage.complete_next_save(OK)


func test_shared_provider_does_not_share_profile_retention() -> void:
	var provider: PayloadProvider = _provider(&"state")
	var first: GFSaveProfile = _profile(
		&"slot_a",
		[provider]
	)
	var second: GFSaveProfile = _profile(
		&"slot_b",
		[provider]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_utility.register_profile(first),
			"registered"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			_utility.register_profile(second),
			"registered"
		)
	)
	assert_true(
		_load(
			first,
			{
				"state": { "value": 1, "future": "A" },
			}
		).get_result().is_successful()
	)
	assert_true(
		_load(
			second,
			{
				"state": { "value": 2, "future": "B" },
			}
		).get_result().is_successful()
	)
	_save(first)
	assert_true(
		_matches(
			_saved().get("future"),
			"A"
		)
	)
	_storage.complete_next_save(OK)
	_save(second)
	assert_true(
		_matches(
			_saved().get("future"),
			"B"
		)
	)
	_storage.complete_next_save(OK)


func test_failed_load_restores_runtime_and_previous_retained_values() -> void:
	var first: PayloadProvider = _provider(&"state")
	var second: PayloadProvider = _provider(&"second")
	var profile: GFSaveProfile = _profile(
		&"rollback",
		[first, second]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_utility.register_profile(profile),
			"registered"
		)
	)
	assert_true(
		_load(
			profile,
			{
				"state": { "value": 1, "future": "old" },
				"second": { "value": 2, "future": "old second" },
			}
		).get_result().is_successful()
	)
	second.fail_apply = true
	var rejected: GFSaveProfileOperation = _load(
		profile,
		{
			"state": { "value": 10, "future": "new" },
			"second": { "value": 20, "future": "new second" },
		}
	)
	assert_false(rejected.get_result().is_successful())
	assert_eq(first.value, 1)
	assert_eq(second.value, 2)
	second.fail_apply = false
	_save(profile)
	assert_true(
		_matches(
			_saved(),
			{ "value": 1, "future": "old" }
		)
	)
	assert_true(
		_matches(
			_saved(&"second"),
			{ "value": 2, "future": "old second" }
		)
	)
	_storage.complete_next_save(OK)


func test_snapshot_deletion_commits_only_after_confirmed_write() -> void:
	var provider: PayloadProvider = _provider(&"state")
	var profile: GFSaveProfile = _profile(
		&"delete",
		[provider]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_utility.register_profile(profile),
			"registered"
		)
	)
	assert_true(
		_load(
			profile,
			{
				"state": { "value": 1, "future": "keep" },
			}
		).get_result().is_successful()
	)
	provider.deletions = {
		"": ["future"],
	}
	_save(profile)
	assert_false(_saved().has("future"))
	_storage.complete_next_save(ERR_INVALID_DATA)
	provider.deletions = {}
	_save(profile)
	assert_true(_saved().has("future"))
	_storage.complete_next_save(OK)
	provider.deletions = {
		"": ["future"],
	}
	_save(profile)
	_storage.complete_next_save(OK)
	provider.deletions = {}
	_save(profile)
	assert_false(_saved().has("future"))
	_storage.complete_next_save(OK)


func test_mutation_deletion_rolls_back_on_persist_failure_and_commits_on_success() -> void:
	var provider: PayloadProvider = _provider(&"state")
	var profile: GFSaveProfile = _profile(
		&"mutation_retention",
		[provider]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_coordinator.register_profile(profile),
			"registered"
		)
	)
	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_load(
		GFSaveProfileTransactionTestSupport.read_success(
			GFSaveProfileTransactionTestSupport.make_document(
				profile,
				{
					"state": { "value": 1, "future": "keep" },
				}
			)
		)
	)
	assert_true(activation.get_result().is_successful())
	var failed: GFSaveProfileTransactionOperation = _mutate(
		profile,
		2,
		{
			"": ["future"],
		}
	)
	assert_false(_saved().has("future"))
	_storage.complete_next_save(ERR_INVALID_DATA)
	assert_false(failed.get_result().is_successful())
	assert_eq(provider.value, 1)
	_save(profile)
	assert_true(
		_matches(
			_saved(),
			{ "value": 1, "future": "keep" }
		)
	)
	_storage.complete_next_save(OK)
	var retained: GFSaveProfileTransactionOperation = _mutate(profile, 3)
	assert_true(
		_matches(
			_saved(),
			{ "value": 3, "future": "keep" }
		)
	)
	_storage.complete_next_save(OK)
	assert_true(retained.get_result().is_successful())
	var deleted: GFSaveProfileTransactionOperation = _mutate(
		profile,
		4,
		{
			"": ["future"],
		}
	)
	_storage.complete_next_save(OK)
	assert_true(deleted.get_result().is_successful())
	var next: GFSaveProfileTransactionOperation = _mutate(profile, 5)
	assert_false(_saved().has("future"))
	_storage.complete_next_save(OK)
	assert_true(next.get_result().is_successful())


# --- 私有/辅助方法 ---

func _provider(section_id: StringName) -> PayloadProvider:
	var provider: PayloadProvider = PayloadProvider.new()
	provider.section_id = section_id
	var policy: GFSavePayloadPolicy = GFSavePayloadPolicy.new()
	policy.schema = GFSchemaField.new().configure(
		&"root",
		GFSchemaField.ValueType.DICTIONARY,
		{ "allow_null": false }
	)
	policy.schema.dictionary_schema = GFDictionarySchema.new()
	policy.schema.dictionary_schema.fields = [
		GFSchemaField.new().configure(
			&"value",
			GFSchemaField.ValueType.INT,
			{ "required": true, "allow_null": false }
		),
	]
	policy.retained_fields = {
		"": PackedStringArray(["future"]),
	}
	provider.payload_policy = policy
	return provider


func _profile(profile_id: StringName, providers: Array[GFSaveSectionProvider]) -> GFSaveProfile:
	return GFSaveProfileTransactionTestSupport.make_profile(profile_id, providers)


func _load(profile: GFSaveProfile, payloads: Dictionary) -> GFSaveProfileOperation:
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(GFSaveProfileTransactionTestSupport.make_document(profile, payloads)))
	assert_true(operation.is_completed())
	return operation


func _save(profile: GFSaveProfile) -> void:
	var _operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	assert_eq(
		_storage.get_pending_save_count(),
		1
	)


func _saved(section_id: StringName = &"state") -> Dictionary:
	var document: GFSaveDocument = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(
			_storage.save_calls[-1],
			"data"
		)
	)
	return GFVariantData.as_dictionary(document.get_section(section_id).get_payload())


func _mutate(
	profile: GFSaveProfile,
	value: int,
	deletions: Dictionary = {}
) -> GFSaveProfileTransactionOperation:
	var mutation: GFSaveSectionMutation = GFSaveSectionMutation.take_ownership(
		&"state",
		1,
		{ "value": value },
		{},
		deletions
	)
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create([mutation])
	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(profile.profile_id, request)
	_utility.tick(0.0)
	_coordinator.tick(0.0)
	_utility.tick(0.0)
	assert_eq(
		_storage.get_pending_save_count(),
		1
	)
	return operation


func _matches(left: Variant, right: Variant) -> bool:
	return left == right


# --- 内部类 ---

class PayloadProvider extends GFSaveProfileTransactionTestSupport.MemorySectionProvider:
	var last_applied: Dictionary = {}
	var deletions: Dictionary = {}


	func _begin_save_snapshot(_context: Dictionary = {}) -> GFSaveSectionSnapshotOperation:
		return make_completed_snapshot(
			{ "value": value },
			{},
			deletions.duplicate(true)
		)


	func _apply_section(section: GFSaveSection, context: Dictionary = {}) -> Error:
		last_applied = GFVariantData.as_dictionary(section.get_payload())
		return super._apply_section(section, context)
