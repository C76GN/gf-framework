extends RefCounted


const SERVICE: StringName = &"GfSegmentVisibilityBackend"
const BATCH: StringName = &"compute_pair_masks_v2"


static func check(expect_native: bool) -> Array[String]:
	var failures: Array[String] = []
	if (ClassDB.class_get_method_argument_count(SERVICE, BATCH, true) == 4) != expect_native:
		failures.append("Unexpected installed segment visibility capability.")
		return failures
	var ids: PackedInt64Array = PackedInt64Array([0, 1, 2, 3, 4])
	var points: Array[Vector2i] = [Vector2i.ZERO, Vector2i(0, 3), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 1)]
	var walls: Array[Dictionary] = [{"from": points[0], "to": points[1], "from_id": 0, "to_id": 1, "blocked_mask": 6}]
	var named: GFSegmentVisibility2D = GFSegmentVisibility2D.create(ids, points, walls, 7)
	var expected: PackedInt64Array = PackedInt64Array([1, 7, 7, 1, 7, 7, 1, 1, 1, 1])
	if named == null or named.compute_pair_masks().get("masks") != expected:
		failures.append("Incorrect named-contact or collinear-overlap masks.")
	walls.append({"from": points[0], "to": points[1]})
	var solid: GFSegmentVisibility2D = GFSegmentVisibility2D.create(ids, points, walls, 7)
	expected.fill(0)
	if solid == null or solid.compute_pair_masks().get("masks") != expected:
		failures.append("An anonymous solid at the same coordinates must block every pair.")
	var small_points: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
	var small_walls: Array[Dictionary] = [{"from": Vector2i.ZERO, "to": Vector2i.ZERO, "blocked_mask": 1}]
	var small: GFSegmentVisibility2D = GFSegmentVisibility2D.create(PackedInt64Array([-1, 9]), small_points, small_walls, 3)
	if small == null or small.compute_pair_masks() != {"ok": true, "error": &"", "backend": &"gdscript", "masks": PackedInt64Array([2])}:
		failures.append("Incorrect single-pair batch with a point obstacle.")
	var topology: GFSegmentVisibility2D = workload(14)
	if topology == null:
		failures.append("Could not prepare the bounded visibility workload.")
		return failures
	var main_backend: StringName = &"native" if expect_native else &"gdscript"
	var worker_native: bool = expect_native and OS.get_name() == "Windows" and Engine.get_architecture_name() == "x86_64"
	var worker_backend: StringName = &"native" if worker_native else &"gdscript"
	var masks: PackedInt64Array = scalar_masks(topology)
	if topology.compute_pair_masks() != _success(masks, main_backend):
		failures.append("Packed masks disagree with stable-ID scalar queries.")
	failures.append_array(_check_workers(worker_backend, masks))
	if expect_native:
		for xy: Variant in [PackedInt32Array([1]), PackedInt64Array([0, 0]), null]:
			var invalid: Variant = ClassDB.class_call_static(SERVICE, BATCH, xy, PackedInt32Array(), PackedInt64Array(), 7)
			if invalid != ERR_INVALID_PARAMETER:
				failures.append("Native visibility accepted malformed input.")
		var empty: Variant = ClassDB.class_call_static(SERVICE, BATCH, PackedInt32Array(), PackedInt32Array(), PackedInt64Array(), 7)
		if not empty is PackedInt64Array or not empty.is_empty():
			failures.append("Native empty topology did not produce an independently owned empty result.")
	return failures


static func _success(masks: PackedInt64Array, backend: StringName) -> Dictionary:
	return {"ok": true, "error": &"", "backend": backend, "masks": masks}


