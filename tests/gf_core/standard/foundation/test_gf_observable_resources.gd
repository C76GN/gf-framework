## 测试可观察数组/字典资源的显式变更报告。
extends GutTest


func test_observable_array_emits_single_change_report() -> void:
	var resource: GFObservableArrayResource = GFObservableArrayResource.new()
	watch_signals(resource)

	var change: Dictionary = resource.append_item("ready", { "source": "test" })

	assert_eq(GFVariantData.get_option_int(change, "index"), 0, "追加应报告写入索引。")
	assert_eq(resource.get_items(), ["ready"], "数组应保存追加值。")
	assert_signal_emitted(resource, "item_changed", "单项变更应发出 item_changed。")
	assert_signal_emitted(resource, "items_changed", "单项变更也应发出批量兼容信号。")


func test_observable_array_batches_changes_until_end_batch() -> void:
	var resource: GFObservableArrayResource = GFObservableArrayResource.new()
	watch_signals(resource)

	resource.begin_batch({ "scope": "bulk" })
	var _first_change: Dictionary = resource.append_item(1)
	var _second_change: Dictionary = resource.append_item(2)
	assert_signal_not_emitted(resource, "item_changed", "批量期间不应提前发出 item_changed。")
	assert_signal_not_emitted(resource, "items_changed", "批量期间不应提前发出 items_changed。")

	var report: Dictionary = resource.end_batch()

	assert_eq(GFVariantData.get_option_int(report, "change_count"), 2, "end_batch 应报告批量变更数量。")
	assert_signal_emit_count(resource, "item_changed", 0, "批量结束不应补发 item_changed。")
	assert_signal_emit_count(resource, "items_changed", 1, "批量结束应只发出一次 aggregate 信号。")
	assert_signal_emitted(resource, "items_changed", "批量结束后应发出一次 items_changed。")


func test_observable_array_linearizes_reentrant_change_signals() -> void:
	var resource: GFObservableArrayResource = GFObservableArrayResource.new()
	var signal_order: Array[String] = []
	var on_item_changed: Callable = func(_operation: StringName, index: int, _old_value: Variant, _new_value: Variant, _metadata: Dictionary) -> void:
		signal_order.append("item_%d" % index)
		if index == 0:
			var _nested_change: Dictionary = resource.append_item("nested")
	var on_items_changed: Callable = func(changes: Array[Dictionary], _metadata: Dictionary) -> void:
		signal_order.append("items_%d" % GFVariantData.get_option_int(changes[0], "index", -1))
	var _item_connected: Error = resource.item_changed.connect(on_item_changed) as Error
	var _items_connected: Error = resource.items_changed.connect(on_items_changed) as Error

	var _outer_change: Dictionary = resource.append_item("outer")

	assert_eq(resource.get_items(), ["outer", "nested"], "重入 mutation 仍应立即更新集合。")
	assert_eq(signal_order, ["item_0", "items_0", "item_1", "items_1"], "每条 mutation 的单项和汇总信号应连续、可重放。")
	resource.item_changed.disconnect(on_item_changed)
	resource.items_changed.disconnect(on_items_changed)


func test_observable_dictionary_reports_set_and_erase() -> void:
	var resource: GFObservableDictionaryResource = GFObservableDictionaryResource.new()
	watch_signals(resource)

	var set_change: Dictionary = resource.set_value(&"hp", 100)
	var erase_change: Dictionary = resource.erase_value(&"hp")

	assert_true(GFVariantData.get_option_bool(set_change, "ok"), "set_value 应成功。")
	assert_eq(GFVariantData.to_int(resource.get_value(&"hp", -1)), -1, "erase 后键值应缺失。")
	assert_eq(GFVariantData.get_option_string_name(erase_change, "operation"), GFObservableDictionaryResource.OPERATION_ERASE, "erase 应报告操作类型。")
	assert_signal_emit_count(resource, "entry_changed", 2)
	assert_signal_emit_count(resource, "entries_changed", 2)


func test_observable_dictionary_batches_changes_without_entry_level_replay() -> void:
	var resource: GFObservableDictionaryResource = GFObservableDictionaryResource.new()
	watch_signals(resource)

	resource.begin_batch({ "scope": "bulk" })
	var _first_change: Dictionary = resource.set_value(&"hp", 100)
	var _second_change: Dictionary = resource.set_value(&"mp", 20)
	assert_signal_not_emitted(resource, "entry_changed", "批量期间不应提前发出 entry_changed。")
	assert_signal_not_emitted(resource, "entries_changed", "批量期间不应提前发出 entries_changed。")

	var report: Dictionary = resource.end_batch()

	assert_eq(GFVariantData.get_option_int(report, "change_count"), 2, "end_batch 应报告字典批量变更数量。")
	assert_signal_emit_count(resource, "entry_changed", 0, "批量结束不应补发 entry_changed。")
	assert_signal_emit_count(resource, "entries_changed", 1, "批量结束应只发出一次 aggregate 信号。")


func test_observable_dictionary_change_reports_preserve_resource_key_identity() -> void:
	var resource: GFObservableDictionaryResource = GFObservableDictionaryResource.new()
	var key_resource: Resource = Resource.new()

	var set_change: Dictionary = resource.set_value(key_resource, "value")
	var erase_change: Dictionary = resource.erase_value(key_resource)
	var raw_set_entry_key: Variant = GFVariantData.get_option_value(set_change, "entry_key")
	var raw_erase_entry_key: Variant = GFVariantData.get_option_value(erase_change, "entry_key")
	var set_entry_key: Resource = raw_set_entry_key if raw_set_entry_key is Resource else null
	var erase_entry_key: Resource = raw_erase_entry_key if raw_erase_entry_key is Resource else null

	assert_same(set_entry_key, key_resource, "Resource key 在 set 报告中应保留引用身份。")
	assert_same(erase_entry_key, key_resource, "Resource key 在 erase 报告中应保留引用身份。")
