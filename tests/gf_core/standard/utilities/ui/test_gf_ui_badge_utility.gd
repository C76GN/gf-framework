extends GutTest


var _utility: GFUIBadgeUtility


func before_each() -> void:
	_utility = GFUIBadgeUtility.new()


func after_each() -> void:
	_utility.dispose()
	_utility = null


func test_configuration_diagnostics_are_read_only_and_do_not_reserve_configuration() -> void:
	var parents: Dictionary = { "root": "", "leaf": "root" }
	watch_signals(_utility)
	var report: Dictionary = _utility.validate_configuration(parents)
	assert_eq(
		report,
		{
			"ok": true,
			"error_kind": "",
			"path": "",
		}
	)
	assert_eq(
		_utility.get_count(&"root"),
		-1
	)
	assert_signal_not_emitted(_utility, "counts_changed")
	parents["root"] = "leaf"
	var cycle: Dictionary = _utility.validate_configuration(parents)
	assert_eq(
		GFVariantData.get_option_string(cycle, "error_kind"),
		"cycle"
	)
	report["ok"] = true
	assert_false(_utility.configure(parents))
	assert_eq(
		_utility.get_count(&"root"),
		-1
	)
	parents["root"] = ""
	assert_true(_utility.configure(parents))
	assert_eq(
		_utility.get_count(&"root"),
		0
	)
	var configured: Dictionary = _utility.validate_configuration(parents)
	assert_eq(
		GFVariantData.get_option_string(configured, "error_kind"),
		"already_configured"
	)
	_utility.dispose()
	assert_eq(
		GFVariantData.get_option_string(
			_utility.validate_configuration(parents),
			"error_kind"
		),
		"service_disposed"
	)


func test_configuration_diagnostics_report_missing_parent_and_real_limits() -> void:
	var missing: Dictionary = _utility.validate_configuration({ "a/b~c": "missing" })
	assert_eq(
		GFVariantData.get_option_string(missing, "error_kind"),
		"missing_parent"
	)
	assert_eq(
		GFVariantData.get_option_string(missing, "path"),
		"/parents/a~1b~0c"
	)
	var invalid: Dictionary = _utility.validate_configuration({ 1: "" })
	assert_eq(
		GFVariantData.get_option_string(invalid, "error_kind"),
		"invalid_type"
	)
	var deep: Dictionary = {}
	for index: int in range(65):
		deep[str(index)] = str(index - 1) if index > 0 else ""
	var depth: Dictionary = _utility.validate_configuration(deep)
	assert_eq(
		GFVariantData.get_option_string(depth, "error_kind"),
		"depth_limit"
	)
	assert_eq(
		GFVariantData.get_option_int(depth, "limit"),
		64
	)
	assert_eq(
		GFVariantData.get_option_int(depth, "observed"),
		65
	)
	assert_true(GFVariantData.get_option_bool(depth, "observed_is_lower_bound"))
	var wide: Dictionary = {}
	for index: int in range(4097):
		wide[str(index)] = ""
	var capacity: Dictionary = _utility.validate_configuration(wide)
	assert_eq(
		GFVariantData.get_option_string(capacity, "error_kind"),
		"node_limit"
	)
	assert_eq(
		GFVariantData.get_option_int(capacity, "limit"),
		4096
	)
	assert_eq(
		GFVariantData.get_option_int(capacity, "observed"),
		4097
	)
	assert_true(_utility.configure({ "valid": "" }))


func test_tree_aggregates_only_leaf_changes_and_ignores_noop() -> void:
	assert_true(
		_utility.configure(
			{
				"root": "",
				"mail": "root",
				"quest": "root",
				"claim": "quest",
			}
		)
	)
	watch_signals(_utility)
	assert_true(_utility.set_leaf_count(&"mail", 3))
	assert_true(_utility.set_leaf_count(&"claim", 2))
	assert_eq(
		_utility.get_count(&"root"),
		5
	)
	assert_eq(
		_utility.get_count(&"quest"),
		2
	)
	assert_true(_utility.set_leaf_count(&"mail", 1))
	assert_eq(
		_utility.get_count(&"root"),
		3
	)
	assert_true(_utility.set_leaf_count(&"mail", 1))
	assert_signal_emit_count(
		_utility,
		"counts_changed",
		3
	)
	assert_false(_utility.set_leaf_count(&"root", 8))
	assert_false(_utility.set_leaf_count(&"mail", -1))
	assert_false(_utility.set_leaf_count(&"mail", 1000000001))
	assert_eq(
		_utility.get_count(&"unknown"),
		-1
	)
	assert_false(_utility.configure({ "new": "" }))


