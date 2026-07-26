## 验证 GFArchitecture 快照捕获与恢复的事务边界。
extends GutTest


# --- 常量 ---

const GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 测试用例 ---

func test_global_capture_result_distinguishes_empty_success_from_failure() -> void:
	var empty_architecture: GFArchitecture = GFArchitecture.new()
	var empty_result: Dictionary = empty_architecture.get_global_snapshot()

	assert_true(
		GFVariantData.get_option_bool(empty_result, "ok"),
		"合法空快照必须通过显式 Result 报告成功。"
	)
	assert_true(empty_result.has("snapshot"), "成功 Result 必须包含可提交 snapshot。")
	var empty_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		empty_result,
		"snapshot"
	)
	assert_eq(
		GFVariantData.get_option_dictionary(empty_snapshot, "models"),
		{},
		"合法空快照应保留空 models 数据。"
	)

	var failed_architecture: GFArchitecture = GFArchitecture.new()
	var first_model: DuplicateSaveKeyModel = DuplicateSaveKeyModel.new()
	var second_model: DuplicateSaveKeyModelPeer = DuplicateSaveKeyModelPeer.new()
	assert_true(await failed_architecture.register_model_instance(first_model))
	assert_true(await failed_architecture.register_model_instance(second_model))

	var failed_result: Dictionary = failed_architecture.get_global_snapshot()

	assert_false(
		GFVariantData.get_option_bool(failed_result, "ok", true),
		"Model 捕获失败必须通过 Result 显式报告。"
	)
	assert_false(
		failed_result.has("snapshot"),
		"失败 Result 不得包含可被持久化层误提交的 snapshot。"
	)
	assert_false(
		GFVariantData.get_option_string(failed_result, "error").is_empty(),
		"失败 Result 必须提供错误原因。"
	)
	assert_false(
		failed_result.has("models"),
		"失败 Result 不得伪装为旧式全局快照。"
	)
	assert_push_error(
		"[GFArchitecture] Model 快照键重复：duplicate_snapshot_key。请为每个 Model 提供唯一 get_save_key()。"
	)

	empty_architecture.dispose()
	failed_architecture.dispose()


func test_global_capture_rejects_non_dictionary_json_model_projection() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: InvalidJsonProjectionModel = InvalidJsonProjectionModel.new()
	assert_true(await architecture.register_model_instance(model))

	var result: Dictionary = architecture.get_global_snapshot()

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"Model 数据无法保持 Dictionary 投影时捕获必须失败。"
	)
	assert_false(
		result.has("snapshot"),
		"JSON 投影失败不得留下可提交 snapshot。"
	)
	assert_false(
		GFVariantData.get_option_string(result, "error").is_empty(),
		"JSON 投影失败必须提供错误原因。"
	)

	architecture.dispose()


func test_sync_model_capture_rejects_verification_serializer_mutating_earlier_model() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var victim: CaptureMutationVictimModel = CaptureMutationVictimModel.new()
	var mutator: CrossMutatingCaptureModel = CrossMutatingCaptureModel.new()
	victim.value = 10
	mutator.victim = victim
	mutator.mutate_on_serialization_call = 2
	assert_true(await architecture.register_model_instance(victim))
	assert_true(await architecture.register_model_instance(mutator))

	var result: Dictionary = architecture.get_all_models_state()

	_assert_unstable_capture_failure(result, "同步 Model capture")
	assert_eq(victim.value, 99, "测试必须确认后序 serializer 已修改先捕获的 Model。")
	architecture.dispose()


func test_async_model_capture_rejects_later_serializer_mutating_earlier_model() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var victim: CaptureMutationVictimModel = CaptureMutationVictimModel.new()
	var mutator: CrossMutatingCaptureModel = CrossMutatingCaptureModel.new()
	victim.value = 10
	mutator.victim = victim
	assert_true(await architecture.register_model_instance(victim))
	assert_true(await architecture.register_model_instance(mutator))

	var result: Dictionary = await architecture.get_all_models_state_async({
		"max_models_per_frame": 1,
	})

	_assert_unstable_capture_failure(result, "异步 Model capture")
	assert_eq(victim.value, 99, "异步测试必须确认后序 serializer 已修改先捕获的 Model。")
	architecture.dispose()


func test_sync_global_capture_rejects_history_verification_mutating_model() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: CaptureMutationVictimModel = CaptureMutationVictimModel.new()
	var history_store: CaptureModelMutatingHistoryUtility = (
		CaptureModelMutatingHistoryUtility.new()
	)
	model.value = 10
	history_store.model = model
	history_store.mutate_on_serialization_call = 2
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))

	var result: Dictionary = architecture.get_global_snapshot()

	_assert_unstable_capture_failure(result, "同步 global capture")
	assert_eq(model.value, 90, "测试必须确认 history serializer 已修改 Model。")
	architecture.dispose()


func test_async_global_capture_rejects_history_serializer_mutating_model() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: CaptureMutationVictimModel = CaptureMutationVictimModel.new()
	var history_store: CaptureModelMutatingHistoryUtility = (
		CaptureModelMutatingHistoryUtility.new()
	)
	model.value = 10
	history_store.model = model
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))

	var result: Dictionary = await architecture.get_global_snapshot_async({
		"max_models_per_frame": 1,
	})

	_assert_unstable_capture_failure(result, "异步 global capture")
	assert_eq(model.value, 90, "异步测试必须确认 history serializer 已修改 Model。")
	architecture.dispose()


