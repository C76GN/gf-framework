extends RefCounted


static func check(expect_native: bool) -> Array[String]:
	var failures: Array[String] = []
	if Engine.has_singleton(&"GfWfcEntropyBackend") != expect_native:
		failures.append("Unexpected installed WFC entropy capability.")
		return failures
	var tiles: Array = ["A", &"B"]
	var rules: Array[Dictionary] = []
	var defaults: Dictionary = _compare(failures, Vector2i(2, 1), tiles, rules, {"seed": 12345})
	if defaults.get("grid") != {Vector2i.ZERO: &"A", Vector2i.RIGHT: &"B"}:
		failures.append("Empty rules must admit both tiles in seeded declaration order.")
	for heuristic: StringName in [&"entropy", &"mrv", &"scanline"]:
		var partial: Dictionary = _compare(failures, Vector2i(3, 2), tiles, rules,
			{"seed": 12345, "heuristic": heuristic, "max_steps": 1})
		var first := Vector2i.ZERO if heuristic == &"scanline" else Vector2i(1, 1)
		if partial.get("status") != &"step_limit" or partial.get("grid") != {first: &"B"}:
			failures.append("Incorrect seeded partial grid for " + str(heuristic))
	var directional: Array[Dictionary] = [{"from": "A", "to": &"B", "direction": "east", "bidirectional": false}]
	var fixed: Dictionary = {Vector2i.RIGHT: "B"}
	var directed: Dictionary = _compare(failures, Vector2i(2, 1), tiles, directional, {"fixed_cells": fixed})
	if not directed.get("ok") or directed.get("step_count") != 0 or directed.get("grid") != defaults.get("grid"):
		failures.append("A directed rule must also constrain the source of a fixed neighbor.")
	fixed[Vector2i.ZERO] = "B"
	var conflict: Dictionary = _compare(failures, Vector2i(2, 1), tiles, directional, {"fixed_cells": fixed})
	if conflict.get("contradiction_cell") != Vector2i.ZERO or conflict.get("error") != "neighbor domain became empty.":
		failures.append("Contradiction location must follow fixed-cell insertion order.")
	var invalid_fixed: Dictionary = _compare(failures, Vector2i(2, 1), tiles, rules,
		{"fixed_cells": {Vector2i.RIGHT: "B", Vector2i.LEFT: "A"}})
	if invalid_fixed.get("status") != &"invalid_input" or invalid_fixed.get("grid") != {Vector2i.RIGHT: &"B"}:
		failures.append("Invalid fixed-cell reports must retain earlier fixed tiles.")
	var invalid_weight: Dictionary = _compare(failures, Vector2i.ONE, [{"id": 7, "weight": 0.0}], rules, {})
	if invalid_weight.get("error") != "tile weight must be a finite positive number.":
		failures.append("Tile weight validation lost its diagnostic.")
	var large: Dictionary = _compare(failures, Vector2i(4097, 1), [1], rules, {"max_cells": 4097})
	if large.get("collapsed_count") != 4097:
		failures.append("A caller-approved grid beyond the native budget must solve.")
	for count: int in [63, 64, 65, 127, 128, 129]:
		var wide: Array = range(count)
		var last: int = count - 1
		var report: Dictionary = _compare(failures, Vector2i(3, 1), wide, rules,
			{"fixed_cells": {Vector2i.ZERO: last}, "seed": -4294967297, "max_steps": 1, "max_tiles": 200, "max_cells": 99})
		if report.get("status") != &"step_limit" or report["grid"].get(Vector2i.ZERO) != last or report.get("max_tiles") != 200:
			failures.append("Lost a high tile bit or the caller's budget at %d tiles." % count)
	var maximum: Dictionary = _compare(failures, Vector2i(64, 64), range(128), rules, {"max_steps": 1, "seed": 17})
	if maximum.get("status") != &"step_limit" or maximum.get("undecided_count") != 4095:
		failures.append("The full-size partial report lost undecided cells.")
	else:
		var snapshots: Dictionary = maximum["domains"]
		var unresolved: Array[Array] = []
		for cell: Vector2i in snapshots:
			var candidates: Array = snapshots[cell]
			if candidates.size() == 128:
				unresolved.append(candidates)
				if unresolved.size() == 2:
					break
		if unresolved.size() != 2:
			failures.append("Full-width candidate lists are missing from the partial report.")
		else:
			unresolved[0].clear()
			if unresolved[1] != range(128):
				failures.append("Public candidate lists must be independent and ordered.")
	# Scaled entropy can contain a zero after underflow. The portable implementation owns that outcome.
	var extremes: Array = [{"id": 7, "weight": 1.0e-300}, {"id": &"7", "weight": 1.0e308}]
	var _extreme: Dictionary = _compare(failures, Vector2i(3, 2), extremes, rules, {"periodic": true, "seed": -1})
	if expect_native:
		var backend: Object = Engine.get_singleton(&"GfWfcEntropyBackend")
		if backend.call(&"protocol_version") != 1:
			failures.append("Unexpected WFC protocol version.")
		var weights := PackedFloat64Array([1.0, 1.0])
		var unrestricted: Variant = backend.call(&"solve_entropy", Vector2i(2, 1), PackedInt64Array(), weights, PackedInt32Array(), 12345, 8, false)
		if unrestricted != PackedInt64Array([2, -1, 1, 2]):
			failures.append("Native entropy protocol must return ordered domain words for empty rules.")
		var invalid: Variant = backend.call(&"solve_entropy", Vector2i.ONE, PackedInt64Array([1]), weights, PackedInt32Array(), 0, 1, false)
		if invalid != PackedInt64Array():
			failures.append("Native entropy accepted a truncated direction mask.")
	return failures


static func _compare(failures: Array[String], size: Vector2i, tiles: Array, rules: Array[Dictionary], options: Dictionary) -> Dictionary:
	var solve: Callable = GFWaveFunctionCollapse2D.solve_grid.bind(size, tiles, rules, options)
	var main: Dictionary = solve.call()
	var worker := Thread.new()
	if worker.start(solve) != OK:
		failures.append("Failed to start WFC worker.")
	elif worker.wait_to_finish() != main:
		failures.append("WFC main and worker reports differ for %s, %d tiles, %s." % [size, tiles.size(), options])
	return main
