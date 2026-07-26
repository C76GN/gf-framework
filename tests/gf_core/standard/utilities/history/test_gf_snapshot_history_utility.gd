## 测试 GFSnapshotHistoryUtility 的通用快照历史与恢复行为。
extends GutTest


# --- 测试方法 ---

## 验证自定义捕获/恢复回调可前后移动，并在新快照写入时裁剪未来分支。
func test_custom_callbacks_step_and_prune_future_branch() -> void:
	var state: Dictionary = { "value": 1 }
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()
	var capture_callback: Callable = func() -> Dictionary:
		return state.duplicate(true)
	var restore_callback: Callable = func(data: Variant) -> void:
		_replace_dictionary_contents(state, GFVariantData.as_dictionary(data))
	history.configure(capture_callback, restore_callback)

	var first_id: int = history.capture({ "label": "first" })
	state["value"] = 2
	var second_id: int = history.capture({ "label": "second" })

	assert_true(history.step_back(), "应可恢复到上一份快照。")
	assert_eq(GFVariantData.get_option_int(state, "value"), 1, "step_back 应恢复旧状态。")

	state["value"] = 3
	var third_id: int = history.capture({ "label": "third" })
	var ids: Array[int] = _snapshot_ids(history)

	assert_eq(first_id, 1, "首个快照 ID 应从 1 开始。")
	assert_eq(second_id, 2, "第二个快照 ID 应递增。")
	assert_eq(third_id, 3, "裁剪未来分支后也应继续递增 ID。")
	assert_eq(ids, [1, 3], "新快照应裁剪当前位置之后的未来分支。")
	assert_false(history.restore_snapshot_id(second_id), "被裁剪的快照不应再可恢复。")


## 验证历史上限会保留最新快照，并维持有效当前索引。
func test_max_history_size_trims_old_snapshots_and_keeps_index_valid() -> void:
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()
	var restored: Dictionary = {}
	var restore_callback: Callable = func(data: Variant) -> void:
		_replace_dictionary_contents(restored, GFVariantData.as_dictionary(data))
	history.configure(Callable(), restore_callback)
	history.max_history_size = 2

	var _push_snapshot_result_44: Variant = history.push_snapshot({ "value": 1 })
	var _push_snapshot_result_45: Variant = history.push_snapshot({ "value": 2 })
	var _push_snapshot_result_46: Variant = history.push_snapshot({ "value": 3 })

	var ids: Array[int] = _snapshot_ids(history)
	assert_eq(ids, [2, 3], "超过上限时应丢弃最旧快照。")
	assert_eq(history.current_index, 1, "当前索引应指向最新保留快照。")

	assert_true(history.step_back(), "裁剪后仍应可恢复上一份保留快照。")
	assert_eq(GFVariantData.get_option_int(restored, "value"), 2, "step_back 应恢复到上一份保留快照。")
	history.max_history_size = 1

	var snapshot: Dictionary = history.get_current_snapshot()
	assert_eq(history.current_index, 0, "进一步裁剪后当前索引仍应有效。")
	assert_eq(GFVariantData.get_option_int(_snapshot_data(snapshot), "value"), 3, "当前被裁掉时应收敛到剩余快照。")
	assert_eq(GFVariantData.get_option_int(restored, "value"), 3, "当前快照被裁剪并收敛到剩余快照时，外部恢复状态也应同步。")


## 验证快照记录和读取结果都执行深拷贝。
func test_snapshots_are_deep_copied() -> void:
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()
	var source: Dictionary = {
		"items": [1, 2],
	}
	var metadata: Dictionary = {
		"tags": ["a"],
	}

	var _push_snapshot_result_71: Variant = history.push_snapshot(source, metadata)
	GFVariantData.as_array(source["items"]).append(3)
	GFVariantData.as_array(metadata["tags"]).append("b")

	var snapshot: Dictionary = history.get_current_snapshot()
	var snapshot_data: Dictionary = _snapshot_data(snapshot)
	var snapshot_metadata: Dictionary = _snapshot_metadata(snapshot)
	GFVariantData.as_array(snapshot_data["items"]).append(4)
	GFVariantData.as_array(snapshot_metadata["tags"]).append("c")

	var stored_snapshot: Dictionary = history.get_current_snapshot()
	assert_eq(GFVariantData.get_option_array(_snapshot_data(stored_snapshot), "items"), [1, 2], "原始数据和外部返回值都不应污染内部快照。")
	assert_eq(GFVariantData.get_option_array(_snapshot_metadata(stored_snapshot), "tags"), ["a"], "元数据也应深拷贝。")


## 验证恢复回调返回 false 时不会移动当前索引。
func test_restore_callback_can_reject_restore() -> void:
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()
	var restore_callback: Callable = func(_data: Variant) -> bool:
		return false
	history.configure(Callable(), restore_callback)

	var _push_snapshot_result_93: Variant = history.push_snapshot({ "value": 1 })
	var _push_snapshot_result_94: Variant = history.push_snapshot({ "value": 2 })

	assert_false(history.restore_index(0), "恢复回调返回 false 时应报告恢复失败。")
	assert_eq(history.current_index, 1, "恢复失败不应移动当前索引。")


