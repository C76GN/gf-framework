## 测试 GFLevelProgressModel 的解锁、完成、结果合并与序列化。
extends GutTest


var _model: GFLevelProgressModel


func before_each() -> void:
	_model = GFLevelProgressModel.new()


func test_unlock_level_emits_once_and_ignores_duplicate() -> void:
	watch_signals(_model)
	_model.unlock_level(&"a")
	assert_signal_emit_count(_model, "level_unlocked", 1)
	_model.unlock_level(&"a")
	assert_signal_emit_count(_model, "level_unlocked", 1)
	assert_true(_model.is_level_unlocked(&"a"))


func test_unlock_empty_id_is_no_op() -> void:
	watch_signals(_model)
	_model.unlock_level(&"")
	assert_signal_emit_count(_model, "level_unlocked", 0)


func test_lock_level_emits_after_unlock() -> void:
	watch_signals(_model)
	_model.unlock_level(&"b")
	_model.lock_level(&"b")
	assert_signal_emitted(_model, "level_locked")
	assert_false(_model.is_level_unlocked(&"b"))


func test_complete_level_unlocks_marks_done_and_emits() -> void:
	watch_signals(_model)
	_model.complete_level(&"c", { "stars": 2 }, true)
	assert_signal_emitted(_model, "level_completed")
	assert_true(_model.is_level_unlocked(&"c"))
	assert_true(_model.is_level_completed(&"c"))
	assert_eq(GFVariantData.get_option_int(_model.get_level_result(&"c"), "stars"), 2)


func test_set_level_result_merge_replaces_when_disabled() -> void:
	_model.set_level_result(&"d", { "a": 1 }, true)
	_model.set_level_result(&"d", { "b": 2 }, false)
	var r: Dictionary = _model.get_level_result(&"d")
	assert_false(r.has("a"), "merge_result 为 false 时应整体替换结果。")
	assert_eq(GFVariantData.get_option_int(r, "b"), 2)


func test_set_level_result_merge_true_combines_keys() -> void:
	_model.set_level_result(&"e", { "a": 1 }, true)
	_model.set_level_result(&"e", { "b": 2 }, true)
	var r: Dictionary = _model.get_level_result(&"e")
	assert_eq(GFVariantData.get_option_int(r, "a"), 1)
	assert_eq(GFVariantData.get_option_int(r, "b"), 2)


func test_get_level_result_returns_copy() -> void:
	_model.set_level_result(&"f", { "x": 1 }, true)
	var a: Dictionary = _model.get_level_result(&"f")
	var b: Dictionary = _model.get_level_result(&"f")
	a["x"] = 99
	assert_eq(GFVariantData.get_option_int(b, "x"), 1, "外部修改副本不应影响内部存储。")


func test_clear_progress_resets_all() -> void:
	_model.unlock_level(&"g")
	_model.complete_level(&"g", {}, true)
	_model.clear_progress()
	assert_false(_model.is_level_unlocked(&"g"))
	assert_false(_model.is_level_completed(&"g"))
	assert_true(_model.get_level_result(&"g").is_empty())


func test_to_dict_from_dict_roundtrip() -> void:
	_model.unlock_level(&"h")
	_model.complete_level(&"h", { "s": 1 }, true)
	var data: Dictionary = _model.to_dict()
	var other: GFLevelProgressModel = GFLevelProgressModel.new()
	other.from_dict(data)
	assert_true(other.is_level_unlocked(&"h"))
	assert_true(other.is_level_completed(&"h"))
	assert_eq(GFVariantData.get_option_int(other.get_level_result(&"h"), "s"), 1)


func test_to_dict_deep_copies_level_results() -> void:
	_model.complete_level(&"nested", {
		"stats": {
			"stars": 3,
		},
	}, true)
	var data: Dictionary = _model.to_dict()
	var level_results: Dictionary = GFVariantData.get_option_dictionary(data, "level_results")
	var nested_result: Dictionary = GFVariantData.get_option_dictionary(level_results, "nested")
	var stats: Dictionary = GFVariantData.get_option_dictionary(nested_result, "stats")
	stats["stars"] = 0

	var current_result: Dictionary = _model.get_level_result(&"nested")
	var current_stats: Dictionary = GFVariantData.get_option_dictionary(current_result, "stats")
	assert_eq(GFVariantData.get_option_int(current_stats, "stars"), 3, "to_dict 返回的嵌套结果不应共享内部引用。")
