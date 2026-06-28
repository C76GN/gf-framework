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
	assert_signal_not_emitted(resource, "items_changed", "批量期间不应提前发出 items_changed。")

	var report: Dictionary = resource.end_batch()

	assert_eq(GFVariantData.get_option_int(report, "change_count"), 2, "end_batch 应报告批量变更数量。")
	assert_signal_emitted(resource, "items_changed", "批量结束后应发出一次 items_changed。")


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