func test_global_restore_rolls_back_all_models_when_apply_verification_fails() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: RollbackModel = RollbackModel.new()
	var failing_model: FailingApplyModel = FailingApplyModel.new()
	first_model.value = 10
	failing_model.value = 20
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(failing_model))

	var raw_result: Variant = architecture.call(&"restore_global_snapshot", {
		"format_version": 1,
		"models": {
			"rollback_model": { "value": 100 },
			"failing_apply_model": { "value": 200 },
		},
	})
	var result: Dictionary = {}
	if raw_result is Dictionary:
		result = raw_result

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"任一 Model 应用未产生目标状态时，整个 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"apply",
		"失败 Result 应标记 apply 阶段。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "rolled_back"),
		"失败 Result 应确认事务已回滚。"
	)
	assert_eq(first_model.value, 10, "已成功应用的前序 Model 必须回滚到恢复前状态。")
	assert_eq(failing_model.value, 20, "失败 Model 自身也必须回滚到恢复前状态。")

	architecture.dispose()


func test_global_restore_rolls_back_models_and_history_when_commit_verification_fails() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: RollbackModel = RollbackModel.new()
	var history_store: CommitRejectingHistoryUtility = CommitRejectingHistoryUtility.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))
	var baseline_history: Dictionary = history_store.serialize_full_history()
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	var result: Dictionary = architecture.restore_global_snapshot(
		{
			"format_version": 1,
			"models": {
				"rollback_model": { "value": 100 },
			},
			"command_history": {
				"undo": [{ "id": "target" }],
				"redo": [],
			},
		},
		command_builder
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"历史提交未达到目标状态时，整个 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"commit",
		"历史提交验证失败应标记 commit 阶段。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "rolled_back"),
		"commit 失败 Result 应确认 Model 与历史均已回滚。"
	)
	assert_eq(model.value, 10, "commit 失败后已应用的 Model 必须回滚。")
	assert_eq(
		history_store.serialize_full_history(),
		baseline_history,
		"commit 失败后命令历史必须回滚到恢复前基线。"
	)

	architecture.dispose()


func test_async_global_capture_fails_when_frozen_registry_changes_between_frames() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: AsyncCaptureModel = AsyncCaptureModel.new()
	var second_model: AsyncCaptureModelPeer = AsyncCaptureModelPeer.new()
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))
	var pending_result: Dictionary = {
		"done": false,
		"result": {},
	}
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_async_global_result"),
		[architecture, pending_result]
	)

	await get_tree().process_frame
	architecture.unregister_model(AsyncCaptureModelPeer)
	assert_true(
		await _wait_for_result(pending_result),
		"分帧捕获应在有界帧数内结束。"
	)
	var result: Dictionary = GFVariantData.get_option_dictionary(
		pending_result,
		"result"
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"冻结后的 Model 注册表跨帧变化必须显式使捕获失败。"
	)
	assert_false(
		result.has("snapshot"),
		"跨帧一致性失败不得留下可提交 snapshot。"
	)
	assert_false(
		GFVariantData.get_option_string(result, "error").is_empty(),
		"跨帧一致性失败必须提供错误原因。"
	)

	architecture.dispose()


func test_async_global_restore_rolls_back_models_and_history_when_commit_fails() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: RollbackModel = RollbackModel.new()
	var history_store: CommitRejectingHistoryUtility = CommitRejectingHistoryUtility.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))
	var baseline_history: Dictionary = history_store.serialize_full_history()
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	var raw_result: Variant = await architecture.restore_global_snapshot_async(
		{
			"format_version": 1,
			"models": {
				"rollback_model": { "value": 100 },
			},
			"command_history": {
				"undo": [{ "id": "target" }],
				"redo": [],
			},
		},
		command_builder,
		{ "max_models_per_frame": 1 }
	)
	var result: Dictionary = {}
	if raw_result is Dictionary:
		result = raw_result

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"异步历史提交失败必须使整个 restore 失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"commit",
		"异步历史提交验证失败应标记 commit 阶段。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "rolled_back"),
		"异步 commit 失败应确认 Model 与历史均已回滚。"
	)
	assert_eq(model.value, 10, "异步 commit 失败后 Model 必须回滚。")
	assert_eq(
		history_store.serialize_full_history(),
		baseline_history,
		"异步 commit 失败后命令历史必须回滚。"
	)

	architecture.dispose()


func test_sync_restore_fails_closed_when_model_replaces_registry_identity() -> void:
	var architecture: RegistryMutationArchitecture = RegistryMutationArchitecture.new()
	var replacement: IdentityReplacingModel = IdentityReplacingModel.new()
	var model: IdentityReplacingModel = IdentityReplacingModel.new()
	model.value = 10
	replacement.value = 777
	model.replacement = replacement
	assert_true(await architecture.register_model_instance(model))

	var result: Dictionary = architecture.restore_all_models_state({
		"identity_replacing_model": { "value": 100 },
	})

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"from_dict 内替换注册表 identity 后 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"apply",
		"identity 漂移应在 apply 阶段被检测。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"原 identity 已不再是当前目标时不得误报 rollback 成功。"
	)
	assert_eq(model.value, 100, "rollback 不得再次写入已被替换的陈旧 Model。")
	assert_eq(model.from_dict_calls, 1, "陈旧 Model 只能收到最初一次 from_dict。")
	assert_eq(replacement.value, 777, "新注册 identity 不得被陈旧事务修改。")
	var model_script: Script = model.get_model_script()
	assert_same(
		architecture.get_model(model_script),
		replacement,
		"注册表必须保留事务期间写入的新 identity。"
	)

	architecture.dispose()


