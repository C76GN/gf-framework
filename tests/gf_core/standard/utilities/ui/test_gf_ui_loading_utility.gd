extends GutTest


var _utility: GFUILoadingUtility
var _clock: GFManualClock


func before_each() -> void:
	_clock = GFManualClock.new()
	_utility = GFUILoadingUtility.new()
	assert_true(
		_utility.configure(
			100,
			200,
			_clock
		)
	)


func after_each() -> void:
	_utility.dispose()
	_utility = null
	_clock = null


func test_acquire_diagnostics_do_not_allocate_connect_or_publish() -> void:
	var lifetime_owner: Node = Node.new()
	add_child(lifetime_owner)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var connections: int = lifetime_owner.get_signal_connection_list(&"tree_exiting").size()
	var before: Dictionary = _utility.get_state()
	watch_signals(_utility)
	var report: Dictionary = _utility.validate_acquire(lifetime_owner, scope)
	assert_eq(
		report,
		{
			"ok": true,
			"error_kind": "",
			"path": "",
		}
	)
	assert_eq(
		lifetime_owner.get_signal_connection_list(&"tree_exiting").size(),
		connections
	)
	assert_eq(
		_utility.get_state(),
		before
	)
	assert_signal_not_emitted(_utility, "state_changed")
	scope.complete()
	assert_eq(
		GFVariantData.get_option_string(
			_utility.validate_acquire(lifetime_owner, scope),
			"error_kind"
		),
		"scope_inactive"
	)
	report["ok"] = true
	assert_null(_utility.acquire(lifetime_owner, scope))
	remove_child(lifetime_owner)
	assert_eq(
		GFVariantData.get_option_string(
			_utility.validate_acquire(lifetime_owner),
			"error_kind"
		),
		"owner_outside_tree"
	)
	lifetime_owner.free()
	var lifetime_object: RefCounted = RefCounted.new()
	var weak_owner: WeakRef = weakref(lifetime_object)
	assert_true(
		GFVariantData.get_option_bool(
			_utility.validate_acquire(lifetime_object),
			"ok"
		)
	)
	lifetime_object = null
	var released_owner: Object = weak_owner.get_ref()
	assert_null(released_owner)
	var lease: GFUILoadingLease = _utility.acquire()
	assert_eq(
		lease.get_id(),
		1
	)
	assert_true(lease.release())


func test_acquire_diagnostics_report_capacity_without_consuming_an_identity() -> void:
	var last: GFUILoadingLease
	for _index: int in range(4096):
		last = _utility.acquire()
		if last == null:
			fail_test("容量测试在公开上限前被拒绝。")
			return
	var before: Dictionary = _utility.get_state()
	var report: Dictionary = _utility.validate_acquire()
	assert_eq(
		GFVariantData.get_option_string(report, "error_kind"),
		"lease_limit"
	)
	assert_eq(
		GFVariantData.get_option_int(report, "limit"),
		4096
	)
	assert_eq(
		GFVariantData.get_option_int(report, "observed"),
		4097
	)
	assert_eq(
		_utility.get_state(),
		before
	)
	report["ok"] = true
	assert_null(_utility.acquire())
	assert_true(last.release())
	var next: GFUILoadingLease = _utility.acquire()
	assert_eq(
		next.get_id(),
		4097
	)
	_utility.dispose()
	assert_eq(
		GFVariantData.get_option_string(
			_utility.validate_acquire(),
			"error_kind"
		),
		"service_disposed"
	)


func test_concurrent_leases_release_independently_and_display_does_not_delay_completion() -> void:
	var first: GFUILoadingLease = _utility.acquire()
	var second: GFUILoadingLease = _utility.acquire()
	assert_ne(
		first.get_id(),
		second.get_id()
	)
	assert_false(_visible())
	_advance(100)
	assert_true(_visible())
	assert_true(first.release())
	assert_false(first.release())
	assert_eq(
		_pending(),
		1
	)
	assert_true(second.release())
	assert_false(second.is_active())
	assert_eq(
		_pending(),
		0
	)
	assert_true(
		_visible(),
		"最短显示只保留反馈，不保留业务请求。"
	)
	_advance(199)
	assert_true(_visible())
	_advance(1)
	assert_false(_visible())


func test_fast_requests_never_flash_and_new_wait_gets_own_delay() -> void:
	var first: GFUILoadingLease = _utility.acquire()
	_advance(99)
	assert_true(first.release())
	_advance(1000)
	assert_false(_visible())
	var next: GFUILoadingLease = _utility.acquire()
	_advance(99)
	assert_false(_visible())
	_advance(1)
	assert_true(_visible())
	assert_true(next.release())


func test_node_exit_scope_cancel_and_scope_complete_release_only_owned_requests() -> void:
	var lifetime_owner: Node = Node.new()
	add_child(lifetime_owner)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var owner_lease: GFUILoadingLease = _utility.acquire(lifetime_owner)
	var scoped: GFUILoadingLease = _utility.acquire(null, scope)
	var independent: GFUILoadingLease = _utility.acquire()
	remove_child(lifetime_owner)
	lifetime_owner.free()
	assert_false(owner_lease.is_active())
	assert_eq(
		_pending(),
		2
	)
	assert_true(scope.cancel("closed"))
	assert_false(scoped.is_active())
	assert_eq(
		_pending(),
		1
	)
	var completed_scope: GFAsyncScope = GFAsyncScope.new()
	var completed: GFUILoadingLease = _utility.acquire(null, completed_scope)
	completed_scope.complete()
	_utility.tick(0.0)
	assert_false(completed.is_active())
	assert_true(independent.release())