static func _check_workers(backend: StringName, masks14: PackedInt64Array) -> Array[String]:
	var failures: Array[String] = []
	var entered := Semaphore.new()
	var resume := Semaphore.new()
	var threads: Array[Thread] = []
	var expected: Array[PackedInt64Array] = [scalar_masks(workload(8)), masks14]
	for walls: int in [8, 14]:
		var thread := Thread.new()
		if thread.start(_pending_batch.bind(walls, entered, resume)) != OK:
			failures.append("Could not start both visibility workers.")
			break
		threads.append(thread)
	for thread: Thread in threads:
		entered.wait()
	# The owner supersedes revision 0 while both jobs are outstanding. Join before disposal.
	var current_revision: int = 1
	for thread: Thread in threads:
		resume.post()
	var published: Array[PackedInt64Array] = []
	for revision: int in range(threads.size()):
		var result: Dictionary = threads[revision].wait_to_finish()
		if result != _success(expected[revision], backend):
			failures.append("Concurrent worker returned wrong masks, order or backend.")
		if revision == current_revision:
			published.append(result.get("masks", PackedInt64Array()))
	if published != [masks14]:
		failures.append("Superseded work was published or the current revision was lost.")
	return failures


static func _pending_batch(walls: int, entered: Semaphore, resume: Semaphore) -> Dictionary:
	var topology: GFSegmentVisibility2D = workload(walls)
	entered.post()
	resume.wait()
	var empty := PackedInt64Array()
	if topology.compute_pair_masks(3485) != {"ok": false, "error": &"pair_budget_exceeded", "backend": &"", "masks": empty}:
		return {}
	if topology.compute_pair_masks(3486, 3486 * walls - 1) != {"ok": false, "error": &"segment_budget_exceeded", "backend": &"", "masks": empty}:
		return {}
	var first: Dictionary = topology.compute_pair_masks(3486, 3486 * walls)
	var second: Dictionary = topology.compute_pair_masks(3486, 3486 * walls)
	if not first.get("ok") or first != second or first.masks.size() != 3486:
		return {}
	second.masks[0] = -1
	if second.masks[0] != -1 or first.masks[0] < 0:
		return {}
	return first


static func workload(barrier_count: int, factory: Callable = Callable()) -> Variant:
	# Four fixed solids plus associated and anonymous oblique barriers, across four layers.
	var points: Array[Vector2i] = []
	var ids: PackedInt64Array = PackedInt64Array()
	if ids.resize(84) != OK:
		return null
	for y: int in range(7):
		for x: int in range(12):
			ids[points.size()] = _id_at(points.size())
			points.append(Vector2i(12 * x + y % 3, 13 * y + x % 3))
	var walls: Array[Dictionary] = []
	var layers: PackedInt64Array = PackedInt64Array([1, 2, 4, 8, 3, 6, 12, 15])
	for k: int in range(barrier_count):
		var a: int = (5 * k + 1) % points.size()
		var b: int = (17 * k + 3) % points.size()
		var wall: Dictionary = {"blocked_mask": layers[k % layers.size()]}
		if k < 4:
			wall["from"] = Vector2i(17 + 31 * k, -10)
			wall["to"] = Vector2i(17 + 31 * k, 114)
		else:
			wall["to"] = points[b]
			wall["to_id"] = ids[b]
			if k % 3 == 0:
				wall["from"] = points[a] + Vector2i(-3, 5)
			else:
				wall["from"] = points[a]
				wall["from_id"] = ids[a]
		walls.append(wall)
	if factory.is_valid():
		return factory.call(ids, points, walls, 15)
	return GFSegmentVisibility2D.create(ids, points, walls, 15)


static func scalar_masks(topology: GFSegmentVisibility2D) -> PackedInt64Array:
	var masks: PackedInt64Array = PackedInt64Array()
	if masks.resize(3486) != OK:
		return masks
	var index: int = 0
	for i: int in range(84):
		for j: int in range(i + 1, 84):
			masks[index] = topology.get_visible_mask(_id_at(j), _id_at(i))
			index += 1
	return masks


static func _id_at(row: int) -> int:
	return -1 if row == 0 else (1 << 60) + 17 * row