func test_invalid_graphs_are_atomic_and_do_not_consume_configuration() -> void:
	assert_false(_utility.configure({ "a": "b" }))
	assert_false(_utility.configure({ "a": "a" }))
	assert_false(_utility.configure({ "a": "b", "b": "a" }))
	assert_false(_utility.configure({ " a ": "" }))
	assert_false(_utility.configure({ 1: "" }))
	var deep: Dictionary = {}
	for index: int in range(65):
		deep[str(index)] = str(index - 1) if index > 0 else ""
	assert_false(_utility.configure(deep))
	assert_eq(
		_utility.get_count(&"a"),
		-1
	)
	assert_true(_utility.configure({ "a": "", "b": "" }))
	assert_true(_utility.set_leaf_count(&"a", 1000000000))
	assert_eq(
		_utility.get_count(&"b"),
		0
	)


func test_repeated_bindings_cancel_independently_and_node_exit_unbinds() -> void:
	assert_true(_utility.configure({ "root": "", "leaf": "root" }))
	var first_values: Array[int] = []
	var second_values: Array[int] = []
	var lifetime_owner: Node = Node.new()
	add_child(lifetime_owner)
	var first: GFSubscriptionToken = _utility.bind_count(
		&"root",
		func(value: int) -> void:
			first_values.append(value)
	)
	var second: GFSubscriptionToken = _utility.bind_count(
		&"root",
		func(value: int) -> void:
			second_values.append(value),
		lifetime_owner
	)
	assert_true(_utility.set_leaf_count(&"leaf", 1))
	assert_true(first.cancel())
	assert_false(first.cancel())
	assert_true(_utility.set_leaf_count(&"leaf", 2))
	remove_child(lifetime_owner)
	lifetime_owner.free()
	assert_false(second.is_active())
	assert_true(_utility.set_leaf_count(&"leaf", 3))
	assert_eq(
		first_values,
		[0, 1]
	)
	assert_eq(
		second_values,
		[
			0,
			1,
			2,
		]
	)


func test_reentrant_updates_are_delivered_in_commit_order() -> void:
	assert_true(_utility.configure({ "root": "", "leaf": "root" }))
	var first_values: Array[int] = []
	var second_values: Array[int] = []
	var first: GFSubscriptionToken = _utility.bind_count(
		&"root",
		func(value: int) -> void:
			first_values.append(value)
			if value == 1:
				var _updated: bool = _utility.set_leaf_count(&"leaf", 2)
	)
	var second: GFSubscriptionToken = _utility.bind_count(
		&"root",
		func(value: int) -> void:
			second_values.append(value)
	)
	assert_true(_utility.set_leaf_count(&"leaf", 1))
	assert_eq(
		first_values,
		[
			0,
			1,
			2,
		]
	)
	assert_eq(
		second_values,
		[
			0,
			1,
			2,
		]
	)
	assert_true(first.cancel())
	assert_true(second.cancel())


func test_weak_owner_cleanup_and_dispose_invalidate_tokens() -> void:
	assert_true(_utility.configure({ "leaf": "" }))
	var values: Array[int] = []
	var lifetime_owner: RefCounted = RefCounted.new()
	var owned: GFSubscriptionToken = _utility.bind_count(
		&"leaf",
		func(value: int) -> void:
			values.append(value),
		lifetime_owner
	)
	lifetime_owner = null
	_utility.tick(0.0)
	assert_false(owned.is_active())
	assert_true(_utility.set_leaf_count(&"leaf", 2))
	assert_eq(
		values,
		[0]
	)
	var independent: GFSubscriptionToken = _utility.bind_count(
		&"leaf",
		func(value: int) -> void:
			values.append(value)
	)
	_utility.dispose()
	assert_false(independent.is_active())
	assert_false(_utility.set_leaf_count(&"leaf", 3))
	assert_eq(
		_utility.get_count(&"leaf"),
		-1
	)


func test_bounded_feedback_defers_work_and_new_binding_skips_older_queued_values() -> void:
	assert_true(_utility.configure({ "leaf": "" }))
	var feedback: GFSubscriptionToken = _utility.bind_count(
		&"leaf",
		func(value: int) -> void:
			if value > 0 and value < 260:
				var _updated: bool = _utility.set_leaf_count(
					&"leaf",
					value + 1
				)
	)
	assert_true(_utility.set_leaf_count(&"leaf", 1))
	assert_eq(
		_utility.get_count(&"leaf"),
		257
	)
	var values: Array[int] = []
	var late: GFSubscriptionToken = _utility.bind_count(
		&"leaf",
		func(value: int) -> void:
			values.append(value)
	)
	_utility.tick(0.0)
	assert_eq(
		values,
		[
			257,
			258,
			259,
			260,
		]
	)
	assert_true(feedback.cancel())
	assert_true(late.cancel())
