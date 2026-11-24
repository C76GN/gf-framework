extends Node


var _failures: Array[String] = []


func _ready() -> void:
	var token: String = ProjectSettings.get_setting("gf_native_acceptance/run_token", "")
	if not token.is_empty():
		print("GF_NATIVE_STARTED=" + token)
	_failures.append_array(preload("res://tests/native/terrain_rgb/acceptance.gd").check(true))
	_failures.append_array(preload("res://tests/native/wfc_entropy/acceptance.gd").check(true))
	_failures.append_array(preload("res://tests/native/row_match/acceptance.gd").check(true))
	var automatic: GFDataBatchPublication = GFDataBatchPublication.create(
		_schema(),
		&"automatic",
		1,
		8,
		1024
	)
	if automatic == null or automatic.get_debug_snapshot().get("backend_selected") != true:
		push_error("The default publication did not select the installed native service.")
		get_tree().quit(1)
		return
	var scripted: GFDataBatchPublication = _owner(null)
	_expect(scripted.get_debug_snapshot().get("backend_selected") == false, "Explicit null selects script.")
	_expect(
		_publish(automatic, _columns(2), 2, PackedInt32Array([1]), 1) == OK,
		"The default publication must gather through the installed backend."
	)
	_check_worker_gather(automatic, OK)
	automatic.close()
	scripted.close()
	var backend: GFDataBatchNativeBackend = GFDataBatchNativeBackend.create()
	if backend == null:
		push_error("Required native gather backend is unavailable.")
		get_tree().quit(1)
		return
	_check_shared_service(backend)
	var required_owner: GFDataBatchPublication = _owner(backend)
	_check_worker_gather(required_owner, ERR_UNAVAILABLE)
	required_owner.close()
	for count: int in [
		0,
		1,
		33,
		1000,
	]:
		_check_case(backend, count)
	var samples: Array[Dictionary] = []
	for count: int in [
		16,
		1000,
		100000,
	]:
		samples.append(_benchmark(backend, count))
	var invalid: Array = backend.gather(
		[
			PackedInt64Array([1]),
		],
		PackedInt32Array([-1]),
		1
	)
	_expect(
		invalid.is_empty(),
		"Native negative index must be rejected."
	)
	invalid = backend.gather(
		[
			PackedInt64Array([1, 2]),
		],
		PackedInt32Array([1]),
		1
	)
	_expect(
		invalid.is_empty(),
		"Native bounds use count rather than capacity."
	)
	var foundation: Dictionary = _foundation_timings() if not token.is_empty() else {}
	var row_match_samples: Array[Dictionary] = preload("res://tests/native/row_match/acceptance.gd").benchmark(_failures)
	var report: Dictionary = {
		"ok": _failures.is_empty(),
		"failures": _failures,
		"samples": samples,
		"row_match_samples": row_match_samples,
		"platform": OS.get_name(),
		"debug_build": OS.is_debug_build(),
		"architecture": Engine.get_architecture_name(),
		"run_token": token,
		"foundation": foundation,
	}
	var encoded: String = JSON.stringify(report)
	if not token.is_empty():
		var file: FileAccess = FileAccess.open("user://gf-native-" + token + ".json", FileAccess.WRITE)
		if file != null:
			file.store_string(encoded)
			file.close()
	print("GF_NATIVE_DATA_BATCH=" + encoded)
	queue_free()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _exit_tree() -> void:
	var token: String = ProjectSettings.get_setting("gf_native_acceptance/run_token", "")
	if not token.is_empty():
		print("GF_NATIVE_FINISHED=" + token)


func _foundation_timings() -> Dictionary:
	var image: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	image.fill(Color8(61, 123, 217))
	var decode: Callable = GFHeightfield3D.samples_from_terrain_rgb_image.bind(image)
	var adjacency_rules: Array[Dictionary] = []
	var solve: Callable = GFWaveFunctionCollapse2D.solve_grid.bind(Vector2i(16, 16), [0, 1, 2, 3], adjacency_rules, {"seed": 927})
	return {"terrain_rgb_256": _time_public_paths(decode), "wfc_entropy_16": _time_public_paths(solve)}


