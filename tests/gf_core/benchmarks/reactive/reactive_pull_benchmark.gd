extends SceneTree


const VIEWS: int = 24
const FRAMES: int = 1200
const SAMPLES: int = 9
const WARMUP_FRAMES: int = 120
const ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# Private pull-only view. It deliberately has no eager value_changed contract.
class PullCache extends RefCounted:
	var _effect: GFReactiveEffect
	var _compute: Callable
	var _cache: Variant = null
	var _dirty: bool = true
	var _disposed: bool = false
	var _running: bool = false
	var _epoch: int = 0
	var _owner_ref: WeakRef
	var invalidations: int = 0
	var rejected_computes: int = 0

	func configure(sources: Array[GFBindableProperty], callback: Callable, owner: Node = null) -> void:
		_compute = callback
		_owner_ref = weakref(owner) if owner != null else null
		_effect = GFReactiveEffect.new(sources, _invalidate, owner, false)
		if owner != null:
			var _connected: Error = owner.tree_exited.connect(dispose, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error

	func _invalidate() -> Variant:
		_epoch += 1
		invalidations += 1
		_dirty = true
		return null

	func get_value() -> Variant:
		if _disposed or _running:
			return null
		if _dirty:
			var epoch: int = _epoch
			_running = true
			_dirty = false
			var computed: Variant = _compute.call()
			_running = false
			if _disposed or epoch != _epoch:
				_dirty = true
				rejected_computes += 1
				return null
			_cache = computed
		return ACCESS.duplicate_collection(_cache, true)

	func dispose() -> void:
		if _disposed:
			return
		_disposed = true
		if _effect != null:
			_effect.dispose()
			_effect = null
		if _owner_ref != null:
			var raw_owner: Variant = _owner_ref.get_ref()
			if raw_owner is Node:
				var owner: Node = raw_owner
				if is_instance_valid(owner) and owner.tree_exited.is_connected(dispose):
					owner.tree_exited.disconnect(dispose)
		_compute = Callable()
		_owner_ref = null
		_cache = null


# Explicit dependency switching, not automatic read tracking or a graph engine.
class BranchCache extends PullCache:
	var _selector: GFBindableProperty
	var _left: GFBindableProperty
	var _right: GFBindableProperty
	var rebinds: int = 0

	func configure_branch(
		selector: GFBindableProperty, left: GFBindableProperty,
		right: GFBindableProperty, callback: Callable
	) -> void:
		_selector = selector
		_left = left
		_right = right
		_compute = callback
		_effect = GFReactiveEffect.new()
		var _connected: Error = _selector.value_changed.connect(_on_selection_changed) as Error
		_bind_active_source()

	func _bind_active_source() -> void:
		var selected: Variant = _selector.get_value()
		var source: GFBindableProperty = _right if selected == true else _left
		_effect.configure([source], _invalidate, null, false)
		rebinds += 1

	func _on_selection_changed(_old: Variant, _new: Variant) -> void:
		var _invalidated: Variant = _invalidate()
		_bind_active_source()

	func dispose() -> void:
		if _selector != null and _selector.value_changed.is_connected(_on_selection_changed):
			_selector.value_changed.disconnect(_on_selection_changed)
		super.dispose()
		_selector = null
		_left = null
		_right = null


class Formula extends RefCounted:
	var left: GFBindableProperty
	var right: GFBindableProperty
	var selector: GFBindableProperty
	var iterations: int = 1
	var offset: int = 0
	var computes: int = 0

	func evaluate() -> Variant:
		computes += 1
		var selected: Variant = selector.get_value()
		var raw: Variant = right.get_value() if selected == true else left.get_value()
		var scalar: int = raw if raw is int else 0
		var result: int = scalar + offset
		for iteration: int in range(iterations):
			result = (result * 31 + iteration) % 1000003
		return result


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_check(args.size() == 2, "Expected workload and mode.")
	if args.size() != 2:
		return
	var workload: String = args[0]
	var mode: String = args[1]
	_check(workload in ["sparse_expensive", "cheap_every_frame", "branch_view", "correctness"], "Unknown workload.")
	_check(mode in ["eager", "static_pull", "branch_pull"], "Unknown mode.")
	if workload == "correctness":
		_run_correctness()
		return
	var _warmup: Dictionary = _sample(workload, mode, WARMUP_FRAMES)
	var samples: Array[Dictionary] = []
	for _sample_index: int in range(SAMPLES):
		samples.append(_sample(workload, mode, FRAMES))
	print("GF_REACTIVE_RESULT=" + JSON.stringify({
		"workload": workload, "mode": mode, "views": VIEWS,
		"frames": FRAMES, "samples": samples,
		"user_data_dir": OS.get_user_data_dir(), "godot": Engine.get_version_info(),
		"time_metric": "monotonic active elapsed usec; process CPU measured separately",
	}))
	quit(0)


func _sample(workload: String, mode: String, frames: int) -> Dictionary:
	var selector: GFBindableProperty = GFBindableProperty.new(false)
	var left: GFBindableProperty = GFBindableProperty.new(0)
	var right: GFBindableProperty = GFBindableProperty.new(0)
	var formulas: Array[Formula] = []
	var eager_views: Array[GFComputedProperty] = []
	var pull_views: Array[PullCache] = []
	var frame_times: Array[int] = []
	var read_times: Array[int] = []
	var checksum: int = 0
	var subscription_peak: int = 0
	for index: int in range(VIEWS):
		var formula: Formula = Formula.new()
		formula.left = left
		formula.right = right
		formula.selector = selector
		formula.offset = index
		formula.iterations = 1 if workload == "cheap_every_frame" else 256
		formulas.append(formula)
		var sources: Array[GFBindableProperty] = [left]
		if workload == "branch_view":
			sources = [selector, left, right]
		if mode == "eager":
			eager_views.append(GFComputedProperty.new(sources, formula.evaluate))
		elif mode == "branch_pull":
			var branch: BranchCache = BranchCache.new()
			branch.configure_branch(selector, left, right, formula.evaluate)
			pull_views.append(branch)
		else:
			var cache: PullCache = PullCache.new()
			cache.configure(sources, formula.evaluate)
			pull_views.append(cache)
	var started: int = Time.get_ticks_usec()
	for frame: int in range(frames):
		var frame_started: int = Time.get_ticks_usec()
		if workload == "branch_view":
			if frame % 120 == 0:
				selector.set_value(frame % 240 == 120)
			var selected: Variant = selector.get_value()
			var active: GFBindableProperty = right if selected == true else left
			var inactive: GFBindableProperty = left if selected == true else right
			if frame % 60 == 0:
				active.set_value(frame + 1)
			if frame % 3 == 0:
				inactive.set_value(frame + 7)
		elif workload == "cheap_every_frame" or frame % 3 == 0:
			left.set_value(frame + 1)
		var should_read: bool = workload != "sparse_expensive" or frame % 60 == 0
		if should_read:
			var read_started: int = Time.get_ticks_usec()
			for index: int in range(VIEWS):
				var raw: Variant = eager_views[index].get_value() if mode == "eager" else pull_views[index].get_value()
				_check(raw is int, "A pure computation must return a scalar.")
				if raw is int:
					checksum += raw
			read_times.append(Time.get_ticks_usec() - read_started)
		frame_times.append(Time.get_ticks_usec() - frame_started)
	var active_usec: int = Time.get_ticks_usec() - started
	subscription_peak = selector.value_changed.get_connections().size() + left.value_changed.get_connections().size() + right.value_changed.get_connections().size()
	var computes: int = 0
	var invalidations: int = 0
	var rebinds: int = 0
	for formula: Formula in formulas:
		computes += formula.computes
	for view: GFComputedProperty in eager_views:
		view.dispose()
	for cache: PullCache in pull_views:
		invalidations += cache.invalidations
		if cache is BranchCache:
			var branch: BranchCache = cache
			rebinds += branch.rebinds
		cache.dispose()
	var remaining_subscriptions: int = selector.value_changed.get_connections().size() + left.value_changed.get_connections().size() + right.value_changed.get_connections().size()
	_check(remaining_subscriptions == 0, "Disposed views must release every source subscription.")
	frame_times.sort()
	read_times.sort()
	return {
		"active_usec": active_usec, "frame_p95_usec": frame_times[ceili(frame_times.size() * 0.95) - 1],
		"read_p95_usec": read_times[ceili(read_times.size() * 0.95) - 1],
		"computes": computes, "invalidations": invalidations, "rebinds": rebinds,
		"checksum": checksum, "subscription_peak": subscription_peak,
		"remaining_subscriptions": remaining_subscriptions,
	}


func _run_correctness() -> void:
	var source: GFBindableProperty = GFBindableProperty.new(1)
	var runs: Array[int] = [0]
	var cache: PullCache = PullCache.new()
	cache.configure([source, source], func() -> Variant:
		runs[0] += 1
		return [{"value": source.get_value()}]
	)
	source.set_value(2)
	source.set_value(3)
	_check(runs[0] == 0, "Writes must not evaluate pull-only views.")
	var first_raw: Variant = cache.get_value()
	_check(first_raw is Array, "Collection compute result.")
	if first_raw is Array:
		var first: Array = first_raw
		first.clear()
	var second_raw: Variant = cache.get_value()
	_check(second_raw is Array and runs[0] == 1, "A read uses isolated cache data without recomputation.")
	if second_raw is Array:
		var second: Array = second_raw
		_check(second.size() == 1, "Caller mutation cannot change the cached collection.")
	_check(source.value_changed.get_connections().size() == 1, "Explicit sources are deduplicated.")
	cache.dispose()
	cache.dispose()
	_check(source.value_changed.get_connections().is_empty(), "Disposal is idempotent and releases sources.")
	_check(cache.get_value() == null, "Disposed pull view rejects reads.")
	var owner: Node = Node.new()
	root.add_child(owner)
	var owned: PullCache = PullCache.new()
	owned.configure([source], func() -> Variant: return source.get_value(), owner)
	root.remove_child(owner)
	_check(source.value_changed.get_connections().is_empty(), "Owner exit releases pull subscriptions.")
	_check(owned.get_value() == null, "Owner exit closes future reads.")
	owner.free()
	var reentrant: PullCache = PullCache.new()
	var mutated: Array[bool] = [false]
	reentrant.configure([source], func() -> Variant:
		if not mutated[0]:
			mutated[0] = true
			source.set_value(4)
		return source.get_value()
	)
	_check(reentrant.get_value() == null, "Compute invalidated by a callback cannot publish a stale cache.")
	var reentrant_raw: Variant = reentrant.get_value()
	var reentrant_value: int = -1
	if reentrant_raw is int:
		reentrant_value = reentrant_raw
	_check(reentrant_raw is int and reentrant_value == 4, "A later pull computes the current epoch.")
	_check(reentrant.rejected_computes == 1, "Reentry is bounded to one callback per read.")
	reentrant.dispose()
	var selector: GFBindableProperty = GFBindableProperty.new(false)
	var left: GFBindableProperty = GFBindableProperty.new(10)
	var right: GFBindableProperty = GFBindableProperty.new(20)
	var branch: BranchCache = BranchCache.new()
	branch.configure_branch(selector, left, right, func() -> Variant:
		return right.get_value() if selector.get_value() == true else left.get_value()
	)
	var initial_branch_raw: Variant = branch.get_value()
	var initial_branch_value: int = -1
	if initial_branch_raw is int:
		initial_branch_value = initial_branch_raw
	_check(initial_branch_raw is int and initial_branch_value == 10, "Initial explicit branch.")
	right.set_value(21)
	_check(not branch._dirty, "Inactive branch writes do not invalidate the view.")
	selector.set_value(true)
	var switched_branch_raw: Variant = branch.get_value()
	var switched_branch_value: int = -1
	if switched_branch_raw is int:
		switched_branch_value = switched_branch_raw
	_check(switched_branch_raw is int and switched_branch_value == 21, "Branch switch captures the new active value.")
	_check(left.value_changed.get_connections().is_empty(), "Branch rebind releases the inactive source.")
	branch.dispose()
	_check(selector.value_changed.get_connections().is_empty() and right.value_changed.get_connections().is_empty(), "Branch disposal releases selector and active source.")
	print("GF_REACTIVE_RESULT=" + JSON.stringify({"workload": "correctness", "ok": true, "checks": 17, "user_data_dir": OS.get_user_data_dir()}))
	quit(0)
