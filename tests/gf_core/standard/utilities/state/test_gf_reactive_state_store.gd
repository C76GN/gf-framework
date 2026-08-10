## 测试 GFReactiveStateStore 的路径状态、dirty queue 和订阅生命周期。
extends GutTest


# --- 常量 ---

const GFReactiveStateStoreBase = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")


# --- 测试方法 ---

func test_set_value_reads_nested_path_and_emits_change() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"player": {
			"hp": 10,
		},
	})
	watch_signals(store)

	assert_true(store.set_value("player.hp", 12), "路径写入应报告变化。")

	assert_eq(GFVariantData.to_int(store.get_value("player.hp")), 12, "路径读取应返回最新值。")
	assert_signal_emitted(store, "state_changed", "写入路径应派发 state_changed。")
	assert_signal_emitted_with_parameters(
		store,
		"path_changed",
		["player.hp", _find_signal_change(store, "path_changed", "player.hp")]
	)


func test_failed_path_write_is_atomic() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"profile": {
			"name": "Ada",
		},
	})
	var before_state: Dictionary = store.get_state()
	watch_signals(store)

	assert_false(
		store.set_value([&"profile", &"inventory", &"items", 0], "potion"),
		"无法创建 Array 索引父级时写入应失败。"
	)

	assert_eq(store.get_state(), before_state, "失败写入不得遗留已创建的中间 Dictionary。")
	assert_true(store.get_dirty_changes().is_empty(), "失败写入不得产生 dirty change。")
	assert_signal_not_emitted(store, "state_changed", "失败写入不得派发 state_changed。")
	assert_signal_not_emitted(store, "path_changed", "失败写入不得派发 path_changed。")


func test_array_path_segments_read_write_erase_and_format() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"items": [
			{ "name": "potion" },
			{ "name": "ether" },
		],
	})

	assert_eq(GFReactiveStateStoreBase.format_path(["items", 1, "name"]), "items[1].name")
	assert_eq(GFVariantData.to_text(store.get_value(["items", 1, "name"])), "ether")
	assert_eq(GFVariantData.to_text(store.get_value("items[1].name")), "ether", "字符串路径应解析数组索引。")
	assert_true(store.set_value(["items", 1, "name"], "elixir"), "数组路径写入应成功。")
	assert_eq(GFVariantData.to_text(store.get_value(["items", 1, "name"])), "elixir")
	assert_true(store.set_value("items[0].name", "hi-potion"), "字符串数组路径写入应成功。")
	assert_eq(GFVariantData.to_text(store.get_value(["items", 0, "name"])), "hi-potion")
	assert_true(store.erase_value(["items", 0]), "数组索引删除应成功。")
	assert_eq(GFVariantData.to_text(store.get_value(["items", 0, "name"])), "elixir")
	assert_false(store.has_value(["items", 1]), "删除数组元素后后续索引应按 Array 语义前移。")


func test_set_state_uses_variant_diff_for_path_level_changes() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"player": {
			"hp": 10,
			"mp": 5,
		},
	})
	var changed_paths: Array[String] = []

	var _unsubscribe: Callable = store.subscribe("player", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		changed_paths.append(GFVariantData.get_option_string(change, "path"))
	, {
		"mode": GFReactiveStateStoreBase.SUBSCRIBE_PREFIX,
	})

	assert_true(store.set_state({
		"player": {
			"hp": 8,
			"mp": 5,
			"level": 2,
		},
	}), "整树替换应通过 diff 生成变更。")

	assert_true(changed_paths.has("player.hp"), "diff 应报告嵌套数值变化。")
	assert_true(changed_paths.has("player.level"), "diff 应报告嵌套新增字段。")