func _time_public_paths(operation: Callable) -> Dictionary:
	var native_usec: Array[int] = []
	var script_usec: Array[int] = []
	for sample: int in range(6):
		var native: Dictionary = {}
		if sample % 2 == 0:
			native = _timed_call(operation)
		var worker: Thread = Thread.new()
		if worker.start(_timed_call.bind(operation)) != OK:
			_failures.append("Could not start the portable performance case.")
			break
		var scripted: Dictionary = worker.wait_to_finish()
		if sample % 2 == 1:
			native = _timed_call(operation)
		_expect(native.result.get("ok") == true and native.result == scripted.result, "Timed public reports differ.")
		if sample > 0:
			native_usec.append(native.usec)
			script_usec.append(scripted.usec)
	return {"script_usec": script_usec, "native_usec": native_usec}


func _timed_call(operation: Callable) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = operation.call()
	return {"usec": Time.get_ticks_usec() - started, "result": result}


func _check_worker_gather(owner: GFDataBatchPublication, expected: Error) -> void:
	var worker: Thread = Thread.new()
	var gather: Callable = owner.publish_gather_copy.bind(_columns(2), 2, 5, PackedInt32Array([1]), 2, 2)
	if worker.start(gather) != OK:
		_expect(false, "Could not start the gather worker.")
		return
	var result: Variant = worker.wait_to_finish()
	_expect(result == expected, "The publisher must honor its backend policy on a serial worker.")
	if expected == OK:
		_expect(owner.get_current().copy_int32_column(0) == PackedInt32Array([2147483647]), "The worker must publish the selected row.")
	else:
		_expect(owner.get_last_failure() == GFDataBatchPublication.Failure.WRONG_THREAD, "A required backend must reject worker use.")


func _check_shared_service(backend: GFDataBatchBackend) -> void:
	var second: GFDataBatchNativeBackend = GFDataBatchNativeBackend.create()
	if second == null:
		_expect(false, "A second adapter must connect to the installed service.")
		return
	var first_owner: GFDataBatchPublication = _owner(backend)
	var second_owner: GFDataBatchPublication = _owner(second)
	if first_owner == null or second_owner == null:
		_expect(false, "Both adapters must support the required publication schema.")
		return
	var columns: Dictionary = _columns(2)
	var indices: PackedInt32Array = PackedInt32Array([1])
	var first_result: Error = _publish(
		first_owner,
		columns,
		2,
		indices,
		7
	)
	_expect(first_result == OK, "First publisher could not gather.")
	first_owner.close()
	var second_result: Error = _publish(
		second_owner,
		columns,
		2,
		indices,
		1
	)
	_expect(
		second_result == OK,
		"Closing another publisher must preserve the service and this publisher's revision."
	)
	second_owner.close()


func _schema() -> GFDataBatchSchema:
	return GFDataBatchSchema.create(
		&"native.acceptance",
		1,
		[&"small", &"large"],
		PackedInt32Array([GFDataBatchSchema.NumericType.INT32, GFDataBatchSchema.NumericType.INT64])
	)


func _owner(backend: GFDataBatchBackend, benchmark: bool = false) -> GFDataBatchPublication:
	var schema: GFDataBatchSchema = _schema()
	if benchmark:
		schema = GFDataBatchSchema.create(
			&"native.benchmark",
			1,
			[
				&"a",
				&"b",
				&"c",
				&"d",
			],
			PackedInt32Array(
				[
					GFDataBatchSchema.NumericType.INT64,
					GFDataBatchSchema.NumericType.INT64,
					GFDataBatchSchema.NumericType.INT64,
					GFDataBatchSchema.NumericType.INT64,
				]
			)
		)
	return GFDataBatchPublication.create(
		schema,
		&"acceptance",
		1,
		200000,
		16 * 1024 * 1024,
		backend,
		backend != null
	)


func _columns(count: int) -> Dictionary:
	var small: PackedInt32Array = PackedInt32Array()
	var large: PackedInt64Array = PackedInt64Array()
	var _small_size: Error = small.resize(count + 3) as Error
	var _large_size: Error = large.resize(count + 3) as Error
	for index: int in range(count):
		small[index] = -2147483648 + index
		large[index] = 9223372036854775807 - index
	if count > 1:
		small[1] = 2147483647
		large[1] = -9223372036854775807 - 1
	return { &"small": small, &"large": large }


func _publish(
	owner: GFDataBatchPublication,
	columns: Dictionary,
	count: int,
	indices: PackedInt32Array,
	revision: int
) -> Error:
	return owner.publish_gather_copy(
		columns,
		count,
		count + 3,
		indices,
		revision,
		revision
	)