func test_sync_restore_checks_save_key_before_each_model_apply() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: PeerKeyMutatingModel = PeerKeyMutatingModel.new()
	var second_model: MutableSaveKeyModel = MutableSaveKeyModel.new()
	first_model.value = 10
	second_model.value = 20
	first_model.peer = second_model
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))

	var result: Dictionary = architecture.restore_all_models_state({
		"peer_key_mutating_model": { "value": 100 },
		"mutable_save_key_model": { "value": 200 },
	})

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"前序 Model 改变后序目标 save key 后 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"apply",
		"调用下一次 from_dict 前发现 save key 漂移应标记 apply。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"事务目标集合仍有 save key 漂移时不得误报完整 rollback。"
	)
	assert_eq(first_model.value, 10, "已经应用且仍为当前目标的前序 Model 应恢复基线。")
	assert_eq(first_model.from_dict_calls, 2, "前序 Model 应包含一次 apply 和一次 rollback。")
	assert_eq(second_model.value, 20, "save key 已漂移的后序 Model 不得执行 from_dict。")
	assert_eq(second_model.from_dict_calls, 0, "每次 from_dict 前必须先校验 save key。")
	assert_eq(
		second_model.get_save_key(),
		&"mutable_save_key_model_changed",
		"测试必须确认后序目标确实发生了 save key 漂移。"
	)

	architecture.dispose()


func test_async_restore_does_not_rollback_model_after_save_key_drift() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: SelfKeyMutatingModel = SelfKeyMutatingModel.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))

	var result: Dictionary = await architecture.restore_all_models_state_async(
		{
			"self_key_mutating_model": { "value": 100 },
		},
		{ "max_models_per_frame": 1 }
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"异步 from_dict 改变自身 save key 后 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"apply",
		"异步 save key 漂移应在 apply 阶段被检测。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"save key 已漂移时不得误报 rollback 成功。"
	)
	assert_eq(model.value, 100, "rollback 不得写入 save key 已漂移的陈旧目标。")
	assert_eq(model.from_dict_calls, 1, "save key 漂移后不得再次调用 from_dict 回滚。")

	architecture.dispose()


func test_history_store_replacement_during_apply_is_detected_and_not_rolled_back() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: RollbackModel = RollbackModel.new()
	var replacement_store: PassiveHistoryStore = PassiveHistoryStore.new()
	var history_store: ReplacingHistoryUtility = ReplacingHistoryUtility.new()
	model.value = 10
	history_store.replacement = replacement_store
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	var result: Dictionary = architecture.restore_global_snapshot(
		{
			"format_version": 1,
			"models": {
				"rollback_model": { "value": 100 },
			},
			"command_history": {
				"undo": [{ "id": "target" }],
				"redo": [],
			},
		},
		command_builder
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"history apply 内替换 resolver store 后全局 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"commit",
		"history store identity 漂移属于 commit 失败。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"原 history store 已非当前目标时不得误报 rollback 成功。"
	)
	assert_eq(model.value, 10, "仍为当前目标的 Model 应回滚到基线。")
	assert_eq(history_store.deserialize_calls, 1, "陈旧 history store 不得被再次调用以 rollback。")
	assert_eq(
		replacement_store.serialize_full_history(),
		{
			"undo": [{ "id": "replacement" }],
			"redo": [],
		},
		"新 history store 不得被陈旧事务修改。"
	)

	architecture.dispose()


func test_history_store_replacement_during_verify_is_detected() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var replacement_store: PassiveHistoryStore = PassiveHistoryStore.new()
	var history_store: VerifyReplacingHistoryUtility = VerifyReplacingHistoryUtility.new()
	history_store.replacement = replacement_store
	assert_true(await architecture.register_utility_instance(history_store))
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	var result: Dictionary = architecture.restore_global_snapshot(
		{
			"format_version": 1,
			"models": {},
			"command_history": {
				"undo": [{ "id": "target" }],
				"redo": [],
			},
		},
		command_builder
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"history verify 内替换 resolver store 后全局 restore 必须失败。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"verify 后 store 已漂移时不得在陈旧 store 上 rollback。"
	)
	assert_eq(history_store.deserialize_calls, 1, "verify 漂移后陈旧 store 不得收到 rollback。")
	assert_eq(
		replacement_store.deserialize_calls,
		0,
		"当前的新 store 也不得接收为旧 store 准备的 baseline。"
	)

	architecture.dispose()


func test_async_global_restore_rechecks_history_store_after_model_yield() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: RollbackModel = RollbackModel.new()
	var history_store: StableHistoryUtility = StableHistoryUtility.new()
	var replacement_store: PassiveHistoryStore = PassiveHistoryStore.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()
	var pending_result: Dictionary = {
		"done": false,
		"result": {},
	}

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_restore_async_global_result"),
		[
			architecture,
			{
				"format_version": 1,
				"models": {
					"rollback_model": { "value": 100 },
				},
				"command_history": {
					"undo": [{ "id": "target" }],
					"redo": [],
				},
			},
			command_builder,
			pending_result,
		]
	)
	assert_eq(model.value, 100, "异步测试应在首个分帧等待前完成 Model apply。")
	assert_true(
		architecture.unregister_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			history_store
		)
	)
	assert_true(
		architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			replacement_store
		)
	)
	assert_true(await _wait_for_result(pending_result), "异步 restore 应在有界帧数内结束。")
	var result: Dictionary = GFVariantData.get_option_dictionary(
		pending_result,
		"result"
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"Model yield 后 history resolver identity 漂移必须使 restore 失败。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"history store 漂移后整个事务不得报告完整 rollback。"
	)
	assert_eq(model.value, 10, "history commit 前检测漂移后已应用 Model 应回滚。")
	assert_eq(history_store.deserialize_calls, 0, "异步恢复不得向陈旧 history store commit。")
	assert_eq(replacement_store.deserialize_calls, 0, "新 store 也不得接收旧事务的目标快照。")

	architecture.dispose()