func test_set_state_emits_root_replacement_when_diff_truncates() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"items": {
			"a": 1,
			"b": 2,
		},
	})
	var received_changes: Array[Dictionary] = []
	var _unsubscribe: Callable = store.subscribe("items", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		received_changes.append(change)
	, {
		"mode": GFReactiveStateStoreBase.SUBSCRIBE_PREFIX,
	})

	assert_true(store.set_state({
		"items": {
			"a": 10,
			"b": 20,
			"c": 30,
		},
	}, {
		"max_changes": 1,
	}), "diff 截断时整树替换仍应报告变化。")

	assert_eq(received_changes.size(), 1, "根级替换应通知前缀订阅者一次。")
	assert_eq(GFVariantData.get_option_string(received_changes[0], "kind"), "state_replaced", "截断 diff 应降级为整树替换变更。")
	assert_eq(GFVariantData.get_option_string(received_changes[0], "path"), "", "整树替换应使用空路径。")
	assert_eq(GFVariantData.to_int(store.get_value("items.c")), 30, "状态本身应完成替换。")


func test_batch_coalesces_repeated_path_and_flushes_once() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"score": 0,
	})
	var received: Array[int] = []
	var _unsubscribe: Callable = store.subscribe("score", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		received.append(GFVariantData.to_int(GFVariantData.get_option_value(change, "new_value")))
	)
	watch_signals(store)

	store.begin_batch()
	var _first_result: Variant = store.set_value("score", 1)
	var _second_result: Variant = store.set_value("score", 2)
	assert_eq(store.get_dirty_changes().size(), 1, "同一路径在同一批次中应合并为一条 dirty change。")
	var flushed: Array[Dictionary] = store.end_batch()

	assert_eq(flushed.size(), 1, "批次结束应只派发合并后的变更。")
	assert_eq(received, [2], "订阅者应收到最终值。")
	assert_signal_emit_count(store, "state_changed", 1)


func test_batch_notifies_subscribers_once_per_matching_change() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"stats": {
			"hp": 10,
			"mp": 5,
		},
	})
	var paths: Array[String] = []
	var _unsubscribe: Callable = store.subscribe("stats", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		paths.append(GFVariantData.get_option_string(change, "path"))
	, {
		"mode": GFReactiveStateStoreBase.SUBSCRIBE_PREFIX,
	})
	watch_signals(store)

	store.begin_batch()
	var _hp_result: Variant = store.set_value("stats.hp", 8)
	var _mp_result: Variant = store.set_value("stats.mp", 3)
	var flushed: Array[Dictionary] = store.end_batch()

	assert_eq(flushed.size(), 2, "不同路径在同一批次中应保留为两条 dirty change。")
	assert_eq(paths, ["stats.hp", "stats.mp"], "订阅者每个匹配变更只应收到一次，不应重复收到整批 changes。")
	assert_signal_emit_count(store, "state_changed", 1)
	assert_signal_emit_count(store, "path_changed", 2)


func test_batch_identity_distinguishes_colliding_display_paths() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"profile.name": "flat",
		"profile": { "name": "nested" },
		"items[1]": "flat-index",
		"items": ["zero", "nested-index"],
	})
	store.begin_batch()
	assert_true(store.set_value([&"profile.name"], "flat-updated"), "平铺点号 key 应可更新。")
	assert_true(store.set_value([&"profile", &"name"], "nested-updated"), "嵌套 key 应可更新。")
	assert_true(store.set_value([&"items[1]"], "flat-index-updated"), "平铺索引文本 key 应可更新。")
	assert_true(store.set_value([&"items", 1], "nested-index-updated"), "数组索引路径应可更新。")

	var changes: Array[Dictionary] = store.end_batch()

	assert_eq(changes.size(), 4, "显示文本相同但结构化路径不同的变更不得合并。")
	assert_eq(GFVariantData.get_option_array(changes[0], "path_segments"), [&"profile.name"], "第一条应保留平铺点号路径。")
	assert_eq(GFVariantData.get_option_array(changes[1], "path_segments"), [&"profile", &"name"], "第二条应保留嵌套路径。")
	assert_eq(GFVariantData.get_option_array(changes[2], "path_segments"), [&"items[1]"], "第三条应保留平铺索引文本路径。")
	assert_eq(GFVariantData.get_option_array(changes[3], "path_segments"), [&"items", 1], "第四条应保留数组索引路径。")


