extends RefCounted


static func check(expect_native: bool) -> Array[String]:
	var failures: Array[String] = []
	const SERVICE: StringName = &"GfSegmentVisibilityBackend"
	if Engine.has_singleton(SERVICE) != expect_native:
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
	if small == null or small.compute_pair_masks().get("masks") != PackedInt64Array([2]):
		failures.append("Incorrect single-pair batch with a point obstacle.")
	var topology: GFSegmentVisibility2D = workload(14)
	if topology == null:
		failures.append("Could not prepare the bounded visibility workload.")
		return failures
	var scalar: Dictionary = scalar_report(topology)
	if topology.compute_pair_masks() != scalar:
		failures.append("Packed masks disagree with stable-ID scalar queries.")
	var worker: Thread = Thread.new()
	if worker.start(topology.compute_pair_masks) != OK:
		failures.append("Could not start the portable visibility worker.")
	elif worker.wait_to_finish() != scalar:
		failures.append("Worker visibility masks disagree with the scalar reference.")
	if expect_native:
		var service: Object = Engine.get_singleton(SERVICE)
		if service.call(&"protocol_version") != 1:
			failures.append("Unexpected segment visibility protocol.")
		var invalid: Variant = service.call(&"compute_pair_masks", PackedInt32Array([1]),
				PackedInt32Array(), PackedInt64Array(), 7)
		if invalid != ERR_INVALID_PARAMETER:
			failures.append("Native visibility accepted a partial coordinate.")
	return failures


static func workload(barrier_count: int) -> GFSegmentVisibility2D:
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
	return GFSegmentVisibility2D.create(ids, points, walls, 15)


static func scalar_report(topology: GFSegmentVisibility2D) -> Dictionary:
	var masks: PackedInt64Array = PackedInt64Array()
	if masks.resize(3486) != OK:
		return {}
	var index: int = 0
	for i: int in range(84):
		for j: int in range(i + 1, 84):
			masks[index] = topology.get_visible_mask(_id_at(j), _id_at(i))
			index += 1
	return {"ok": true, "error": &"", "masks": masks}


static func _id_at(row: int) -> int:
	return -1 if row == 0 else (1 << 60) + 17 * row