func test_sync_restore_aggregate_verification_catches_later_model_corruption() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: AggregateFirstModel = AggregateFirstModel.new()
	var second_model: LaterCorruptingModel = LaterCorruptingModel.new()
	first_model.value = 10
	second_model.value = 20
	second_model.first_model = first_model
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))

	var result: Dictionary = architecture.restore_all_models_state({
		"aggregate_first_model": { "value": 100 },
		"later_corrupting_model": { "value": 200 },
	})

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"后序 from_dict 回写前序 Model 后同步 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"commit",
		"逐项 apply 均通过但聚合目标失配应标记 commit。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "rolled_back"),
		"identity 稳定且聚合基线恢复成功时应报告 rollback 成功。"
	)
	assert_eq(first_model.value, 10, "同步聚合校验失败后前序 Model 应恢复基线。")
	assert_eq(second_model.value, 20, "同步聚合校验失败后后序 Model 应恢复基线。")

	architecture.dispose()


func test_async_restore_aggregate_verification_catches_later_model_corruption() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: AggregateFirstModel = AggregateFirstModel.new()
	var second_model: LaterCorruptingModel = LaterCorruptingModel.new()
	first_model.value = 10
	second_model.value = 20
	second_model.first_model = first_model
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))

	var result: Dictionary = await architecture.restore_all_models_state_async(
		{
			"aggregate_first_model": { "value": 100 },
			"later_corrupting_model": { "value": 200 },
		},
		{ "max_models_per_frame": 1 }
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"后序 from_dict 回写前序 Model 后异步 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"commit",
		"异步逐项 apply 均通过但聚合目标失配应标记 commit。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "rolled_back"),
		"异步聚合失败且完整恢复基线时应报告 rollback 成功。"
	)
	assert_eq(first_model.value, 10, "异步聚合校验失败后前序 Model 应恢复基线。")
	assert_eq(second_model.value, 20, "异步聚合校验失败后后序 Model 应恢复基线。")

	architecture.dispose()


func test_rollback_aggregate_verification_catches_later_callback_corruption() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: RollbackCorruptingFirstModel = RollbackCorruptingFirstModel.new()
	var failing_model: RollbackTriggerModel = RollbackTriggerModel.new()
	first_model.value = 10
	failing_model.value = 20
	first_model.peer = failing_model
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(failing_model))

	var result: Dictionary = architecture.restore_all_models_state({
		"rollback_corrupting_first_model": { "value": 100 },
		"rollback_trigger_model": { "value": 200 },
	})

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"触发 apply 失败后事务必须返回失败。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"后执行的 rollback callback 改坏已回滚 Model 时不得误报成功。"
	)
	assert_eq(first_model.value, 10, "最后执行的前序 Model rollback 应恢复自身基线。")
	assert_eq(
		failing_model.value,
		999,
		"测试必须确认后序 Model 在通过逐项 rollback 校验后又被回写。"
	)

	architecture.dispose()


func test_history_commit_aggregate_verification_catches_model_corruption() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: RollbackModel = RollbackModel.new()
	var history_store: ModelCorruptingHistoryUtility = (
		ModelCorruptingHistoryUtility.new()
	)
	model.value = 10
	history_store.model = model
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))
	var baseline_history: Dictionary = history_store.serialize_full_history()
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	var result: Dictionary = architecture.restore_global_snapshot(
		{
			"format_version": 1,
			"models": {
				"rollback_model": { "value": 100 },
			},
			"command_history": {
				"undo": [{ "id": "target" }],
				"redo": [],
			},
		},
		command_builder
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"history deserialize 改坏已验收 Model 后全局 restore 必须失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"commit",
		"history commit 后聚合 Model 失配应标记 commit。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "rolled_back"),
		"Model 与 history 都恢复并通过最终聚合基线时应报告 rollback 成功。"
	)
	assert_eq(model.value, 10, "history commit 污染 Model 后应回滚 Model 基线。")
	assert_eq(
		history_store.serialize_full_history(),
		baseline_history,
		"history commit 污染 Model 后也应回滚历史基线。"
	)

	architecture.dispose()


func test_global_rollback_reverifies_history_after_model_callbacks() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var history_store: CommitRejectingHistoryUtility = CommitRejectingHistoryUtility.new()
	var model: HistoryCorruptingRollbackModel = HistoryCorruptingRollbackModel.new()
	model.value = 10
	model.history_store = history_store
	assert_true(await architecture.register_model_instance(model))
	assert_true(await architecture.register_utility_instance(history_store))
	var command_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	var result: Dictionary = architecture.restore_global_snapshot(
		{
			"format_version": 1,
			"models": {
				"history_corrupting_rollback_model": { "value": 100 },
			},
			"command_history": {
				"undo": [{ "id": "target" }],
				"redo": [],
			},
		},
		command_builder
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"history commit 拒绝后全局 restore 必须失败。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, "rolled_back", true),
		"Model rollback callback 再次污染 history 时不得误报完整 rollback。"
	)
	assert_eq(model.value, 10, "Model 自身仍应恢复到基线。")
	assert_eq(
		history_store.serialize_full_history(),
		{
			"undo": [{ "id": "rollback_corrupted" }],
			"redo": [],
		},
		"测试必须确认 history 在先通过 rollback 后又被 Model callback 污染。"
	)

	architecture.dispose()