func test_flush_sends_isolated_change_copies_to_subscribers() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"count": 0,
	})
	var observed_paths: Array[String] = []
	var _first_unsubscribe: Callable = store.subscribe("count", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		change["path"] = "corrupted"
	)
	var _second_unsubscribe: Callable = store.subscribe("count", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		observed_paths.append(GFVariantData.get_option_string(change, "path"))
	)

	var _set_result: Variant = store.set_value("count", 1)

	assert_eq(observed_paths, ["count"], "一个订阅者修改 change 不应污染后续订阅者。")


func test_subscribe_unsubscribe_and_emit_current() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"enabled": true,
	})
	var values: Array[bool] = []

	var unsubscribe: Callable = store.subscribe("enabled", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		values.append(GFVariantData.to_bool(GFVariantData.get_option_value(change, "new_value")))
	, {
		"emit_current": true,
	})
	var _set_false_result: Variant = store.set_value("enabled", false)
	var _unsubscribe_result: Variant = unsubscribe.call()
	var _set_true_result: Variant = store.set_value("enabled", true)

	assert_eq(values, [true, false], "emit_current 应先推送当前值，取消后不再接收变更。")
	assert_eq(store.get_subscription_count(), 0, "取消订阅后不应残留订阅。")


func test_duplicate_subscriptions_are_independent_handles() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"count": 0,
	})
	var calls: Array[String] = []
	var callback: Callable = func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		calls.append(GFVariantData.get_option_string(change, "path"))

	var unsubscribe_first: Callable = store.subscribe("count", callback)
	var unsubscribe_second: Callable = store.subscribe("count", callback)

	assert_eq(store.get_subscription_count(), 2, "重复订阅同一 callback 应产生两个独立订阅句柄。")
	var _first_result: Variant = store.set_value("count", 1)
	unsubscribe_first.call()
	var _second_result: Variant = store.set_value("count", 2)
	unsubscribe_second.call()
	var _third_result: Variant = store.set_value("count", 3)

	assert_eq(calls, ["count", "count", "count"], "取消一个句柄不应影响同 callback 的另一个订阅。")
	assert_eq(store.get_subscription_count(), 0, "两个句柄都取消后不应残留订阅。")


func test_unsubscribe_during_flush_stops_remaining_batch_callbacks() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"stats": {
			"hp": 10,
			"mp": 5,
		},
	})
	var paths: Array[String] = []
	var unsubscribe_holder: Array[Callable] = []
	unsubscribe_holder.append(store.subscribe("stats", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		paths.append(GFVariantData.get_option_string(change, "path"))
		var _unsubscribe_result: Variant = unsubscribe_holder[0].call()
	, {
		"mode": GFReactiveStateStoreBase.SUBSCRIBE_PREFIX,
	}))

	store.begin_batch()
	var _hp_result: Variant = store.set_value("stats.hp", 8)
	var _mp_result: Variant = store.set_value("stats.mp", 2)
	var _flush_result: Array[Dictionary] = store.end_batch()

	assert_eq(paths.size(), 1, "订阅在 flush 中取消后，不应继续接收同批次剩余变更。")
	assert_eq(store.get_subscription_count(), 0, "flush 中取消订阅后不应残留订阅。")


