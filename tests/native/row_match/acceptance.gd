extends RefCounted


static func check(expect_native: bool) -> Array[String]:
	var failures: Array[String] = []
	const SERVICE: StringName = &"GfDataBatchRowMatchBackend"
	if Engine.has_singleton(SERVICE) != expect_native:
		failures.append("Unexpected installed row-match capability.")
		return failures
	var previous: PackedInt64Array = PackedInt64Array([20, -1, 9223372036854775807, 20])
	var current: PackedInt64Array = PackedInt64Array([-1, -2, 20, 9223372036854775807, -2])
	var expected: PackedInt32Array = PackedInt32Array([1, -1, 0, 2])
	var good: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(previous, 3, current, 4)
	var duplicate: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(previous, 3, current, 5)
	var empty: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(previous, 3, current, 0)
	if good.error != OK or good.previous_rows != expected or empty.error != OK or not empty.previous_rows.is_empty():
		failures.append("Public row match lost valid rows, ID precision or empty success.")
	if duplicate.error != ERR_INVALID_DATA or not duplicate.previous_rows.is_empty():
		failures.append("Public row match accepted duplicate current IDs.")
	if expect_native:
		var backend: Object = Engine.get_singleton(SERVICE)
		if backend.call(&"protocol_version") != 1 or backend.call(&"match_ids", previous, 3, current, 4) != expected:
			failures.append("Native row-match protocol or signed-ID mapping differs.")
		if backend.call(&"match_ids", previous, 4, current, 0) != ERR_INVALID_DATA:
			failures.append("Native row match skipped previous-column validation for an empty current column.")
		if backend.call(&"match_ids", previous, -1, current, 4) != ERR_INVALID_PARAMETER or backend.call(&"match_ids", previous, 3, current, 6) != ERR_INVALID_PARAMETER:
			failures.append("Native row match accepted an invalid prefix.")
	return failures


static func benchmark(failures: Array[String]) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for count: int in [16, 4096, 65536]:
		for reordered: bool in [false, true]:
			var previous: PackedInt64Array = PackedInt64Array()
			var current: PackedInt64Array = PackedInt64Array()
			var expected: PackedInt32Array = PackedInt32Array()
			for row: int in range(count):
				var _previous_appended: bool = previous.append((1 << 60) + 2 * row)
				# An odd stride permutes each power-of-two fixture exactly once.
				var old_row: int = (row * 251 + 7) % count if reordered else row
				var is_new: bool = old_row % 8 == 0
				var _current_appended: bool = current.append((1 << 60) + 2 * old_row + int(is_new))
				var _expected_appended: bool = expected.append(-1 if is_new else old_row)
			var operation: Callable = GFDataBatchRowMatch.match_ids.bind(previous, count, current, count)
			var repeats: int = 64 if count == 16 else 1
			var timed: Callable = _time_calls.bind(operation, repeats)
			var automatic_usec: Array[int] = []
			var script_usec: Array[int] = []
			for sample: int in range(11):
				var automatic: Dictionary = {}
				if sample % 2 == 0:
					automatic = timed.call()
				var worker: Thread = Thread.new()
				if worker.start(timed) != OK:
					failures.append("Could not start the row-match script worker.")
					return samples
				var scripted: Dictionary = worker.wait_to_finish()
				if sample % 2 == 1:
					automatic = timed.call()
				for measured: Dictionary in [automatic, scripted]:
					var result: GFDataBatchRowMatch = measured.result
					if result.error != OK or result.previous_rows != expected:
						failures.append("Timed row match differs from the expected rows.")
						return samples
				if sample >= 2:
					automatic_usec.append(automatic.usec)
					script_usec.append(scripted.usec)
			samples.append({
				"rows": count, "reordered": reordered, "calls_per_sample": repeats,
				"automatic_usec": automatic_usec, "script_usec": script_usec,
			})
	return samples


static func _time_calls(operation: Callable, repeats: int) -> Dictionary:
	var result: GFDataBatchRowMatch
	var start: int = Time.get_ticks_usec()
	for iteration: int in range(repeats):
		result = operation.call()
	return {"usec": Time.get_ticks_usec() - start, "result": result}