func test_async_restore_rejects_overlap_until_transaction_finishes() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: ConcurrentRestoreFirstModel = ConcurrentRestoreFirstModel.new()
	var second_model: ConcurrentRestoreSecondModel = ConcurrentRestoreSecondModel.new()
	first_model.value = 10
	second_model.value = 20
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))
	var pending_result: Dictionary = {
		"done": false,
		"result": {},
	}

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_restore_async_global_result"),
		[
			architecture,
			{
				"format_version": 1,
				"models": {
					"concurrent_restore_first_model": { "value": 100 },
					"concurrent_restore_second_model": { "value": 200 },
				},
			},
			Callable(),
			pending_result,
		]
	)
	var overlapping_result: Dictionary = architecture.restore_all_models_state({
		"concurrent_restore_first_model": { "value": 300 },
		"concurrent_restore_second_model": { "value": 400 },
	})

	assert_false(
		GFVariantData.get_option_bool(overlapping_result, "ok", true),
		"异步 restore 让帧期间，后启动的同步 restore 必须 fail-fast。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(overlapping_result, "phase"),
		&"busy",
		"并发 restore 应返回稳定 busy phase。"
	)
	assert_false(
		GFVariantData.get_option_bool(overlapping_result, "rolled_back", true),
		"未获得事务所有权的 restore 不得报告 rollback。"
	)
	assert_true(
		await _wait_for_result(pending_result),
		"持有 gate 的异步 restore 应在有界帧数内完成。"
	)
	var first_result: Dictionary = GFVariantData.get_option_dictionary(
		pending_result,
		"result"
	)
	assert_true(
		GFVariantData.get_option_bool(first_result, "ok"),
		"先启动的异步 restore 应完整提交。"
	)
	assert_eq(first_model.value, 100, "并发拒绝后首个 Model 应保持第一事务目标。")
	assert_eq(second_model.value, 200, "并发拒绝后第二个 Model 应保持第一事务目标。")

	var later_result: Dictionary = architecture.restore_all_models_state({
		"concurrent_restore_first_model": { "value": 300 },
		"concurrent_restore_second_model": { "value": 400 },
	})
	assert_true(
		GFVariantData.get_option_bool(later_result, "ok"),
		"首个事务结束后 gate 必须允许新的 restore。"
	)
	assert_eq(first_model.value, 300, "后续事务应在 gate 释放后提交第一个 Model。")
	assert_eq(second_model.value, 400, "后续事务应在 gate 释放后提交第二个 Model。")

	architecture.dispose()


func test_model_apply_callback_cannot_reenter_other_restore_entry() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: ReentrantRestoreModel = ReentrantRestoreModel.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))

	var outer_result: Dictionary = architecture.restore_global_snapshot({
		"format_version": 1,
		"models": {
			"reentrant_restore_model": { "value": 100 },
		},
	})

	assert_true(
		GFVariantData.get_option_bool(outer_result, "ok"),
		"内部实现不应因共享 gate 误拒持有事务的全局 restore。"
	)
	assert_false(
		GFVariantData.get_option_bool(model.reentrant_result, "ok", true),
		"Model.from_dict() 回调重入其他 restore 入口必须 fail-fast。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(model.reentrant_result, "phase"),
		&"busy",
		"回调重入应返回稳定 busy phase。"
	)
	assert_eq(model.value, 100, "被拒绝的重入不得覆盖外层事务目标。")

	var later_result: Dictionary = architecture.restore_all_models_state({
		"reentrant_restore_model": { "value": 300 },
	})
	assert_true(
		GFVariantData.get_option_bool(later_result, "ok"),
		"回调返回且外层提交后，restore gate 必须恢复。"
	)
	assert_eq(model.value, 300, "gate 恢复后新的 Model restore 应正常提交。")

	architecture.dispose()


func test_async_restore_rejects_every_capture_entry_until_transaction_finishes() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: ConcurrentRestoreFirstModel = ConcurrentRestoreFirstModel.new()
	var second_model: ConcurrentRestoreSecondModel = ConcurrentRestoreSecondModel.new()
	first_model.value = 10
	second_model.value = 20
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))
	var pending_result: Dictionary = {
		"done": false,
		"result": {},
	}

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_restore_async_global_result"),
		[
			architecture,
			{
				"format_version": 1,
				"models": {
					"concurrent_restore_first_model": { "value": 100 },
					"concurrent_restore_second_model": { "value": 200 },
				},
			},
			Callable(),
			pending_result,
		]
	)
	var sync_models_capture: Dictionary = architecture.get_all_models_state()
	var sync_global_capture: Dictionary = architecture.get_global_snapshot()
	var async_models_capture: Dictionary = await architecture.get_all_models_state_async(
		{ "max_models_per_frame": 1 }
	)
	var async_global_capture: Dictionary = await architecture.get_global_snapshot_async(
		{ "max_models_per_frame": 1 }
	)

	_assert_capture_busy_result(sync_models_capture, "同步 Model capture")
	_assert_capture_busy_result(sync_global_capture, "同步 global capture")
	_assert_capture_busy_result(async_models_capture, "异步 Model capture")
	_assert_capture_busy_result(async_global_capture, "异步 global capture")
	assert_true(
		await _wait_for_result(pending_result),
		"持有 gate 的异步 restore 应在有界帧数内完成。"
	)
	assert_true(
		GFVariantData.get_option_bool(
			GFVariantData.get_option_dictionary(pending_result, "result"),
			"ok"
		),
		"capture 被拒绝后，原异步 restore 仍应完整提交。"
	)

	var later_capture: Dictionary = architecture.get_global_snapshot()
	assert_true(
		GFVariantData.get_option_bool(later_capture, "ok"),
		"restore 结束后 snapshot gate 必须允许新的 capture。"
	)
	architecture.dispose()