func test_weak_owners_and_scopes_do_not_leak_or_keep_waits_alive() -> void:
	var lifetime_owner: RefCounted = RefCounted.new()
	var scope: GFAsyncScope = GFAsyncScope.new()
	var owned: GFUILoadingLease = _utility.acquire(lifetime_owner)
	var scoped: GFUILoadingLease = _utility.acquire(null, scope)
	lifetime_owner = null
	scope = null
	_utility.tick(0.0)
	assert_false(owned.is_active())
	assert_false(scoped.is_active())
	assert_eq(
		_pending(),
		0
	)


func test_progress_is_sampled_and_missing_progress_remains_indeterminate() -> void:
	var progress: GFAsyncProgress = GFAsyncProgress.new(0.25)
	var known: GFUILoadingLease = _utility.acquire(
		null,
		null,
		progress
	)
	var unknown: GFUILoadingLease = _utility.acquire()
	assert_eq(
		GFVariantData.get_option_int(
			_utility.get_state(),
			"indeterminate_count"
		),
		1
	)
	assert_eq(
		GFVariantData.get_option_float(
			_utility.get_state(),
			"progress"
		),
		0.25
	)
	var _updated: bool = progress.complete()
	_utility.tick(0.0)
	assert_true(
		known.is_active(),
		"进度 1 不等于业务结束。"
	)
	assert_eq(
		GFVariantData.get_option_float(
			_utility.get_state(),
			"progress"
		),
		1.0
	)
	assert_true(unknown.release())
	assert_true(known.release())


func test_dispose_and_foreign_lease_cannot_affect_other_service() -> void:
	var other: GFUILoadingUtility = GFUILoadingUtility.new()
	var local: GFUILoadingLease = _utility.acquire()
	var foreign: GFUILoadingLease = other.acquire()
	assert_false(_utility.release_for_framework(foreign))
	assert_true(local.is_active())
	_advance(100)
	_utility.dispose()
	assert_false(_visible())
	assert_false(local.is_active())
	assert_false(local.release())
	assert_true(foreign.is_active())
	assert_null(_utility.acquire())
	other.dispose()


func test_invalid_lifetimes_and_reconfiguration_are_rejected() -> void:
	var node: Node = Node.new()
	assert_null(_utility.acquire(node))
	node.free()
	var scope: GFAsyncScope = GFAsyncScope.new()
	scope.complete()
	assert_null(_utility.acquire(null, scope))
	assert_false(_utility.configure())
	assert_eq(
		_pending(),
		0
	)


func test_scope_cancel_in_first_listener_leaves_later_listener_current() -> void:
	var utility: GFUILoadingUtility = GFUILoadingUtility.new()
	assert_true(
		utility.configure(
			0,
			0,
			_clock
		)
	)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var observed: Array[Dictionary] = []
	var cancel: Callable = func(state: Dictionary) -> void:
		if state["pending_count"] == 1:
			var _cancelled: bool = scope.cancel("listener")
	var observe: Callable = func(state: Dictionary) -> void:
		observed.append(state)
	var _first: int = utility.state_changed.connect(cancel)
	var _second: int = utility.state_changed.connect(observe)
	var lease: GFUILoadingLease = utility.acquire(null, scope)
	assert_false(lease.is_active())
	assert_eq(
		observed.size(),
		2
	)
	assert_eq(
		observed[-1],
		utility.get_state()
	)
	utility.dispose()


func test_feedback_is_bounded_and_tick_publishes_latest_state() -> void:
	var utility: GFUILoadingUtility = GFUILoadingUtility.new()
	assert_true(
		utility.configure(
			0,
			0,
			_clock
		)
	)
	var counts: Array[int] = []
	var feedback: Callable = func(state: Dictionary) -> void:
		if state["pending_count"] > 0 and state["pending_count"] < 260:
			var _feedback_lease: GFUILoadingLease = utility.acquire()
	var observe: Callable = func(state: Dictionary) -> void:
		counts.append(state["pending_count"])
	var _first: int = utility.state_changed.connect(feedback)
	var _second: int = utility.state_changed.connect(observe)
	var _initial_lease: GFUILoadingLease = utility.acquire()
	assert_eq(
		counts.size(),
		256
	)
	assert_eq(
		GFVariantData.get_option_int(
			utility.get_state(),
			"pending_count"
		),
		257
	)
	utility.tick(0.0)
	assert_eq(
		counts[-1],
		260
	)
	assert_eq(
		GFVariantData.get_option_int(
			utility.get_state(),
			"pending_count"
		),
		260
	)
	utility.dispose()
	assert_eq(
		counts[-1],
		0
	)
	utility.state_changed.disconnect(feedback)
	utility.state_changed.disconnect(observe)


func _advance(msec: int) -> void:
	assert_true(_clock.advance_msec(msec))
	_utility.tick(0.0)


func _visible() -> bool:
	return GFVariantData.get_option_bool(
		_utility.get_state(),
		"visible"
	)


func _pending() -> int:
	return GFVariantData.get_option_int(
		_utility.get_state(),
		"pending_count"
	)