func _check_case(backend: GFDataBatchBackend, count: int) -> void:
	var script_owner: GFDataBatchPublication = _owner(null)
	var native_owner: GFDataBatchPublication = _owner(backend)
	var columns: Dictionary = _columns(count)
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(
		count - 1,
		-1,
		-1
	):
		var _added: bool = indices.append(index)
	if count > 0:
		var _duplicate: bool = indices.append(0)
	var script_error: Error = _publish(
		script_owner,
		columns,
		count,
		indices,
		1
	)
	var native_error: Error = _publish(
		native_owner,
		columns,
		count,
		indices,
		1
	)
	_expect(
		script_error == OK and native_error == OK,
		"Valid gather must publish on both paths."
	)
	if script_error != OK or native_error != OK:
		return
	var expected: GFDataBatchSnapshot = script_owner.get_current()
	var actual: GFDataBatchSnapshot = native_owner.get_current()
	_expect(
		actual.copy_int32_column(0) == expected.copy_int32_column(0),
		"Int32 values/order differ."
	)
	_expect(
		actual.copy_int64_column(1) == expected.copy_int64_column(1),
		"Int64 extrema/order differ."
	)
	var original: PackedInt64Array = actual.copy_int64_column(1)
	var input: PackedInt64Array = columns[&"large"]
	input[0] = 7
	_expect(
		actual.copy_int64_column(1) == original,
		"Source writes changed published native output."
	)
	var reader_copy: PackedInt64Array = actual.copy_int64_column(1)
	if not reader_copy.is_empty():
		reader_copy[0] = 8
	_expect(
		actual.copy_int64_column(1) == original,
		"Reader copy changed published native output."
	)
	for rejected: int in [-1, count]:
		var invalid: PackedInt32Array = PackedInt32Array([rejected])
		script_error = _publish(
			script_owner,
			columns,
			count,
			invalid,
			2
		)
		native_error = _publish(
			native_owner,
			columns,
			count,
			invalid,
			2
		)
		_expect(
			script_error == native_error and native_error != OK,
			"Invalid selection errors differ."
		)
		_expect(
			native_owner.get_current() == actual,
			"Rejected input replaced the current native snapshot."
		)
	_expect(
		_publish(
			native_owner,
			columns,
			count,
			indices,
			1
		) != OK,
		"Stale revision accepted."
	)
	native_owner.close()
	_expect(
		actual.copy_int64_column(1) == original,
		"Close invalidated retained output."
	)
	_expect(
		_publish(
			native_owner,
			columns,
			count,
			indices,
			2
		) == ERR_UNAVAILABLE,
		"Closed publication accepted work."
	)


func _benchmark(backend: GFDataBatchBackend, count: int) -> Dictionary:
	var script_owner: GFDataBatchPublication = _owner(null, true)
	var native_owner: GFDataBatchPublication = _owner(backend, true)
	var columns: Dictionary = {}
	for name_value: StringName in [
		&"a",
		&"b",
		&"c",
		&"d",
	]:
		var column: PackedInt64Array = PackedInt64Array()
		var _size_error: Error = column.resize(count + 3) as Error
		for row: int in range(count):
			column[row] = 9223372036854775807 - row
		columns[name_value] = column
	var indices: PackedInt32Array = PackedInt32Array()
	var _resized: Error = indices.resize(count >> 1) as Error
	for index: int in range(indices.size()):
		indices[index] = count - 1 - index
	var script_samples: Array[int] = []
	var native_samples: Array[int] = []
	var revision: int = 0
	for sample: int in range(12):
		for native_first: bool in [sample % 2 == 0, sample % 2 != 0]:
			revision += 1
			var owner: GFDataBatchPublication = native_owner if native_first else script_owner
			var start: int = Time.get_ticks_usec()
			var error: Error = _publish(
				owner,
				columns,
				count,
				indices,
				revision
			)
			var duration: int = Time.get_ticks_usec() - start
			_expect(
				error == OK,
				"Benchmark publication failed."
			)
			if sample >= 2:
				if native_first:
					native_samples.append(duration)
				else:
					script_samples.append(duration)
	for column_index: int in range(4):
		_expect(
			native_owner.get_current().copy_int64_column(column_index) == script_owner.get_current().copy_int64_column(column_index),
			"Benchmark output differs."
		)
	return {
		"source_rows": count,
		"selected_rows": indices.size(),
		"int64_columns": 4,
		"script_usec": script_samples,
		"native_usec": native_samples,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