func test_async_capture_rejects_capture_and_restore_until_transaction_finishes() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_model: ConcurrentRestoreFirstModel = ConcurrentRestoreFirstModel.new()
	var second_model: ConcurrentRestoreSecondModel = ConcurrentRestoreSecondModel.new()
	first_model.value = 10
	second_model.value = 20
	assert_true(await architecture.register_model_instance(first_model))
	assert_true(await architecture.register_model_instance(second_model))
	var pending_result: Dictionary = {
		"done": false,
		"result": {},
	}

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_async_global_result"),
		[architecture, pending_result]
	)
	var overlapping_capture: Dictionary = architecture.get_all_models_state()
	var overlapping_restore: Dictionary = architecture.restore_all_models_state({
		"concurrent_restore_first_model": { "value": 100 },
		"concurrent_restore_second_model": { "value": 200 },
	})

	_assert_capture_busy_result(overlapping_capture, "异步 global capture 期间的 Model capture")
	assert_false(
		GFVariantData.get_option_bool(overlapping_restore, "ok", true),
		"异步 capture 让帧期间 restore 必须 fail-fast。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(overlapping_restore, "phase"),
		&"busy",
		"capture 持有 gate 时 restore 应返回稳定 busy phase。"
	)
	assert_eq(first_model.value, 10, "被拒绝的 restore 不得改写第一个 Model。")
	assert_eq(second_model.value, 20, "被拒绝的 restore 不得改写第二个 Model。")
	assert_true(
		await _wait_for_result(pending_result),
		"持有 gate 的异步 capture 应在有界帧数内完成。"
	)
	assert_true(
		GFVariantData.get_option_bool(
			GFVariantData.get_option_dictionary(pending_result, "result"),
			"ok"
		),
		"先启动的异步 capture 应完整返回。"
	)

	var later_restore: Dictionary = architecture.restore_all_models_state({
		"concurrent_restore_first_model": { "value": 100 },
		"concurrent_restore_second_model": { "value": 200 },
	})
	assert_true(
		GFVariantData.get_option_bool(later_restore, "ok"),
		"capture 结束后 snapshot gate 必须允许新的 restore。"
	)
	architecture.dispose()


func test_model_capture_callback_cannot_reenter_restore() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: CaptureReentrantRestoreModel = CaptureReentrantRestoreModel.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))

	var capture_result: Dictionary = architecture.get_all_models_state()
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(
		capture_result,
		"snapshot"
	)
	var model_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"capture_reentrant_restore_model"
	)

	assert_true(
		GFVariantData.get_option_bool(capture_result, "ok"),
		"持有 gate 的 Model capture 自身应成功。"
	)
	assert_eq(
		GFVariantData.get_option_int(model_snapshot, "value"),
		10,
		"被拒绝的 restore 不得让 capture 返回混合状态。"
	)
	assert_false(
		GFVariantData.get_option_bool(model.reentrant_result, "ok", true),
		"Model.to_dict() 回调重入 restore 必须 fail-fast。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(model.reentrant_result, "phase"),
		&"busy",
		"capture callback 重入 restore 应返回稳定 busy phase。"
	)
	assert_eq(model.value, 10, "被拒绝的 callback restore 不得改写 Model。")

	var later_restore: Dictionary = architecture.restore_all_models_state({
		"capture_reentrant_restore_model": { "value": 300 },
	})
	assert_true(
		GFVariantData.get_option_bool(later_restore, "ok"),
		"capture callback 返回且事务完成后 restore gate 必须恢复。"
	)
	assert_eq(model.value, 300, "gate 恢复后的 restore 应正常提交。")
	architecture.dispose()


func test_model_restore_callback_cannot_reenter_capture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: RestoreReentrantCaptureModel = RestoreReentrantCaptureModel.new()
	model.value = 10
	assert_true(await architecture.register_model_instance(model))

	var restore_result: Dictionary = architecture.restore_all_models_state({
		"restore_reentrant_capture_model": { "value": 200 },
	})

	assert_true(
		GFVariantData.get_option_bool(restore_result, "ok"),
		"持有 gate 的 Model restore 自身应成功。"
	)
	_assert_capture_busy_result(
		model.reentrant_result,
		"Model.from_dict() 回调重入 global capture"
	)
	assert_eq(model.value, 200, "被拒绝的 callback capture 不得影响外层 restore。")

	var later_capture: Dictionary = architecture.get_all_models_state()
	assert_true(
		GFVariantData.get_option_bool(later_capture, "ok"),
		"restore callback 返回且外层提交后，snapshot gate 必须允许新的 capture。"
	)
	var later_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		later_capture,
		"snapshot"
	)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(
				later_snapshot,
				"restore_reentrant_capture_model"
			),
			"value"
		),
		200,
		"gate 恢复后的 capture 应读取已提交 Model 状态。"
	)
	architecture.dispose()


# --- 私有/辅助方法 ---

func _capture_async_global_result(
	architecture: GFArchitecture,
	state: Dictionary
) -> void:
	state["result"] = await architecture.get_global_snapshot_async(
		{ "max_models_per_frame": 1 }
	)
	state["done"] = true


func _restore_async_global_result(
	architecture: GFArchitecture,
	snapshot: Dictionary,
	command_builder: Callable,
	state: Dictionary
) -> void:
	state["result"] = await architecture.restore_global_snapshot_async(
		snapshot,
		command_builder,
		{ "max_models_per_frame": 1 }
	)
	state["done"] = true


func _wait_for_result(state: Dictionary, max_frames: int = 30) -> bool:
	for _frame_index: int in range(max_frames):
		if GFVariantData.get_option_bool(state, "done"):
			return true
		await get_tree().process_frame
	return GFVariantData.get_option_bool(state, "done")