func test_nested_write_during_flush_is_dispatched_after_current_subscriber_batch() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"source": 0,
		"derived": 0,
	})
	var events: Array[String] = []
	var _first_unsubscribe: Callable = store.subscribe("source", func(change: Dictionary, target_store: GFReactiveStateStoreBase) -> void:
		events.append("first:%s" % GFVariantData.get_option_string(change, "path"))
		var _nested_result: Variant = target_store.set_value("derived", 2)
	)
	var _second_unsubscribe: Callable = store.subscribe("source", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		events.append("second:%s" % GFVariantData.get_option_string(change, "path"))
	)
	var _derived_unsubscribe: Callable = store.subscribe("derived", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		events.append("derived:%s" % GFVariantData.get_option_string(change, "path"))
	)
	var _state_changed_connected: Variant = store.state_changed.connect(func(changes: Array[Dictionary], _snapshot: Dictionary) -> void:
		events.append("state:%s" % _format_change_paths(changes))
	)
	var _path_changed_connected: Variant = store.path_changed.connect(func(path: String, _change: Dictionary) -> void:
		events.append("path:%s" % path)
	)

	var changed: bool = store.set_value("source", 1)

	assert_true(changed, "嵌套写入测试应触发初始变更。")
	assert_eq(
		events,
		[
			"state:source",
			"path:source",
			"first:source",
			"second:source",
			"state:derived",
			"path:derived",
			"derived:derived",
		],
		"flush 期间的新 dirty 应等当前订阅者批次结束后再派发。"
	)
	assert_eq(GFVariantData.to_int(store.get_value("derived")), 2, "嵌套写入应更新状态。")
	assert_true(store.get_dirty_changes().is_empty(), "嵌套 flush drain 完成后 dirty queue 应清空。")


func test_owner_tree_exit_auto_unsubscribes() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"count": 0,
	})
	var subscription_owner: Node = Node.new()
	var received_count: Counter = Counter.new()
	add_child(subscription_owner)

	var _unsubscribe: Callable = store.subscribe("count", func(_change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		received_count.value += 1
	, {
		"owner": subscription_owner,
	})

	var _first_result: Variant = store.set_value("count", 1)
	remove_child(subscription_owner)
	subscription_owner.tree_exited.emit()
	var _second_result: Variant = store.set_value("count", 2)

	assert_eq(received_count.value, 1, "owner 退出树后订阅不应继续触发。")
	assert_eq(store.get_subscription_count(), 0, "owner 自动解绑后不应残留订阅。")
	subscription_owner.free()


func test_ref_counted_owner_is_pruned_when_released() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"count": 0,
	})
	var subscription_owner: RefCounted = RefCounted.new()
	var received_count: Counter = Counter.new()

	var _unsubscribe: Callable = store.subscribe("count", func(_change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		received_count.value += 1
	, {
		"owner": subscription_owner,
	})
	assert_eq(store.get_subscription_count(), 1, "RefCounted owner 存活时订阅应有效。")

	subscription_owner = null
	assert_eq(store.get_subscription_count(), 0, "RefCounted owner 释放后应由懒清理移除订阅。")
	var _set_result: Variant = store.set_value("count", 1)

	assert_eq(received_count.value, 0, "owner 释放后的订阅不应再收到变更。")


func test_erase_value_reports_removed_change() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"inventory": {
			"slot": "potion",
		},
	})
	var received: Array[Dictionary] = []
	var _unsubscribe: Callable = store.subscribe("inventory.slot", func(change: Dictionary, _store: GFReactiveStateStoreBase) -> void:
		received.append(change)
	)

	assert_true(store.erase_value("inventory.slot"), "删除已存在路径应成功。")

	assert_false(store.has_value("inventory.slot"), "删除后路径应不存在。")
	assert_eq(GFVariantData.get_option_string(received[0], "kind"), "removed", "删除应派发 removed 变更。")
	assert_false(GFVariantData.get_option_bool(received[0], "new_exists", true), "removed 变更应标记 new_exists=false。")


# --- 私有/辅助方法 ---

func _find_signal_change(store: GFReactiveStateStoreBase, signal_name: String, path: String) -> Dictionary:
	var parameters: Array = get_signal_parameters(store, signal_name)
	if parameters.size() < 2:
		return {}
	var change: Dictionary = GFVariantData.as_dictionary(parameters[1])
	if GFVariantData.get_option_string(change, "path") == path:
		return change
	return {}


func _format_change_paths(changes: Array[Dictionary]) -> String:
	var paths: PackedStringArray = PackedStringArray()
	for change: Dictionary in changes:
		var _path_appended: bool = paths.append(GFVariantData.get_option_string(change, "path"))
	return ",".join(paths)


# --- 内部类 ---

class Counter:
	var value: int = 0