## 验证 configure 会忽略错误类型的可选回调，并钳制历史上限。
func test_configure_ignores_invalid_optional_callable() -> void:
	var state: Dictionary = { "value": 1 }
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()
	var capture_callback: Callable = func() -> Dictionary:
		return state.duplicate(true)
	var restore_callback: Callable = func(data: Variant) -> void:
		_replace_dictionary_contents(state, GFVariantData.as_dictionary(data))

	history.configure(capture_callback, restore_callback, {
		"max_history_size": -10,
		"restore_command_builder": "not_callable",
	})

	assert_eq(history.max_history_size, 0, "负数历史上限应钳制为 0，表示不限制。")
	assert_ne(history.capture(), 0, "错误类型的可选回调不应阻止捕获。")
	state["value"] = 2
	assert_true(history.restore_index(0), "错误类型的可选回调不应阻止自定义恢复。")
	assert_eq(GFVariantData.get_option_int(state, "value"), 1, "自定义恢复回调仍应正常执行。")


## 验证默认捕获/恢复路径会使用注入架构的全局快照。
func test_default_capture_uses_injected_architecture_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var model: SnapshotModel = SnapshotModel.new()
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()

	await arch.register_model_instance(model)
	await arch.register_utility_instance(history)

	model.value = 10
	var _capture_result_131: Variant = history.capture()
	model.value = 20
	var _capture_result_133: Variant = history.capture()

	assert_true(history.step_back(), "默认恢复路径应可还原架构全局快照。")
	assert_eq(model.value, 10, "Model 状态应通过架构快照恢复。")

	arch.dispose()


func test_default_capture_does_not_record_failed_architecture_result() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var first_model: DuplicateSnapshotModel = DuplicateSnapshotModel.new()
	var second_model: DuplicateSnapshotModelPeer = DuplicateSnapshotModelPeer.new()
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()

	assert_true(await arch.register_model_instance(first_model))
	assert_true(await arch.register_model_instance(second_model))
	assert_true(await arch.register_utility_instance(history))

	var snapshot_id: int = history.capture()

	assert_eq(snapshot_id, 0, "架构捕获失败时不得提交 SnapshotHistory 记录。")
	assert_eq(history.snapshot_count, 0, "失败 Result 不得作为普通快照载荷写入历史。")
	assert_push_error(
		"[GFArchitecture] Model 快照键重复：snapshot_history_duplicate。请为每个 Model 提供唯一 get_save_key()。"
	)
	assert_push_warning(
		"[GFSnapshotHistoryUtility] capture() 失败：Model 快照键重复：snapshot_history_duplicate。请为每个 Model 提供唯一 get_save_key()。"
	)

	arch.dispose()


func test_default_restore_failure_does_not_move_current_index() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var model: SnapshotModel = SnapshotModel.new()
	var history: GFSnapshotHistoryUtility = GFSnapshotHistoryUtility.new()

	assert_true(await arch.register_model_instance(model))
	assert_true(await arch.register_utility_instance(history))
	var invalid_snapshot_id: int = history.push_snapshot(
		{
			"format_version": 1,
			"models": {
				"unknown_model": { "value": 10 },
			},
		}
	)
	model.value = 20
	var valid_snapshot_id: int = history.capture()
	model.value = 30
	var current_index_before_restore: int = history.current_index

	assert_false(
		history.restore_snapshot_id(invalid_snapshot_id),
		"架构 restore Result 失败时默认恢复路径必须返回 false。"
	)
	assert_eq(
		history.current_index,
		current_index_before_restore,
		"架构 restore Result 失败时不得移动当前索引。"
	)
	assert_eq(model.value, 30, "validate 失败不得修改当前 Model 状态。")
	assert_eq(
		GFVariantData.get_option_int(history.get_current_snapshot(), "id"),
		valid_snapshot_id,
		"恢复失败后当前快照记录必须保持不变。"
	)
	assert_push_warning(
		"[GFSnapshotHistoryUtility] restore 失败：快照包含未注册的 Model 键：unknown_model。"
	)

	arch.dispose()


# --- 私有/辅助方法 ---

func _snapshot_ids(history: GFSnapshotHistoryUtility) -> Array[int]:
	var debug_snapshot: Dictionary = history.get_debug_snapshot()
	return GFVariantData.to_int_array(GFVariantData.get_option_value(debug_snapshot, "ids"))


func _snapshot_data(snapshot: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "data"))


func _snapshot_metadata(snapshot: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "metadata"))


func _replace_dictionary_contents(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	for key: Variant in source.keys():
		target[key] = source[key]


# --- 内部类 ---

class SnapshotModel:
	extends GFModel

	var value: int = 0

	func get_save_key() -> StringName:
		return &"snapshot_history_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value", 0)


class DuplicateSnapshotModel:
	extends GFModel

	func get_save_key() -> StringName:
		return &"snapshot_history_duplicate"


class DuplicateSnapshotModelPeer:
	extends GFModel

	func get_save_key() -> StringName:
		return &"snapshot_history_duplicate"