func _assert_capture_busy_result(result: Dictionary, label: String) -> void:
	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"%s 必须 fail-fast。" % label
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "phase"),
		&"busy",
		"%s 应返回稳定 busy phase。" % label
	)
	assert_false(result.has("snapshot"), "%s 不得返回可提交 snapshot。" % label)
	assert_false(
		GFVariantData.get_option_string(result, "error").is_empty(),
		"%s 应返回稳定错误信息。" % label
	)


func _assert_unstable_capture_failure(result: Dictionary, label: String) -> void:
	assert_false(
		GFVariantData.get_option_bool(result, "ok", true),
		"%s 遇到跨对象状态变化时必须 fail closed。" % label
	)
	assert_false(
		result.has("snapshot"),
		"%s 一致性复核失败后不得返回可提交 snapshot。" % label
	)
	var error: String = GFVariantData.get_option_string(result, "error")
	assert_false(error.is_empty(), "%s 必须返回稳定错误原因。" % label)
	assert_true(
		error.contains("稳定性复核失败"),
		"%s 应明确标识 snapshot 稳定性复核失败。" % label
	)


# --- 辅助类型 ---

class DuplicateSaveKeyModel extends GFModel:
	func get_save_key() -> StringName:
		return &"duplicate_snapshot_key"


class DuplicateSaveKeyModelPeer extends GFModel:
	func get_save_key() -> StringName:
		return &"duplicate_snapshot_key"


class RollbackModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"rollback_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")


class InvalidJsonProjectionModel extends GFModel:
	func get_save_key() -> StringName:
		return &"invalid_json_projection_model"

	func to_dict() -> Dictionary:
		return {
			1: "Dictionary key must stay string-like.",
		}


class CaptureMutationVictimModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"capture_mutation_victim_model"

	func to_dict() -> Dictionary:
		return { "value": value }


class CrossMutatingCaptureModel extends GFModel:
	var victim: CaptureMutationVictimModel = null
	var mutate_on_serialization_call: int = 1
	var _serialization_calls: int = 0

	func get_save_key() -> StringName:
		return &"cross_mutating_capture_model"

	func to_dict() -> Dictionary:
		_serialization_calls += 1
		if (
			victim != null
			and _serialization_calls == mutate_on_serialization_call
		):
			victim.value = 99
		return { "value": 20 }


class FailingApplyModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"failing_apply_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		var requested_value: int = GFVariantData.get_option_int(data, "value")
		value = requested_value + 1 if requested_value == 200 else requested_value


class AsyncCaptureModel extends GFModel:
	func get_save_key() -> StringName:
		return &"async_capture_model"

	func to_dict() -> Dictionary:
		return { "value": 1 }


class AsyncCaptureModelPeer extends GFModel:
	func get_save_key() -> StringName:
		return &"async_capture_model_peer"

	func to_dict() -> Dictionary:
		return { "value": 2 }


class CommitRejectingHistoryUtility extends GFUtility:
	var _state: Dictionary = {
		"undo": [{ "id": "baseline" }],
		"redo": [],
	}

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		var _registered_service: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)

	func serialize_full_history() -> Dictionary:
		return _state.duplicate(true)

	func deserialize_full_history(data: Dictionary, _command_builder: Callable) -> void:
		var undo_entries: Array = GFVariantData.get_option_array(data, "undo")
		var first_entry: Dictionary = {}
		if not undo_entries.is_empty() and undo_entries[0] is Dictionary:
			first_entry = undo_entries[0]
		if GFVariantData.get_option_string(first_entry, "id") == "target":
			_state = {
				"undo": [{ "id": "corrupted" }],
				"redo": [],
			}
			return
		_state = data.duplicate(true)


class CaptureModelMutatingHistoryUtility extends GFUtility:
	var model: CaptureMutationVictimModel = null
	var mutate_on_serialization_call: int = 1
	var _serialization_calls: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		var _registered_service: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)

	func serialize_full_history() -> Dictionary:
		_serialization_calls += 1
		if (
			model != null
			and _serialization_calls == mutate_on_serialization_call
		):
			model.value = 90
		return {
			"undo": [{ "id": "baseline" }],
			"redo": [],
		}


class RegistryMutationArchitecture extends GFArchitecture:
	func replace_model_identity_for_test(script: Script, replacement: GFModel) -> void:
		_models[script] = replacement


class IdentityReplacingModel extends GFModel:
	var value: int = 0
	var from_dict_calls: int = 0
	var replacement: IdentityReplacingModel = null

	func get_save_key() -> StringName:
		return &"identity_replacing_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func get_model_script() -> Script:
		var script_value: Variant = get_script()
		if script_value is Script:
			var model_script: Script = script_value
			return model_script
		return null

	func from_dict(data: Dictionary) -> void:
		from_dict_calls += 1
		value = GFVariantData.get_option_int(data, "value")
		if value != 100 or replacement == null:
			return
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture is RegistryMutationArchitecture:
			var mutation_architecture: RegistryMutationArchitecture = architecture
			mutation_architecture.replace_model_identity_for_test(
				get_model_script(),
				replacement
			)


class PeerKeyMutatingModel extends GFModel:
	var value: int = 0
	var from_dict_calls: int = 0
	var peer: MutableSaveKeyModel = null

	func get_save_key() -> StringName:
		return &"peer_key_mutating_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		from_dict_calls += 1
		value = GFVariantData.get_option_int(data, "value")
		if value == 100 and peer != null:
			peer.save_key = &"mutable_save_key_model_changed"


class MutableSaveKeyModel extends GFModel:
	var value: int = 0
	var from_dict_calls: int = 0
	var save_key: StringName = &"mutable_save_key_model"

	func get_save_key() -> StringName:
		return save_key

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		from_dict_calls += 1
		value = GFVariantData.get_option_int(data, "value")


class SelfKeyMutatingModel extends GFModel:
	var value: int = 0
	var from_dict_calls: int = 0
	var save_key: StringName = &"self_key_mutating_model"

	func get_save_key() -> StringName:
		return save_key

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		from_dict_calls += 1
		value = GFVariantData.get_option_int(data, "value")
		if value == 100:
			save_key = &"self_key_mutating_model_changed"


class PassiveHistoryStore extends RefCounted:
	var deserialize_calls: int = 0
	var _state: Dictionary = {
		"undo": [{ "id": "replacement" }],
		"redo": [],
	}

	func serialize_full_history() -> Dictionary:
		return _state.duplicate(true)

	func deserialize_full_history(data: Dictionary, _command_builder: Callable) -> void:
		deserialize_calls += 1
		_state = data.duplicate(true)


class StableHistoryUtility extends GFUtility:
	var deserialize_calls: int = 0
	var _state: Dictionary = {
		"undo": [{ "id": "baseline" }],
		"redo": [],
	}

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		var _registered_service: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)

	func serialize_full_history() -> Dictionary:
		return _state.duplicate(true)

	func deserialize_full_history(data: Dictionary, _command_builder: Callable) -> void:
		deserialize_calls += 1
		_state = data.duplicate(true)


class ReplacingHistoryUtility extends StableHistoryUtility:
	var replacement: PassiveHistoryStore = null

	func deserialize_full_history(data: Dictionary, command_builder: Callable) -> void:
		super.deserialize_full_history(data, command_builder)
		if replacement == null:
			return
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture == null:
			return
		var _unregistered: bool = architecture.unregister_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)
		var _registered: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			replacement
		)


class VerifyReplacingHistoryUtility extends StableHistoryUtility:
	var replacement: PassiveHistoryStore = null
	var _replace_during_verify: bool = false

	func deserialize_full_history(data: Dictionary, command_builder: Callable) -> void:
		super.deserialize_full_history(data, command_builder)
		_replace_during_verify = true

	func serialize_full_history() -> Dictionary:
		var snapshot: Dictionary = super.serialize_full_history()
		if not _replace_during_verify or replacement == null:
			return snapshot
		_replace_during_verify = false
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture == null:
			return snapshot
		var _unregistered: bool = architecture.unregister_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)
		var _registered: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			replacement
		)
		return snapshot


class AggregateFirstModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"aggregate_first_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")


class LaterCorruptingModel extends GFModel:
	var value: int = 0
	var first_model: AggregateFirstModel = null

	func get_save_key() -> StringName:
		return &"later_corrupting_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")
		if value == 200 and first_model != null:
			first_model.value = 999


class RollbackTriggerModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"rollback_trigger_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		var requested_value: int = GFVariantData.get_option_int(data, "value")
		value = requested_value + 1 if requested_value == 200 else requested_value


class RollbackCorruptingFirstModel extends GFModel:
	var value: int = 0
	var peer: RollbackTriggerModel = null

	func get_save_key() -> StringName:
		return &"rollback_corrupting_first_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")
		if value == 10 and peer != null:
			peer.value = 999


class ModelCorruptingHistoryUtility extends StableHistoryUtility:
	var model: RollbackModel = null

	func deserialize_full_history(data: Dictionary, command_builder: Callable) -> void:
		super.deserialize_full_history(data, command_builder)
		var undo_entries: Array = GFVariantData.get_option_array(data, "undo")
		var first_entry: Dictionary = {}
		if not undo_entries.is_empty() and undo_entries[0] is Dictionary:
			first_entry = undo_entries[0]
		if (
			GFVariantData.get_option_string(first_entry, "id") == "target"
			and model != null
		):
			model.value = 999


class HistoryCorruptingRollbackModel extends GFModel:
	var value: int = 0
	var history_store: CommitRejectingHistoryUtility = null

	func get_save_key() -> StringName:
		return &"history_corrupting_rollback_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")
		if value == 10 and history_store != null:
			history_store._state = {
				"undo": [{ "id": "rollback_corrupted" }],
				"redo": [],
			}


class ConcurrentRestoreFirstModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"concurrent_restore_first_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")


class ConcurrentRestoreSecondModel extends GFModel:
	var value: int = 0

	func get_save_key() -> StringName:
		return &"concurrent_restore_second_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")


class ReentrantRestoreModel extends GFModel:
	var value: int = 0
	var reentrant_result: Dictionary = {}
	var _attempted_reentry: bool = false

	func get_save_key() -> StringName:
		return &"reentrant_restore_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")
		if value != 100 or _attempted_reentry:
			return
		_attempted_reentry = true
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture == null:
			return
		reentrant_result = architecture.restore_all_models_state({
			"reentrant_restore_model": { "value": 200 },
		})


class CaptureReentrantRestoreModel extends GFModel:
	var value: int = 0
	var reentrant_result: Dictionary = {}
	var _attempted_reentry: bool = false

	func get_save_key() -> StringName:
		return &"capture_reentrant_restore_model"

	func to_dict() -> Dictionary:
		var captured_value: int = value
		if not _attempted_reentry:
			_attempted_reentry = true
			var architecture: GFArchitecture = _get_architecture_or_null()
			if architecture != null:
				reentrant_result = architecture.restore_all_models_state({
					"capture_reentrant_restore_model": { "value": 200 },
				})
		return { "value": captured_value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")


class RestoreReentrantCaptureModel extends GFModel:
	var value: int = 0
	var reentrant_result: Dictionary = {}
	var _attempted_reentry: bool = false

	func get_save_key() -> StringName:
		return &"restore_reentrant_capture_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")
		if _attempted_reentry:
			return
		_attempted_reentry = true
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture != null:
			reentrant_result = architecture.get_global_snapshot()
